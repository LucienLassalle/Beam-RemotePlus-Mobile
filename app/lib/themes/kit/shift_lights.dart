import 'package:flutter/material.dart';

/// Row of round shift LEDs lighting up from the left as RPM approaches the
/// limiter: green, then red, then everything blinks blue at the shift point.
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

  Color _colorFor(int index) {
    if (shiftNow) return Colors.lightBlueAccent;
    final position = index / count;
    if (position < 0.4) return Colors.greenAccent;
    if (position < 0.75) return Colors.redAccent;
    return Colors.purpleAccent;
  }

  @override
  Widget build(BuildContext context) {
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
              color: i < lit ? _colorFor(i) : Colors.white10,
              boxShadow: i < lit ? [BoxShadow(color: _colorFor(i).withValues(alpha: 0.7), blurRadius: size / 3)] : null,
            ),
          ),
      ],
    );
  }
}
