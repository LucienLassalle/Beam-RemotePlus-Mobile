import 'package:flutter/material.dart';

/// Colour-blind friendly colours (setting "Colour-blind mode"): the
/// red / green pairs of the controls and gauges become orange / blue, which
/// stay apart for the common red-green colour blindness. The driving screen
/// provides it; kit widgets read it with [ColorVision.colorBlindOf].
class ColorVision extends InheritedWidget {
  final bool colorBlind;
  const ColorVision({super.key, required this.colorBlind, required super.child});

  /// False outside the driving screen (settings previews, screenshots).
  static bool colorBlindOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ColorVision>()?.colorBlind ?? false;

  /// Pedals in colour-blind mode.
  static const Color brake = Color(0xFFFF9100);
  static const Color throttle = Color(0xFF40C4FF);

  /// "Fine" instead of green, next to amber and red.
  static const Color fine = Color(0xFF2E9BFF);

  @override
  bool updateShouldNotify(ColorVision oldWidget) => oldWidget.colorBlind != colorBlind;
}
