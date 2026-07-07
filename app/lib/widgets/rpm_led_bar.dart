import 'package:flutter/material.dart';

/// Rangée de LEDs façon volant de course : s'allument progressivement à
/// l'approche du rupteur, passent au rouge tout proche de la limite.
class RpmLedBar extends StatelessWidget {
  final double rpm;
  final double redlineRpm;
  static const int ledCount = 12;

  const RpmLedBar({super.key, required this.rpm, required this.redlineRpm});

  @override
  Widget build(BuildContext context) {
    final redline = redlineRpm > 0 ? redlineRpm : 7000;
    // Les LEDs couvrent les derniers 35% de la plage de régime.
    final rangeStart = redline * 0.65;
    final ratio = ((rpm - rangeStart) / (redline - rangeStart)).clamp(
      0.0,
      1.0,
    );
    final litCount = (ratio * ledCount).round();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(ledCount, (i) {
        final lit = i < litCount;
        final isRed = i >= (ledCount * 0.75).floor();
        Color color;
        if (!lit) {
          color = Colors.white12;
        } else if (isRed) {
          color = Colors.redAccent;
        } else {
          color = Colors.greenAccent;
        }
        return Container(
          width: 10,
          height: 16,
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            boxShadow: lit
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.7),
                      blurRadius: 4,
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }
}
