import 'dart:convert';
import 'dart:typed_data';

import 'package:beam_remoteplus/core/protocol/mod_message.dart';
import 'package:beam_remoteplus/core/protocol/vehicle_skeleton.dart';
import 'package:flutter_test/flutter_test.dart';

SkeletonChunk chunk(int offset, List<int> seg, {String id = 'a', int count = 3}) =>
    SkeletonChunk.fromJson({'id': id, 'offset': offset, 'count': count, 'seg': seg})!;

void main() {
  test('decodes a skeleton datagram (cm -> m)', () {
    final json = {
      'type': 'skeleton', 'id': '3-ab', 'offset': 2, 'count': 3, 'seg': [-80, 200, 80, 200],
      'wheels': {'FL': [-78, 141, 31, 22]}, 'engine': [0, 120],
    };
    final m = ModMessage.decode(Uint8List.fromList(utf8.encode(jsonEncode(json))), 2);
    final c = (m! as SkeletonMessage).chunk;
    expect(c.id, '3-ab');
    expect(c.offset, 2);
    expect(c.wheels['FL']!.center, const Offset(-0.78, 1.41));
    expect(c.wheels['FL']!.radius, closeTo(0.31, 1e-9));
    expect(c.wheels['FL']!.isLeft, isTrue);
    expect(c.engine, const Offset(0, 1.2));
  });

  test('rejects malformed datagrams', () {
    expect(SkeletonChunk.fromJson({'id': 'a', 'offset': 0, 'count': 1, 'seg': [1, 2, 3]}), isNull);
    expect(SkeletonChunk.fromJson({'id': 'a', 'offset': 1, 'count': 1, 'seg': [1, 2, 3, 4]}), isNull);
    expect(SkeletonChunk.fromJson({'offset': 0, 'count': 1, 'seg': [1, 2, 3, 4]}), isNull);
  });

  test('assembles the pieces in any order, once all arrived', () {
    final a = SkeletonAssembler();
    expect(a.add(chunk(2, [0, 0, 100, 0])), isNull);
    expect(a.add(chunk(0, [0, 0, 0, 100, 0, 100, 100, 100])), isNotNull);
    final s = a.add(chunk(0, [0, 0, 0, 100, 0, 100, 100, 100]))!;
    expect(s.count, 3);
    expect(s.segments.sublist(8), [0, 0, 1, 0]);
  });

  test('a new id starts over', () {
    final a = SkeletonAssembler();
    a.add(chunk(0, [0, 0, 1, 1, 0, 0, 1, 1]));
    expect(a.add(chunk(2, [0, 0, 1, 1], id: 'b')), isNull);
    expect(a.id, 'b');
  });

  test('outline and bounds include the tyres', () {
    final s = VehicleSkeleton(
      id: 'x',
      segments: Float32List.fromList([-1, -2, 1, -2, 1, -2, 1, 2, 1, 2, -1, 2, -1, 2, -1, -2, 0, 0, 0.5, 0.5]),
      wheels: const {'FL': SkeletonWheel(Offset(-1, 1.5), 0.3, 0.4)},
    );
    expect(s.hull.length, 4);
    expect(s.bounds.left, closeTo(-1.2, 1e-6));
    expect(s.bounds.top, -2);
    expect(s.bounds.bottom, 2);
  });

  test('damage digits become levels when they match the skeleton', () {
    final s = VehicleSkeleton(id: 'x', segments: Float32List(12));
    expect(s.levels('090'), [0, 9, 0]);
    expect(s.levels(''), [0, 0, 0]);
    expect(s.levels('09'), isNull);
    expect(s.levels(null), isNull);
  });
}
