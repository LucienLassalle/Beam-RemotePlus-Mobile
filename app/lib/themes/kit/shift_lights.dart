import 'package:flutter/material.dart';

import 'color_vision.dart';

/// Row of round shift LEDs lighting up from the left as RPM approaches the
/// limiter: green, then red, then everything blinks blue at the shift point
/// (blue, orange, then white in colour-blind mode, see [ColorVision]).
class ShiftLights extends StatelessWidget {
  final double? rpm;
  final double? maxRpm;
  final bool shiftNow;
  final int count;
  final double size;

  /// Fraction of max RPM where the first LED lights up.
  final double startRatio;

  const ShiftLights({
    super.key,
    required this.rpm,
    required this.maxRpm,
    this.shiftNow = false,
    this.count = 15,
    this.size = 12,
    this.startRatio = 0.6,
  });

  /// Number of lit LEDs (pure, unit-tested).
  static int litCount(double? rpm, double? maxRpm, int count, double startRatio) {
    if (rpm == null || maxRpm == null || maxRpm <= 0) return 0;
    final start = maxRpm * startRatio;
    final ratio = ((rpm - start) / (maxRpm - start)).clamp(0.0, 1.0);
    return (ratio * count).round();
  }

  /// Colour of the LED at [index] (pure, unit-tested).
  Color colorFor(int index, {bool colorBlind = false}) {
    if (shiftNow) return colorBlind ? Colors.white : Colors.lightBlueAccent;
    final position = index / count;
    if (position < 0.4) return colorBlind ? ColorVision.throttle : Colors.greenAccent;
    if (position < 0.75) return colorBlind ? ColorVision.brake : Colors.redAccent;
    return Colors.purpleAccent;
  }

  @override
  Widget build(BuildContext context) {
    final colorBlind = ColorVision.colorBlindOf(context);
    Color colorAt(int i) => colorFor(i, colorBlind: colorBlind);
    final lit = shiftNow ? count : litCount(rpm, maxRpm, count, startRatio);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          Container(
            width: size,
            height: size,
            margin: EdgeInsets.symmetric(horizontal: size * 0.15),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < lit ? colorAt(i) : Colors.white10,
              boxShadow: i < lit ? [BoxShadow(color: colorAt(i).withValues(alpha: 0.7), blurRadius: size / 3)] : null,
            ),
          ),
      ],
    );
  }
}
