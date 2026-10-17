import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../core/protocol/mod_protocol.dart';
import '../../core/settings/app_settings.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../themes/control_theme.dart';
import '../../themes/kit/color_vision.dart';
import '../../themes/kit/dashboard_button.dart';
import '../vehicle_status/widgets/vehicle_panel.dart';
import '../vehicle_status/widgets/warning_overlay.dart';
import 'driving_controller.dart';
import 'pedal_mapping.dart';
import 'tilt_steering.dart';
import 'widgets/hold_button.dart';
import 'widgets/more_sheet.dart';
import 'widgets/pedal_zones.dart';
import 'widgets/player_badge.dart';
import 'widgets/steering_control.dart';
import 'widgets/top_bar.dart';
import 'widgets/touch_wheel.dart';
import 'widgets/vehicle_actions_bar.dart';

/// Composition of the driving screen, without any platform side effect
/// (lifecycle lives in DrivingScreen), so tests can pump it. Layers, bottom
/// to top:
///   1. pedal zones: every touch not taken by a layer above
///   2. theme dashboard: lets touches through, except on its DashboardButtons
///   3. steering bar, buttons and overlays: only the area they cover
/// In second-screen mode only the dashboard, warnings and the vehicle
/// panel are shown: no controls at all.
class DrivingView extends StatelessWidget {
  final DrivingController controller;
  final AppSettings settings;
  final ControlTheme theme;
  final int recalibrateCounter;
  final Widget hostButtons;
  final Widget? debugOverlay;
  final VoidCallback onRecovered;
  final Stream<AccelerometerEvent>? accelerometer;

  static const double topBarHeight = 52;
  static const double bottomBarHeight = 60;
  static const double touchSteeringHeight = 72;
  /// Thumb wheel, bottom left (the pedals are then both on the right).
  static const double touchWheelSize = 150;

  const DrivingView({
    super.key,
    required this.controller,
    required this.settings,
    required this.theme,
    required this.hostButtons,
    required this.onRecovered,
    this.recalibrateCounter = 0,
    this.debugOverlay,
    this.accelerometer,
  });

  bool get _display => settings.secondScreen;

  /// Room the touch steering takes under the buttons (none when tilting).
  double get _touchSteeringHeight => settings.tiltSteering || settings.touchWheel ? 0 : touchSteeringHeight;

  PedalMapping get _pedalMapping =>
      settings.tiltSteering ? PedalMapping.wide : (settings.touchWheel ? PedalMapping.rightThumb : PedalMapping.sides);

  @override
  Widget build(BuildContext context) {
    final style = theme.style;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final t = controller.telemetry;
        final data = DashboardData(
          telemetry: t,
          modActive: controller.modActive,
          useKmh: settings.useKmh,
          temperatureUnit: settings.temperatureUnit,
          pressureUnit: settings.pressureUnit,
          readOnly: controller.readOnly,
          gearFlash: controller.gearFlash,
          onCommand: !_display && controller.commandsEnabled ? controller.press : null,
        );
        final actions = settings.showActionsBar && !_display
            ? style.actions.where((a) => !settings.hiddenActions.contains(a.name)).toSet()
            : const <VehicleAction>{};
        final bottom = _display ? 8.0 : bottomBarHeight + _touchSteeringHeight;
        return ColorVision(
          colorBlind: settings.colorBlind,
          child: ColoredBox(
            color: style.background,
            child: Stack(
              children: [
                if (!_display)
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: controller.readOnly,
                      child: PedalZones(
                        mapping: _pedalMapping,
                        onBrake: controller.brake,
                        onThrottle: controller.throttle,
                        visible: style.visiblePedals,
                        brakeColor: settings.colorBlind ? ColorVision.brake : style.brakeColor,
                        throttleColor: settings.colorBlind ? ColorVision.throttle : style.throttleColor,
                        swapped: settings.swapPedals,
                      ),
                    ),
                  ),
                // The dashboard gets the space between the button rows, so
                // buttons never hide a gauge. In second-screen mode the vehicle
                // panel takes the right third.
                Positioned(
                  top: topBarHeight,
                  bottom: bottom,
                  left: 0,
                  right: _display ? MediaQuery.of(context).size.width * 0.34 : 0,
                  child: DashboardTouchFilter(child: theme.buildDashboard(context, data)),
                ),
                if (!_display) _steering(context),
                // Drift themes: the handbrake under the left thumb, above the brake.
                if (!_display && style.handbrakeButton)
                  Positioned(
                    left: 28,
                    bottom: 40 + _touchSteeringHeight,
                    child: HoldButton(
                      icon: Icons.local_parking,
                      tooltip: AppLocalizations.of(context).actionHandbrake,
                      color: Colors.redAccent,
                      size: 72,
                      enabled: controller.commandsEnabled,
                      active: controller.heldCommands.contains(ModCommand.handbrake),
                      onHold: (pressed) => controller.hold(ModCommand.handbrake, pressed: pressed),
                    ),
                  ),
                if (controller.gearFlash != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ColoredBox(
                        color: (controller.gearFlash == GearFlash.up ? Colors.cyanAccent : Colors.orangeAccent).withValues(alpha: 0.18),
                      ),
                    ),
                  ),
                if (!_display) ...[
                  Positioned(top: 8, left: 12, child: VehicleSwitchButtons(controller: controller, color: style.buttonColor)),
                  Positioned(
                    top: 4,
                    left: 0,
                    right: 0,
                    child: Center(child: RecoverButton(controller: controller, onRecovered: onRecovered)),
                  ),
                ],
                Positioned(top: 4, right: 8, child: hostButtons),
                Positioned(
                  top: 54,
                  right: 16,
                  child: IgnorePointer(
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      // Only with the colour the game gives the player: never a guess.
                      if (!_display && t.player != null && controller.playerColor != null) ...[
                        PlayerBadge(player: t.player!, color: controller.playerColor!),
                        const SizedBox(width: 6),
                      ],
                      StatusChip(state: controller.linkState, latencyMs: controller.latencyMs, signalLost: controller.signalLost),
                    ]),
                  ),
                ),
                if (settings.warningPopups)
                  Positioned(top: topBarHeight, left: 0, right: 0, bottom: bottom, child: WarningOverlay(telemetry: t, resetCount: controller.resetCount)),
                if (_display)
                  Positioned(
                    top: topBarHeight + 24,
                    right: 28,
                    bottom: 12,
                    width: MediaQuery.of(context).size.width * 0.3,
                    child: FittedBox(
                      child: VehiclePanel(
                        telemetry: t,
                        temperatureUnit: settings.temperatureUnit,
                        pressureUnit: settings.pressureUnit,
                        skeleton: controller.skeleton,
                        skeletonLevels: controller.skeletonLevels,
                        showCarParts: settings.damageCarParts,
                        showWheelParts: settings.showsDamageWheelParts,
                        simpleDamage: settings.simpleDamage,
                      ),
                    ),
                  )
                else if (settings.showVehiclePanel)
                  Positioned(top: 48, left: 12, child: VehiclePanel(
                      telemetry: t,
                      height: 160,
                      temperatureUnit: settings.temperatureUnit,
                      pressureUnit: settings.pressureUnit,
                      skeleton: controller.skeleton,
                      skeletonLevels: controller.skeletonLevels,
                      showCarParts: settings.damageCarParts,
                      showWheelParts: settings.showsDamageWheelParts,
                      simpleDamage: settings.simpleDamage,
                    )),
                if (!controller.modActive)
                  Positioned(
                    top: 80,
                    left: 16,
                    right: 140,
                    child: IgnorePointer(
                      child: Text(AppLocalizations.of(context).modMissingBanner,
                          style: const TextStyle(color: Colors.white38, fontSize: 11)),
                    ),
                  ),
                if (debugOverlay != null) Positioned(top: 78, right: 12, child: IgnorePointer(child: debugOverlay)),
                if (!_display)
                  Positioned(
                    bottom: 6 + _touchSteeringHeight,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (style.moreButton) ...[
                            HoldButton(
                              label: AppLocalizations.of(context).moreButton,
                              tooltip: AppLocalizations.of(context).moreTitle,
                              color: style.buttonColor,
                              enabled: controller.commandsEnabled,
                              onPressed: () => unawaited(showMoreSheet(context, controller)),
                            ),
                            const SizedBox(width: 12),
                          ],
                          if (actions.isNotEmpty) ...[
                            VehicleActionsBar(controller: controller, actions: actions, color: style.buttonColor),
                            const SizedBox(width: 12),
                          ],
                          CameraButtons(controller: controller, color: style.buttonColor),
                        ]),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _steering(BuildContext context) {
    final steering = SteeringControl(
      onSteering: controller.steer,
      tiltMode: settings.tiltSteering,
      rotationRangeDeg: settings.rotationRangeDeg,
      invert: settings.invertSteering,
      smoothing: settings.steeringSmoothing,
      sensor: settings.steeringSensor,
      recalibrateCounter: recalibrateCounter,
      accelerometer: accelerometer,
      onPitchShift: settings.pitchGearShift ? (direction) => controller.shift(up: direction > 0) : null,
    );
    if (settings.tiltSteering) return Positioned(left: 0, top: 0, child: steering);
    if (settings.touchWheel) {
      // Under the left thumb, where the brake usually is: the pedals move
      // to the right thumb (PedalMapping.rightThumb).
      // Mirrored for left-handed players (Throttle on the left setting).
      return Positioned(
        bottom: 12,
        left: settings.swapPedals ? null : 20,
        right: settings.swapPedals ? 20 : null,
        child: IgnorePointer(
          ignoring: controller.readOnly,
          child: TouchWheel(
            onSteering: controller.steer,
            maxAngleDeg: TiltSteering.maxTiltDegFor(settings.rotationRangeDeg),
            color: theme.style.buttonColor,
            size: touchWheelSize,
          ),
        ),
      );
    }
    final width = MediaQuery.of(context).size.width;
    return Positioned(
      bottom: 12,
      left: width * 0.34,
      right: width * 0.34,
      child: IgnorePointer(ignoring: controller.readOnly, child: steering),
    );
  }
}
