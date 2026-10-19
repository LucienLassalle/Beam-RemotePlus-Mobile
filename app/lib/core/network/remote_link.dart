import '../protocol/mod_message.dart';
import '../protocol/mod_protocol.dart';
import '../protocol/telemetry.dart';

/// [kicked]: the player removed this phone from the game; the connection is
/// closed and does not retry.
enum LinkState { idle, connecting, connected, timeout, error, kicked }

/// What the driving screen needs from a connection to the game. Implemented
/// by [BeamngConnection]; tests use a fake.
abstract class RemoteLink {
  Stream<LinkState> get states;
  LinkState get state;

  /// True once the Beam-RemotePlus mod answered (analog pedals, telemetry,
  /// commands). Without it only native steering/pedals work.
  Stream<bool> get modActiveChanges;
  bool get modActive;

  /// Negotiated mod protocol version (0 while the mod is not detected).
  int get protocolVersion;

  /// Round trip to the mod (keep-alive ping to pong), null until measured.
  int? get latencyMs;

  /// Nothing received from the mod for [ModProtocol.signalLostAfter]: the
  /// mod has not heard from this phone either, so it brakes the car.
  bool get signalLost;

  /// Fires when [latencyMs] or [signalLost] changes.
  Stream<void> get qualityChanges;

  Stream<Telemetry> get telemetry;

  /// Acks and session messages from the mod.
  Stream<ModMessage> get events;

  /// Sets the analog inputs (0..1, steering 0.5 = centre); sent at a fixed rate.
  void updateControls({double? steering, double? throttle, double? brake});

  /// Sends `cmd|name` or `cmd|name|arg` to the mod (ignored without mod).
  void sendCommand(String name, [String? arg]);

  /// Point of view video frames, while [setPovVideo] is on.
  Stream<PovFrame> get povFrames;

  /// Starts the point of view video of the mod in [quality] (listens on
  /// [ModProtocol.povPort] and asks the mod for it), or stops it (null).
  /// Asking again (new mod session, other quality) is harmless.
  void setPovVideo(PovQuality? quality);

  Future<void> disconnect();
  void dispose();
}
