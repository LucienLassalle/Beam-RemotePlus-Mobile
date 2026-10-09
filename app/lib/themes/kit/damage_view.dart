import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';

import '../../core/protocol/telemetry.dart';
import '../../core/protocol/vehicle_skeleton.dart';
import 'dash_format.dart';

/// Health of one part on the schematic.
enum PartState { unknown, ok, warning, broken }

/// Top-down damage schematic in the spirit of BeamNG.drive's damage apps:
/// every part is a filled shape, green = fine, amber = check, red = broken,
/// grey = not reported by this car, readable at a glance.
/// - body: with the mod's [skeleton], the real structure of this vehicle,
///   each beam coloured like the game's detailed damage app (white =
///   intact, green to red = bent); otherwise a generic outline in six zones
/// - radiator (car radiator with its fins) at the front, the engine
///   (engine pictogram) where it really sits
/// - driveshafts and wheel axles as thick bars, differentials as discs
/// - a brake block inside each wheel, coloured by the brake temperature
/// - the fuel tank as a jerrycan in the boot, filled to the fuel level
/// - tyres (at their real place with the skeleton): temperature colour
///   with the tyre mod, crossed out when flat, dashed when torn off;
///   pressure (and tyre temperature) beside them
class DamageView extends StatelessWidget {
  final Telemetry telemetry;
  final TemperatureUnit temperatureUnit;
  final PressureUnit pressureUnit;

  /// Real structure of the vehicle and the damage level of each segment.
  final VehicleSkeleton? skeleton;
  final Uint8List? skeletonLevels;

  const DamageView({
    super.key,
    required this.telemetry,
    this.temperatureUnit = TemperatureUnit.celsius,
    this.pressureUnit = PressureUnit.bar,
    this.skeleton,
    this.skeletonLevels,
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

  /// Skeleton beam, as in the game's detailed damage app: hue from green
  /// (barely bent, level 1) to red (level 9).
  static Color beamColor(int level) => HSLColor.fromAHSL(1, (1 - level / 9) * 120, 1, 0.5).toColor();

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
    if (t.fuelLeak == true || t.batteryDamaged == true) return PartState.broken;
    if (t.lowFuel == true || (t.fuel != null && t.fuel! < 0.1)) return PartState.warning;
    return t.fuel == null ? PartState.unknown : PartState.ok;
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: aspectRatio,
        child: CustomPaint(
          painter: _DamagePainter(telemetry, temperatureUnit, pressureUnit, DamageLayout.of(telemetry, skeleton), skeletonLevels),
        ),
      );
}

/// Where each part goes in the 100 x 200 car area of the schematic (front
/// at the top): fixed places for a generic car, or the real ones from the
/// vehicle skeleton.
class DamageLayout {
  /// Tyres seen from above, by wheel name.
  final Map<String, Rect> tyres;
  final double frontAxleY;
  final double rearAxleY;
  final Offset engine;

  /// Top of the body: the radiator sits right behind it.
  final double noseY;
  final double tailY;

  /// Real structure, mapped on the schematic (null = generic car).
  final VehicleSkeleton? skeleton;
  final double scale;
  final Offset origin;

  /// Size of the pictograms (radiator, engine, tank): smaller on a narrow
  /// vehicle so they stay inside its body.
  final double partScale;

  const DamageLayout._({
    required this.tyres,
    required this.frontAxleY,
    required this.rearAxleY,
    required this.engine,
    required this.noseY,
    required this.tailY,
    this.skeleton,
    this.scale = 1,
    this.origin = Offset.zero,
    this.partScale = 1,
  });

  static const double centerX = 50;

  /// Engine of a classic front-engined car when the mod does not say.
  static const double defaultEngineAt = 0.2;

  static const _genericTyres = {
    'FL': Rect.fromLTWH(1, 32, 13, 32),
    'FR': Rect.fromLTWH(86, 32, 13, 32),
    'RL': Rect.fromLTWH(1, 138, 13, 32),
    'RR': Rect.fromLTWH(86, 138, 13, 32),
  };

  static double _engineY(double? engineAt, double nose, double tail) =>
      (nose + (engineAt ?? defaultEngineAt) * (tail - nose)).clamp(nose + 33, tail - 29);

  factory DamageLayout.of(Telemetry t, VehicleSkeleton? skeleton) {
    final b = skeleton?.bounds;
    if (skeleton == null || b == null || b.width < 0.5 || b.height < 0.5) {
      return DamageLayout._(
        tyres: _genericTyres,
        frontAxleY: 48,
        rearAxleY: 154,
        engine: Offset(centerX, _engineY(t.engineAt, 3, 197)),
        noseY: 3,
        tailY: 197,
      );
    }
    // Metres -> schematic, forward up, centred, as big as the area allows.
    final k = math.min(96 / b.width, 194 / b.height);
    final origin = Offset(centerX - b.center.dx * k, 100 + b.center.dy * k);
    Offset map(Offset p) => Offset(origin.dx + p.dx * k, origin.dy - p.dy * k);

    final tyres = <String, Rect>{
      for (final e in skeleton.wheels.entries)
        e.key: Rect.fromCenter(
          center: map(e.value.center),
          width: math.max(e.value.width * k, 6),
          height: math.max(e.value.radius * 2 * k, 14),
        ),
    };
    var nose = double.infinity, tail = -double.infinity;
    for (final p in skeleton.hull) {
      final y = map(p).dy;
      nose = math.min(nose, y);
      tail = math.max(tail, y);
    }
    // Front axle(s): the wheels in the front half of the wheelbase.
    final ys = [for (final r in tyres.values) r.center.dy];
    double front, rear;
    if (ys.isEmpty) {
      front = nose + (tail - nose) * 0.22;
      rear = nose + (tail - nose) * 0.78;
    } else {
      final mid = (ys.reduce(math.min) + ys.reduce(math.max)) / 2;
      final f = ys.where((y) => y <= mid).toList();
      final r = ys.where((y) => y > mid).toList();
      front = f.reduce((a, b) => a + b) / f.length;
      rear = r.isEmpty ? tail - 20 : r.reduce((a, b) => a + b) / r.length;
    }
    // The generic body is 66 wide.
    var left = double.infinity, right = -double.infinity;
    for (final p in skeleton.hull) {
      left = math.min(left, map(p).dx);
      right = math.max(right, map(p).dx);
    }
    final partScale = ((right - left) / 66).clamp(0.55, 1.0);
    // Real place, kept clear of the radiator and of the tail.
    final engine = skeleton.engine != null
        ? Offset(map(skeleton.engine!).dx, map(skeleton.engine!).dy.clamp(nose + 33 * partScale, tail - 29 * partScale))
        : Offset(centerX, _engineY(t.engineAt, nose, tail));
    return DamageLayout._(
      tyres: tyres,
      frontAxleY: front,
      rearAxleY: rear,
      engine: engine,
      noseY: nose,
      tailY: tail,
      skeleton: skeleton,
      scale: k,
      origin: origin,
      partScale: partScale,
    );
  }

  bool isLeft(String wheel) => (tyres[wheel]?.center.dx ?? 0) < centerX;

  /// Engine behind the middle of the car (mid / rear engine).
  bool get rearEngine => engine.dy > (noseY + tailY) / 2;
}

/// Drawn in a [width] x [height] design box: the car (front at the top)
/// in the middle 100 units, labels in the side margins.
class _DamagePainter extends CustomPainter {
  final Telemetry t;
  final TemperatureUnit temperatureUnit;
  final PressureUnit pressureUnit;
  final DamageLayout layout;
  final Uint8List? levels;
  _DamagePainter(this.t, this.temperatureUnit, this.pressureUnit, this.layout, this.levels);

  static const double width = 164;
  static const double height = 200;
  static const double margin = (width - 100) / 2;
  static const double cx = DamageLayout.centerX;

  static const _zones = [
    ['FL', 'FR'],
    ['ML', 'MR'],
    ['RL', 'RR'],
  ];

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

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width / width, size.height / height);
    canvas.translate((size.width - width * s) / 2, (size.height - height * s) / 2);
    canvas.scale(s);
    canvas.save();
    canvas.translate(margin, 0);

    final skeleton = layout.skeleton;
    final beams = skeleton == null ? null : _beamPoints(skeleton);
    if (skeleton != null) {
      _hull(canvas, skeleton);
      _beams(canvas, beams!, 0, 0);
    } else {
      _bodyZones(canvas);
    }
    _drivetrain(canvas);
    _scaled(canvas, Offset(cx, layout.noseY + 13), () => _radiator(canvas));
    _scaled(canvas, layout.engine, () => _engine(canvas));
    _fuelTank(canvas);
    // Bent beams over the parts: the crash must never hide behind them.
    if (beams != null) _beams(canvas, beams, 1, 9);
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

  /// Pictogram drawn at full size, shrunk around [center] on a narrow
  /// vehicle.
  void _scaled(Canvas canvas, Offset center, void Function() draw) {
    if (layout.partScale == 1) return draw();
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(layout.partScale);
    canvas.translate(-center.dx, -center.dy);
    draw();
    canvas.restore();
  }

  /// Outline of the real structure.
  void _hull(Canvas canvas, VehicleSkeleton s) {
    if (s.hull.length < 3) return;
    final k = layout.scale, o = layout.origin;
    final hull = Path()..addPolygon([for (final p in s.hull) Offset(o.dx + p.dx * k, o.dy - p.dy * k)], true);
    canvas.drawPath(hull, _fill(Colors.black.withValues(alpha: 0.35)));
    canvas.drawPath(
      hull,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  /// Beams of damage levels [from] .. [to]: intact ones faint, bent ones
  /// from green to red.
  void _beams(Canvas canvas, List<Float32List> points, int from, int to) {
    for (var level = from; level <= to; level++) {
      if (points[level].isEmpty) continue;
      canvas.drawRawPoints(
        PointMode.lines,
        points[level],
        Paint()
          ..color = level == 0 ? Colors.white.withValues(alpha: 0.16) : DamageView.beamColor(level)
          ..strokeWidth = level == 0 ? 0.6 : 1.4
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  /// Segment ends on the schematic, grouped by damage level (0..9).
  List<Float32List> _beamPoints(VehicleSkeleton s) {
    final k = layout.scale, o = layout.origin;
    final levels = this.levels;
    final perLevel = List.filled(10, 0);
    for (var i = 0; i < s.count; i++) {
      perLevel[levels?[i] ?? 0]++;
    }
    final points = [for (final n in perLevel) Float32List(n * 4)];
    final filled = List.filled(10, 0);
    final seg = s.segments;
    for (var i = 0; i < s.count; i++) {
      final level = levels?[i] ?? 0;
      final list = points[level];
      var j = filled[level];
      list[j++] = o.dx + seg[i * 4] * k;
      list[j++] = o.dy - seg[i * 4 + 1] * k;
      list[j++] = o.dx + seg[i * 4 + 2] * k;
      list[j++] = o.dy - seg[i * 4 + 3] * k;
      filled[level] = j;
    }
    return points;
  }

  PartState _shaftState(String name) => t.brokenParts.contains(name) ? PartState.broken : PartState.ok;

  /// Tyre driven by a wheelaxle shaft (wheelaxleFL -> FL).
  Rect? _axleTyre(String shaft) {
    if (!shaft.startsWith('wheelaxle') || shaft.length < 11) return null;
    return layout.tyres[shaft.substring(9)] ?? layout.tyres[shaft.substring(9, 11)];
  }

  /// Axles, driveshafts and differentials as thick bars.
  void _drivetrain(Canvas canvas) {
    final engineY = layout.engine.dy;
    if (_hasEngine) {
      for (final name in t.shafts) {
        if (!name.startsWith('driveshaft')) continue;
        final targetY = name.endsWith('_F') ? layout.frontAxleY : layout.rearAxleY;
        final fromY = engineY + (targetY > engineY ? 12 : -12);
        final top = math.min(fromY, targetY), bottom = math.max(fromY, targetY);
        _part(canvas, _rrect(Rect.fromLTRB(cx - 2.5, top, cx + 2.5, bottom), 2), DamageView.partColor(_shaftState(name)));
      }
    }
    final diffs = <int>{};
    for (final name in t.shafts) {
      final tyre = _axleTyre(name);
      if (tyre == null) continue;
      final y = tyre.center.dy;
      final r = tyre.center.dx < cx
          ? Rect.fromLTRB(tyre.right + 7, y - 2.6, cx - 5, y + 2.6)
          : Rect.fromLTRB(cx + 5, y - 2.6, tyre.left - 7, y + 2.6);
      if (r.width > 0) _part(canvas, _rrect(r, 2), DamageView.partColor(_shaftState(name)));
      diffs.add(y.round());
    }
    for (final y in diffs) {
      _part(canvas, Path()..addOval(Rect.fromCircle(center: Offset(cx, y.toDouble()), radius: 6.5)), DamageView.okColor);
    }
  }

  bool get _hasEngine => t.rpm != null || t.engineAt != null || t.engineDamage.isNotEmpty || layout.skeleton?.engine != null;

  /// Car radiator at the nose: header tanks top and bottom, fins between.
  void _radiator(Canvas canvas) {
    if (t.waterTemp == null && DamageView.radiatorState(t) == PartState.ok) return;
    final color = DamageView.partColor(DamageView.radiatorState(t));
    canvas.save();
    // Drawn for a nose at y = 3.
    canvas.translate(0, layout.noseY - 3);
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
    canvas.restore();
  }

  /// Engine pictogram (like a check-engine light): block, valve cover with
  /// its filler cap, intake on the left, fan on the right, sump below.
  void _engine(Canvas canvas) {
    if (!_hasEngine) return;
    final color = DamageView.partColor(DamageView.engineState(t));
    if (t.isElectric) return _motor(canvas, color);
    final x = layout.engine.dx, y = layout.engine.dy;
    final shape = Path()
      // valve cover and cap
      ..moveTo(x - 10, y - 9)
      ..lineTo(x - 6, y - 9)
      ..lineTo(x - 6, y - 12)
      ..lineTo(x + 2, y - 12)
      ..lineTo(x + 2, y - 9)
      ..lineTo(x + 8, y - 9)
      // block, then the fan housing on the right
      ..lineTo(x + 11, y - 5)
      ..lineTo(x + 14, y - 5)
      ..lineTo(x + 14, y - 8)
      ..lineTo(x + 17, y - 8)
      ..lineTo(x + 17, y + 7)
      ..lineTo(x + 14, y + 7)
      ..lineTo(x + 14, y + 4)
      ..lineTo(x + 11, y + 4)
      // sump
      ..lineTo(x + 7, y + 10)
      ..lineTo(x - 9, y + 10)
      ..lineTo(x - 12, y + 5)
      // intake on the left
      ..lineTo(x - 15, y + 5)
      ..lineTo(x - 15, y + 1)
      ..lineTo(x - 18, y + 1)
      ..lineTo(x - 18, y - 4)
      ..lineTo(x - 15, y - 4)
      ..lineTo(x - 15, y - 6)
      ..lineTo(x - 12, y - 6)
      ..close();
    _part(canvas, shape, color);
  }

  /// Jerrycan in the boot (ahead of the cabin for mid/rear engines),
  /// filled from the bottom to the fuel level.
  void _fuelTank(Canvas canvas) {
    final state = DamageView.fuelTankState(t);
    if (state == PartState.unknown && t.fuel == null) return;
    if (t.isElectric) {
      final mid = Offset(cx, (layout.frontAxleY + layout.rearAxleY) / 2);
      return _scaled(canvas, mid, () => _battery(canvas, DamageView.partColor(state)));
    }
    final top = layout.rearEngine
        ? layout.frontAxleY + 10
        : math.min(layout.rearAxleY + 9, layout.tailY - 31);
    _scaled(canvas, Offset(cx, top + 14), () => _jerrycan(canvas, top, DamageView.partColor(state)));
  }

  void _jerrycan(Canvas canvas, double top, Color color) {
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

  /// Electric motor pictogram: round stator with a lightning bolt.
  void _motor(Canvas canvas, Color color) {
    final c = layout.engine;
    _part(canvas, _rrect(Rect.fromCenter(center: c.translate(0, -11), width: 8, height: 4), 1), color); // terminals
    _part(canvas, Path()..addOval(Rect.fromCircle(center: c, radius: 10)), color);
    final bolt = Path()
      ..moveTo(c.dx + 1.5, c.dy - 7)
      ..lineTo(c.dx - 4, c.dy + 1)
      ..lineTo(c.dx - 0.5, c.dy + 1)
      ..lineTo(c.dx - 1.5, c.dy + 7)
      ..lineTo(c.dx + 4, c.dy - 1)
      ..lineTo(c.dx + 0.5, c.dy - 1)
      ..close();
    canvas.drawPath(bolt, _fill(Colors.black.withValues(alpha: 0.8)));
  }

  /// Battery pack in the floor between the axles, charged to the level.
  void _battery(Canvas canvas, Color color) {
    final mid = (layout.frontAxleY + layout.rearAxleY) / 2;
    final half = math.min(19.0, (layout.rearAxleY - layout.frontAxleY) / 2 - 16).clamp(8.0, 19.0);
    final pack = Rect.fromLTRB(31, mid - half, 69, mid + half);
    canvas.drawRRect(RRect.fromRectAndRadius(pack, const Radius.circular(2)), _fill(const Color(0xFF3A3F45)));
    final level = (t.fuel ?? 1).clamp(0.0, 1.0);
    canvas.drawRect(Rect.fromLTRB(pack.left, pack.bottom - pack.height * level, pack.right, pack.bottom), _fill(color));
    // Cells.
    final cell = Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..strokeWidth = 0.8;
    for (var y = pack.top + 7.6; y < pack.bottom; y += 7.6) {
      canvas.drawLine(Offset(pack.left, y), Offset(pack.right, y), cell);
    }
    canvas.drawLine(pack.topCenter, pack.bottomCenter, cell);
    canvas.drawRRect(RRect.fromRectAndRadius(pack, const Radius.circular(2)), _outline);
    // + and - terminals.
    _part(canvas, _rrect(Rect.fromLTRB(36, pack.top - 4, 42, pack.top), 0.8), color);
    _part(canvas, _rrect(Rect.fromLTRB(58, pack.top - 4, 64, pack.top), 0.8), color);
  }

  void _wheels(Canvas canvas) {
    final low = t.lowPressureTires().toSet();
    layout.tyres.forEach((name, r) {
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
      final radius = math.min(4.0, r.shortestSide / 2);
      _part(canvas, _rrect(r, radius), tyreColor);
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
      final half = math.min(11.0, r.height / 2 - 2);
      final brake = layout.isLeft(name)
          ? Rect.fromLTRB(r.right + 1, r.center.dy - half, r.right + 7, r.center.dy + half)
          : Rect.fromLTRB(r.left - 7, r.center.dy - half, r.left - 1, r.center.dy + half);
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
    final low = t.lowPressureTires().toSet();
    layout.tyres.forEach((name, r) {
      final left = layout.isLeft(name);
      final x = left ? margin - 2 : margin + 100 + 2;
      final pressure = t.tirePressures?[name];
      final tyreTemp = t.tyres?[name]?.temp;
      final brakeTemp = t.brakeTemps?[name] ?? t.tyres?[name]?.brake;
      // (text, colour, is the brake temperature)
      final lines = <(String, Color, bool)>[
        if (pressure != null)
          (DashFormat.pressure(pressure, pressureUnit), low.contains(name) ? DamageView.warningColor : Colors.white, false),
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
