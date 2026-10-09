import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/protocol/telemetry.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../warnings.dart';

IconData warningIcon(VehicleWarning w) => switch (w) {
      VehicleWarning.checkEngine => Icons.car_repair,
      VehicleWarning.oilPressure => Icons.oil_barrel,
      VehicleWarning.overheating => Icons.thermostat,
      VehicleWarning.engineStopped => Icons.battery_alert,
      VehicleWarning.lowFuel => Icons.local_gas_station,
      VehicleWarning.flatTire => Icons.tire_repair,
      VehicleWarning.lowTirePressure => Icons.tire_repair,
      VehicleWarning.brakesOverheating => Icons.disc_full,
      VehicleWarning.parkingBrakeWhileMoving => Icons.local_parking,
      VehicleWarning.fuelLeak => Icons.water_drop,
      VehicleWarning.clutchOverheating => Icons.settings,
      VehicleWarning.clutchDamaged => Icons.settings,
      VehicleWarning.drivetrainBroken => Icons.link_off,
      VehicleWarning.turboOverheating => Icons.cyclone,
      VehicleWarning.overRev => Icons.speed,
      VehicleWarning.waterInEngine => Icons.water,
      VehicleWarning.gearbox => Icons.settings_input_component,
      VehicleWarning.lowAirPressure => Icons.compress,
    };

String warningLabel(AppLocalizations l10n, VehicleWarning w) => switch (w) {
      VehicleWarning.checkEngine => l10n.warningCheckEngine,
      VehicleWarning.oilPressure => l10n.warningOilPressure,
      VehicleWarning.overheating => l10n.warningOverheating,
      VehicleWarning.engineStopped => l10n.warningEngineStopped,
      VehicleWarning.lowFuel => l10n.warningLowFuel,
      VehicleWarning.flatTire => l10n.warningFlatTire,
      VehicleWarning.lowTirePressure => l10n.warningLowTirePressure,
      VehicleWarning.brakesOverheating => l10n.warningBrakesOverheating,
      VehicleWarning.parkingBrakeWhileMoving => l10n.warningParkingBrake,
      VehicleWarning.fuelLeak => l10n.warningFuelLeak,
      VehicleWarning.clutchOverheating => l10n.warningClutchOverheating,
      VehicleWarning.clutchDamaged => l10n.warningClutchDamaged,
      VehicleWarning.drivetrainBroken => l10n.warningDrivetrainBroken,
      VehicleWarning.turboOverheating => l10n.warningTurboOverheating,
      VehicleWarning.overRev => l10n.warningOverRev,
      VehicleWarning.waterInEngine => l10n.warningWaterInEngine,
      VehicleWarning.gearbox => l10n.warningGearbox,
      VehicleWarning.lowAirPressure => l10n.warningLowAirPressure,
    };

/// Warning lights: a big icon with its name pops in the middle of the
/// screen when a warning turns on, then stays as a small icon while it is
/// active. Never takes touches.
///
/// When [resetCount] changes (the vehicle was reset from the phone), the
/// warnings active at that moment are acknowledged and hidden: the game does
/// not always clear its damage flags on a recovery although the car is
/// repaired. They show again only after turning off and on.
class WarningOverlay extends StatefulWidget {
  final Telemetry telemetry;
  final int resetCount;
  const WarningOverlay({super.key, required this.telemetry, this.resetCount = 0});

  static const popDuration = Duration(milliseconds: 2500);

  @override
  State<WarningOverlay> createState() => _WarningOverlayState();
}

class _WarningOverlayState extends State<WarningOverlay> {
  List<VehicleWarning> _active = const [];
  final Set<VehicleWarning> _acknowledged = {};
  VehicleWarning? _popping;
  Timer? _popTimer;

  @override
  void initState() {
    super.initState();
    _active = activeWarnings(widget.telemetry);
  }

  @override
  void didUpdateWidget(covariant WarningOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.resetCount != oldWidget.resetCount) {
      _acknowledged.addAll(activeWarnings(widget.telemetry));
      _popping = null;
    }
    final raw = activeWarnings(widget.telemetry);
    _acknowledged.removeWhere((w) => !raw.contains(w)); // turned off: armed again
    final next = raw.where((w) => !_acknowledged.contains(w)).toList();
    final appeared = next.where((w) => !_active.contains(w)).toList();
    _active = next;
    if (appeared.isNotEmpty) {
      _popping = appeared.first;
      _popTimer?.cancel();
      _popTimer = Timer(WarningOverlay.popDuration, () {
        if (mounted) setState(() => _popping = null);
      });
    }
  }

  @override
  void dispose() {
    _popTimer?.cancel();
    super.dispose();
  }

  Color _color(VehicleWarning w) => isCritical(w) ? Colors.redAccent : Colors.amber;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final popping = _popping;
    return IgnorePointer(
      child: Stack(children: [
        // Active warnings stack on the right edge, under the connection
        // status, where no theme draws (the dashboard is centred).
        Positioned(
          top: 28,
          right: 14,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final w in _active)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Icon(warningIcon(w), color: _color(w), size: 24),
              ),
          ]),
        ),
        if (popping != null)
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _color(popping), width: 2),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(warningIcon(popping), color: _color(popping), size: 64),
                const SizedBox(height: 6),
                Text(warningLabel(l10n, popping), style: TextStyle(color: _color(popping), fontSize: 16, fontWeight: FontWeight.bold)),
              ]),
            ),
          ),
      ]),
    );
  }
}
