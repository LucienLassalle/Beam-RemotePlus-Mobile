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
    };

/// Real-car style warning lights: a big icon with its name pops in the
/// middle of the screen when a warning turns on, then stays as a small
/// icon in a row while it is active. Never takes touches.
class WarningOverlay extends StatefulWidget {
  final Telemetry telemetry;
  const WarningOverlay({super.key, required this.telemetry});

  static const popDuration = Duration(milliseconds: 2500);

  @override
  State<WarningOverlay> createState() => _WarningOverlayState();
}

class _WarningOverlayState extends State<WarningOverlay> {
  List<VehicleWarning> _active = const [];
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
    final next = activeWarnings(widget.telemetry);
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
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (final w in _active)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
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
