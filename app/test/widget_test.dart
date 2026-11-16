import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robot_controller/controller.dart';
import 'package:robot_controller/main.dart';
import 'package:robot_controller/protocol.dart';
import 'controller_test.dart' show FakeRadio;

void main() {
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
