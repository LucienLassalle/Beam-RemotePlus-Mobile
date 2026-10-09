import 'dart:typed_data';
import 'dart:ui';

/// One wheel of a [VehicleSkeleton]: centre, radius and width in metres.
class SkeletonWheel {
  final Offset center;
  final double radius;
  final double width;
  const SkeletonWheel(this.center, this.radius, this.width);

  bool get isLeft => center.dx < 0;

  /// The tyre seen from above.
  Rect get rect => Rect.fromCenter(center: center, width: width, height: radius * 2);
}

/// Top view of the vehicle's real structure: the beams of BeamNG.drive's
/// detailed damage app, sent by the mod on request (`skeleton` messages).
/// Metres, x to the right and y forward of the vehicle reference node.
class VehicleSkeleton {
  final String id;

  /// x1, y1, x2, y2 for each segment.
  final Float32List segments;
  final Map<String, SkeletonWheel> wheels;

  /// Engine (or electric motor) position.
  final Offset? engine;

  VehicleSkeleton({required this.id, required this.segments, this.wheels = const {}, this.engine});

  int get count => segments.length ~/ 4;

  /// Everything drawn: the structure and the tyres.
  late final Rect bounds = () {
    var r = hull.isEmpty ? Rect.zero : Rect.fromPoints(hull.first, hull.first);
    for (final p in hull) {
      r = r.expandToInclude(Rect.fromPoints(p, p));
    }
    for (final w in wheels.values) {
      r = r.expandToInclude(w.rect);
    }
    return r;
  }();

  /// Outline of the body: convex hull of the beam ends.
  late final List<Offset> hull = convexHull([
    for (var i = 0; i + 1 < segments.length; i += 2) Offset(segments[i], segments[i + 1]),
  ]);

  /// Monotone chain convex hull, counter-clockwise, without repeating the
  /// first point.
  static List<Offset> convexHull(List<Offset> points) {
    final pts = points.toSet().toList()
      ..sort((a, b) => a.dx != b.dx ? a.dx.compareTo(b.dx) : a.dy.compareTo(b.dy));
    if (pts.length < 3) return pts;
    double cross(Offset o, Offset a, Offset b) => (a.dx - o.dx) * (b.dy - o.dy) - (a.dy - o.dy) * (b.dx - o.dx);
    final lower = <Offset>[];
    for (final p in pts) {
      while (lower.length >= 2 && cross(lower[lower.length - 2], lower.last, p) <= 0) {
        lower.removeLast();
      }
      lower.add(p);
    }
    final upper = <Offset>[];
    for (final p in pts.reversed) {
      while (upper.length >= 2 && cross(upper[upper.length - 2], upper.last, p) <= 0) {
        upper.removeLast();
      }
      upper.add(p);
    }
    return [...lower.sublist(0, lower.length - 1), ...upper.sublist(0, upper.length - 1)];
  }

  /// Damage level of each segment (0 intact .. 9 broken) from the
  /// `skeletonDamage` digits; null when they do not match this skeleton.
  Uint8List? levels(String? damage) {
    if (damage == null) return null;
    final levels = Uint8List(count);
    if (damage.isEmpty) return levels;
    if (damage.length != count) return null;
    for (var i = 0; i < count; i++) {
      final level = damage.codeUnitAt(i) - 0x30;
      levels[i] = level < 0 || level > 9 ? 0 : level;
    }
    return levels;
  }
}

/// One `skeleton` datagram: segments [offset] .. of [count], in cm.
class SkeletonChunk {
  final String id;
  final int offset;
  final int count;
  final List<int> seg;
  final Map<String, SkeletonWheel> wheels;
  final Offset? engine;

  const SkeletonChunk({
    required this.id,
    required this.offset,
    required this.count,
    required this.seg,
    this.wheels = const {},
    this.engine,
  });

  static int? _int(Object? v) => v is num && v.isFinite ? v.round() : null;

  static Offset? _point(Object? v) {
    if (v is! List || v.length < 2) return null;
    final x = _int(v[0]), y = _int(v[1]);
    return x == null || y == null ? null : Offset(x / 100, y / 100);
  }

  /// Null when malformed.
  static SkeletonChunk? fromJson(Map<String, Object?> j) {
    final id = j['id'], offset = _int(j['offset']), count = _int(j['count']), seg = j['seg'];
    if (id is! String || offset == null || count == null || seg is! List || offset < 0 || count <= 0) return null;
    final ints = [for (final v in seg) _int(v) ?? 0];
    if (ints.length % 4 != 0 || offset + ints.length ~/ 4 > count) return null;
    final wheels = <String, SkeletonWheel>{};
    final w = j['wheels'];
    if (w is Map) {
      w.forEach((name, v) {
        final c = _point(v);
        if (name is String && c != null && v is List && v.length >= 4) {
          wheels[name] = SkeletonWheel(c, (_int(v[2]) ?? 30) / 100, (_int(v[3]) ?? 20) / 100);
        }
      });
    }
    return SkeletonChunk(id: id, offset: offset, count: count, seg: ints, wheels: wheels, engine: _point(j['engine']));
  }
}

/// Puts the `skeleton` datagrams back together, in any order.
class SkeletonAssembler {
  String? _id;
  Float32List _segments = Float32List(0);
  Uint8List _received = Uint8List(0);
  int _missing = 0;
  Map<String, SkeletonWheel> _wheels = const {};
  Offset? _engine;

  String? get id => _id;

  /// Returns the skeleton once its last missing piece arrived.
  VehicleSkeleton? add(SkeletonChunk c) {
    if (c.id != _id || c.count * 4 != _segments.length) {
      _id = c.id;
      _segments = Float32List(c.count * 4);
      _received = Uint8List(c.count);
      _missing = c.count;
    }
    for (var i = 0; i < c.seg.length; i++) {
      _segments[c.offset * 4 + i] = c.seg[i] / 100;
    }
    for (var s = c.offset; s < c.offset + c.seg.length ~/ 4; s++) {
      if (_received[s] == 0) {
        _received[s] = 1;
        _missing--;
      }
    }
    if (c.wheels.isNotEmpty) _wheels = c.wheels;
    _engine = c.engine ?? _engine;
    if (_missing > 0) return null;
    return VehicleSkeleton(id: c.id, segments: Float32List.fromList(_segments), wheels: _wheels, engine: _engine);
  }
}
