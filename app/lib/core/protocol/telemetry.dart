import 'dart:typed_data';

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
  final bool? shiftLight;
  final Map<String, double>? tirePressures; // kPa by wheel name
  final String? driveMode;
  final int? player;
  final String? vehicle;

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
    this.shiftLight,
    this.tirePressures,
    this.driveMode,
    this.player,
    this.vehicle,
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

  /// True when at least one tyre is below [thresholdKpa].
  bool lowTirePressure({double thresholdKpa = 120}) =>
      tirePressures?.values.any((p) => p > 0 && p < thresholdKpa) ?? false;

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
      shiftLight: _bool(j['shiftLight']),
      tirePressures: _pressures(j['tirePressures']),
      driveMode: _driveMode(j['driveMode']),
      player: _int(j['player']),
      vehicle: _str(j['vehicle']),
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
