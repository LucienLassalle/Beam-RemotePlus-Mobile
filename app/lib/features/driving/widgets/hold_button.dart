import 'package:flutter/material.dart';

/// Round icon button reporting press and release (for hold commands such as
/// the horn) or a simple tap ([onPressed]), and a long press
/// ([onLongPress]). A short [label] ("DRS") may replace the icon, like the
/// buttons of a race steering wheel.
class HoldButton extends StatelessWidget {
  final IconData? icon;
  final String? label;
  final String tooltip;
  final bool enabled;
  final bool active;
  final Color color;

  /// Fill when [active] (defaults to [color]), e.g. blue for main beam.
  final Color? activeColor;
  final ValueChanged<bool>? onHold;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final double size;

  const HoldButton({
    super.key,
    this.icon,
    this.label,
    required this.tooltip,
    required this.color,
    this.activeColor,
    this.enabled = true,
    this.active = false,
    this.onHold,
    this.onPressed,
    this.onLongPress,
    this.size = 42,
  }) : assert(icon != null || label != null);

  @override
  Widget build(BuildContext context) {
    final fill = activeColor ?? color;
    final fg = !enabled ? color.withValues(alpha: 0.2) : (active ? Colors.black : color);
    return Tooltip(
      message: tooltip,
      child: Listener(
        onPointerDown: enabled && onHold != null ? (_) => onHold!(true) : null,
        onPointerUp: enabled && onHold != null ? (_) => onHold!(false) : null,
        onPointerCancel: enabled && onHold != null ? (_) => onHold!(false) : null,
        child: GestureDetector(
          onTap: enabled ? onPressed : null,
          onLongPress: enabled ? onLongPress : null,
          child: Container(
            width: size,
            height: size,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? fill : Colors.black.withValues(alpha: 0.45),
              border: Border.all(color: color.withValues(alpha: enabled ? 0.35 : 0.1)),
            ),
            alignment: Alignment.center,
            child: label != null
                ? Text(label!, style: TextStyle(color: fg, fontSize: size * 0.26, fontWeight: FontWeight.w800, letterSpacing: 0.5))
                : Icon(icon, size: size * 0.48, color: fg),
          ),
        ),
      ),
    );
  }
}
