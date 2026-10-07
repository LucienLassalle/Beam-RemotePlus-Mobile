import 'package:flutter/material.dart';

/// Dashboard telltale: bright when [on], dim otherwise, hidden when the
/// vehicle does not report it ([on] == null).
class WarningLamp extends StatelessWidget {
  final IconData icon;
  final bool? on;
  final Color color;
  final double size;
  final bool hideWhenUnknown;

  const WarningLamp({
    super.key,
    required this.icon,
    required this.on,
    required this.color,
    this.size = 20,
    this.hideWhenUnknown = false,
  });

  @override
  Widget build(BuildContext context) {
    if (on == null && hideWhenUnknown) return SizedBox(width: size, height: size);
    return Icon(icon, size: size, color: on == true ? color : color.withValues(alpha: 0.15));
  }
}
