import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../core/settings/app_settings.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../themes/control_theme.dart';
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

  @override
  Widget build(BuildContext context) {
    final style = theme.style;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final data = DashboardData(
          telemetry: controller.telemetry,
          modActive: controller.modActive,
          useKmh: settings.useKmh,
          readOnly: controller.readOnly,
          gearFlash: controller.gearFlash,
        );
        return ColoredBox(
          color: style.background,
          child: Stack(
            children: [
              // The dashboard gets the space between the top and bottom
              // button rows, so buttons never hide a gauge.
              Positioned.fill(
                top: topBarHeight,
                bottom: settings.tiltSteering ? bottomBarHeight : bottomBarHeight + touchSteeringHeight,
                child: IgnorePointer(child: theme.buildDashboard(context, data)),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: controller.readOnly,
                  child: PedalZones(
                    mapping: settings.tiltSteering ? PedalMapping.halves : PedalMapping.sides,
                    onBrake: controller.brake,
                    onThrottle: controller.throttle,
                    visible: style.visiblePedals,
                    brakeColor: style.brakeColor,
                    throttleColor: style.throttleColor,
                  ),
                ),
              ),
              _steering(context),
              if (controller.gearFlash != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ColoredBox(
                      color: (controller.gearFlash == GearFlash.up ? Colors.cyanAccent : Colors.orangeAccent).withValues(alpha: 0.18),
                    ),
                  ),
                ),
              Positioned(top: 6, left: 12, child: VehicleTopBar(controller: controller, color: style.buttonColor, onRecovered: onRecovered)),
              Positioned(top: 6, right: 8, child: hostButtons),
              Positioned(top: 54, right: 16, child: IgnorePointer(child: StatusChip(state: controller.linkState))),
              if (!controller.modActive)
                Positioned(
                  top: 54,
                  left: 16,
                  right: 140,
                  child: IgnorePointer(
                    child: Text(AppLocalizations.of(context).modMissingBanner,
                        style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ),
                ),
              if (debugOverlay != null) Positioned(top: 54, left: 12, child: IgnorePointer(child: debugOverlay)),
              Positioned(
                bottom: settings.tiltSteering ? 8 : 76,
                left: 0,
                right: 0,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (settings.showActionsBar) VehicleActionsBar(controller: controller, color: style.buttonColor),
                      const SizedBox(width: 12),
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
