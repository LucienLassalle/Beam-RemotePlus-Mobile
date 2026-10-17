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
      VehicleWarning.lowBattery => Icons.battery_1_bar,
      VehicleWarning.batteryDamaged => Icons.electric_bolt,
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
      VehicleWarning.lowBattery => l10n.warningLowBattery,
      VehicleWarning.batteryDamaged => l10n.warningBatteryDamaged,
    };

/// Warning lights: a big icon with its name pops in the middle of the
/// screen when a warning turns on, then flies to its small icon in the
/// column of active warnings (right edge), where it stays while the warning
/// is on. Never takes touches.
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
  static const flyDuration = Duration(milliseconds: 600);

  /// Column of active warnings: offset from the top right corner, and the
  /// height of one icon with its padding.
  static const double columnTop = 28;
  static const double columnRight = 14;
  static const double iconSize = 24;
  static const double rowHeight = iconSize + 6;
  static const double popIconSize = 64;

  @override
  State<WarningOverlay> createState() => _WarningOverlayState();
}

class _WarningOverlayState extends State<WarningOverlay> with SingleTickerProviderStateMixin {
  List<VehicleWarning> _active = const [];
  final Set<VehicleWarning> _acknowledged = {};
  VehicleWarning? _popping;
  Timer? _popTimer;

  /// The warning flying from the middle to its column icon, if any.
  VehicleWarning? _flying;
  late final AnimationController _fly = AnimationController(vsync: this, duration: WarningOverlay.flyDuration)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) setState(() => _flying = null);
    });

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
      _flying = null;
    }
    final raw = activeWarnings(widget.telemetry);
    _acknowledged.removeWhere((w) => !raw.contains(w)); // turned off: armed again
    final next = raw.where((w) => !_acknowledged.contains(w)).toList();
    final appeared = next.where((w) => !_active.contains(w)).toList();
    _active = next;
    if (_flying != null && !_active.contains(_flying)) _flying = null;
    if (appeared.isNotEmpty) {
      _popping = appeared.first;
      _flying = null;
      _popTimer?.cancel();
      _popTimer = Timer(WarningOverlay.popDuration, _startFlying);
    }
  }

  void _startFlying() {
    if (!mounted) return;
    setState(() {
      // Still on: it flies to its icon; turned off meanwhile: it just goes.
      _flying = _popping != null && _active.contains(_popping) ? _popping : null;
      _popping = null;
    });
    if (_flying != null) unawaited(_fly.forward(from: 0));
  }

  @override
  void dispose() {
    _popTimer?.cancel();
    _fly.dispose();
    super.dispose();
  }

  Color _color(VehicleWarning w) => isCritical(w) ? Colors.redAccent : Colors.amber;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final popping = _popping;
    final flying = _flying;
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(children: [
          // Active warnings stack on the right edge, under the connection
          // status, where no theme draws (the dashboard is centred). The one
          // flying there appears when it lands.
          Positioned(
            top: WarningOverlay.columnTop,
            right: WarningOverlay.columnRight,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final w in _active)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Opacity(
                    opacity: w == flying ? 0 : 1,
                    child: Icon(warningIcon(w), color: _color(w), size: WarningOverlay.iconSize),
                  ),
                ),
            ]),
          ),
          if (popping != null) Center(child: _popup(l10n, popping)),
          if (flying != null) _flight(l10n, flying, constraints.biggest),
        ]),
      ),
    );
  }

  /// The popup moving from the middle to the column icon of [w], shrinking
  /// to its size while the frame and the name fade out.
  Widget _flight(AppLocalizations l10n, VehicleWarning w, Size size) {
    final index = _active.indexOf(w);
    final start = size.center(Offset.zero);
    final end = Offset(
      size.width - WarningOverlay.columnRight - WarningOverlay.iconSize / 2,
      WarningOverlay.columnTop + WarningOverlay.rowHeight * index + WarningOverlay.rowHeight / 2,
    );
    return AnimatedBuilder(
      animation: _fly,
      builder: (context, _) {
        final t = Curves.easeInOutCubic.transform(_fly.value);
        final fade = (1 - _fly.value * 2.5).clamp(0.0, 1.0);
        final scale = 1 + (WarningOverlay.iconSize / WarningOverlay.popIconSize - 1) * t;
        return Center(
          child: Transform.translate(
            offset: (end - start) * t,
            child: Transform.scale(scale: scale, child: _popup(l10n, w, frame: fade)),
          ),
        );
      },
    );
  }

  /// Big icon with the name of the warning; [frame] fades the box and the
  /// name (1 = fully shown) while it flies.
  Widget _popup(AppLocalizations l10n, VehicleWarning w, {double frame = 1}) {
    final color = _color(w);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75 * frame),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: frame), width: 2),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(warningIcon(w), color: color, size: WarningOverlay.popIconSize),
        const SizedBox(height: 6),
        Opacity(
          opacity: frame,
          child: Text(warningLabel(l10n, w), style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}
