import '../protocol/mod_message.dart';
import '../protocol/telemetry.dart';

enum LinkState { idle, connecting, connected, timeout, error }

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

  Stream<Telemetry> get telemetry;

  /// Acks and session messages from the mod.
  Stream<ModMessage> get events;

  /// Sets the analog inputs (0..1, steering 0.5 = centre); sent at a fixed rate.
  void updateControls({double? steering, double? throttle, double? brake});

  /// Sends `cmd|name` or `cmd|name|arg` to the mod (ignored without mod).
  void sendCommand(String name, [String? arg]);

  Future<void> disconnect();
  void dispose();
}
