import 'package:flutter/material.dart';

import '../../../core/protocol/mod_protocol.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../themes/control_theme.dart';
import '../driving_controller.dart';
import 'hold_button.dart';

String vehicleActionLabel(AppLocalizations l10n, VehicleAction a) => switch (a) {
      VehicleAction.signals => l10n.actionSignals,
      VehicleAction.hazard => l10n.actionHazard,
      VehicleAction.horn => l10n.actionHorn,
      VehicleAction.highBeam => l10n.actionHighBeam,
      VehicleAction.lights => l10n.actionLights,
      VehicleAction.parkingBrake => l10n.actionParkingBrake,
      VehicleAction.starter => l10n.actionStarter,
      VehicleAction.driveMode => l10n.actionEscMode,
      VehicleAction.cruise => l10n.actionCruise,
    };

/// Vehicle buttons offered by the theme and not hidden by the user. Their
/// lit state comes from telemetry, so the phone shows what the car really
/// does (e.g. hazards on).
class VehicleActionsBar extends StatelessWidget {
  final DrivingController controller;
  final Set<VehicleAction> actions;
  final Color color;

  const VehicleActionsBar({super.key, required this.controller, required this.actions, required this.color});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = controller.telemetry;
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
    final buttons = <Widget>[
      for (final a in VehicleAction.values)
        if (actions.contains(a))
          ...switch (a) {
            VehicleAction.signals => [
                press(Icons.arrow_back, l10n.actionSignalLeft, ModCommand.signalLeft, t.signalLeft),
                press(Icons.arrow_forward, l10n.actionSignalRight, ModCommand.signalRight, t.signalRight),
              ],
            VehicleAction.hazard => [press(Icons.warning_amber, l10n.actionHazard, ModCommand.hazard, t.hazard)],
            VehicleAction.horn => [hold(Icons.campaign, l10n.actionHorn, ModCommand.horn, null)],
            VehicleAction.highBeam => [hold(Icons.flare, l10n.actionHighBeam, ModCommand.highBeam, t.highBeam)],
            VehicleAction.lights => [press(Icons.light_mode, l10n.actionLights, ModCommand.lights, t.lowBeam)],
            VehicleAction.parkingBrake => [
                press(Icons.local_parking, l10n.actionParkingBrake, ModCommand.parkingBrake, t.parkingBrake),
              ],
            VehicleAction.starter => [hold(Icons.key, l10n.actionStarter, ModCommand.starter, t.engineRunning)],
            VehicleAction.driveMode => [press(Icons.tune, l10n.actionEscMode, ModCommand.escMode, null)],
            VehicleAction.cruise => [
                press(Icons.speed, l10n.actionCruise, t.cruiseActive == true ? ModCommand.cruiseOff : ModCommand.cruiseSet,
                    t.cruiseActive),
              ],
          },
    ];
    return Row(mainAxisSize: MainAxisSize.min, children: buttons);
  }
}
