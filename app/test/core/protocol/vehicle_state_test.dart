import 'package:beam_remoteplus/core/protocol/telemetry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('telemetry v2 vehicle state', () {
    test('decodes radar, damage and tyres', () {
      final t = Telemetry.fromJson({
        'radar': [
          {'x': 2, 'y': 8, 'heading': 180, 'length': 4, 'width': 2},
        ],
        'bodyDamage': {'FL': 0.4},
        'engineDamage': ['radiatorLeak'],
        'flatTires': ['RR'],
        'tyres': {
          'FL': {'temp': 95, 'working': 85, 'condition': 97},
        },
        'wheelSlip': 4.2,
      });
      expect(t.radar!.single.distance, closeTo(8.246, 1e-3));
      expect(t.bodyDamage, {'FL': 0.4});
      expect(t.engineDamage, ['radiatorLeak']);
      expect(t.flatTires, ['RR']);
      expect(t.tyres!['FL']!.heat, closeTo(10 / 34, 1e-6));
      expect(t.wheelSlip, 4.2);
    });

    test('an empty Lua radar table means nobody around', () {
      expect(Telemetry.fromJson({'radar': <String, Object?>{}}).radar, isEmpty);
      expect(Telemetry.fromJson({}).radar, isNull);
    });
  });
}
