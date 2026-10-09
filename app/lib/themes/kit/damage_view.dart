import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/protocol/telemetry.dart';

/// Health of one mechanical part on the schematic.
enum PartState { ok, warning, broken }

/// Top-down damage schematic:
/// - the six body zones coloured from grey (intact) to red (wrecked)
/// - radiator, engine (where it really sits), driveshafts, wheel axles and
///   fuel tank (with its level), outlined in grey, amber or red
/// - a tyre at each corner coloured by temperature (blue = cold, green =
///   working temperature, red = overheating, with the tyre mod), flat tyres
///   crossed out, torn off wheels dashed
/// - a brake disc in each wheel coloured by its temperature, with °C
class DamageView extends StatelessWidget {
  final Telemetry telemetry;
  const DamageView({super.key, required this.telemetry});

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

  /// Grey while cold, amber when hot, red from ~700 °C or when fading.
  static Color brakeColor(double? temp, {bool fading = false}) {
    if (fading) return Colors.redAccent;
    if (temp == null) return Colors.white24;
    if (temp <= 150) return Colors.white54;
    if (temp <= 450) return Color.lerp(Colors.white54, Colors.amber, (temp - 150) / 300)!;
    return Color.lerp(Colors.amber, Colors.redAccent, ((temp - 450) / 250).clamp(0.0, 1.0))!;
  }

  static Color partColor(PartState s) => switch (s) {
        PartState.ok => Colors.white60,
        PartState.warning => Colors.amber,
        PartState.broken => Colors.redAccent,
      };

  static const _engineFailures = {
    'engineLockedUp', 'engineHydrolocked', 'blockMelted', 'cylinderWallsMelted',
    'catastrophicOverrevDamage', 'catastrophicOverTorqueDamage', 'engineDisabled',
  };
  static const _radiatorFailures = {'radiatorLeak', 'coolantOverheating', 'oilRadiatorLeak'};

  static PartState engineState(Telemetry t) {
    if (t.engineDamage.any(_engineFailures.contains) || t.brokenParts.contains('mainEngine')) return PartState.broken;
    if (t.engineDamage.any((d) => !_radiatorFailures.contains(d))) return PartState.warning;
    return PartState.ok;
  }

  static PartState radiatorState(Telemetry t) {
    if (t.engineDamage.contains('radiatorLeak')) return PartState.broken;
    if (t.engineDamage.contains('coolantOverheating') || (t.waterTemp ?? 0) >= 115) return PartState.warning;
    return PartState.ok;
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: 0.6,
        child: CustomPaint(painter: _DamagePainter(telemetry)),
      );
}

/// Top-down car drawn in a 100x200 design box (front at the top).
class _DamagePainter extends CustomPainter {
  final Telemetry t;
  _DamagePainter(this.t);

  static const _zones = [
    ['FL', 'FR'],
    ['ML', 'MR'],
    ['RL', 'RR'],
  ];

  static const double frontAxleY = 51;
  static const double rearAxleY = 151;

  /// Engine of a classic front-engined car when the mod does not say.
  static const double defaultEngineAt = 0.2;

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

  static Paint _stroke(Color color, [double width = 1.6]) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round;

  static final Paint _partFill = Paint()..color = Colors.black.withValues(alpha: 0.55);

  void _label(Canvas canvas, String text, Offset at, Color color, {double size = 11, bool alignRight = false}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size, fontFamily: 'Roboto')),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(alignRight ? at.dx - tp.width : at.dx, at.dy - tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width / 100, size.height / 200);
    canvas.translate((size.width - 100 * s) / 2, (size.height - 200 * s) / 2);
    canvas.scale(s);

    // Wheels first: the body covers their inner half, like seen from above.
    _wheels.forEach((name, r) {
      final rr = RRect.fromRectAndRadius(r, const Radius.circular(4));
      if (t.brokenWheels.contains(name)) {
        _dashed(canvas, rr, _stroke(Colors.redAccent, 1.4));
        return;
      }
      final flat = t.flatTires.contains(name);
      final tyre = t.tyres?[name];
      canvas.drawRRect(rr, Paint()..color = flat ? Colors.redAccent : DamageView.heatColor(tyre?.heat));
      if (flat) {
        final x = Paint()
          ..color = Colors.black
          ..strokeWidth = 2.5;
        canvas.drawLine(r.topLeft, r.bottomRight, x);
        canvas.drawLine(r.topRight, r.bottomLeft, x);
      }
    });

    final outline = body();
    canvas.save();
    canvas.clipPath(outline);
    // Damage zones: thirds of the length, halves of the width.
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 2; col++) {
        final damage = t.bodyDamage?[_zones[row][col]] ?? 0;
        canvas.drawRect(Rect.fromLTWH(col * 50.0, row * 200 / 3, 50, 200 / 3), Paint()..color = DamageView.damageColor(damage));
      }
    }
    _glass(canvas);
    _mechanicals(canvas);
    canvas.restore();

    // Mirrors and outline.
    canvas.drawPath(outline, _stroke(Colors.white.withValues(alpha: 0.55), 1.5));
    final mirror = Paint()..color = Colors.white.withValues(alpha: 0.4);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(4, 66, 8, 5), const Radius.circular(2)), mirror);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(88, 66, 8, 5), const Radius.circular(2)), mirror);

    _brakesAndLabels(canvas);
  }

  void _glass(Canvas canvas) {
    final glass = Paint()..color = Colors.black.withValues(alpha: 0.35);
    canvas.drawPath(
        Path()
          ..moveTo(22, 62)
          ..quadraticBezierTo(50, 52, 78, 62)
          ..lineTo(74, 84)
          ..quadraticBezierTo(50, 78, 26, 84)
          ..close(),
        glass);
    canvas.drawPath(
        Path()
          ..moveTo(26, 138)
          ..quadraticBezierTo(50, 142, 74, 138)
          ..lineTo(77, 156)
          ..quadraticBezierTo(50, 162, 23, 156)
          ..close(),
        glass);
  }

  /// Radiator, engine, shafts and fuel tank, over the body zones.
  void _mechanicals(Canvas canvas) {
    final hasEngine = t.rpm != null || t.engineAt != null || t.engineDamage.isNotEmpty;
    final engineY = (4 + (t.engineAt ?? defaultEngineAt) * 192).clamp(22.0, 178.0);
    final broken = t.brokenParts.toSet();

    // Shafts first, the parts are drawn over their ends. A dark edge keeps
    // them readable over any body colour.
    final edge = _stroke(Colors.black.withValues(alpha: 0.7), 4);
    void shaft(String name, Offset from, Offset to) {
      canvas.drawLine(from, to, edge);
      canvas.drawLine(from, to, _stroke(DamageView.partColor(broken.contains(name) ? PartState.broken : PartState.ok), 2.2));
    }

    for (final name in t.shafts) {
      if (name.startsWith('wheelaxle') && name.length >= 11) {
        final wheel = name.substring(9, 11);
        final y = wheel.startsWith('F') ? frontAxleY : rearAxleY;
        shaft(name, Offset(50, y), Offset(wheel.endsWith('L') ? 16.0 : 84.0, y));
      } else if (name.startsWith('driveshaft') && hasEngine) {
        shaft(name, Offset(50, engineY), Offset(50, name.endsWith('_F') ? frontAxleY : rearAxleY));
      }
    }
    // Differentials where axles meet.
    for (final (axle, y) in [('F', frontAxleY), ('R', rearAxleY)]) {
      if (t.shafts.any((n) => n.startsWith('wheelaxle$axle'))) {
        canvas.drawCircle(Offset(50, y), 4, _partFill);
        canvas.drawCircle(Offset(50, y), 4, _stroke(Colors.white60, 1.2));
      }
    }

    // Radiator at the nose (cars with a coolant temperature).
    if (t.waterTemp != null || DamageView.radiatorState(t) != PartState.ok) {
      final r = RRect.fromRectAndRadius(const Rect.fromLTWH(32, 9, 36, 6), const Radius.circular(1.5));
      canvas.drawRRect(r, _partFill);
      canvas.drawRRect(r, _stroke(DamageView.partColor(DamageView.radiatorState(t)), 1.4));
      for (var x = 36.0; x < 68; x += 4) {
        canvas.drawLine(Offset(x, 10.5), Offset(x, 13.5), _stroke(Colors.white24, 0.6));
      }
    }

    if (hasEngine) {
      final r = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(50, engineY), width: 30, height: 20), const Radius.circular(3));
      final color = DamageView.partColor(DamageView.engineState(t));
      canvas.drawRRect(r, _partFill);
      canvas.drawRRect(r, _stroke(color, 1.6));
      // Cylinders.
      for (var i = 0; i < 3; i++) {
        canvas.drawCircle(Offset(42 + i * 8.0, engineY), 2.4, _stroke(color.withValues(alpha: 0.7), 0.9));
      }
    }

    // Fuel tank: under the rear seats, or ahead of a mid/rear engine.
    if (t.fuel != null || t.fuelLeak == true) {
      final rearEngine = (t.engineAt ?? defaultEngineAt) > 0.5;
      final y = rearEngine ? (engineY - 36).clamp(70.0, 120.0) : 118.0;
      final r = Rect.fromLTWH(33, y, 34, 12);
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(2)), _partFill);
      final level = (t.fuel ?? 0).clamp(0.0, 1.0);
      if (level > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(r.left + 1.5, r.top + 1.5, (r.width - 3) * level, r.height - 3), const Radius.circular(1)),
          Paint()..color = (level < 0.12 ? Colors.amber : Colors.white38),
        );
      }
      final leak = t.fuelLeak == true;
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(2)),
          _stroke(DamageView.partColor(leak ? PartState.broken : PartState.ok), 1.4));
      if (leak) canvas.drawCircle(Offset(r.center.dx, r.bottom + 4), 2.2, Paint()..color = Colors.redAccent);
    }
  }

  /// Brake discs over the wheels, tyre and brake temperatures beside them.
  void _brakesAndLabels(Canvas canvas) {
    _wheels.forEach((name, r) {
      final left = name.endsWith('L');
      final labelX = left ? r.left - 2 : r.right + 2;
      final tyreTemp = t.tyres?[name]?.temp;
      final brakeTemp = t.brakeTemps?[name] ?? t.tyres?[name]?.brake;
      final fading = t.hotBrakes.contains(name);
      if (!t.brokenWheels.contains(name) && (brakeTemp != null || fading || t.brokenBrakes.contains(name))) {
        final c = Offset(left ? r.left + 6 : r.right - 6, r.center.dy);
        final color = DamageView.brakeColor(brakeTemp, fading: fading || t.brokenBrakes.contains(name));
        canvas.drawCircle(c, 4.2, Paint()..color = Colors.black.withValues(alpha: 0.6));
        canvas.drawCircle(c, 4.2, _stroke(color, 1.6));
        canvas.drawCircle(c, 1.2, Paint()..color = color);
        if (t.brokenBrakes.contains(name)) {
          canvas.drawLine(c - const Offset(3, 3), c + const Offset(3, 3), _stroke(Colors.redAccent, 1.4));
        }
      }
      final lines = <(String, Color, double)>[
        if (tyreTemp != null) ('${tyreTemp.round()}°', Colors.white, 11),
        if (brakeTemp != null) ('${brakeTemp.round()}°', DamageView.brakeColor(brakeTemp, fading: fading), 9),
      ];
      var y = r.center.dy - (lines.length - 1) * 6.5;
      for (final (text, color, size) in lines) {
        _label(canvas, text, Offset(labelX, y), color, size: size, alignRight: left);
        y += 13;
      }
    });
  }

  static void _dashed(Canvas canvas, RRect rr, Paint paint) {
    for (final metric in (Path()..addRRect(rr)).computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 6) {
        canvas.drawPath(metric.extractPath(d, math.min(d + 3, metric.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DamagePainter oldDelegate) => true;
}
