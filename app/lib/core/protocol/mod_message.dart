import 'dart:convert';
import 'dart:typed_data';

import 'telemetry.dart';

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
  const SessionMessage({this.modVersion, this.player, this.commands = const []});
}
