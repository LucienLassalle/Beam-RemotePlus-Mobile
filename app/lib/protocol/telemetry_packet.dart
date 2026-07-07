import 'dart:convert';
import 'dart:typed_data';

/// Paquet de télémétrie reçu du jeu (port 4445), format proche d'OutGauge
/// (Live For Speed). Offsets et endianness (little-endian) vérifiés depuis
/// Receivepacket.java + le README du repo archivé.
///
/// Contrairement à l'ancienne app, on exploite ICI tous les champs
/// disponibles (turbo, huile, embrayage, odomètre réel...), pas seulement
/// vitesse/RPM/température/essence.
class TelemetryPacket {
  final int timeMs;
  final String car;
  final int flags;
  final int gearRaw;
  final int playerId;

  /// m/s
  final double speed;
  final double rpm;

  /// bar
  final double turbo;

  /// °C
  final double engineTemp;

  /// 0-1
  final double fuel;

  /// bar
  final double oilPressure;

  /// °C
  final double oilTemp;
  final int dashLights;
  final int showLights;

  /// 0-1
  final double throttle;

  /// 0-1
  final double brake;

  /// 0-1
  final double clutch;
  final String display1;
  final String display2;
  final int id;

  /// mètres (ou miles selon préférence utilisateur dans le jeu)
  final int odometer;

  const TelemetryPacket({
    required this.timeMs,
    required this.car,
    required this.flags,
    required this.gearRaw,
    required this.playerId,
    required this.speed,
    required this.rpm,
    required this.turbo,
    required this.engineTemp,
    required this.fuel,
    required this.oilPressure,
    required this.oilTemp,
    required this.dashLights,
    required this.showLights,
    required this.throttle,
    required this.brake,
    required this.clutch,
    required this.display1,
    required this.display2,
    required this.id,
    required this.odometer,
  });

  static const int minSizeBytes = 100;

  factory TelemetryPacket.fromBytes(Uint8List bytes) {
    if (bytes.length < minSizeBytes) {
      throw FormatException(
        'Paquet télémétrie trop court: ${bytes.length} < $minSizeBytes octets',
      );
    }
    final d = ByteData.sublistView(bytes);
    const le = Endian.little;

    return TelemetryPacket(
      timeMs: d.getUint32(0, le),
      car: _readCString(bytes, 4, 4),
      flags: d.getUint16(8, le),
      gearRaw: bytes[10],
      playerId: bytes[11],
      speed: d.getFloat32(12, le),
      rpm: d.getFloat32(16, le),
      turbo: d.getFloat32(20, le),
      engineTemp: d.getFloat32(24, le),
      fuel: d.getFloat32(28, le),
      oilPressure: d.getFloat32(32, le),
      oilTemp: d.getFloat32(36, le),
      dashLights: d.getUint32(40, le),
      showLights: d.getUint32(44, le),
      throttle: d.getFloat32(48, le),
      brake: d.getFloat32(52, le),
      clutch: d.getFloat32(56, le),
      display1: _readCString(bytes, 60, 16),
      display2: _readCString(bytes, 76, 16),
      id: d.getInt32(92, le),
      odometer: d.getUint32(96, le),
    );
  }

  static String _readCString(Uint8List bytes, int offset, int maxLen) {
    final slice = bytes.sublist(offset, offset + maxLen);
    final zeroIndex = slice.indexOf(0);
    final end = zeroIndex == -1 ? slice.length : zeroIndex;
    return latin1.decode(slice.sublist(0, end)).trim();
  }

  // --- Flags (OG_x) ---
  static const int _flagKmh = 16384;
  bool get prefersKmh => (flags & _flagKmh) != 0;

  // --- ShowLights (DL_x) ---
  static const int _dlShift = 1;
  static const int _dlFullbeam = 2;
  static const int _dlHandbrake = 4;
  static const int _dlPitspeed = 8;
  static const int _dlTc = 16;
  static const int _dlSignalL = 32;
  static const int _dlSignalR = 64;
  static const int _dlSignalAny = 128;
  static const int _dlOilwarn = 256;
  static const int _dlBattery = 512;
  static const int _dlAbs = 1024;

  bool get shiftLight => (showLights & _dlShift) != 0;
  bool get fullBeam => (showLights & _dlFullbeam) != 0;
  bool get handbrake => (showLights & _dlHandbrake) != 0;
  bool get pitSpeedLimiter => (showLights & _dlPitspeed) != 0;
  bool get tractionControl => (showLights & _dlTc) != 0;
  bool get signalLeft => (showLights & _dlSignalL) != 0;
  bool get signalRight => (showLights & _dlSignalR) != 0;
  bool get signalAny => (showLights & _dlSignalAny) != 0;
  bool get oilWarning => (showLights & _dlOilwarn) != 0;
  bool get batteryWarning => (showLights & _dlBattery) != 0;
  bool get absActive => (showLights & _dlAbs) != 0;

  /// Vitesse en km/h (le paquet transporte des m/s).
  double get speedKmh => speed * 3.6;

  /// Vitesse en mph.
  double get speedMph => speed * 2.23694;

  String get gearLabel {
    switch (gearRaw) {
      case 0:
        return 'R';
      case 1:
        return 'N';
      default:
        return '${gearRaw - 1}';
    }
  }
}
