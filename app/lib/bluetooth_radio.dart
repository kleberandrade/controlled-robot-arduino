import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_bluetooth_serial_plus/flutter_bluetooth_serial_plus.dart';
import 'controller.dart';

class BluetoothRadio implements RobotRadio {
  final _bluetooth = FlutterBluetoothSerial.instance;
  Future<void> _prepare() async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('HC-05 SPP requires Android');
    }
    if (!await _bluetooth.ensurePermissions()) {
      throw StateError(
        'Bluetooth permission denied. Allow Nearby devices in app settings.',
      );
    }
    if (await _bluetooth.isEnabled != true &&
        await _bluetooth.requestEnable() != true) {
      throw StateError('Enable Bluetooth in Android settings.');
    }
  }

  @override
  Future<List<PairedRobot>> paired() async {
    await _prepare();
    final devices = await _bluetooth.getBondedDevices();
    return devices
        .map((d) => PairedRobot(d.name ?? 'Unnamed device', d.address))
        .toList();
  }

  @override
  Future<RobotLink> connect(String address) async {
    await _prepare();
    return _BluetoothLink(await BluetoothConnection.toAddress(address));
  }

  @override
  Future<void> settings() => _bluetooth.openSettings();
}

class _BluetoothLink implements RobotLink {
  _BluetoothLink(this.connection);
  final BluetoothConnection connection;
  @override
  Stream<List<int>> get bytes => connection.input;
  @override
  Future<void> send(String frame) async {
    connection.output.add(Uint8List.fromList(frame.codeUnits));
    await connection.output.allSent;
  }

  @override
  Future<void> close() => connection.close();
}
