import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'demo_motion.dart';
import 'protocol.dart';

class DemoRobot extends StatefulWidget {
  const DemoRobot({super.key, required this.movement});
  final Movement movement;
  @override
  State<DemoRobot> createState() => _DemoRobotState();
}

class _DemoRobotState extends State<DemoRobot>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  DemoPose _pose = const DemoPose();
  Duration _previous = Duration.zero;
  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTicker();
  }

  @override
  void didUpdateWidget(DemoRobot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.movement != widget.movement) _syncTicker();
  }

  void _syncTicker() {
    _ticker.stop();
    _previous = Duration.zero;
    if (widget.movement != Movement.stop &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled) {
      _ticker.start();
    }
  }

  void _tick(Duration elapsed) {
    final previous = _previous;
    _previous = elapsed;
    // Dropped/muted frames must not teleport the robot across the preview.
    final seconds = ((elapsed - previous).inMicroseconds / 1000000).clamp(
      0.0,
      0.1,
    );
    setState(() {
      _pose = _pose.advance(widget.movement, seconds);
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Animated demo robot',
      value: '${widget.movement.name}, illustration only',
      child: Column(
        children: [
          SizedBox(
            height: 150,
            width: double.infinity,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final rangeX = (constraints.maxWidth / 2 - 36).clamp(
                  0.0,
                  double.infinity,
                );
                const rangeY = 150 / 2 - 36;
                return ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ColoredBox(
                    color: colors.surface,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _ArenaPainter(colors.outlineVariant),
                          ),
                        ),
                        Transform.translate(
                          key: const Key('demo-position'),
                          offset: Offset(_pose.x * rangeX, _pose.y * rangeY),
                          child: Transform.rotate(
                            key: const Key('demo-heading'),
                            angle: _pose.heading,
                            child: CustomPaint(
                              size: const Size(48, 52),
                              painter: _RobotPainter(colors.primary),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          Text(
            MediaQuery.disableAnimationsOf(context)
                ? 'Animation paused (reduced motion)'
                : 'Illustrative top view • bounded preview',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ArenaPainter extends CustomPainter {
  const _ArenaPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
  }

  @override
  bool shouldRepaint(_ArenaPainter oldDelegate) => oldDelegate.color != color;
}

class _RobotPainter extends CustomPainter {
  const _RobotPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final wheels = Paint()..color = const Color(0xff263238);
    for (final x in [1.0, 39.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 13, 8, 30),
          const Radius.circular(3),
        ),
        wheels,
      );
    }
    final body = Paint()..color = color;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(10, 8, 28, 39),
        const Radius.circular(8),
      ),
      body,
    );
    canvas.drawPath(
      Path()
        ..moveTo(24, 1)
        ..lineTo(16, 12)
        ..lineTo(32, 12)
        ..close(),
      body,
    );
    final detail = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(18, 20), 3, detail);
    canvas.drawCircle(const Offset(30, 20), 3, detail);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(17, 32, 14, 5),
        const Radius.circular(2),
      ),
      detail,
    );
  }

  @override
  bool shouldRepaint(_RobotPainter oldDelegate) => oldDelegate.color != color;
}
