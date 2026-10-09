import '../../core/protocol/telemetry.dart';

/// Warning lights shown over the driving screen.
enum VehicleWarning {
  checkEngine,
  oilPressure,
  overheating,
  engineStopped,
  lowFuel,
  fuelLeak,
  flatTire,
  lowTirePressure,
  brakesOverheating,
  parkingBrakeWhileMoving,
  clutchOverheating,
  clutchDamaged,
  drivetrainBroken,
}

/// Engine failures that mean "stop now" (red) rather than "check soon".
const _overheatingFailures = {'coolantOverheating', 'oilOverheating', 'blockMelted', 'cylinderWallsMelted'};
const _oilFailures = {'oilpanLeak', 'oilRadiatorLeak', 'starvedOfOil', 'oilLevelCritical'};

/// Broken powertrain part that is not the engine itself (driveshaft,
/// wheel axle, gearbox...): the car loses drive.
bool _isTransmissionPart(String name) => !name.toLowerCase().contains('engine') && !name.toLowerCase().contains('motor');

/// Warnings active for this telemetry frame, most severe first. Pure.
List<VehicleWarning> activeWarnings(Telemetry t) {
  final engineDamage = t.engineDamage.toSet();
  return [
    if ((t.waterTemp ?? 0) >= 115 || engineDamage.intersection(_overheatingFailures).isNotEmpty) VehicleWarning.overheating,
    if (t.lowPressure == true || engineDamage.intersection(_oilFailures).isNotEmpty) VehicleWarning.oilPressure,
    if (t.fuelLeak == true) VehicleWarning.fuelLeak,
    if (t.brokenParts.any(_isTransmissionPart)) VehicleWarning.drivetrainBroken,
    if (t.clutchState == 'damaged') VehicleWarning.clutchDamaged,
    if (t.checkEngine == true || engineDamage.difference(_overheatingFailures).difference(_oilFailures).isNotEmpty)
      VehicleWarning.checkEngine,
    // Engine off while the ignition is on: the battery light of real cars.
    if (t.engineRunning == false && (t.ignitionLevel ?? 0) >= 2) VehicleWarning.engineStopped,
    if (t.flatTires.isNotEmpty || t.brokenWheels.isNotEmpty) VehicleWarning.flatTire,
    if (t.flatTires.isEmpty && t.lowTirePressure()) VehicleWarning.lowTirePressure,
    if (t.hotBrakes.isNotEmpty || t.brokenBrakes.isNotEmpty) VehicleWarning.brakesOverheating,
    if (t.clutchState == 'hot' || t.clutchState == 'overheating') VehicleWarning.clutchOverheating,
    if (t.parkingBrake == true && (t.speed ?? 0) > 3) VehicleWarning.parkingBrakeWhileMoving,
    if (t.lowFuel == true) VehicleWarning.lowFuel,
  ];
}

/// Red = stop as soon as possible, amber = check soon.
bool isCritical(VehicleWarning w) => switch (w) {
      VehicleWarning.overheating ||
      VehicleWarning.oilPressure ||
      VehicleWarning.fuelLeak ||
      VehicleWarning.flatTire ||
      VehicleWarning.clutchDamaged ||
      VehicleWarning.drivetrainBroken ||
      VehicleWarning.parkingBrakeWhileMoving =>
        true,
      _ => false,
    };
