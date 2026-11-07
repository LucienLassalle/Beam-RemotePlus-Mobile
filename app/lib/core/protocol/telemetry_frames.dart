/// Rebuilds the full telemetry frames from the delta frames of the mod
/// (`delta` feature, docs/PROTOCOL.md of the mod): a delta carries only
/// the fields that changed since the previous frame, null for a field gone.
class TelemetryFrames {
  Map<String, Object?>? _last;

  /// The full frame [json] stands for: itself, or the last one with the
  /// delta applied. Null for a delta arriving before any full frame (the
  /// mod sends one every second).
  Map<String, Object?>? accept(Map<String, Object?> json) {
    if (json['delta'] != true) return _last = json;
    final last = _last;
    if (last == null) return null;
    final frame = Map<String, Object?>.of(last);
    for (final MapEntry(:key, :value) in json.entries) {
      if (key == 'delta') continue;
      if (value == null) {
        frame.remove(key);
      } else {
        frame[key] = value;
      }
    }
    return _last = frame;
  }

  /// A new session: the mod starts it with a full frame.
  void reset() => _last = null;
}
