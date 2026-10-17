import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../kit/kit.dart';

/// Drift: the drift angle in big, a car pictogram turned by it against the
/// direction of travel, RPM lights, speed and gear, and a big handbrake to
/// hold at the bottom left, above the brake.
class DriftTheme extends ControlTheme {
  const DriftTheme();

  @override
  String get name => 'Drift';

  @override
  String get author => 'LucienLassalle';

  @override
  ThemeStyle get style => const ThemeStyle(handbrakeButton: true);

  /// Colour of the angle: white while gripping, then amber and red as the
  /// slide grows.
  static Color angleColor(double? angle) {
    final a = (angle ?? 0).abs();
    if (a < 10) return Colors.white;
    if (a < 35) return Colors.amberAccent;
    return Colors.deepOrangeAccent;
  }

  @override
  Widget buildDashboard(BuildContext context, DashboardData data) {
    if (!data.modActive) {
      return const Center(child: Icon(Icons.rotate_90_degrees_ccw, size: 72, color: Colors.white12));
    }
    final t = data.telemetry;
    final angle = t.driftAngle;
    return Center(
      child: FittedBox(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ShiftLights(rpm: t.rpm, maxRpm: t.maxRpm, shiftNow: t.shiftLight ?? false, count: 12, size: 14),
            const SizedBox(height: 12),
            Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [
              _SlipPictogram(angle: angle),
              const SizedBox(width: 20),
              Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('DRIFT', style: TextStyle(color: Colors.white38, fontSize: 13, letterSpacing: 3)),
                Text(
                  angle == null ? DashFormat.missing : '${angle.abs().round()}°',
                  style: TextStyle(color: angleColor(angle), fontSize: 110, fontWeight: FontWeight.w800, height: 1),
                ),
              ]),
              const SizedBox(width: 40),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text(t.gearLabel,
                    style: TextStyle(
                      color: data.gearFlash == null ? Colors.amberAccent : Colors.white,
                      fontSize: 64,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    )),
                const SizedBox(height: 6),
                Text('${DashFormat.speed(t, kmh: data.useKmh)} ${DashFormat.speedUnit(kmh: data.useKmh)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 24)),
              ]),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// The direction of travel (arrow up) and the car turned by the drift angle
/// against it: how sideways the car is, at a glance.
class _SlipPictogram extends StatelessWidget {
  final double? angle;
  const _SlipPictogram({required this.angle});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 96,
        height: 120,
        child: Stack(alignment: Alignment.center, children: [
          const Positioned(top: 0, child: Icon(Icons.arrow_upward, color: Colors.white24, size: 28)),
          // A positive angle: the car goes to the left of its nose, so the
          // nose points right of the travel arrow.
          Transform.rotate(
            angle: (angle ?? 0) * math.pi / 180,
            child: Icon(Icons.directions_car_filled, color: DriftTheme.angleColor(angle), size: 72),
          ),
        ]),
      );
}
