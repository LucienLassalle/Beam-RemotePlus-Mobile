import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Static and RPM-driven parts of the Civetta display, drawn in a 1024x512
/// design space (the in-game screen resolution) and scaled to the canvas.
class CivettaPainter extends CustomPainter {
  final double? rpm;
  final double? maxRpm;
  final bool shiftLight;

  CivettaPainter({required this.rpm, required this.maxRpm, required this.shiftLight});

  static const Size design = Size(1024, 512);
  static const Offset center = Offset(512, 330);
  static const double radius = 160;

  /// Needle sweep: -106° (0 rpm) .. +106° (scale max), 0° = straight up.
  static const double sweepDeg = 106;
  static const int markers = 21;

  static const Color red = Color(0xFFE5141B);
  static const Color blue = Color(0xFF1626FF);
  static const Color yellow = Color(0xFFFFD700);
  static const Color off = Color(0xFF26262E);

  /// Top of the tachometer scale: max RPM rounded up to the next 1000, at
  /// least 8000 so idle sits low on the dial like on the real car.
  static double scaleMax(double? maxRpm) {
    final m = maxRpm ?? 0;
    return math.max(8000, ((m / 1000).ceil() + 1) * 1000).toDouble();
  }

  /// Angle in degrees (0 = up) for [value] rpm on the dial.
  static double angleFor(double value, double scale) =>
      -sweepDeg + (value.clamp(0, scale) / scale) * sweepDeg * 2;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width / design.width, size.height / design.height);
    canvas.translate((size.width - design.width * s) / 2, (size.height - design.height * s) / 2);
    canvas.scale(s);
    _paintWings(canvas);
    _paintDial(canvas);
  }

  void _paintWings(Canvas canvas) {
    final fill = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFF1E1D3A), Color(0xFF07070C)],
      ).createShader(const Rect.fromLTWH(0, 150, 1024, 300));
    final stroke = Paint()
      ..color = red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeJoin = StrokeJoin.round;
    for (final mirror in [false, true]) {
      canvas.save();
      if (mirror) {
        canvas.translate(1024, 0);
        canvas.scale(-1, 1);
      }
      final wing = Path()
        ..moveTo(360, 162)
        ..quadraticBezierTo(200, 170, 120, 280)
        ..lineTo(14, 410)
        ..lineTo(250, 410)
        ..quadraticBezierTo(290, 405, 370, 352)
        ..close();
      canvas.drawPath(wing, fill);
      canvas.drawPath(wing, stroke);
      canvas.restore();
    }
  }

  void _paintDial(Canvas canvas) {
    canvas.drawCircle(center, radius + 22, Paint()..color = Colors.black);
    final scale = scaleMax(maxRpm);
    final redFrom = (maxRpm ?? scale) / scale * (markers - 1);
    final current = rpm == null ? -1 : (rpm! / scale) * (markers - 1);
    final ring = Rect.fromCircle(center: center, radius: radius);
    final segSweep = (sweepDeg * 2 / markers) * math.pi / 180;
    for (var i = 0; i < markers; i++) {
      final start = (-90 - sweepDeg) * math.pi / 180 + i * segSweep;
      final lit = i <= current;
      Color color;
      if (!lit) {
        color = off;
      } else if (i >= redFrom) {
        color = shiftLight ? Colors.white : red;
      } else if (i >= redFrom - 2) {
        color = yellow;
      } else {
        color = blue;
      }
      canvas.drawArc(
        ring,
        start + segSweep * 0.08,
        segSweep * 0.84,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 30,
      );
    }
    // Outer red line, like the original bezel.
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius + 24),
      (-90 - sweepDeg) * math.pi / 180,
      sweepDeg * 2 * math.pi / 180,
      false,
      Paint()
        ..color = red
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    _paintTicks(canvas, scale);
    _paintNeedle(canvas, scale);
  }

  void _paintTicks(Canvas canvas, double scale) {
    final tick = Paint()
      ..color = Colors.white
      ..strokeWidth = 3;
    final steps = (scale / 1000).round();
    for (var k = 0; k <= steps; k++) {
      final a = angleFor(k * 1000.0, scale) * math.pi / 180;
      final dir = Offset(math.sin(a), -math.cos(a));
      canvas.drawLine(center + dir * (radius - 38), center + dir * (radius - 22), tick);
      final label = TextPainter(
        text: TextSpan(text: '$k', style: const TextStyle(color: Colors.white70, fontSize: 20)),
        textDirection: TextDirection.ltr,
      )..layout();
      final pos = center + dir * (radius - 58);
      label.paint(canvas, pos - Offset(label.width / 2, label.height / 2));
    }
  }

  void _paintNeedle(Canvas canvas, double scale) {
    final a = angleFor(rpm ?? 0, scale) * math.pi / 180;
    final dir = Offset(math.sin(a), -math.cos(a));
    canvas.drawLine(
      center,
      center + dir * (radius + 8),
      Paint()
        ..color = red
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(center, 22, Paint()..color = red);
    canvas.drawCircle(center, 14, Paint()..color = Colors.black);
    canvas.drawCircle(center, 7, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(CivettaPainter oldDelegate) =>
      oldDelegate.rpm != rpm || oldDelegate.maxRpm != maxRpm || oldDelegate.shiftLight != shiftLight;
}
