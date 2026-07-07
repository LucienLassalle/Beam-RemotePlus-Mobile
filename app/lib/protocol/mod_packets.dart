import 'dart:typed_data';

/// Paquet de contrôle envoyé au mod (port 4446), analogique sur les trois
/// axes. Miroir exact de `rp_control_t` côté Lua (struct FFI de 3 floats,
/// endianness native = little-endian), d'où le choix du little-endian ici.
class ModControlPacket {
  final double steering;
  final double throttle;
  final double brake;

  const ModControlPacket({
    required this.steering,
    required this.throttle,
    required this.brake,
  });

  Uint8List toBytes() {
    final data = ByteData(12);
    data.setFloat32(0, steering.clamp(0.0, 1.0), Endian.little);
    data.setFloat32(4, throttle.clamp(0.0, 1.0), Endian.little);
    data.setFloat32(8, brake.clamp(0.0, 1.0), Endian.little);
    return data.buffer.asUint8List();
  }
}

/// Télémétrie reçue du mod (port 4447). Miroir exact de `rp_telemetry_t`
/// côté Lua (struct FFI de 8 floats, little-endian).
class ModTelemetryPacket {
  final double speed; // m/s
  final double rpm;
  final double redlineRpm;
  final int gear; // 0=R, 1=N, 2+=rapport engagé - 1, même convention que le natif
  final double fuel; // 0-1
  final double engineTemp; // °C
  final int lights; // bitfield, voir lightsBit*
  final bool shiftLight;

  const ModTelemetryPacket({
    required this.speed,
    required this.rpm,
    required this.redlineRpm,
    required this.gear,
    required this.fuel,
    required this.engineTemp,
    required this.lights,
    required this.shiftLight,
  });

  static const int sizeBytes = 32;

  factory ModTelemetryPacket.fromBytes(Uint8List bytes) {
    if (bytes.length < sizeBytes) {
      throw FormatException(
        'Paquet télémétrie mod trop court: ${bytes.length} < $sizeBytes octets',
      );
    }
    final d = ByteData.sublistView(bytes);
    const le = Endian.little;
    return ModTelemetryPacket(
      speed: d.getFloat32(0, le),
      rpm: d.getFloat32(4, le),
      redlineRpm: d.getFloat32(8, le),
      gear: d.getFloat32(12, le).round(),
      fuel: d.getFloat32(16, le),
      engineTemp: d.getFloat32(20, le),
      lights: d.getFloat32(24, le).round(),
      shiftLight: d.getFloat32(28, le) >= 0.5,
    );
  }

  static const int lightBitLowBeam = 1;
  static const int lightBitHighBeam = 2;
  static const int lightBitHandbrake = 4;
  static const int lightBitSignalLeft = 8;
  static const int lightBitSignalRight = 16;
  static const int lightBitOilWarning = 32;
  static const int lightBitAbs = 64;

  bool get lowBeam => (lights & lightBitLowBeam) != 0;
  bool get highBeam => (lights & lightBitHighBeam) != 0;
  bool get handbrake => (lights & lightBitHandbrake) != 0;
  bool get signalLeft => (lights & lightBitSignalLeft) != 0;
  bool get signalRight => (lights & lightBitSignalRight) != 0;
  bool get oilWarning => (lights & lightBitOilWarning) != 0;
  bool get absActive => (lights & lightBitAbs) != 0;

  double get speedKmh => speed * 3.6;
  double get speedMph => speed * 2.23694;

  String get gearLabel {
    switch (gear) {
      case 0:
        return 'R';
      case 1:
        return 'N';
      default:
        return '${gear - 1}';
    }
  }
}
