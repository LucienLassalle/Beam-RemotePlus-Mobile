import 'dart:async';

import 'package:flutter/foundation.dart';

import '../network/remote_link.dart';
import '../protocol/mod_message.dart';
import '../protocol/telemetry.dart';

/// One command result reported by the mod.
class CommandResult {
  final String command;
  final bool ok;
  final String? error;
  final DateTime at;
  const CommandResult(this.command, this.ok, this.error, this.at);
}

/// Collects what the debug overlay shows: telemetry rate, telemetry fields
/// the vehicle did not send, and the last command results.
class DebugMonitor extends ChangeNotifier {
  static const int journalSize = 6;

  final RemoteLink link;
  final DateTime Function() _now;
  final List<StreamSubscription<Object?>> _subs = [];
  final List<DateTime> _recentFrames = [];
  final List<CommandResult> _journal = [];
  Telemetry? _last;
  String? _modVersion;

  DebugMonitor(this.link, {DateTime Function()? now}) : _now = now ?? DateTime.now {
    _subs.add(link.telemetry.listen(_onTelemetry));
    _subs.add(link.events.listen(_onEvent));
  }

  Telemetry? get lastTelemetry => _last;
  String? get modVersion => _modVersion;
  List<CommandResult> get journal => List.unmodifiable(_journal);

  /// Telemetry frames received during the last second.
  int get telemetryRate {
    final cutoff = _now().subtract(const Duration(seconds: 1));
    return _recentFrames.where((t) => t.isAfter(cutoff)).length;
  }

  /// Expected fields that the last telemetry frame did not contain.
  List<String> get missingFields => missingTelemetryFields(_last);

  void _onTelemetry(Telemetry t) {
    final now = _now();
    _last = t;
    _recentFrames.add(now);
    final cutoff = now.subtract(const Duration(seconds: 1));
    _recentFrames.removeWhere((f) => f.isBefore(cutoff));
    notifyListeners();
  }

  void _onEvent(ModMessage message) {
    if (message is AckMessage) {
      _journal.insert(0, CommandResult(message.command, message.ok, message.error, _now()));
      if (_journal.length > journalSize) _journal.removeLast();
      notifyListeners();
    } else if (message is SessionMessage) {
      _modVersion = message.modVersion;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}

/// Pure helper: which of [Telemetry.expectedFields] are absent from [t].
List<String> missingTelemetryFields(Telemetry? t) {
  if (t == null) return List.of(Telemetry.expectedFields);
  return [for (final f in Telemetry.expectedFields) if (!t.receivedFields.contains(f)) f];
}
