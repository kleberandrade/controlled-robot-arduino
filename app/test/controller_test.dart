import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:robot_controller/controller.dart';
import 'package:robot_controller/protocol.dart';

class FakeLink implements RobotLink {
  final input = StreamController<List<int>>();
  final sent = <String>[];
  bool closed = false;
  bool fail = false;
  Completer<void>? blocked;
  @override
  Stream<List<int>> get bytes => input.stream;
  @override
  Future<void> send(String frame) async {
    if (fail) throw StateError('write failed');
    sent.add(frame);
    await blocked?.future;
  }

  @override
  Future<void> close() async {
    closed = true;
  }

  void reply(String text) => input.add(text.codeUnits);
}

class FakeRadio implements RobotRadio {
  Completer<RobotLink>? pending;
  final link = FakeLink();
  @override
  Future<List<PairedRobot>> paired() async => [
    const PairedRobot('robot', '00:11:22:33:44:55'),
  ];
  @override
  Future<RobotLink> connect(String address) async =>
      pending == null ? link : await pending!.future;
  @override
  Future<void> settings() async {}
}

void main() {
  test('protocol encodes commands and bounds fragmented replies', () {
    expect(Movement.forward.frame, 'F\n');
    final parser = ReplyParser();
    expect(parser.add('OK '.codeUnits), isEmpty);
    expect(parser.add('F\r\nERR\nTIMEOUT\n'.codeUnits), [
      'OK F',
      'ERR',
      'TIMEOUT',
    ]);
    expect(parser.add(List.filled(500, 65)), isEmpty);
    expect(parser.add('\nOK S\n'.codeUnits), ['OK S']);
  });
  test(
    'connect stops first, holds repeat, release and disconnect stop',
    () async {
      final radio = FakeRadio();
      final c = RobotController(radio);
      await c.connect('00:11:22:33:44:55');
      expect(radio.link.sent, ['S\n']);
      expect(c.canMove, isFalse);
      radio.link.reply('OK S\r\n');
      await Future<void>.delayed(Duration.zero);
      expect(c.canMove, isTrue);
      c.move(Movement.forward);
      await Future<void>.delayed(Duration.zero);
      expect(radio.link.sent.last, 'F\n');
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(
        radio.link.sent.where((s) => s == 'F\n').length,
        greaterThanOrEqualTo(2),
      );
      c.stop();
      await Future<void>.delayed(Duration.zero);
      expect(radio.link.sent.last, 'S\n');
      final closing = c.disconnect();
      await Future<void>.delayed(Duration.zero);
      await closing;
      expect(radio.link.sent.last, 'S\n');
      expect(radio.link.closed, isTrue);
      expect(c.canMove, isFalse);
      c.dispose();
    },
  );
  test('transport closes even when input cancellation stalls', () async {
    final radio = FakeRadio();
    final cancellation = Completer<void>();
    radio.link.input.onCancel = () => cancellation.future;
    final c = RobotController(radio);
    await c.connect('robot');
    await c.disconnect();
    expect(radio.link.closed, isTrue);
    cancellation.complete();
    c.dispose();
  });
  test('cancelled connection never enables or replays movement', () async {
    final radio = FakeRadio()..pending = Completer<RobotLink>();
    final c = RobotController(radio);
    final connection = c.connect('robot');
    await c.disconnect();
    radio.pending!.complete(radio.link);
    await connection;
    expect(c.canMove, isFalse);
    expect(radio.link.closed, isTrue);
    expect(radio.link.sent, isEmpty);
    c.dispose();
  });
  test('blocked write coalesces release and closes on deadline', () async {
    final radio = FakeRadio();
    final c = RobotController(radio);
    await c.connect('robot');
    radio.link.reply('OK S\n');
    await Future<void>.delayed(Duration.zero);
    radio.link.blocked = Completer<void>();
    c.move(Movement.forward);
    c.move(Movement.left);
    c.stop();
    await Future<void>.delayed(const Duration(milliseconds: 350));
    expect(c.canMove, isFalse);
    expect(radio.link.closed, isTrue);
    expect(radio.link.sent.where((s) => s == 'L\n'), isEmpty);
    radio.link.blocked!.complete();
    c.dispose();
  });
  test('missing feedback disconnects and prevents more movement', () async {
    final radio = FakeRadio();
    final c = RobotController(radio);
    await c.connect('robot');
    radio.link.reply('OK S\n');
    await Future<void>.delayed(Duration.zero);
    c.move(Movement.left);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(const Duration(milliseconds: 850));
    await Future<void>.delayed(Duration.zero);
    expect(c.canMove, isFalse);
    expect(radio.link.closed, isTrue);
    expect(c.status, contains('feedback'));
    c.dispose();
  });
  test(
    'firmware rejection stops repetition; write error closes link',
    () async {
      final radio = FakeRadio();
      final c = RobotController(radio);
      await c.connect('robot');
      radio.link.reply('OK S\n');
      await Future<void>.delayed(Duration.zero);
      c.move(Movement.right);
      await Future<void>.delayed(Duration.zero);
      radio.link.reply('ERR\n');
      await Future<void>.delayed(Duration.zero);
      expect(c.desired, Movement.stop);
      expect(c.canMove, isFalse);
      final closing = c.disconnect();
      await Future<void>.delayed(Duration.zero);
      await closing;
      c.dispose();
      final other = FakeRadio();
      final d = RobotController(other);
      await d.connect('robot');
      other.link.reply('OK S\n');
      await Future<void>.delayed(Duration.zero);
      other.link.fail = true;
      d.move(Movement.backward);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(d.canMove, isFalse);
      expect(other.link.closed, isTrue);
      d.dispose();
    },
  );
}
