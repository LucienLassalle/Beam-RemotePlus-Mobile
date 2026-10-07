import 'package:flutter/material.dart';

import '../../../core/protocol/mod_protocol.dart';
import '../../../core/protocol/telemetry.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../driving_controller.dart';
import 'hold_button.dart';

/// Vehicle function buttons. Their lit state comes from telemetry, so the
/// phone always shows what the car really does (e.g. hazards on).
class VehicleActionsBar extends StatelessWidget {
  final DrivingController controller;
  final Color color;

  const VehicleActionsBar({super.key, required this.controller, required this.color});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final Telemetry t = controller.telemetry;
    final enabled = controller.commandsEnabled;
    final held = controller.heldCommands;
    HoldButton press(IconData icon, String tip, String command, bool? on) => HoldButton(
          icon: icon,
          tooltip: tip,
          color: color,
          enabled: enabled,
          active: on ?? false,
          onPressed: () => controller.press(command),
        );
    HoldButton hold(IconData icon, String tip, String command, bool? on) => HoldButton(
          icon: icon,
          tooltip: tip,
          color: color,
          enabled: enabled,
          active: held.contains(command) || (on ?? false),
          onHold: (pressed) => controller.hold(command, pressed: pressed),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        press(Icons.arrow_back, l10n.actionSignalLeft, ModCommand.signalLeft, t.signalLeft),
        press(Icons.warning_amber, l10n.actionHazard, ModCommand.hazard, t.hazard),
        press(Icons.arrow_forward, l10n.actionSignalRight, ModCommand.signalRight, t.signalRight),
        const SizedBox(width: 8),
        hold(Icons.campaign, l10n.actionHorn, ModCommand.horn, null),
        hold(Icons.flare, l10n.actionHighBeam, ModCommand.highBeam, t.highBeam),
        press(Icons.light_mode, l10n.actionLights, ModCommand.lights, t.lowBeam),
        press(Icons.local_parking, l10n.actionParkingBrake, ModCommand.parkingBrake, t.parkingBrake),
        const SizedBox(width: 8),
        hold(Icons.key, l10n.actionStarter, ModCommand.starter, t.engineRunning),
        press(Icons.tune, l10n.actionEscMode, ModCommand.escMode, null),
        press(Icons.speed, l10n.actionCruise, t.cruiseActive == true ? ModCommand.cruiseOff : ModCommand.cruiseSet, t.cruiseActive),
      ],
    );
  }
}
