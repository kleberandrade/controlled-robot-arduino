// Run explicitly; this writes a real Flutter-rendered documentation screenshot.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robot_controller/bluetooth_radio.dart';
import 'package:robot_controller/controller.dart';
import 'package:robot_controller/main.dart';
import 'package:robot_controller/protocol.dart';

void main() {
  testWidgets('capture the demo screen with production widgets', (
    tester,
  ) async {
    final fonts = Platform.environment['ROBOT_FONT_DIR'];
    if (fonts == null) {
      throw StateError(
        'Set ROBOT_FONT_DIR to Flutter SDK bin/cache/artifacts/material_fonts',
      );
    }
    await tester.runAsync(() async {
      for (final family in {
        'Roboto': [
          'Roboto-Regular.ttf',
          'Roboto-Medium.ttf',
          'Roboto-Bold.ttf',
        ],
        'MaterialIcons': ['MaterialIcons-Regular.otf'],
      }.entries) {
        final loader = FontLoader(family.key);
        for (final name in family.value) {
          loader.addFont(
            File(
              '$fonts/$name',
            ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
          );
        }
        await loader.load();
      }
    });
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = RobotController(BluetoothRadio());
    const screen = Key('screenshot');
    await tester.pumpWidget(
      RepaintBoundary(
        key: screen,
        child: RobotApp(controller: c),
      ),
    );
    await tester.tap(find.text('Start demo'));
    await tester.pumpAndSettle();
    final held = await tester.startGesture(
      tester.getCenter(find.text('Forward')),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(c.isDemo, isTrue);
    expect(c.desired, Movement.forward);
    expect(c.reported, 'OK F');
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(screen),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) throw StateError('Could not encode the screenshot');
      await File(
        '../docs/screenshots/demo-mode.png',
      ).writeAsBytes(png.buffer.asUint8List());
      image.dispose();
    });
    await held.up();
    await tester.pump();
    expect(c.desired, Movement.stop);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
