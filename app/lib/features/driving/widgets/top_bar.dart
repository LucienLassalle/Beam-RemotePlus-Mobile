import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/remote_link.dart';
import '../../../core/protocol/mod_protocol.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../driving_controller.dart';
import 'hold_button.dart';

/// Vehicle switching (left) and hold-to-reset (centre). The settings / help
/// / debug buttons are added by the screen on the right.
class VehicleTopBar extends StatelessWidget {
  final DrivingController controller;
  final Color color;
  final VoidCallback onRecovered;

  const VehicleTopBar({super.key, required this.controller, required this.color, required this.onRecovered});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final enabled = controller.commandsEnabled;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        HoldButton(
          icon: Icons.skip_previous,
          tooltip: l10n.vehiclePrev,
          color: color,
          enabled: enabled,
          onPressed: () => controller.press(ModCommand.prevVehicle),
        ),
        HoldButton(
          icon: Icons.skip_next,
          tooltip: l10n.vehicleNext,
          color: color,
          enabled: enabled,
          onPressed: () => controller.press(ModCommand.nextVehicle),
        ),
        const SizedBox(width: 12),
        HoldButton(
          icon: Icons.restart_alt,
          tooltip: l10n.resetVehicleTooltip,
          color: Colors.orangeAccent,
          enabled: enabled,
          active: controller.heldCommands.contains(ModCommand.recover),
          // Same as the Insert key: short hold = small reset, long hold =
          // rewind further back in the position history.
          onHold: (pressed) {
            if (pressed) HapticFeedback.mediumImpact();
            controller.hold(ModCommand.recover, pressed: pressed);
            if (!pressed) onRecovered();
          },
        ),
      ],
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
