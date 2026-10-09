import 'dart:typed_data';

import '../../core/protocol/telemetry.dart';
import '../../core/protocol/vehicle_skeleton.dart';

/// Keeps the skeleton of the followed vehicle: asks the mod for it when
/// the telemetry announces one this phone does not have (new vehicle, new
/// configuration, datagrams lost), and keeps the last damage digits.
class SkeletonTracker {
  /// Sends `cmd|skeleton`.
  final void Function() request;
  SkeletonTracker({required this.request});

  /// Time left to the mod to answer before asking again.
  static const retry = Duration(seconds: 2);

  final SkeletonAssembler _assembler = SkeletonAssembler();
  VehicleSkeleton? _skeleton;
  String? _wanted;
  String? _damage;
  Uint8List? _levels;
  DateTime? _lastRequest;

  /// Skeleton of the vehicle followed right now, null while it is not
  /// (completely) received or with an older mod.
  VehicleSkeleton? get skeleton => _skeleton != null && _skeleton!.id == _wanted ? _skeleton : null;

  /// Damage level of each segment of [skeleton] (0 intact .. 9 broken).
  Uint8List? get levels => skeleton == null ? null : _levels;

  void onTelemetry(Telemetry t, DateTime now) {
    final id = t.skeletonId;
    if (id != _wanted) {
      _wanted = id;
      _damage = null;
      _levels = null;
      _lastRequest = null;
    }
    if (id == null) return;
    if (t.skeletonDamage != null && t.skeletonDamage != _damage) {
      _damage = t.skeletonDamage;
      _levels = _skeleton?.id == id ? _skeleton!.levels(_damage) : null;
    }
    if (_skeleton?.id != id && (_lastRequest == null || now.difference(_lastRequest!) >= retry)) {
      _lastRequest = now;
      request();
    }
  }

  /// Returns true when the skeleton just became complete.
  bool onChunk(SkeletonChunk chunk) {
    if (chunk.id != _wanted || _skeleton?.id == chunk.id) return false;
    final s = _assembler.add(chunk);
    if (s == null) return false;
    _skeleton = s;
    _levels = s.levels(_damage);
    return true;
  }
}
