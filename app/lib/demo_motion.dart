import 'dart:math' as math;
import 'protocol.dart';

/// Illustrative arena coordinates, not measured distance or robot dynamics.
class DemoPose {
  const DemoPose({this.x = 0, this.y = 0, this.heading = 0});
  final double x, y;

  /// Clockwise radians from the top of the preview.
  final double heading;

  DemoPose advance(Movement movement, double seconds) {
    if (seconds <= 0 || !seconds.isFinite || movement == Movement.stop) {
      return this;
    }
    if (movement == Movement.left || movement == Movement.right) {
      final turn = movement == Movement.right ? 1 : -1;
      return DemoPose(
        x: x,
        y: y,
        heading: (heading + turn * math.pi / 2 * seconds) % (2 * math.pi),
      );
    }
    final distance = (movement == Movement.forward ? 1 : -1) * 0.8 * seconds;
    return DemoPose(
      x: (x + math.sin(heading) * distance).clamp(-1.0, 1.0),
      y: (y - math.cos(heading) * distance).clamp(-1.0, 1.0),
      heading: heading,
    );
  }
}
