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
/// côté Lua (struct FFI de 9 floats, little-endian).
class ModTelemetryPacket {
  final double speed; // m/s
  final double rpm;
  final double redlineRpm;
  final int gear; // 0=R, 1=N, 2+=rapport engagé - 1, même convention que le natif
  final double fuel; // 0-1
  final double engineTemp; // °C (eau/liquide de refroidissement)
  final int lights; // bitfield, voir lightsBit*
  final bool shiftLight;

  /// °C. 0 si le véhicule ne remonte pas cette valeur (électrique côté mod
  /// non standard selon les véhicules) — à traiter comme "non disponible".
  final double oilTemp;

  const ModTelemetryPacket({
    required this.speed,
    required this.rpm,
    required this.redlineRpm,
    required this.gear,
    required this.fuel,
    required this.engineTemp,
    required this.lights,
    required this.shiftLight,
    required this.oilTemp,
  });

  static const int sizeBytes = 36;

  /// Neutralise NaN/Infinity : le jeu peut transitoirement remonter des
  /// valeurs non finies côté electrics (ex: juste après un spawn, un
  /// changement ou une récupération de véhicule), avant que la physique ne
  /// se stabilise. `double.round()` lève une [UnsupportedError] sur une
  /// valeur non finie (pas de FormatException), donc non rattrapée par le
  /// catch générique du client UDP : on l'évite ici, au point d'entrée
  /// unique du paquet, plutôt que de blinder chaque écran de thème.
  static double _finite(double v, [double fallback = 0]) =>
      v.isFinite ? v : fallback;

  factory ModTelemetryPacket.fromBytes(Uint8List bytes) {
    if (bytes.length < sizeBytes) {
      throw FormatException(
        'Paquet télémétrie mod trop court: ${bytes.length} < $sizeBytes octets',
      );
    }
    final d = ByteData.sublistView(bytes);
    const le = Endian.little;
    return ModTelemetryPacket(
      speed: _finite(d.getFloat32(0, le)),
      rpm: _finite(d.getFloat32(4, le)),
      redlineRpm: _finite(d.getFloat32(8, le)),
      // Fallback 1 = point mort plutôt que 0 = marche arrière, moins trompeur
      // pour une lecture aberrante ponctuelle.
      gear: _finite(d.getFloat32(12, le), 1).round(),
      fuel: _finite(d.getFloat32(16, le)),
      engineTemp: _finite(d.getFloat32(20, le)),
      lights: _finite(d.getFloat32(24, le)).round(),
      shiftLight: d.getFloat32(28, le) >= 0.5,
      oilTemp: _finite(d.getFloat32(32, le)),
    );
  }

  static const int lightBitLowBeam = 1;
  static const int lightBitHighBeam = 2;
  static const int lightBitHandbrake = 4;
  static const int lightBitSignalLeft = 8;
  static const int lightBitSignalRight = 16;
  static const int lightBitOilWarning = 32;
  static const int lightBitAbs = 64;
  static const int lightBitTc = 128;

  bool get lowBeam => (lights & lightBitLowBeam) != 0;
  bool get highBeam => (lights & lightBitHighBeam) != 0;
  bool get handbrake => (lights & lightBitHandbrake) != 0;
  bool get signalLeft => (lights & lightBitSignalLeft) != 0;
  bool get signalRight => (lights & lightBitSignalRight) != 0;
  bool get oilWarning => (lights & lightBitOilWarning) != 0;
  bool get absActive => (lights & lightBitAbs) != 0;
  bool get tractionControlActive => (lights & lightBitTc) != 0;

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
