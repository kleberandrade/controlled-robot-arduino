import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robot_controller/controller.dart';
import 'package:robot_controller/main.dart';
import 'package:robot_controller/protocol.dart';
import 'controller_test.dart' show FakeRadio;

void main() {
  testWidgets(
    'touch controls drive animation, release freezes and background removes it',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final radio = FakeRadio();
      final c = RobotController(radio);
      double y() => tester
          .widget<Transform>(find.byKey(const Key('demo-position')))
          .transform
          .storage[13];
      await tester.pumpWidget(RobotApp(controller: c));
      await tester.tap(find.text('Start demo'));
      await tester.pumpAndSettle();
      final forward = await tester.startGesture(
        tester.getCenter(find.text('Forward')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(y(), lessThan(0));
      await forward.up();
      await tester.pump();
      final stopped = y();
      await tester.pump(const Duration(milliseconds: 500));
      expect(y(), stopped);
      final right = await tester.startGesture(
        tester.getCenter(find.text('Right')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester
            .widget<Transform>(find.byKey(const Key('demo-heading')))
            .transform
            .storage[1],
        greaterThan(0),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(find.byKey(const Key('demo-position')), findsNothing);
      expect(c.desired, Movement.stop);
      expect(radio.connectionCalls, 0);
      await right.cancel();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
  testWidgets('demo controls, STOP, cancel and exit work without Bluetooth', (
    tester,
  ) async {
    final radio = FakeRadio();
    final c = RobotController(radio);
    await tester.pumpWidget(RobotApp(controller: c));
    await tester.tap(find.text('Start demo'));
    await tester.pumpAndSettle();
    expect(find.text('DEMO • No Bluetooth connection'), findsOneWidget);
    expect(find.text('Pair in Android settings'), findsNothing);
    expect(c.isDemo, isTrue);
    expect(c.canMove, isTrue);
    final controls = {
      'Forward': Movement.forward,
      'Left': Movement.left,
      'Right': Movement.right,
      'Backward': Movement.backward,
    };
    for (final entry in controls.entries) {
      await tester.ensureVisible(find.text(entry.key));
      final gesture = await tester.startGesture(
        tester.getCenter(find.text(entry.key)),
      );
      await tester.pump();
      expect(c.desired, entry.value);
      expect(c.reported, 'OK ${entry.value.code}');
      await gesture.up();
      await tester.pump();
      expect(c.desired, Movement.stop);
      expect(c.reported, 'OK S');
    }
    await tester.ensureVisible(find.text('Forward'));
    final held = await tester.startGesture(
      tester.getCenter(find.text('Forward')),
      pointer: 7,
    );
    await tester.pump();
    await tester.tap(find.text('STOP'));
    await tester.pump();
    expect(c.desired, Movement.stop);
    expect(c.reported, 'OK S');
    await held.cancel();
    await tester.pump();
    final cancelled = await tester.startGesture(
      tester.getCenter(find.text('Forward')),
    );
    await tester.pump();
    await cancelled.cancel();
    await tester.pump();
    expect(c.desired, Movement.stop);
    await tester.ensureVisible(find.text('Exit demo'));
    await tester.tap(find.text('Exit demo'));
    await tester.pumpAndSettle();
    expect(c.isDemo, isFalse);
    expect(c.canMove, isFalse);
    expect(radio.connectionCalls, 0);
    await tester.ensureVisible(find.text('Start demo'));
    await tester.tap(find.text('Start demo'));
    await tester.pumpAndSettle();
    expect(c.isDemo, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(c.isDemo, isFalse);
    expect(c.canMove, isFalse);
    expect(c.desired, Movement.stop);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
  testWidgets('paired selection, handshake, hold/release and background stop', (
    tester,
  ) async {
    final radio = FakeRadio();
    final c = RobotController(radio);
    await tester.pumpWidget(RobotApp(controller: c));
    expect(c.canMove, isFalse);
    await tester.tap(find.text('Refresh paired devices'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('robot (00:11:22:33:44:55)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connect'));
    await tester.pump();
    radio.link.reply('OK S\n');
    await tester.pump();
    expect(c.canMove, isTrue);
    await tester.ensureVisible(find.text('Forward'));
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Forward')),
    );
    await tester.pump();
    expect(c.desired, Movement.forward);
    await gesture.up();
    await tester.pump();
    expect(c.desired, Movement.stop);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(c.canMove, isFalse);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 350));
    expect(radio.link.closed, isTrue);
  });
}
