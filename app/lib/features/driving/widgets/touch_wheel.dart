import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../wheel_gesture.dart';

/// Steering wheel turned with a thumb (third steering mode, besides tilt and
/// the touch bar). Released, it comes back to the centre in [returnDuration]
/// like a real wheel letting go.
class TouchWheel extends StatefulWidget {
  final ValueChanged<double> onSteering;

  /// Wheel rotation giving full lock, each way.
  final double maxAngleDeg;
  final Color color;
  final double size;

  const TouchWheel({
    super.key,
    required this.onSteering,
    required this.maxAngleDeg,
    this.color = Colors.white70,
    this.size = 124,
  });

  static const returnDuration = Duration(milliseconds: 250);

  @override
  State<TouchWheel> createState() => _TouchWheelState();
}

class _TouchWheelState extends State<TouchWheel> with SingleTickerProviderStateMixin {
  late final WheelGesture _wheel = WheelGesture(maxAngleDeg: widget.maxAngleDeg);
  late final AnimationController _return = AnimationController(vsync: this, duration: TouchWheel.returnDuration)
    ..addListener(_onReturn);
  double _releasedAt = 0;

  @override
  void didUpdateWidget(covariant TouchWheel old) {
    super.didUpdateWidget(old);
    _wheel.maxAngleDeg = widget.maxAngleDeg;
  }

  @override
  void dispose() {
    _return.dispose();
    super.dispose();
  }

  double _fingerDeg(Offset local) {
    final c = Offset(widget.size / 2, widget.size / 2);
    return math.atan2(local.dy - c.dy, local.dx - c.dx) * 180 / math.pi;
  }

  void _emit() {
    widget.onSteering(_wheel.steering);
    setState(() {});
  }

  void _onReturn() {
    _wheel.angleDeg = _releasedAt * (1 - Curves.easeOut.transform(_return.value));
    _emit();
  }

  void _down(Offset local) {
    _return.stop();
    _wheel.start(_fingerDeg(local));
  }

  void _move(Offset local) {
    _wheel.move(_fingerDeg(local));
    _emit();
  }

  void _up() {
    _wheel.end();
    _releasedAt = _wheel.angleDeg;
    if (_releasedAt != 0) _return.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onPanDown: (d) => _down(d.localPosition),
        onPanUpdate: (d) => _move(d.localPosition),
        onPanEnd: (_) => _up(),
        onPanCancel: _up,
        child: CustomPaint(
          size: Size.square(widget.size),
          painter: SteeringWheelPainter(angleDeg: _wheel.angleDeg, color: widget.color),
        ),
      );
}

/// A steering wheel turned by [angleDeg] (clockwise), with an amber top
/// marker; also drawn by the tutorial.
class SteeringWheelPainter extends CustomPainter {
  final double angleDeg;
  final Color color;
  SteeringWheelPainter({required this.angleDeg, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 6;
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..color = color.withValues(alpha: 0.35);
    canvas.drawCircle(c, r, Paint()..color = Colors.black.withValues(alpha: 0.35));
    canvas.drawCircle(c, r, rim);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angleDeg * math.pi / 180);
    final spoke = Paint()
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.35);
    canvas.drawLine(Offset(-r, 0), Offset(r, 0), spoke);
    canvas.drawLine(Offset.zero, Offset(0, r), spoke);
    canvas.drawCircle(Offset.zero, r * 0.22, Paint()..color = color.withValues(alpha: 0.5));
    // Top marker: shows the wheel position at a glance.
    canvas.drawLine(Offset(0, -r - 5), Offset(0, -r + 5), Paint()
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = Colors.amberAccent);
    canvas.restore();
  }

  @override
  bool shouldRepaint(SteeringWheelPainter old) => old.angleDeg != angleDeg || old.color != color;
}
