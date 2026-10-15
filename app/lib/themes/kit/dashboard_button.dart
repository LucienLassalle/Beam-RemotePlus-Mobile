import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// A pressable spot of a dashboard, e.g. the indicator arrows of Road: a tap
/// sends [command] to the game. The rest of the dashboard still lets every
/// touch through to the pedals (see [DashboardTouchFilter]), so keep these
/// spots few and away from where thumbs rest.
///
/// [onCommand] is [DashboardData.onCommand]: null without the mod or in
/// read-only mode, then [child] is drawn as is and takes no touch.
class DashboardButton extends StatefulWidget {
  final String command;
  final void Function(String command)? onCommand;
  final String? tooltip;

  /// Diameter of the round touch area (at least 48 logical pixels once the
  /// dashboard is scaled to the screen is comfortable).
  final double size;
  final Widget child;

  const DashboardButton({
    super.key,
    required this.command,
    required this.onCommand,
    required this.child,
    this.tooltip,
    this.size = 56,
  });

  @override
  State<DashboardButton> createState() => _DashboardButtonState();
}

class _DashboardButtonState extends State<DashboardButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final onCommand = widget.onCommand;
    final ring = AnimatedContainer(
      duration: const Duration(milliseconds: 90),
      width: widget.size,
      height: widget.size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: _pressed ? 0.14 : 0),
        border: Border.all(color: Colors.white.withValues(alpha: onCommand == null ? 0 : (_pressed ? 0.55 : 0.14))),
      ),
      child: AnimatedScale(scale: _pressed ? 0.88 : 1, duration: const Duration(milliseconds: 90), child: widget.child),
    );
    if (onCommand == null) return ring;
    final button = _DashboardButtonMarker(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapCancel: () => _setPressed(false),
        onTapUp: (_) => _setPressed(false),
        onTap: () => onCommand(widget.command),
        child: ring,
      ),
    );
    final tooltip = widget.tooltip;
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}

/// Wraps a theme dashboard: touches go through to the controls underneath
/// (the pedals), except on its [DashboardButton]s.
class DashboardTouchFilter extends SingleChildRenderObjectWidget {
  const DashboardTouchFilter({super.key, required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderDashboardTouchFilter();
}

class _RenderDashboardTouchFilter extends RenderProxyBox {
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null || !size.contains(position)) return false;
    // Dry run first: a hit result cannot be rolled back, and a touch that
    // misses every button must leave no trace so the pedals get it.
    final probe = BoxHitTestResult();
    if (!child.hitTest(probe, position: position)) return false;
    if (!probe.path.any((entry) => entry.target is _RenderDashboardButtonMarker)) return false;
    return super.hitTest(result, position: position);
  }
}

class _DashboardButtonMarker extends SingleChildRenderObjectWidget {
  const _DashboardButtonMarker({required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderDashboardButtonMarker();
}

class _RenderDashboardButtonMarker extends RenderProxyBox {}
