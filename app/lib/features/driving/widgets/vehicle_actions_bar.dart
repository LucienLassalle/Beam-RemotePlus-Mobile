import 'package:flutter/material.dart';

import '../../../core/protocol/mod_protocol.dart';
import '../../../core/protocol/telemetry.dart';
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
      VehicleAction.flashers => l10n.actionFlashers,
      VehicleAction.siren => l10n.actionSiren,
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
    HoldButton press(IconData icon, String tip, String command, bool? on, {Color? activeColor}) => HoldButton(
          icon: icon,
          tooltip: tip,
          color: color,
          activeColor: activeColor,
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
            VehicleAction.lights => [_lights(l10n, t, enabled)],
            // Emergency vehicles only (police, ambulance, fire, pace car).
            VehicleAction.flashers => [
                if (t.hasLightbar == true)
                  press(Icons.emergency_share, l10n.actionFlashers, ModCommand.flashers, (t.lightbar ?? 0) > 0,
                      activeColor: Colors.lightBlueAccent),
              ],
            VehicleAction.siren => [
                if (t.hasSiren == true)
                  press(Icons.volume_up, l10n.actionSiren, ModCommand.siren, t.lightbar == 2, activeColor: Colors.redAccent),
              ],
            VehicleAction.parkingBrake => [
                press(Icons.local_parking, l10n.actionParkingBrake, ModCommand.parkingBrake, t.parkingBrake),
              ],
            VehicleAction.starter => [hold(Icons.key, l10n.actionStarter, ModCommand.starter, t.engineRunning)],
            // Hidden on vehicles with neither drive modes nor ESC.
            VehicleAction.driveMode => [
                if (t.driveMode case final mode?)
                  _ModeButton(
                    mode: mode,
                    esc: t.driveModeIsEsc ?? false,
                    modeColor: t.driveModeColor,
                    intervening: (t.escActive ?? false) || (t.tcsActive ?? false),
                    color: color,
                    enabled: enabled,
                    onPressed: () => controller.press(ModCommand.escMode),
                  ),
              ],
            VehicleAction.cruise => [
                press(Icons.speed, l10n.actionCruise, t.cruiseActive == true ? ModCommand.cruiseOff : ModCommand.cruiseSet,
                    t.cruiseActive),
              ],
          },
    ];
    return Row(mainAxisSize: MainAxisSize.min, children: buttons);
  }

  /// One button for the headlights: each tap goes to the next state (the
  /// game cycles off, dipped, main beam), shown with the dashboard colors.
  HoldButton _lights(AppLocalizations l10n, Telemetry t, bool enabled) {
    final high = t.highBeam ?? false;
    final low = !high && (t.lowBeam ?? false);
    return HoldButton(
      icon: high ? Icons.highlight : Icons.light_mode,
      tooltip: high ? l10n.actionLightsHigh : (low ? l10n.actionLightsLow : l10n.actionLightsOff),
      color: color,
      activeColor: high ? Colors.lightBlueAccent : Colors.greenAccent,
      enabled: enabled,
      active: high || low,
      onPressed: () => controller.press(ModCommand.lights),
    );
  }
}

/// Drive mode button: says which mode is on ("MODE / SPORT", or "ESC /
/// REGULAR" on vehicles without drive modes) and that a tap goes to the
/// next one (chevron), in the color the game gives that mode; like the
/// game's own ESC button, it blinks while the ESC or traction control acts.
class _ModeButton extends StatelessWidget {
  final String mode;
  final bool esc;

  /// 0xRRGGBB from the game, or null (then the theme button color).
  final int? modeColor;
  final bool intervening;
  final Color color;
  final bool enabled;
  final VoidCallback onPressed;

  const _ModeButton({
    required this.mode,
    required this.esc,
    required this.modeColor,
    required this.intervening,
    required this.color,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Telemetry rebuilds the bar ~30 times per second: enough to blink at
    // the game's pace without an animation of our own.
    final blinkOff = intervening && DateTime.now().millisecondsSinceEpoch ~/ 150 % 2 == 1;
    final rgb = modeColor;
    final tint = rgb == null || blinkOff ? null : Color(0xFF000000 | rgb);
    final base = tint ?? color;
    final fg = enabled ? base : base.withValues(alpha: 0.2);
    final tooltip = esc ? l10n.actionEscNext(mode) : l10n.actionDriveModeNext(mode);
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: enabled ? onPressed : null,
        child: Container(
          height: 42,
          constraints: const BoxConstraints(minWidth: 72, maxWidth: 132),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.only(left: 14, right: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(21),
            color: tint == null ? Colors.black.withValues(alpha: 0.45) : Color.alphaBlend(tint.withValues(alpha: 0.16), Colors.black),
            border: Border.all(color: base.withValues(alpha: !enabled ? 0.1 : (tint == null ? 0.35 : 0.8))),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(esc ? l10n.actionEscCaption : l10n.actionDriveModeCaption,
                    style: TextStyle(color: fg.withValues(alpha: enabled ? 0.55 : 0.2), fontSize: 9, letterSpacing: 1.2, height: 1.1)),
                Text(mode.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.w700, height: 1.2)),
              ]),
            ),
            Icon(Icons.chevron_right, size: 20, color: fg),
          ]),
        ),
      ),
    );
  }
}
