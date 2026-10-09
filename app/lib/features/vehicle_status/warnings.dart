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
  turboOverheating,
  overRev,
  waterInEngine,
  gearbox,
  lowAirPressure,
}

/// Engine failures that mean "stop now" (red) rather than "check soon".
const _overheatingFailures = {'coolantOverheating', 'oilOverheating', 'blockMelted', 'cylinderWallsMelted'};
const _oilFailures = {'oilpanLeak', 'oilRadiatorLeak', 'starvedOfOil', 'oilLevelCritical'};

/// Live dangers the game warns about: their own light, not "check engine".
const _turbo = 'turbochargerHot';
const _overRev = {'overRevDanger', 'overTorqueDanger'};
const _hydrolocking = 'engineIsHydrolocking';
const _liveDangers = {_turbo, ..._overRev, _hydrolocking};

/// A gearbox this worn (synchronizers) grinds and will soon lose gears.
const double gearboxWearWarning = 0.3;

/// Broken powertrain part that is not the engine itself (driveshaft,
/// wheel axle, gearbox...): the car loses drive.
bool _isTransmissionPart(String name) => !name.toLowerCase().contains('engine') && !name.toLowerCase().contains('motor');

/// Warnings active for this telemetry frame, most severe first. Pure.
List<VehicleWarning> activeWarnings(Telemetry t) {
  final engineDamage = t.engineDamage.toSet();
  final otherEngineFailures = engineDamage.difference(_overheatingFailures).difference(_oilFailures).difference(_liveDangers);
  return [
    if ((t.waterTemp ?? 0) >= 115 || engineDamage.intersection(_overheatingFailures).isNotEmpty) VehicleWarning.overheating,
    if (t.lowPressure == true || engineDamage.intersection(_oilFailures).isNotEmpty) VehicleWarning.oilPressure,
    if (engineDamage.contains(_hydrolocking)) VehicleWarning.waterInEngine,
    if (t.lowAirPressure == true) VehicleWarning.lowAirPressure,
    if (t.fuelLeak == true) VehicleWarning.fuelLeak,
    if (t.brokenParts.any(_isTransmissionPart)) VehicleWarning.drivetrainBroken,
    if (t.clutchState == 'damaged') VehicleWarning.clutchDamaged,
    if (engineDamage.intersection(_overRev).isNotEmpty) VehicleWarning.overRev,
    if (t.checkEngine == true || otherEngineFailures.isNotEmpty) VehicleWarning.checkEngine,
    // Engine off while the ignition is on: the battery light of real cars.
    if (t.engineRunning == false && (t.ignitionLevel ?? 0) >= 2) VehicleWarning.engineStopped,
    if (t.flatTires.isNotEmpty || t.brokenWheels.isNotEmpty) VehicleWarning.flatTire,
    if (t.flatTires.isEmpty && t.lowTirePressure()) VehicleWarning.lowTirePressure,
    if (t.hotBrakes.isNotEmpty || t.brokenBrakes.isNotEmpty) VehicleWarning.brakesOverheating,
    if (engineDamage.contains(_turbo)) VehicleWarning.turboOverheating,
    if (t.clutchState == 'hot' || t.clutchState == 'overheating') VehicleWarning.clutchOverheating,
    if (t.gearGrinding == true || (t.gearboxWear ?? 0) >= gearboxWearWarning) VehicleWarning.gearbox,
    if (t.parkingBrake == true && (t.speed ?? 0) > 3) VehicleWarning.parkingBrakeWhileMoving,
    if (t.lowFuel == true) VehicleWarning.lowFuel,
  ];
}

/// Red = stop as soon as possible, amber = check soon.
bool isCritical(VehicleWarning w) => switch (w) {
      VehicleWarning.overheating ||
      VehicleWarning.oilPressure ||
      VehicleWarning.waterInEngine ||
      VehicleWarning.lowAirPressure ||
      VehicleWarning.fuelLeak ||
      VehicleWarning.flatTire ||
      VehicleWarning.clutchDamaged ||
      VehicleWarning.drivetrainBroken ||
      VehicleWarning.overRev ||
      VehicleWarning.parkingBrakeWhileMoving =>
        true,
      _ => false,
    };
