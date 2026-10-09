import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/protocol/telemetry.dart';
import 'dash_format.dart';

/// Health of one part on the schematic.
enum PartState { unknown, ok, warning, broken }

/// Top-down damage schematic in the spirit of BeamNG.drive's damage app:
/// every part is a filled shape, green = fine, amber = check, red = broken,
/// grey = not reported by this car, readable at a glance.
/// - body: the outline in six zones, green to red as it gets crushed
/// - radiator (car radiator with its fins) at the front, the engine
///   (engine pictogram) right behind it, or where it really sits
/// - driveshafts and wheel axles as thick bars, differentials as discs
/// - a brake block inside each wheel, coloured by the brake temperature
/// - the fuel tank as a jerrycan in the boot, filled to the fuel level
/// - tyres: temperature colour with the tyre mod, crossed out when flat,
///   dashed when torn off; pressure (and tyre temperature) beside them
class DamageView extends StatelessWidget {
  final Telemetry telemetry;
  final TemperatureUnit temperatureUnit;
  final PressureUnit pressureUnit;
  const DamageView({
    super.key,
    required this.telemetry,
    this.temperatureUnit = TemperatureUnit.celsius,
    this.pressureUnit = PressureUnit.bar,
  });

  /// Width / height of the schematic (car + labels on both sides).
  static const double aspectRatio = _DamagePainter.width / _DamagePainter.height;

  static const Color okColor = Color(0xFF43C443);
  static const Color warningColor = Color(0xFFFFB300);
  static const Color brokenColor = Color(0xFFFF3B30);
  static const Color unknownColor = Color(0xFF5A6068);

  static Color partColor(PartState s) => switch (s) {
        PartState.unknown => unknownColor,
        PartState.ok => okColor,
        PartState.warning => warningColor,
        PartState.broken => brokenColor,
      };

  /// Body zone: green when intact, then yellow, orange and red.
  static Color damageColor(double damage) {
    if (damage <= 0.01) return okColor;
    final d = (damage * 3).clamp(0.0, 1.0);
    return d < 0.5 ? Color.lerp(Colors.yellow, Colors.orange, d * 2)! : Color.lerp(Colors.orange, brokenColor, (d - 0.5) * 2)!;
  }

  /// Tyre temperature (tyre mod): blue = cold, green = working, red = hot.
  static Color heatColor(double? heat) {
    if (heat == null) return okColor;
    if (heat < 0) return Color.lerp(okColor, Colors.lightBlueAccent, -heat)!;
    return Color.lerp(okColor, brokenColor, heat)!;
  }

  /// Brake: green while cool, amber from 300 °C, red from ~550 °C or when
  /// fading.
  static Color brakeColor(double? temp, {bool fading = false}) {
    if (fading) return brokenColor;
    if (temp == null) return okColor;
    if (temp <= 300) return okColor;
    if (temp <= 450) return Color.lerp(okColor, warningColor, (temp - 300) / 150)!;
    return Color.lerp(warningColor, brokenColor, ((temp - 450) / 100).clamp(0.0, 1.0))!;
  }

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

  static PartState fuelTankState(Telemetry t) {
    if (t.fuelLeak == true) return PartState.broken;
    if (t.lowFuel == true || (t.fuel != null && t.fuel! < 0.1)) return PartState.warning;
    return t.fuel == null ? PartState.unknown : PartState.ok;
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: aspectRatio,
        child: CustomPaint(painter: _DamagePainter(telemetry, temperatureUnit, pressureUnit)),
      );
}

/// Drawn in a [width] x [height] design box: the car (front at the top)
/// in the middle 100 units, labels in the side margins.
class _DamagePainter extends CustomPainter {
  final Telemetry t;
  final TemperatureUnit temperatureUnit;
  final PressureUnit pressureUnit;
  _DamagePainter(this.t, this.temperatureUnit, this.pressureUnit);

  static const double width = 164;
  static const double height = 200;
  static const double margin = (width - 100) / 2;

  static const double frontAxleY = 48;
  static const double rearAxleY = 154;

  /// Engine of a classic front-engined car when the mod does not say.
  static const double defaultEngineAt = 0.2;

  static const _zones = [
    ['FL', 'FR'],
    ['ML', 'MR'],
    ['RL', 'RR'],
  ];

  static const _tyres = {
    'FL': Rect.fromLTWH(1, 32, 13, 32),
    'FR': Rect.fromLTWH(86, 32, 13, 32),
    'RL': Rect.fromLTWH(1, 138, 13, 32),
    'RR': Rect.fromLTWH(86, 138, 13, 32),
  };

  static final Paint _outline = Paint()
    ..color = Colors.black
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.1
    ..strokeJoin = StrokeJoin.round;

  static Paint _fill(Color c) => Paint()..color = c;

  /// Filled shape with a black outline, like the game's damage app.
  static void _part(Canvas canvas, Path path, Color color) {
    canvas.drawPath(path, _fill(color));
    canvas.drawPath(path, _outline);
  }

  static Path _rrect(Rect r, double radius) => Path()..addRRect(RRect.fromRectAndRadius(r, Radius.circular(radius)));

  static Path body() => Path()
    ..moveTo(50, 3)
    ..cubicTo(72, 3, 80, 9, 81, 26)
    ..lineTo(83, 96)
    ..lineTo(82, 176)
    ..cubicTo(81, 192, 72, 197, 50, 197)
    ..cubicTo(28, 197, 19, 192, 18, 176)
    ..lineTo(17, 96)
    ..lineTo(19, 26)
    ..cubicTo(20, 9, 28, 3, 50, 3)
    ..close();

  bool get _rearEngine => (t.engineAt ?? defaultEngineAt) > 0.5;
  double get _engineY => (3 + (t.engineAt ?? defaultEngineAt) * 194).clamp(36.0, 168.0);

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width / width, size.height / height);
    canvas.translate((size.width - width * s) / 2, (size.height - height * s) / 2);
    canvas.scale(s);
    canvas.save();
    canvas.translate(margin, 0);

    _bodyZones(canvas);
    _drivetrain(canvas);
    _radiator(canvas);
    _engine(canvas);
    _fuelTank(canvas);
    _wheels(canvas);
    canvas.restore();
    _labels(canvas);
  }

  /// The outline, thick, coloured zone by zone (thirds of the length,
  /// halves of the width).
  void _bodyZones(Canvas canvas) {
    final outline = body();
    canvas.drawPath(outline, _fill(Colors.black.withValues(alpha: 0.35)));
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 2; col++) {
        final damage = t.bodyDamage?[_zones[row][col]] ?? 0;
        canvas.save();
        canvas.clipRect(Rect.fromLTWH(col * 50.0, row * height / 3, 50, height / 3));
        canvas.drawPath(
          outline,
          Paint()
            ..color = DamageView.damageColor(damage)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5,
        );
        canvas.restore();
      }
    }
    // Zone separators, so a red corner reads as a corner.
    final sep = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.2;
    for (final y in [height / 3, height * 2 / 3]) {
      canvas.drawLine(Offset(14, y), Offset(21, y), sep);
      canvas.drawLine(Offset(79, y), Offset(86, y), sep);
    }
  }

  PartState _shaftState(String name) => t.brokenParts.contains(name) ? PartState.broken : PartState.ok;

  /// Axles, driveshafts and differentials as thick bars.
  void _drivetrain(Canvas canvas) {
    final hasEngine = _hasEngine;
    for (final name in t.shafts) {
      if (name.startsWith('driveshaft') && hasEngine) {
        final toFront = name.endsWith('_F');
        final targetY = toFront ? frontAxleY : rearAxleY;
        final fromY = _engineY + (targetY > _engineY ? 12 : -12);
        final top = math.min(fromY, targetY), bottom = math.max(fromY, targetY);
        _part(canvas, _rrect(Rect.fromLTRB(47.5, top, 52.5, bottom), 2), DamageView.partColor(_shaftState(name)));
      }
    }
    for (final name in t.shafts) {
      if (!name.startsWith('wheelaxle') || name.length < 11) continue;
      final wheel = name.substring(9, 11);
      final y = wheel.startsWith('F') ? frontAxleY : rearAxleY;
      final r = wheel.endsWith('L') ? Rect.fromLTRB(21, y - 2.6, 45, y + 2.6) : Rect.fromLTRB(55, y - 2.6, 79, y + 2.6);
      _part(canvas, _rrect(r, 2), DamageView.partColor(_shaftState(name)));
    }
    for (final (axle, y) in [('F', frontAxleY), ('R', rearAxleY)]) {
      if (t.shafts.any((n) => n.startsWith('wheelaxle$axle'))) {
        _part(canvas, Path()..addOval(Rect.fromCircle(center: Offset(50, y), radius: 6.5)), DamageView.okColor);
      }
    }
  }

  bool get _hasEngine => t.rpm != null || t.engineAt != null || t.engineDamage.isNotEmpty;

  /// Car radiator at the nose: header tanks top and bottom, fins between.
  void _radiator(Canvas canvas) {
    if (t.waterTemp == null && DamageView.radiatorState(t) == PartState.ok) return;
    final color = DamageView.partColor(DamageView.radiatorState(t));
    const core = Rect.fromLTRB(30, 11, 70, 21);
    _part(canvas, _rrect(core, 1), color);
    final fin = Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..strokeWidth = 0.8;
    for (var x = 33.0; x < 70; x += 3) {
      canvas.drawLine(Offset(x, core.top + 1), Offset(x, core.bottom - 1), fin);
    }
    _part(canvas, _rrect(const Rect.fromLTRB(28, 8.5, 72, 11.5), 1.2), color); // top tank
    _part(canvas, _rrect(const Rect.fromLTRB(28, 20.5, 72, 23.5), 1.2), color); // bottom tank
    _part(canvas, _rrect(const Rect.fromLTRB(66, 5.5, 69, 8.5), 0.6), color); // filler cap
  }

  /// Engine pictogram (like a check-engine light): block, valve cover with
  /// its filler cap, intake on the left, fan on the right, sump below.
  void _engine(Canvas canvas) {
    if (!_hasEngine) return;
    final color = DamageView.partColor(DamageView.engineState(t));
    final y = _engineY;
    final shape = Path()
      // valve cover and cap
      ..moveTo(40, y - 9)
      ..lineTo(44, y - 9)
      ..lineTo(44, y - 12)
      ..lineTo(52, y - 12)
      ..lineTo(52, y - 9)
      ..lineTo(58, y - 9)
      // block, then the fan housing on the right
      ..lineTo(61, y - 5)
      ..lineTo(64, y - 5)
      ..lineTo(64, y - 8)
      ..lineTo(67, y - 8)
      ..lineTo(67, y + 7)
      ..lineTo(64, y + 7)
      ..lineTo(64, y + 4)
      ..lineTo(61, y + 4)
      // sump
      ..lineTo(57, y + 10)
      ..lineTo(41, y + 10)
      ..lineTo(38, y + 5)
      // intake on the left
      ..lineTo(35, y + 5)
      ..lineTo(35, y + 1)
      ..lineTo(32, y + 1)
      ..lineTo(32, y - 4)
      ..lineTo(35, y - 4)
      ..lineTo(35, y - 6)
      ..lineTo(38, y - 6)
      ..close();
    _part(canvas, shape, color);
  }

  /// Jerrycan in the boot (ahead of the cabin for mid/rear engines),
  /// filled from the bottom to the fuel level.
  void _fuelTank(Canvas canvas) {
    final state = DamageView.fuelTankState(t);
    if (state == PartState.unknown && t.fuel == null) return;
    final top = _rearEngine ? 58.0 : 163.0;
    final color = DamageView.partColor(state);
    // Spout on the cut corner, then the can.
    _part(
      canvas,
      Path()
        ..moveTo(54, top + 6)
        ..lineTo(58.5, top + 0.5)
        ..lineTo(62.5, top + 4)
        ..lineTo(58, top + 9.5)
        ..close(),
      color,
    );
    final can = Path()
      ..moveTo(39, top + 5)
      ..lineTo(54, top + 5)
      ..lineTo(61, top + 12)
      ..lineTo(61, top + 28)
      ..lineTo(39, top + 28)
      ..close();
    canvas.drawPath(can, _fill(const Color(0xFF3A3F45)));
    final level = (t.fuel ?? 1).clamp(0.0, 1.0);
    canvas.save();
    canvas.clipPath(can);
    canvas.drawRect(Rect.fromLTRB(38, top + 28 - 23 * level, 62, top + 28), _fill(color));
    canvas.restore();
    canvas.drawPath(can, _outline);
    // Carrying handle with its hole, and the X pressed in the side.
    _part(canvas, _rrect(Rect.fromLTRB(40, top + 0.5, 52, top + 5), 1.5), color);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(42.5, top + 1.8, 49.5, top + 3.7), const Radius.circular(1)),
        _fill(Colors.black));
    final x = Paint()
      ..color = Colors.black.withValues(alpha: 0.75)
      ..strokeWidth = 1.2;
    canvas.drawRect(Rect.fromLTRB(42, top + 14, 58, top + 26), _outline);
    canvas.drawLine(Offset(42, top + 14), Offset(58, top + 26), x);
    canvas.drawLine(Offset(58, top + 14), Offset(42, top + 26), x);
  }

  void _wheels(Canvas canvas) {
    final low = t.lowPressureTires().toSet();
    _tyres.forEach((name, r) {
      if (t.brokenWheels.contains(name)) {
        _dashed(canvas, RRect.fromRectAndRadius(r, const Radius.circular(4)), Paint()
          ..color = DamageView.brokenColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4);
        return;
      }
      final flat = t.flatTires.contains(name);
      final heat = t.tyres?[name]?.heat;
      final tyreColor = flat
          ? DamageView.brokenColor
          : low.contains(name)
              ? DamageView.warningColor
              : DamageView.heatColor(heat);
      _part(canvas, _rrect(r, 4), tyreColor);
      // Tread lines.
      final tread = Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..strokeWidth = 0.8;
      for (var y = r.top + 5; y < r.bottom - 3; y += 5) {
        canvas.drawLine(Offset(r.left + 2, y), Offset(r.right - 2, y), tread);
      }
      if (flat) {
        final x = Paint()
          ..color = Colors.black
          ..strokeWidth = 2.2;
        canvas.drawLine(r.topLeft, r.bottomRight, x);
        canvas.drawLine(r.topRight, r.bottomLeft, x);
      }

      // Brake block between the tyre and the axle.
      final left = name.endsWith('L');
      final brake = left
          ? Rect.fromLTRB(r.right + 1, r.center.dy - 11, r.right + 7, r.center.dy + 11)
          : Rect.fromLTRB(r.left - 7, r.center.dy - 11, r.left - 1, r.center.dy + 11);
      final molten = t.brokenBrakes.contains(name);
      final temp = t.brakeTemps?[name] ?? t.tyres?[name]?.brake;
      final known = temp != null || molten || t.hotBrakes.contains(name) || t.brakeTemps != null;
      final brakeColor = !known
          ? DamageView.unknownColor
          : molten
              ? DamageView.brokenColor
              : DamageView.brakeColor(temp, fading: t.hotBrakes.contains(name));
      _part(canvas, _rrect(brake, 1.5), brakeColor);
      if (molten) {
        final x = Paint()
          ..color = Colors.black
          ..strokeWidth = 1.2;
        canvas.drawLine(brake.topLeft, brake.bottomRight, x);
        canvas.drawLine(brake.topRight, brake.bottomLeft, x);
      }
    });
  }

  /// Beside each tyre: its pressure, its temperature (tyre mod) and the
  /// brake temperature once the brake gets hot.
  void _labels(Canvas canvas) {
    _tyres.forEach((name, r) {
      final left = name.endsWith('L');
      final x = left ? margin - 2 : margin + 100 + 2;
      final pressure = t.tirePressures?[name];
      final tyreTemp = t.tyres?[name]?.temp;
      final brakeTemp = t.brakeTemps?[name] ?? t.tyres?[name]?.brake;
      final low = t.lowPressureTires().contains(name);
      // (text, colour, is the brake temperature)
      final lines = <(String, Color, bool)>[
        if (pressure != null)
          (DashFormat.pressure(pressure, pressureUnit), low ? DamageView.warningColor : Colors.white, false),
        if (tyreTemp != null)
          ('${DashFormat.temperature(tyreTemp, temperatureUnit)}°', DamageView.heatColor(t.tyres?[name]?.heat), false),
        if (brakeTemp != null && brakeTemp > 300)
          (
            '${DashFormat.temperature(brakeTemp, temperatureUnit)}°',
            DamageView.brakeColor(brakeTemp, fading: t.hotBrakes.contains(name)),
            true,
          ),
      ];
      const lineHeight = 11.0;
      var y = r.center.dy - (lines.length - 1) * lineHeight / 2;
      for (final (text, color, brake) in lines) {
        final tp = TextPainter(
          text: TextSpan(text: text, style: TextStyle(color: color, fontSize: 9.5, fontFamily: 'Roboto', fontWeight: FontWeight.w600)),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: margin - 8);
        final dx = left ? x - tp.width : x + (brake ? 6 : 0);
        tp.paint(canvas, Offset(dx, y - tp.height / 2));
        if (brake) {
          // Small brake block before the value: tells it from the tyre one.
          final markerX = left ? dx - 6 : x;
          canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(markerX, y - 4, 3.5, 8), const Radius.circular(1)), _fill(color));
        }
        y += lineHeight;
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
