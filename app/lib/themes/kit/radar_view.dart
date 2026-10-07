import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/protocol/telemetry.dart';

/// Top-down proximity radar: our car in the middle (pointing up), the cars
/// around drawn to scale, red when very close.
class RadarView extends StatelessWidget {
  final List<RadarTarget>? targets;

  /// Metres from the centre to the edge of the view.
  final double range;
  final Color color;

  const RadarView({super.key, required this.targets, this.range = 25, this.color = Colors.white70});

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: 1,
        child: CustomPaint(painter: _RadarPainter(targets ?? const [], range, color, available: targets != null)),
      );
}

class _RadarPainter extends CustomPainter {
  final List<RadarTarget> targets;
  final double range;
  final Color color;
  final bool available;

  _RadarPainter(this.targets, this.range, this.color, {required this.available});

  static Color colorFor(double distance, Color base) {
    if (distance < 5) return Colors.redAccent;
    if (distance < 10) return Colors.orangeAccent;
    return base;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final scale = size.shortestSide / 2 / range;
    final ring = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke;
    for (final r in [range / 3, range * 2 / 3, range]) {
      canvas.drawCircle(center, r * scale, ring);
    }
    _car(canvas, center, 0, 4.5 * scale, 1.9 * scale, available ? Colors.lightBlueAccent : color.withValues(alpha: 0.3));
    for (final t in targets) {
      final p = center + Offset(t.x * scale, -t.y * scale);
      if ((p - center).distance > size.shortestSide / 2 + 10) continue;
      _car(canvas, p, t.heading * math.pi / 180, t.length * scale, t.width * scale, colorFor(t.distance, color));
    }
  }

  void _car(Canvas canvas, Offset at, double angle, double length, double width, Color c) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(angle);
    final rect = Rect.fromCenter(center: Offset.zero, width: math.max(width, 3), height: math.max(length, 5));
    canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(rect.width / 4)), Paint()..color = c);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RadarPainter oldDelegate) => true;
}
