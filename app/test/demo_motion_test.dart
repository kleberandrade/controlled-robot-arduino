import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:robot_controller/demo_motion.dart';
import 'package:robot_controller/protocol.dart';

void main() {
  test('forward, reverse, pivot and stop update the illustrated pose', () {
    const origin = DemoPose();
    final forward = origin.advance(Movement.forward, 1);
    expect(forward.x, 0);
    expect(forward.y, lessThan(0));
    final returned = forward.advance(Movement.backward, 1);
    expect(returned.y, closeTo(0, 1e-10));
    final right = origin.advance(Movement.right, 1);
    expect(right.heading, closeTo(math.pi / 2, 1e-10));
    expect(right.x, 0);
    expect(right.y, 0);
    final east = right.advance(Movement.forward, 1);
    expect(east.x, greaterThan(0));
    expect(east.y, closeTo(0, 1e-10));
    final left = origin.advance(Movement.left, 1);
    expect(left.heading, closeTo(3 * math.pi / 2, 1e-10));
    expect(left.advance(Movement.forward, 1).x, lessThan(0));
    expect(identical(east.advance(Movement.stop, 10), east), isTrue);
  });
  test('arena bounds and headings stay bounded during long holds', () {
    const origin = DemoPose();
    expect(origin.advance(Movement.forward, 100).y, -1);
    expect(origin.advance(Movement.backward, 100).y, 1);
    final turned = origin.advance(Movement.right, 1000.5);
    expect(turned.heading, inInclusiveRange(0, 2 * math.pi));
    expect(turned.advance(Movement.forward, 100).x, inInclusiveRange(-1, 1));
    expect(origin.advance(Movement.forward, 0), same(origin));
    expect(origin.advance(Movement.forward, double.nan), same(origin));
    expect(origin.advance(Movement.forward, -1), same(origin));
  });
}
