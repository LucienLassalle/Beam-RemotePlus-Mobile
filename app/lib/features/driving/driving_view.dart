import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../core/settings/app_settings.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../themes/control_theme.dart';
import '../vehicle_status/widgets/vehicle_panel.dart';
import '../vehicle_status/widgets/warning_overlay.dart';
import 'driving_controller.dart';
import 'pedal_mapping.dart';
import 'widgets/pedal_zones.dart';
import 'widgets/steering_control.dart';
import 'widgets/top_bar.dart';
import 'widgets/vehicle_actions_bar.dart';

/// Composition of the driving screen, without any platform side effect
/// (lifecycle lives in DrivingScreen), so tests can pump it. Layers, bottom
/// to top:
///   1. theme dashboard: visual only, ignores touches
///   2. pedal zones: every touch not taken by a control below
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
        );
        final actions = settings.showActionsBar && !_display
            ? style.actions.where((a) => !settings.hiddenActions.contains(a.name)).toSet()
            : const <VehicleAction>{};
        final bottom = _display ? 8.0 : (settings.tiltSteering ? bottomBarHeight : bottomBarHeight + touchSteeringHeight);
        return ColoredBox(
          color: style.background,
          child: Stack(
            children: [
              // The dashboard gets the space between the button rows, so
              // buttons never hide a gauge. In second-screen mode the vehicle
              // panel takes the right third.
              Positioned(
                top: topBarHeight,
                bottom: bottom,
                left: 0,
                right: _display ? MediaQuery.of(context).size.width * 0.34 : 0,
                child: IgnorePointer(child: theme.buildDashboard(context, data)),
              ),
              if (!_display) ...[
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: controller.readOnly,
                    child: PedalZones(
                      mapping: settings.tiltSteering ? PedalMapping.wide : PedalMapping.sides,
                      onBrake: controller.brake,
                      onThrottle: controller.throttle,
                      visible: style.visiblePedals,
                      brakeColor: style.brakeColor,
                      throttleColor: style.throttleColor,
                    ),
                  ),
                ),
                _steering(context),
              ],
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
              Positioned(top: 54, right: 16, child: IgnorePointer(child: StatusChip(state: controller.linkState))),
              if (settings.warningPopups)
                Positioned(top: topBarHeight, left: 0, right: 0, bottom: bottom, child: WarningOverlay(telemetry: t, resetCount: controller.resetCount)),
              if (_display)
                Positioned(
                  top: topBarHeight + 24,
                  right: 28,
                  bottom: 12,
                  width: MediaQuery.of(context).size.width * 0.3,
                  child: FittedBox(
                    child: VehiclePanel(telemetry: t, temperatureUnit: settings.temperatureUnit, pressureUnit: settings.pressureUnit),
                  ),
                )
              else if (settings.showVehiclePanel)
                Positioned(top: 48, left: 12, child: VehiclePanel(
                    telemetry: t,
                    height: 160,
                    temperatureUnit: settings.temperatureUnit,
                    pressureUnit: settings.pressureUnit,
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
                  bottom: settings.tiltSteering ? 6 : 76,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
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
      recalibrateCounter: recalibrateCounter,
      accelerometer: accelerometer,
      onPitchShift: settings.pitchGearShift ? (direction) => controller.shift(up: direction > 0) : null,
    );
    if (settings.tiltSteering) return Positioned(left: 0, top: 0, child: steering);
    final width = MediaQuery.of(context).size.width;
    return Positioned(
      bottom: 12,
      left: width * 0.34,
      right: width * 0.34,
      child: IgnorePointer(ignoring: controller.readOnly, child: steering),
    );
  }
}
