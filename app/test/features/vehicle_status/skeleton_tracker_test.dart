import 'package:beam_remoteplus/core/protocol/telemetry.dart';
import 'package:beam_remoteplus/core/protocol/vehicle_skeleton.dart';
import 'package:beam_remoteplus/features/vehicle_status/skeleton_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime(2026);
  SkeletonChunk piece(String id, int offset) =>
      SkeletonChunk(id: id, offset: offset, count: 2, seg: const [0, 0, 100, 100]);

  test('asks for an announced skeleton, again every 2 s until it is complete', () {
    var requests = 0;
    final tracker = SkeletonTracker(request: () => requests++);
    tracker.onTelemetry(Telemetry.empty, t0);
    expect(requests, 0);
    const t = Telemetry(skeletonId: 'a');
    tracker.onTelemetry(t, t0);
    tracker.onTelemetry(t, t0.add(const Duration(seconds: 1)));
    expect(requests, 1);
    expect(tracker.onChunk(piece('a', 0)), isFalse);
    tracker.onTelemetry(t, t0.add(const Duration(seconds: 2)));
    expect(requests, 2);
    expect(tracker.onChunk(piece('a', 1)), isTrue);
    expect(tracker.skeleton!.count, 2);
    tracker.onTelemetry(t, t0.add(const Duration(seconds: 10)));
    expect(requests, 2);
  });

  test('keeps the last damage, even when it arrived before the geometry', () {
    final tracker = SkeletonTracker(request: () {});
    tracker.onTelemetry(const Telemetry(skeletonId: 'a', skeletonDamage: '09'), t0);
    tracker.onTelemetry(const Telemetry(skeletonId: 'a'), t0);
    tracker.onChunk(piece('a', 0));
    tracker.onChunk(piece('a', 1));
    expect(tracker.levels, [0, 9]);
    tracker.onTelemetry(const Telemetry(skeletonId: 'a', skeletonDamage: ''), t0);
    expect(tracker.levels, [0, 0]);
  });

  test('another vehicle hides the old skeleton and ignores its late pieces', () {
    var requests = 0;
    final tracker = SkeletonTracker(request: () => requests++);
    tracker.onTelemetry(const Telemetry(skeletonId: 'a'), t0);
    tracker.onChunk(piece('a', 0));
    tracker.onChunk(piece('a', 1));
    tracker.onTelemetry(const Telemetry(skeletonId: 'b'), t0);
    expect(tracker.skeleton, isNull);
    expect(requests, 2);
    expect(tracker.onChunk(piece('a', 0)), isFalse);
  });
}
