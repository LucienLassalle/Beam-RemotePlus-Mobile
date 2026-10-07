import 'package:flutter/material.dart';

/// Round icon button reporting press and release (for hold commands such as
/// the horn) or a simple tap ([onPressed]).
class HoldButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool enabled;
  final bool active;
  final Color color;
  final ValueChanged<bool>? onHold;
  final VoidCallback? onPressed;

  const HoldButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.color,
    this.enabled = true,
    this.active = false,
    this.onHold,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final fg = !enabled ? color.withValues(alpha: 0.2) : (active ? Colors.black : color);
    return Tooltip(
      message: tooltip,
      child: Listener(
        onPointerDown: enabled && onHold != null ? (_) => onHold!(true) : null,
        onPointerUp: enabled && onHold != null ? (_) => onHold!(false) : null,
        onPointerCancel: enabled && onHold != null ? (_) => onHold!(false) : null,
        child: GestureDetector(
          onTap: enabled ? onPressed : null,
          child: Container(
            width: 42,
            height: 42,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? color : Colors.black.withValues(alpha: 0.45),
              border: Border.all(color: color.withValues(alpha: enabled ? 0.35 : 0.1)),
            ),
            child: Icon(icon, size: 20, color: fg),
          ),
        ),
      ),
    );
  }
}
