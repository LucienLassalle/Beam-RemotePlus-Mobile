import '../protocol/mod_message.dart';
import '../protocol/mod_protocol.dart';
import '../protocol/telemetry.dart';

/// The point of view video as the phone's player draws it.
class PovPicture {
  /// Texture to show with a Texture widget.
  final int textureId;
  final int width;
  final int height;

  /// The phone's decoder failed (it tries again on the next keyframe).
  final String? error;

  const PovPicture({required this.textureId, required this.width, required this.height, this.error});
}

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

  /// What the phone's player shows of the point of view video, while
  /// [setPovVideo] is on: the texture to draw and the picture size, or the
  /// failure of the phone's decoder.
  Stream<PovPicture> get povPictures;

  /// Starts the point of view video of the mod in [format] (the phone's
  /// player listens on [ModProtocol.povPort] and the mod is asked for it),
  /// or stops it (null). Asking again (new mod session) is harmless.
  void setPovVideo(PovFormat? format);

  Future<void> disconnect();
  void dispose();
}
