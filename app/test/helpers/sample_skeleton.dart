import 'dart:typed_data';
import 'dart:ui';

import 'package:beam_remoteplus/core/protocol/vehicle_skeleton.dart';

/// A lattice of beams shaped like a vehicle seen from above (rounded nose
/// and tail), [width] x [length] metres, with its wheels at [axles] (y of
/// each axle, metres from the centre).
VehicleSkeleton sampleSkeleton({
  String id = 'car',
  double width = 1.8,
  double length = 4.4,
  List<double> axles = const [1.35, -1.35],
  Offset? engine = const Offset(0, 1.5),
  double step = 0.25,
}) {
  final nodes = <Offset>[];
  final index = <(int, int), int>{};
  final cols = (width / step).round(), rows = (length / step).round();
  for (var r = 0; r <= rows; r++) {
    for (var c = 0; c <= cols; c++) {
      final x = -width / 2 + c * step, y = -length / 2 + r * step;
      // Round the four corners off.
      final edge = (y.abs() - (length / 2 - 0.5)).clamp(0.0, 0.5) * 1.2;
      if (x.abs() > width / 2 - edge + 1e-6) continue;
      index[(r, c)] = nodes.length;
      nodes.add(Offset(x, y));
    }
  }
  final seg = <double>[];
  void beam(int a, int b) => seg.addAll([nodes[a].dx, nodes[a].dy, nodes[b].dx, nodes[b].dy]);
  index.forEach((rc, i) {
    final (r, c) = rc;
    for (final (dr, dc) in [(0, 1), (1, 0), (1, 1), (1, -1)]) {
      final j = index[(r + dr, c + dc)];
      if (j != null) beam(i, j);
    }
  });
  final wheels = <String, SkeletonWheel>{};
  for (var a = 0; a < axles.length; a++) {
    final prefix = a == 0 ? 'F' : (axles.length > 2 ? 'R$a' : 'R');
    wheels['${prefix}L'] = SkeletonWheel(Offset(-width / 2 + 0.1, axles[a]), 0.33, 0.24);
    wheels['${prefix}R'] = SkeletonWheel(Offset(width / 2 - 0.1, axles[a]), 0.33, 0.24);
  }
  return VehicleSkeleton(id: id, segments: Float32List.fromList(seg), wheels: wheels, engine: engine);
}

/// Damage digits: segments ahead of [y] and left of [x] crushed, the
/// worse the closer to the front left corner.
String sampleDamage(VehicleSkeleton s, {double y = 1.2, double x = 0.2}) {
  final digits = StringBuffer();
  for (var i = 0; i < s.count; i++) {
    final sx = (s.segments[i * 4] + s.segments[i * 4 + 2]) / 2;
    final sy = (s.segments[i * 4 + 1] + s.segments[i * 4 + 3]) / 2;
    final depth = (sy - y) * 4 + (x - sx) * 2;
    digits.write(sy > y && sx < x ? depth.clamp(1, 9).round() : 0);
  }
  return digits.toString();
}
