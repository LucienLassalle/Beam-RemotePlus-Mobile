import 'dart:typed_data';

/// Beam-RemotePlus mod protocol. The reference specification lives in the
/// mod repository: docs/PROTOCOL.md.
class ModProtocol {
  ModProtocol._();

  /// The mod listens here (PC side).
  static const int hostPort = 4446;

  /// The app listens here (phone side).
  static const int clientPort = 4447;

  /// Highest protocol version this app speaks.
  static const int version = 2;

  static const String pingPrefix = 'beamngremoteplus|ping|';
  static const String pongPrefix = 'beamngremoteplus|pong|';
  static const String discoverMessage = 'beamngremoteplus|discover';
  static const String helloPrefix = 'beamngremoteplus|hello|';
  static const String cmdPrefix = 'cmd|';

  static const int discoverTimeoutMs = 4000;
  static const int discoverRetryMs = 400;
  static const int pingRetryMs = 500;

  /// Once paired, a ping every [keepAlivePingEvery] x [pingRetryMs] (2 s)
  /// re-pairs the phone if the mod restarted and forgot it.
  static const int keepAlivePingEvery = 4;

  /// Nothing received from the mod for this long: it is considered gone and
  /// the app falls back to the native channel until it answers again.
  static const Duration modSilenceTimeout = Duration(seconds: 6);
  static const int controlIntervalMs = 16; // ~60 Hz

  /// [display]: second-screen phone, telemetry only (no virtual device).
  static String ping(String code, String deviceName, {bool display = false}) =>
      '$pingPrefix$code|$version|${deviceName.replaceAll('|', ' ')}${display ? '|display' : ''}';

  /// Returns the negotiated protocol version if [message] is the pong for
  /// [code], null otherwise. A pong without version comes from a v1 mod.
  static int? parsePong(String message, String code) {
    final prefix = '$pongPrefix$code';
    if (message != prefix && !message.startsWith('$prefix|')) return null;
    final rest = message.length > prefix.length ? message.substring(prefix.length + 1) : '';
    return int.tryParse(rest.split('|').first) ?? 1;
  }

  /// `cmd|name` or `cmd|name|arg`.
  static String command(String name, [String? arg]) =>
      arg == null ? '$cmdPrefix$name' : '$cmdPrefix$name|$arg';
}

/// Names of the commands understood by the mod (see docs/PROTOCOL.md).
class ModCommand {
  ModCommand._();

  // Press commands
  static const nextVehicle = 'next_vehicle';
  static const prevVehicle = 'prev_vehicle';
  static const camNext = 'cam_next';
  static const camPrev = 'cam_prev';
  static const gearUp = 'gear_up';
  static const gearDown = 'gear_down';
  static const hazard = 'hazard';
  static const signalLeft = 'signal_left';
  static const signalRight = 'signal_right';
  static const lights = 'lights';
  static const parkingBrake = 'parkingbrake';
  static const escMode = 'esc_mode';
  static const shifterMode = 'shifter_mode';
  static const cruiseSet = 'cruise_set';
  static const cruiseResume = 'cruise_resume';
  static const cruiseOff = 'cruise_off';
  static const cruiseUp = 'cruise_up';
  static const cruiseDown = 'cruise_down';

  // Hold commands: send with "1" on press and "0" on release
  static const horn = 'horn';
  static const highBeam = 'highbeam';
  static const starter = 'starter';
  static const recover = 'recover';
  static const debug = 'debug';

  // Asks for the vehicle skeleton (allowed on a second screen too)
  static const skeleton = 'skeleton';

  static const Set<String> holds = {horn, highBeam, starter, recover, debug};
}

/// Analog control packet sent to the mod: 12 bytes, three little-endian
/// float32 (steering, throttle, brake), mirror of `rp_control_t` in Lua.
class ModControlPacket {
  final double steering;
  final double throttle;
  final double brake;

  const ModControlPacket({
    required this.steering,
    required this.throttle,
    required this.brake,
  });

  static const int sizeBytes = 12;

  Uint8List toBytes() {
    final data = ByteData(sizeBytes);
    data.setFloat32(0, steering.clamp(0.0, 1.0), Endian.little);
    data.setFloat32(4, throttle.clamp(0.0, 1.0), Endian.little);
    data.setFloat32(8, brake.clamp(0.0, 1.0), Endian.little);
    return data.buffer.asUint8List();
  }
}

/// A PC found by automatic discovery.
class DiscoveredHost {
  final String securityCode;
  final String hostAddress;
  final String label;

  const DiscoveredHost({
    required this.securityCode,
    required this.hostAddress,
    required this.label,
  });

  static const defaultLabel = 'BeamNG.drive';

  /// Parses `beamngremoteplus|hello|<code>|<label>`; null if not a hello.
  static DiscoveredHost? parseHello(String message, String hostAddress) {
    if (!message.startsWith(ModProtocol.helloPrefix)) return null;
    final rest = message.substring(ModProtocol.helloPrefix.length);
    final sep = rest.indexOf('|');
    final code = sep >= 0 ? rest.substring(0, sep) : rest;
    final label = sep >= 0 ? rest.substring(sep + 1) : '';
    if (code.isEmpty) return null;
    return DiscoveredHost(
      securityCode: code,
      hostAddress: hostAddress,
      label: label.isEmpty ? defaultLabel : label,
    );
  }
}
