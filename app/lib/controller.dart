import 'dart:async';
import 'package:flutter/foundation.dart';
import 'protocol.dart';

class PairedRobot {
  const PairedRobot(this.name, this.address);
  final String name;
  final String address;
}

abstract interface class RobotLink {
  Stream<List<int>> get bytes;
  Future<void> send(String frame);
  Future<void> close();
}

abstract interface class RobotRadio {
  Future<List<PairedRobot>> paired();
  Future<RobotLink> connect(String address);
  Future<void> settings();
}

class RobotController extends ChangeNotifier {
  RobotController(this.radio);
  final RobotRadio radio;
  RobotLink? _link;
  StreamSubscription<List<int>>? _input;
  Timer? _heartbeat, _feedback;
  bool _ready = false, _disposed = false;
  RobotLink? _writingLink;
  int _epoch = 0;
  bool connecting = false;
  String status = 'Disconnected';
  String reported = 'No firmware feedback';
  Movement desired = Movement.stop;
  bool get connected => _link != null;
  bool get canMove => connected && _ready;
  Future<void> connect(String address) async {
    if (connected || connecting || _disposed) return;
    final epoch = ++_epoch;
    connecting = true;
    status = 'Connecting…';
    _changed();
    try {
      final link = await radio.connect(address);
      if (_disposed || epoch != _epoch) {
        await link.close();
        return;
      }
      _link = link;
      final parser = ReplyParser();
      _input = link.bytes.listen(
        (bytes) {
          for (final line in parser.add(bytes)) {
            if (identical(link, _link)) _reply(line);
          }
        },
        onDone: () {
          if (identical(link, _link)) {
            unawaited(_fail('Bluetooth disconnected'));
          }
        },
        onError: (Object error) {
          if (identical(link, _link)) {
            unawaited(_fail('Bluetooth read failed: $error'));
          }
        },
      );
      status = 'Connected; waiting for firmware';
      _armFeedback();
      _heartbeat = Timer.periodic(const Duration(milliseconds: 100), (_) {
        unawaited(_send());
      });
      await _send();
    } catch (error) {
      if (epoch == _epoch) await _fail('Connection failed: $error');
    } finally {
      if (epoch == _epoch) {
        connecting = false;
        _changed();
      }
    }
  }

  void move(Movement movement) {
    if (!canMove) return;
    desired = movement;
    _changed();
    unawaited(_send());
  }

  void stop() {
    desired = Movement.stop;
    _changed();
    unawaited(_send());
  }

  void _reply(String line) {
    if (line == 'ERR' || line == 'TIMEOUT') {
      unawaited(_fail('Firmware stopped: $line'));
      return;
    }
    if (!Movement.values.any((m) => line == 'OK ${m.code}')) return;
    reported = line;
    if (!_ready && line == 'OK S') _ready = true;
    status = _ready ? 'Connected' : 'Waiting for stop acknowledgement';
    _armFeedback();
    _changed();
  }

  void _armFeedback() {
    _feedback?.cancel();
    _feedback = Timer(const Duration(milliseconds: 700), () {
      unawaited(_fail('No firmware feedback; reconnect required'));
    });
  }

  Future<void> _send() async {
    final link = _link;
    if (link == null || identical(_writingLink, link)) return;
    final movement = desired;
    _writingLink = link;
    try {
      await link
          .send(movement.frame)
          .timeout(const Duration(milliseconds: 300));
    } catch (error) {
      if (identical(link, _link)) await _fail('Bluetooth write failed: $error');
    } finally {
      if (identical(_writingLink, link)) _writingLink = null;
    }
    // Coalesce changes instead of queueing obsolete movement frames.
    if (identical(link, _link) && desired != movement) await _send();
  }

  Future<void> disconnect() => _close('Disconnected', sendStop: true);
  Future<void> _fail(String reason) => _close(reason);
  Future<void> _close(String reason, {bool sendStop = false}) async {
    ++_epoch;
    connecting = false;
    desired = Movement.stop;
    _ready = false;
    _heartbeat?.cancel();
    _feedback?.cancel();
    final link = _link;
    _link = null;
    final input = _input;
    _input = null;
    status = reason;
    _changed();
    // Subscription cleanup must not delay closing the physical transport.
    if (input != null) unawaited(input.cancel().catchError((Object _) {}));
    if (link == null) return;
    try {
      if (sendStop && !identical(_writingLink, link)) {
        await link
            .send(Movement.stop.frame)
            .timeout(const Duration(milliseconds: 300));
      }
    } catch (_) {
      /* Firmware watchdog is the final stop boundary. */
    }
    try {
      await link.close();
    } catch (_) {
      /* Preserve original fault. */
    }
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(disconnect());
    super.dispose();
  }
}
