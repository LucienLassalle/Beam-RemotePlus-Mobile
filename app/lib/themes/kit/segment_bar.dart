import 'package:flutter/material.dart';

/// Vertical or horizontal bar made of segments, like the small bar gauges of
/// in-game dashboards (temperatures, fuel, boost).
class SegmentBar extends StatelessWidget {
  /// 0..1, null = unknown (all segments off).
  final double? value;
  final int segments;
  final Axis direction;
  final Color onColor;
  final Color offColor;

  /// Colors overriding [onColor] for the first / last segment (e.g. blue when
  /// cold, red when too hot).
  final Color? firstColor;
  final Color? lastColor;
  final double thickness;
  final double gap;

  const SegmentBar({
    super.key,
    required this.value,
    this.segments = 6,
    this.direction = Axis.horizontal,
    this.onColor = Colors.white,
    this.offColor = const Color(0xFF323232),
    this.firstColor,
    this.lastColor,
    this.thickness = 8,
    this.gap = 2,
  });

  /// Index of segments that are on (same rule as the game's gauges: a
  /// segment lights up when the value passes its middle).
  static bool isOn(double? value, int index, int segments) =>
      value != null && value > (index + 0.5) / segments;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      for (var i = 0; i < segments; i++)
        Expanded(
          child: Container(
            margin: direction == Axis.horizontal ? EdgeInsets.only(right: gap) : EdgeInsets.only(top: gap),
            color: !isOn(value, i, segments)
                ? offColor
                : i == 0 && firstColor != null
                    ? firstColor
                    : i == segments - 1 && lastColor != null
                        ? lastColor
                        : onColor,
          ),
        ),
    ];
    return direction == Axis.horizontal
        ? SizedBox(height: thickness, child: Row(children: children))
        : SizedBox(width: thickness, child: Column(children: children.reversed.toList()));
  }
}
