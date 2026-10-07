import '../../core/protocol/telemetry.dart';

/// Warning lights shown over the driving screen like on a real dashboard.
enum VehicleWarning {
  checkEngine,
  oilPressure,
  overheating,
  engineStopped,
  lowFuel,
  flatTire,
  lowTirePressure,
  brakesOverheating,
  parkingBrakeWhileMoving,
}

/// Engine failures that mean "stop now" (red) rather than "check soon".
const _overheatingFailures = {'coolantOverheating', 'oilOverheating', 'blockMelted', 'cylinderWallsMelted'};
const _oilFailures = {'oilpanLeak', 'oilRadiatorLeak', 'starvedOfOil', 'oilLevelCritical'};

/// Warnings active for this telemetry frame, most severe first. Pure.
List<VehicleWarning> activeWarnings(Telemetry t) {
  final engineDamage = t.engineDamage.toSet();
  return [
    if ((t.waterTemp ?? 0) >= 115 || engineDamage.intersection(_overheatingFailures).isNotEmpty) VehicleWarning.overheating,
    if (t.lowPressure == true || engineDamage.intersection(_oilFailures).isNotEmpty) VehicleWarning.oilPressure,
    if (t.checkEngine == true || engineDamage.difference(_overheatingFailures).difference(_oilFailures).isNotEmpty)
      VehicleWarning.checkEngine,
    // Engine off while the ignition is on: the battery light of real cars.
    if (t.engineRunning == false && (t.ignitionLevel ?? 0) >= 2) VehicleWarning.engineStopped,
    if (t.flatTires.isNotEmpty) VehicleWarning.flatTire,
    if (t.flatTires.isEmpty && t.lowTirePressure()) VehicleWarning.lowTirePressure,
    if (t.hotBrakes.isNotEmpty) VehicleWarning.brakesOverheating,
    if (t.parkingBrake == true && (t.speed ?? 0) > 3) VehicleWarning.parkingBrakeWhileMoving,
    if (t.lowFuel == true) VehicleWarning.lowFuel,
  ];
}

/// Red = stop as soon as possible, amber = check soon.
bool isCritical(VehicleWarning w) => switch (w) {
      VehicleWarning.overheating ||
      VehicleWarning.oilPressure ||
      VehicleWarning.flatTire ||
      VehicleWarning.parkingBrakeWhileMoving =>
        true,
      _ => false,
    };
