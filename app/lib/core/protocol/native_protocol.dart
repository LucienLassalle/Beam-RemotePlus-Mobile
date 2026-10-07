import 'dart:typed_data';

/// BeamNG.drive's built-in remote control protocol (no mod needed), as
/// implemented by the official app (github.com/BeamNG/remotecontrol).
///
/// Only used for pairing and as a steering/pedal fallback when the
/// Beam-RemotePlus mod is not installed: the native telemetry channel calls a
/// deprecated game function and never sends anything in current versions.
class NativeProtocol {
  NativeProtocol._();

  /// The game listens here for the handshake and control packets.
  static const int hostPort = 4444;

  /// The phone listens here for the handshake answer.
  static const int clientPort = 4445;

  static const String handshakePrefix = 'beamng';

  static const int controlIntervalMs = 50; // 20 Hz, like the official app
  static const int discoveryRetryMs = 250;
  static const int discoveryMaxRetries = 20;

  static String handshake(String deviceName, String code) =>
      '$handshakePrefix|$deviceName|$code';

  static String expectedAnswer(String code) => '$handshakePrefix|$code';
}

/// Native control packet: 16 bytes, four big-endian float32
/// (steering, throttle, brake, sequence id). Values outside 0..1 are clamped.
class NativeControlPacket {
  final double steering;
  final double throttle;
  final double brake;
  final int sequenceId;

  const NativeControlPacket({
    required this.steering,
    required this.throttle,
    required this.brake,
    required this.sequenceId,
  });

  Uint8List toBytes() {
    final data = ByteData(16);
    data.setFloat32(0, steering.clamp(0.0, 1.0), Endian.big);
    data.setFloat32(4, throttle.clamp(0.0, 1.0), Endian.big);
    data.setFloat32(8, brake.clamp(0.0, 1.0), Endian.big);
    data.setFloat32(12, sequenceId.toDouble(), Endian.big);
    return data.buffer.asUint8List();
  }
}
