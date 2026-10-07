import 'package:flutter/material.dart';

/// Framed label + value cell used by race displays.
class ValueBox extends StatelessWidget {
  final String label;
  final String value;
  final double scale;
  final double valueSize;
  final Color valueColor;
  final Color borderColor;
  final Color labelColor;

  const ValueBox({
    super.key,
    required this.label,
    required this.value,
    this.scale = 1,
    this.valueSize = 20,
    this.valueColor = Colors.white,
    this.borderColor = const Color(0x40FFFFFF),
    this.labelColor = Colors.white38,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 4 * scale, horizontal: 4 * scale),
      decoration: BoxDecoration(border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(4 * scale)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 9 * scale, color: labelColor, letterSpacing: 1.2)),
          SizedBox(height: 2 * scale),
          FittedBox(
            child: Text(
              value,
              style: TextStyle(fontSize: valueSize * scale, fontWeight: FontWeight.w700, color: valueColor, height: 1),
            ),
          ),
        ],
      ),
    );
  }
}
