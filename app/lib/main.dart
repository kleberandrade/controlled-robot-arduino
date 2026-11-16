import 'dart:async';
import 'package:flutter/material.dart';
import 'bluetooth_radio.dart';
import 'controller.dart';
import 'protocol.dart';

void main() => runApp(RobotApp(controller: RobotController(BluetoothRadio())));

class RobotApp extends StatelessWidget {
  const RobotApp({super.key, required this.controller});
  final RobotController controller;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Controlled Robot',
    theme: ThemeData(colorSchemeSeed: Colors.teal),
    home: RobotPage(controller: controller),
  );
}

class RobotPage extends StatefulWidget {
  const RobotPage({super.key, required this.controller});
  final RobotController controller;
  @override
  State<RobotPage> createState() => _RobotPageState();
}

class _RobotPageState extends State<RobotPage> with WidgetsBindingObserver {
  List<PairedRobot> _devices = [];
  String? _selected, _error;
  bool _loading = false;
  int? _pointer;
  RobotController get c => widget.controller;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _pointer = null;
      unawaited(c.disconnect());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    c.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final devices = await c.radio.paired();
      if (mounted) {
        setState(() {
          _devices = devices;
          _selected = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _settings() async {
    try {
      await c.radio.settings();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Widget _direction(String label, Movement movement) => Listener(
    onPointerDown: (event) {
      if (_pointer == null && c.canMove) {
        _pointer = event.pointer;
        c.move(movement);
      }
    },
    onPointerUp: _release,
    onPointerCancel: _release,
    child: Semantics(
      label: 'Hold $label to move; release to stop',
      child: SizedBox(
        width: 112,
        height: 64,
        child: FilledButton(
          onPressed: c.canMove ? () {} : null,
          child: Text(label),
        ),
      ),
    ),
  );
  void _release(PointerEvent event) {
    if (_pointer == event.pointer) {
      _pointer = null;
      c.stop();
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: c,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Controlled Robot')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Android • HC-05 Bluetooth Classic SPP'),
                  const SizedBox(height: 12),
                  Text(
                    c.status,
                    key: const Key('status'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text('Firmware: ${c.reported}'),
                  Text('Requested: ${c.desired.name} (not measured motion)'),
                  if (_error != null)
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: c.connected || c.connecting ? null : _settings,
                    child: const Text('Pair in Android settings'),
                  ),
                  OutlinedButton(
                    onPressed: _loading || c.connected || c.connecting
                        ? null
                        : _refresh,
                    child: Text(
                      _loading ? 'Loading…' : 'Refresh paired devices',
                    ),
                  ),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: _selected,
                    hint: const Text('Select your paired HC-05'),
                    items: _devices
                        .map(
                          (d) => DropdownMenuItem(
                            value: d.address,
                            child: Text('${d.name} (${d.address})'),
                          ),
                        )
                        .toList(),
                    onChanged: c.connected || c.connecting
                        ? null
                        : (value) => setState(() => _selected = value),
                  ),
                  FilledButton(
                    onPressed: _selected == null || c.connected || c.connecting
                        ? null
                        : () => c.connect(_selected!),
                    child: const Text('Connect'),
                  ),
                  OutlinedButton(
                    onPressed: c.connected || c.connecting
                        ? () => c.disconnect()
                        : null,
                    child: const Text('Disconnect'),
                  ),
                  const Divider(height: 32),
                  const Text(
                    'Hold a direction. Release to stop. Start with wheels lifted.',
                  ),
                  const SizedBox(height: 12),
                  Center(child: _direction('Forward', Movement.forward)),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _direction('Left', Movement.left),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red.shade800,
                        ),
                        onPressed: () {
                          _pointer = null;
                          c.stop();
                        },
                        child: const SizedBox(
                          height: 48,
                          child: Center(widthFactor: 1, child: Text('STOP')),
                        ),
                      ),
                      _direction('Right', Movement.right),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Center(child: _direction('Backward', Movement.backward)),
                  const SizedBox(height: 20),
                  const Text(
                    'No obstacle detection. Firmware disables motors after 500 ms without a valid command. Backgrounding disconnects. Stop is coast/standby, not an emergency brake.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
