import 'dart:typed_data';

import 'vehicle_state.dart';

export 'vehicle_state.dart';

/// One telemetry snapshot of the vehicle followed by this phone.
///
/// Every field is nullable: null means "this vehicle (or an older mod) does
/// not provide it", which themes should show as unavailable rather than 0.
/// Field names and units match docs/PROTOCOL.md of the mod.
class Telemetry {
  final double? speed; // m/s
  final double? rpm;
  final double? maxRpm;
  final String? gear; // label shown by the car: P, R, N, D, S5, 1...
  final int? gearIndex; // -1 = R, 0 = N
  final int? maxGearIndex;
  final String? gearboxMode;
  final double? fuel; // 0..1
  final double? fuelVolume; // litres
  final double? fuelCapacity; // litres
  final double? waterTemp; // °C
  final double? oilTemp; // °C
  final double? envTemp; // °C
  final double? boost;
  final bool? engineRunning;
  final int? ignitionLevel;
  final double? throttle; // 0..1, actual vehicle value
  final double? brake;
  final double? clutch;
  final bool? parkingBrake;
  final bool? lowBeam;
  final bool? highBeam;
  final bool? signalLeft;
  final bool? signalRight;
  final bool? hazard;
  final bool? lowPressure;
  final bool? checkEngine;
  final bool? lowFuel;
  final bool? hasAbs;
  final bool? absActive;
  final bool? hasEsc;
  final bool? escActive;
  final bool? hasTcs;
  final bool? tcsActive;
  final bool? cruiseActive;
  final double? cruiseSpeed; // m/s
  final double? odometer; // m
  final double? trip; // m
  final double? gx; // m/s²
  final double? gy;
  final double? gz;
  final bool? shiftLight;
  final Map<String, double>? tirePressures; // kPa by wheel name

  /// Pressures set in the vehicle configuration (kPa by wheel name).
  final Map<String, double>? tirePressuresNominal;
  final String? driveMode;
  final int? player;
  final String? vehicle;

  /// Largest wheel slip velocity (m/s): wheelspin, locked wheels, drifts.
  final double? wheelSlip;

  /// Largest wheelspin (tyre faster than the car) and locked-wheel slip,
  /// m/s. Null with an older mod (only [wheelSlip] then).
  final double? wheelSpin;
  final double? wheelLock;

  /// Brake disc temperature (°C) by wheel name.
  final Map<String, double>? brakeTemps;

  /// Clutch temperature (°C), only for cars with a friction clutch.
  final double? clutchTemp;

  /// 'hot', 'overheating' (slipping) or 'damaged'; null when fine.
  final String? clutchState;

  /// Broken powertrain parts: driveshaft, wheelaxleFL, mainEngine...
  final List<String> brokenParts;

  /// Shafts of this car (driveshaft, driveshaft_F, wheelaxleFL...).
  final List<String> shafts;

  /// Engine position along the car: 0 = front bumper, 1 = rear bumper.
  final double? engineAt;

  /// Molten brakes and torn off wheels (wheel names).
  final List<String> brokenBrakes;
  final List<String> brokenWheels;
  final bool? fuelLeak;

  /// Cars around (empty list = none nearby, null = not sent by the mod).
  final List<RadarTarget>? radar;

  /// Body damage per zone (FL, FR, ML, MR, RL, RR), 0..1; null = intact.
  final Map<String, double>? bodyDamage;

  /// Engine failures reported by the game (radiatorLeak, oilpanLeak...).
  final List<String> engineDamage;
  final List<String> flatTires;
  final List<String> hotBrakes;

  /// Per-wheel tyre data, only with the "Tyre Thermals and Wear" mod.
  final Map<String, TyreState>? tyres;

  /// Names of the fields actually received (for the debug overlay).
  final Set<String> receivedFields;

  const Telemetry({
    this.speed,
    this.rpm,
    this.maxRpm,
    this.gear,
    this.gearIndex,
    this.maxGearIndex,
    this.gearboxMode,
    this.fuel,
    this.fuelVolume,
    this.fuelCapacity,
    this.waterTemp,
    this.oilTemp,
    this.envTemp,
    this.boost,
    this.engineRunning,
    this.ignitionLevel,
    this.throttle,
    this.brake,
    this.clutch,
    this.parkingBrake,
    this.lowBeam,
    this.highBeam,
    this.signalLeft,
    this.signalRight,
    this.hazard,
    this.lowPressure,
    this.checkEngine,
    this.lowFuel,
    this.hasAbs,
    this.absActive,
    this.hasEsc,
    this.escActive,
    this.hasTcs,
    this.tcsActive,
    this.cruiseActive,
    this.cruiseSpeed,
    this.odometer,
    this.trip,
    this.gx,
    this.gy,
    this.gz,
    this.shiftLight,
    this.tirePressures,
    this.tirePressuresNominal,
    this.driveMode,
    this.player,
    this.vehicle,
    this.wheelSlip,
    this.wheelSpin,
    this.wheelLock,
    this.brakeTemps,
    this.clutchTemp,
    this.clutchState,
    this.brokenParts = const [],
    this.shafts = const [],
    this.engineAt,
    this.brokenBrakes = const [],
    this.brokenWheels = const [],
    this.fuelLeak,
    this.radar,
    this.bodyDamage,
    this.engineDamage = const [],
    this.flatTires = const [],
    this.hotBrakes = const [],
    this.tyres,
    this.receivedFields = const {},
  });

  static const empty = Telemetry();

  /// Fields every vehicle with a combustion engine is expected to provide;
  /// the debug overlay reports the ones that are missing.
  static const List<String> expectedFields = [
    'speed', 'rpm', 'maxRpm', 'gear', 'gearIndex', 'fuel', 'waterTemp',
    'oilTemp', 'engineRunning', 'ignitionLevel', 'parkingBrake', 'lowBeam',
    'highBeam', 'signalLeft', 'signalRight', 'hazard', 'lowPressure',
    'checkEngine', 'lowFuel', 'odometer', 'gx', 'gy', 'shiftLight',
  ];

  // Derived values used by themes -------------------------------------------

  double? get speedKmh => speed == null ? null : speed! * 3.6;
  double? get speedMph => speed == null ? null : speed! * 2.23694;
  double? speedIn({required bool kmh}) => kmh ? speedKmh : speedMph;

  /// Gear label with a numeric fallback for v1 telemetry.
  String get gearLabel {
    if (gear != null && gear!.isNotEmpty) return gear!;
    final index = gearIndex;
    if (index == null || index == 0) return 'N';
    if (index < 0) return 'R';
    return '$index';
  }

  /// RPM ratio 0..1 against [maxRpm] (null when unknown).
  double? get rpmRatio {
    if (rpm == null || maxRpm == null || maxRpm! <= 0) return null;
    return (rpm! / maxRpm!).clamp(0.0, 1.0);
  }

  bool get absOn => absActive ?? false;
  bool get tcsOn => tcsActive ?? false;
  bool get escOn => escActive ?? false;

  /// A tyre counts as underinflated below this share of the pressure the
  /// car is configured with.
  static const double lowPressureRatio = 0.75;

  /// Wheels whose tyre is underinflated: compared to the pressure set in
  /// the vehicle configuration (race cars run low pressures), or to
  /// [fallbackKpa] with an older mod that does not send it.
  List<String> lowPressureTires({double fallbackKpa = 120}) => [
        for (final e in (tirePressures ?? const <String, double>{}).entries)
          if (e.value > 0 && e.value < (_nominal(e.key) ?? fallbackKpa)) e.key,
      ];

  double? _nominal(String wheel) {
    final n = tirePressuresNominal?[wheel];
    return n == null || n <= 0 ? null : n * lowPressureRatio;
  }

  bool lowTirePressure({double fallbackKpa = 120}) => lowPressureTires(fallbackKpa: fallbackKpa).isNotEmpty;

  // Decoding -------------------------------------------------------------------

  static double? _num(Object? v) {
    if (v is num && v.isFinite) return v.toDouble();
    return null;
  }

  static int? _int(Object? v) => _num(v)?.round();

  static bool? _bool(Object? v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    return null;
  }

  static String? _str(Object? v) => v is String ? v : null;

  static Map<String, double>? _pressures(Object? v) {
    if (v is! Map) return null;
    final result = <String, double>{};
    v.forEach((key, value) {
      final p = _num(value);
      if (key is String && p != null) result[key] = p;
    });
    return result.isEmpty ? null : result;
  }

  static Map<String, double>? _numbers(Object? v) => _pressures(v);

  static Map<Object?, Object?>? _map(Object? v) => v is Map ? v : null;

  static List<String> _strings(Object? v) =>
      v is List ? [for (final e in v) if (e is String) e] : const [];

  static List<RadarTarget>? _radar(Object? v) {
    if (v is Map && v.isEmpty) return const []; // empty Lua table
    if (v is! List) return null;
    return [for (final e in v) if (e is Map) RadarTarget.fromJson(e)];
  }

  static Map<String, TyreState>? _tyres(Object? v) {
    if (v is! Map || v.isEmpty) return null;
    return {
      for (final e in v.entries)
        if (e.key is String && e.value is Map) e.key as String: TyreState.fromJson(e.value as Map<Object?, Object?>),
    };
  }

  static String? _driveMode(Object? v) {
    if (v is Map) return _str(v['name']) ?? _str(v['key']);
    return _str(v);
  }

  /// Protocol v2 telemetry (decoded JSON object). Wrong types become null
  /// instead of throwing: one bad field must not drop the whole frame.
  factory Telemetry.fromJson(Map<String, Object?> j) {
    return Telemetry(
      speed: _num(j['speed']),
      rpm: _num(j['rpm']),
      maxRpm: _num(j['maxRpm']),
      gear: _str(j['gear']),
      gearIndex: _int(j['gearIndex']),
      maxGearIndex: _int(j['maxGearIndex']),
      gearboxMode: _str(j['gearboxMode']),
      fuel: _num(j['fuel']),
      fuelVolume: _num(j['fuelVolume']),
      fuelCapacity: _num(j['fuelCapacity']),
      waterTemp: _num(j['waterTemp']),
      oilTemp: _num(j['oilTemp']),
      envTemp: _num(j['envTemp']),
      boost: _num(j['boost']),
      engineRunning: _bool(j['engineRunning']),
      ignitionLevel: _int(j['ignitionLevel']),
      throttle: _num(j['throttle']),
      brake: _num(j['brake']),
      clutch: _num(j['clutch']),
      parkingBrake: _bool(j['parkingBrake']),
      lowBeam: _bool(j['lowBeam']),
      highBeam: _bool(j['highBeam']),
      signalLeft: _bool(j['signalLeft']),
      signalRight: _bool(j['signalRight']),
      hazard: _bool(j['hazard']),
      lowPressure: _bool(j['lowPressure']),
      checkEngine: _bool(j['checkEngine']),
      lowFuel: _bool(j['lowFuel']),
      hasAbs: _bool(j['hasAbs']),
      absActive: _bool(j['absActive']),
      hasEsc: _bool(j['hasEsc']),
      escActive: _bool(j['escActive']),
      hasTcs: _bool(j['hasTcs']),
      tcsActive: _bool(j['tcsActive']),
      cruiseActive: _bool(j['cruiseActive']),
      cruiseSpeed: _num(j['cruiseSpeed']),
      odometer: _num(j['odometer']),
      trip: _num(j['trip']),
      gx: _num(j['gx']),
      gy: _num(j['gy']),
      gz: _num(j['gz']),
      shiftLight: _bool(j['shiftLight']),
      tirePressures: _pressures(j['tirePressures']),
      tirePressuresNominal: _pressures(j['tirePressuresNominal']),
      driveMode: _driveMode(j['driveMode']),
      player: _int(j['player']),
      vehicle: _str(j['vehicle']),
      wheelSlip: _num(j['wheelSlip']),
      wheelSpin: _num(j['wheelSpin']),
      wheelLock: _num(j['wheelLock']),
      brakeTemps: _numbers(j['brakeTemps']),
      clutchTemp: _num(j['clutchTemp']),
      clutchState: _str(j['clutchState']),
      brokenParts: _strings(j['brokenParts']),
      shafts: _strings(_map(j['drivetrain'])?['shafts']),
      engineAt: _num(_map(j['drivetrain'])?['engineAt']),
      brokenBrakes: _strings(j['brokenBrakes']),
      brokenWheels: _strings(j['brokenWheels']),
      fuelLeak: _bool(j['fuelLeak']),
      radar: _radar(j['radar']),
      bodyDamage: _numbers(j['bodyDamage']),
      engineDamage: _strings(j['engineDamage']),
      flatTires: _strings(j['flatTires']),
      hotBrakes: _strings(j['hotBrakes']),
      tyres: _tyres(j['tyres']),
      receivedFields: {
        for (final e in j.entries)
          if (e.value != null && e.key != 'type') e.key,
      },
    );
  }

  static const int legacySizeBytes = 36;

  /// Protocol v1 telemetry: nine little-endian float32 (see PROTOCOL.md).
  factory Telemetry.fromLegacyBytes(Uint8List bytes) {
    if (bytes.length < legacySizeBytes) {
      throw FormatException('legacy telemetry too short: ${bytes.length} bytes');
    }
    final d = ByteData.sublistView(bytes);
    double f(int offset) {
      final v = d.getFloat32(offset, Endian.little);
      return v.isFinite ? v : 0;
    }

    final lights = f(24).round();
    bool bit(int mask) => (lights & mask) != 0;
    final oilTemp = f(32);
    return Telemetry(
      speed: f(0),
      rpm: f(4),
      maxRpm: f(8),
      // v1 gear: 0 = R, 1 = N, 2+ = engaged gear + 1
      gearIndex: f(12).round() - 1,
      fuel: f(16),
      waterTemp: f(20),
      lowBeam: bit(1),
      highBeam: bit(2),
      parkingBrake: bit(4),
      signalLeft: bit(8),
      signalRight: bit(16),
      lowPressure: bit(32),
      absActive: bit(64),
      tcsActive: bit(128),
      shiftLight: f(28) >= 0.5,
      oilTemp: oilTemp > 0 ? oilTemp : null,
      receivedFields: const {
        'speed', 'rpm', 'maxRpm', 'gearIndex', 'fuel', 'waterTemp', 'lowBeam',
        'highBeam', 'parkingBrake', 'signalLeft', 'signalRight', 'lowPressure',
        'absActive', 'tcsActive', 'shiftLight', 'oilTemp',
      },
    );
  }
}
