import 'dart:convert';
import 'dart:typed_data';

import 'telemetry.dart';
import 'vehicle_command.dart';
import 'vehicle_skeleton.dart';

/// A datagram received from the mod on [ModProtocol.clientPort].
sealed class ModMessage {
  const ModMessage();

  /// Decodes a datagram according to the negotiated protocol version.
  /// Returns null for anything that is not understood (forward compatible:
  /// a newer mod may send message types this app does not know).
  static ModMessage? decode(Uint8List data, int protocolVersion) {
    if (protocolVersion < 2) {
      if (data.length != Telemetry.legacySizeBytes) return null;
      return TelemetryMessage(Telemetry.fromLegacyBytes(data));
    }
    if (data.isEmpty || data.first != 0x7B /* { */) return null;
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(data));
    } on FormatException {
      return null;
    }
    if (json is! Map<String, Object?>) return null;
    switch (json['type']) {
      case 'telemetry':
        return TelemetryMessage(Telemetry.fromJson(json));
      case 'ack':
        return AckMessage(
          command: json['cmd'] is String ? json['cmd']! as String : '?',
          ok: json['ok'] == true,
          error: json['error'] is String ? json['error']! as String : null,
        );
      case 'session':
        return SessionMessage(
          modVersion: json['modVersion'] is String ? json['modVersion']! as String : null,
          player: json['player'] is num ? (json['player']! as num).toInt() : null,
          commands: json['commands'] is List
              ? [for (final c in json['commands']! as List<Object?>) if (c is String) c]
              : const [],
          optionalMods: json['optionalMods'] is Map
              ? {
                  for (final e in (json['optionalMods']! as Map).entries)
                    if (e.key is String && e.value is String) e.key as String: e.value as String,
                }
              : null,
          playerColor: parseHexColor(json['playerColor']),
        );
      case 'skeleton':
        final chunk = SkeletonChunk.fromJson(json);
        return chunk == null ? null : SkeletonMessage(chunk);
      case 'kicked':
        return const KickedMessage();
      case 'pov':
        return PovMessage(
          state: json['state'] is String ? json['state']! as String : '?',
          error: json['error'] is String ? json['error']! as String : null,
          inside: json['inside'] == true,
        );
      case 'actions':
        return ActionsMessage(
          vehicle: json['vehicle'] is String ? json['vehicle']! as String : null,
          commands: json['actions'] is List
              ? [
                  for (final c in json['actions']! as List<Object?>)
                    if (VehicleCommand.fromJson(c) case final command?) command,
                ]
              : const [],
        );
      default:
        return null;
    }
  }
}

class TelemetryMessage extends ModMessage {
  final Telemetry telemetry;
  const TelemetryMessage(this.telemetry);
}

/// Result of a command: always sent on failure, on success only in debug.
class AckMessage extends ModMessage {
  final String command;
  final bool ok;
  final String? error;
  const AckMessage({required this.command, required this.ok, this.error});
}

class SessionMessage extends ModMessage {
  final String? modVersion;
  final int? player;
  final List<String> commands;

  /// State of each optional mod in the game, by id (`tyreThermals`,
  /// `cf26`...): `enabled`, `disabled` or `missing`. Null for older mods,
  /// which do not tell.
  final Map<String, String>? optionalMods;

  /// 0xRRGGBB colour the game gives the player (its name tag above the car
  /// in local multiplayer); null for older mods, a second screen or while
  /// unassigned.
  final int? playerColor;

  const SessionMessage({this.modVersion, this.player, this.commands = const [], this.optionalMods, this.playerColor});
}

/// The player kicked this phone from the mod's in-game panel: the session
/// is already closed on the PC side.
class KickedMessage extends ModMessage {
  const KickedMessage();
}

/// State of the point of view video of this phone (mod 0.0.5+).
class PovMessage extends ModMessage {
  /// `starting`, `live` or `error` (no video, the mod stopped it).
  final String state;

  /// Why there is no video: `encoder`, the PC's graphics card could not
  /// start its video encoder.
  final String? error;

  /// A seat camera: the car's own dashboard is in view.
  final bool inside;

  const PovMessage({required this.state, this.error, this.inside = false});

  static const live = 'live';
  static const failed = 'error';
  static const errorEncoder = 'encoder';
}

/// One piece of the vehicle skeleton (answer to `cmd|skeleton`).
class SkeletonMessage extends ModMessage {
  final SkeletonChunk chunk;
  const SkeletonMessage(this.chunk);
}

/// "#rrggbb" (or "rrggbb") to 0xRRGGBB, null for anything else.
int? parseHexColor(Object? value) {
  if (value is! String) return null;
  final hex = value.startsWith('#') ? value.substring(1) : value;
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex)) return null;
  return int.parse(hex, radix: 16);
}

/// Answer to `cmd|actions`: the commands of the "More" sheet for the vehicle
/// the phone drives.
class ActionsMessage extends ModMessage {
  final String? vehicle;
  final List<VehicleCommand> commands;
  const ActionsMessage({this.vehicle, this.commands = const []});
}
