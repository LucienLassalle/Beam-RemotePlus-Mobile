import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/protocol/telemetry.dart';
import 'dash_format.dart';

/// Simplified damage schematic, the one of version 0.0.3 (shown without
/// the vehicle skeleton, or when the user prefers it): the six body zones coloured from green
/// (intact) to red (wrecked), a tyre at each corner coloured by temperature
/// (blue = cold, green = working temperature, red = overheating, with the
/// wear % when the tyre mod is installed) and flat tyres crossed out.
class SimpleDamageView extends StatelessWidget {
  final Telemetry telemetry;
  final TemperatureUnit temperatureUnit;
  const SimpleDamageView({super.key, required this.telemetry, this.temperatureUnit = TemperatureUnit.celsius});

  /// Intact = neutral grey, then yellow, orange and red as damage grows.
  static Color damageColor(double damage) {
    if (damage <= 0.01) return const Color(0xFF5A6068);
    final d = (damage * 3).clamp(0.0, 1.0);
    return d < 0.5 ? Color.lerp(Colors.amber, Colors.orange, d * 2)! : Color.lerp(Colors.orange, Colors.red, (d - 0.5) * 2)!;
  }

  static Color heatColor(double? heat) {
    if (heat == null) return Colors.white24;
    if (heat < 0) return Color.lerp(Colors.greenAccent, Colors.lightBlueAccent, -heat)!;
    return Color.lerp(Colors.greenAccent, Colors.redAccent, heat)!;
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: 0.6,
        child: CustomPaint(painter: _SimpleDamagePainter(telemetry, temperatureUnit)),
      );
}

/// Top-down car drawn in a 100x200 design box (front at the top).
class _SimpleDamagePainter extends CustomPainter {
  final Telemetry t;
  final TemperatureUnit temperatureUnit;
  _SimpleDamagePainter(this.t, this.temperatureUnit);

  static const _zones = [
    ['FL', 'FR'],
    ['ML', 'MR'],
    ['RL', 'RR'],
  ];

  static Path body() => Path()
    ..moveTo(50, 4)
    ..cubicTo(78, 4, 86, 14, 87, 34) // front right corner
    ..lineTo(89, 92)
    ..lineTo(88, 170)
    ..cubicTo(87, 190, 76, 196, 50, 196) // rear
    ..cubicTo(24, 196, 13, 190, 12, 170)
    ..lineTo(11, 92)
    ..lineTo(13, 34)
    ..cubicTo(14, 14, 22, 4, 50, 4)
    ..close();

  static const _wheels = {
    'FL': Rect.fromLTWH(3, 36, 14, 30),
    'FR': Rect.fromLTWH(83, 36, 14, 30),
    'RL': Rect.fromLTWH(3, 136, 14, 30),
    'RR': Rect.fromLTWH(83, 136, 14, 30),
  };

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width / 100, size.height / 200);
    canvas.translate((size.width - 100 * s) / 2, (size.height - 200 * s) / 2);
    canvas.scale(s);

    // Wheels first: the body covers their inner half, like seen from above.
    _wheels.forEach((name, r) {
      final flat = t.flatTires.contains(name);
      final tyre = t.tyres?[name];
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(4)),
          Paint()..color = flat ? Colors.redAccent : SimpleDamageView.heatColor(tyre?.heat));
      if (flat) {
        final x = Paint()
          ..color = Colors.black
          ..strokeWidth = 2.5;
        canvas.drawLine(r.topLeft, r.bottomRight, x);
        canvas.drawLine(r.topRight, r.bottomLeft, x);
      }
      if (tyre?.temp != null) {
        final tp = TextPainter(
          text: TextSpan(text: '${DashFormat.temperature(tyre!.temp!, temperatureUnit)}°', style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'Roboto')),
          textDirection: TextDirection.ltr,
        )..layout();
        final dx = name.endsWith('L') ? r.left - tp.width - 2 : r.right + 2;
        tp.paint(canvas, Offset(dx, r.center.dy - tp.height / 2));
      }
    });

    final outline = body();
    canvas.save();
    canvas.clipPath(outline);
    // Damage zones: thirds of the length, halves of the width.
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 2; col++) {
        final damage = t.bodyDamage?[_zones[row][col]] ?? 0;
        canvas.drawRect(Rect.fromLTWH(col * 50.0, row * 200 / 3, 50, 200 / 3), Paint()..color = SimpleDamageView.damageColor(damage));
      }
    }
    // Glass: windscreen, roof, rear window.
    final glass = Paint()..color = Colors.black.withValues(alpha: 0.55);
    canvas.drawPath(
        Path()
          ..moveTo(22, 62)
          ..quadraticBezierTo(50, 52, 78, 62)
          ..lineTo(74, 84)
          ..quadraticBezierTo(50, 78, 26, 84)
          ..close(),
        glass);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(26, 88, 48, 46), const Radius.circular(6)),
        Paint()..color = Colors.black.withValues(alpha: 0.25));
    canvas.drawPath(
        Path()
          ..moveTo(26, 138)
          ..quadraticBezierTo(50, 142, 74, 138)
          ..lineTo(77, 156)
          ..quadraticBezierTo(50, 162, 23, 156)
          ..close(),
        glass);
    canvas.restore();

    // Mirrors and outline.
    final edge = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(outline, edge);
    final mirror = Paint()..color = Colors.white.withValues(alpha: 0.4);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(4, 66, 8, 5), const Radius.circular(2)), mirror);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(88, 66, 8, 5), const Radius.circular(2)), mirror);
  }

  @override
  bool shouldRepaint(_SimpleDamagePainter oldDelegate) => true;
}
