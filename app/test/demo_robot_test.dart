import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robot_controller/demo_robot.dart';
import 'package:robot_controller/protocol.dart';

Offset position(WidgetTester tester) {
  final transform = tester
      .widget<Transform>(find.byKey(const Key('demo-position')))
      .transform;
  return Offset(transform.storage[12], transform.storage[13]);
}

Widget scene(
  Movement movement, {
  bool reducedMotion = false,
  bool paused = false,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reducedMotion),
    child: TickerMode(
      enabled: !paused,
      child: Center(
        child: SizedBox(width: 320, child: DemoRobot(movement: movement)),
      ),
    ),
  ),
);
void main() {
  testWidgets(
    'frames animate movement, stop freezes, and direction changes do not jump',
    (tester) async {
      await tester.pumpWidget(scene(Movement.forward));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final moving = position(tester);
      expect(moving.dy, lessThan(0));
      await tester.pumpWidget(scene(Movement.stop));
      final stopped = position(tester);
      await tester.pump(const Duration(seconds: 5));
      expect(position(tester), stopped);
      await tester.pumpWidget(scene(Movement.right));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final rotation = tester
          .widget<Transform>(find.byKey(const Key('demo-heading')))
          .transform;
      expect(rotation.storage[1], greaterThan(0));
      expect(position(tester), stopped);
      await tester.pumpWidget(scene(Movement.backward));
      expect(position(tester), stopped);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(position(tester).dy, greaterThan(stopped.dy));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('muted frames and long frame gaps do not teleport the preview', (
    tester,
  ) async {
    await tester.pumpWidget(scene(Movement.forward));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    final afterGap = position(tester);
    expect(afterGap.dy, lessThan(0));
    expect(afterGap.dy.abs(), lessThan(5));
    await tester.pumpWidget(scene(Movement.forward, paused: true));
    await tester.pump(const Duration(seconds: 5));
    expect(position(tester), afterGap);
    await tester.pumpWidget(scene(Movement.forward));
    expect(position(tester), afterGap);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(position(tester).dy, lessThan(afterGap.dy));
    await tester.pumpWidget(scene(Movement.stop));
  });
  testWidgets('reduced motion pauses and resumes visual updates', (
    tester,
  ) async {
    await tester.pumpWidget(scene(Movement.forward, reducedMotion: true));
    await tester.pump(const Duration(seconds: 2));
    expect(position(tester), Offset.zero);
    expect(find.text('Animation paused (reduced motion)'), findsOneWidget);
    await tester.pumpWidget(scene(Movement.forward));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(position(tester).dy, lessThan(0));
    await tester.pumpWidget(scene(Movement.stop));
  });
}
