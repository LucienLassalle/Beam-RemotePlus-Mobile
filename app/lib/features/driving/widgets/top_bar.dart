import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/remote_link.dart';
import '../../../core/protocol/mod_protocol.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../driving_controller.dart';
import 'hold_button.dart';

/// Previous / next vehicle, small, top left.
class VehicleSwitchButtons extends StatelessWidget {
  final DrivingController controller;
  final Color color;
  const VehicleSwitchButtons({super.key, required this.controller, required this.color});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final enabled = controller.commandsEnabled;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      HoldButton(
        icon: Icons.skip_previous,
        tooltip: l10n.vehiclePrev,
        color: color,
        enabled: enabled,
        size: 34,
        onPressed: () => controller.press(ModCommand.prevVehicle),
      ),
      HoldButton(
        icon: Icons.skip_next,
        tooltip: l10n.vehicleNext,
        color: color,
        enabled: enabled,
        size: 34,
        onPressed: () => controller.press(ModCommand.nextVehicle),
      ),
    ]);
  }
}

/// Hold-to-reset, top centre. Nothing happens on a short tap: a ring fills
/// up for [holdDelay], then the recovery starts and keeps rewinding (like
/// holding the Insert key) until the button is released.
class RecoverButton extends StatefulWidget {
  final DrivingController controller;
  final VoidCallback onRecovered;
  const RecoverButton({super.key, required this.controller, required this.onRecovered});

  static const holdDelay = Duration(seconds: 1);

  @override
  State<RecoverButton> createState() => _RecoverButtonState();
}

class _RecoverButtonState extends State<RecoverButton> with SingleTickerProviderStateMixin {
  late final AnimationController _progress = AnimationController(vsync: this, duration: RecoverButton.holdDelay)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        HapticFeedback.heavyImpact();
        widget.controller.hold(ModCommand.recover, pressed: true);
      }
    });

  void _press() {
    if (!widget.controller.commandsEnabled) return;
    HapticFeedback.selectionClick();
    _progress.forward(from: 0);
  }

  void _release() {
    final recovering = widget.controller.heldCommands.contains(ModCommand.recover);
    widget.controller.hold(ModCommand.recover, pressed: false);
    _progress.reset();
    if (recovering) widget.onRecovered();
  }

  @override
  void dispose() {
    widget.controller.hold(ModCommand.recover, pressed: false);
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.controller.commandsEnabled;
    return Tooltip(
      message: AppLocalizations.of(context).resetVehicleTooltip,
      child: Listener(
        onPointerDown: (_) => _press(),
        onPointerUp: (_) => _release(),
        onPointerCancel: (_) => _release(),
        child: SizedBox(
          width: 48,
          height: 48,
          child: AnimatedBuilder(
            animation: _progress,
            builder: (context, _) {
              final recovering = widget.controller.heldCommands.contains(ModCommand.recover);
              return Stack(alignment: Alignment.center, children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: recovering ? Colors.orangeAccent : Colors.black.withValues(alpha: 0.45),
                    border: Border.all(color: Colors.orangeAccent.withValues(alpha: enabled ? 0.35 : 0.1)),
                  ),
                  child: Icon(Icons.restart_alt,
                      size: 20, color: recovering ? Colors.black : Colors.orangeAccent.withValues(alpha: enabled ? 1 : 0.2)),
                ),
                if (_progress.value > 0 && !recovering)
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(value: _progress.value, strokeWidth: 3, color: Colors.orangeAccent),
                  ),
              ]);
            },
          ),
        ),
      ),
    );
  }
}

class CameraButtons extends StatelessWidget {
  final DrivingController controller;
  final Color color;
  const CameraButtons({super.key, required this.controller, required this.color});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      HoldButton(
        icon: Icons.photo_camera_back,
        tooltip: l10n.camPrev,
        color: color,
        enabled: controller.commandsEnabled,
        onPressed: () => controller.press(ModCommand.camPrev),
      ),
      HoldButton(
        icon: Icons.flip_camera_android,
        tooltip: l10n.camNext,
        color: color,
        enabled: controller.commandsEnabled,
        onPressed: () => controller.press(ModCommand.camNext),
      ),
    ]);
  }
}

class StatusChip extends StatelessWidget {
  final LinkState state;
  const StatusChip({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (label, color) = switch (state) {
      LinkState.connected => (l10n.statusConnected, Colors.greenAccent),
      LinkState.connecting => (l10n.statusConnecting, Colors.amberAccent),
      LinkState.timeout => (l10n.statusTimeout, Colors.orangeAccent),
      LinkState.error => (l10n.statusError, Colors.redAccent),
      LinkState.idle => (l10n.statusIdle, Colors.white38),
    };
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.circle, size: 8, color: color),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
    ]);
  }
}
