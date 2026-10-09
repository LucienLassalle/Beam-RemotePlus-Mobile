import 'dart:typed_data';

import 'package:beam_remoteplus/core/protocol/telemetry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Telemetry.fromJson (protocol v2)', () {
    test('reads every kind of field', () {
      final t = Telemetry.fromJson({
        'type': 'telemetry',
        'speed': 10,
        'gear': 'S5',
        'fuel': 0.5,
        'lowBeam': true,
        'escActive': 1,
        'tirePressures': {'FL': 210, 'FR': 'bad'},
        'driveMode': {'key': 'sport', 'name': 'Sport'},
        'player': 1,
      });
      expect(t.speed, 10);
      expect(t.gearLabel, 'S5');
      expect(t.lowBeam, isTrue);
      expect(t.escActive, isTrue);
      expect(t.tirePressures, {'FL': 210.0});
      expect(t.driveMode, 'Sport');
      expect(t.player, 1);
      expect(t.receivedFields, containsAll(['speed', 'gear', 'player']));
      expect(t.receivedFields, isNot(contains('type')));
    });

    test('reads the drivetrain, brakes and clutch fields', () {
      final t = Telemetry.fromJson({
        'tirePressuresNominal': {'FL': 137.9},
        'brakeTemps': {'FL': 352, 'RR': 80},
        'clutchTemp': 240,
        'clutchState': 'overheating',
        'brokenParts': ['driveshaft'],
        'drivetrain': {'shafts': ['driveshaft', 'wheelaxleRL'], 'engineAt': 0.2},
        'brokenBrakes': ['FL'],
        'brokenWheels': ['RR'],
        'fuelLeak': true,
        'wheelSpin': 3.5,
        'wheelLock': 0,
      });
      expect(t.tirePressuresNominal, {'FL': 137.9});
      expect(t.brakeTemps!['FL'], 352);
      expect(t.clutchState, 'overheating');
      expect(t.brokenParts, ['driveshaft']);
      expect(t.shafts, ['driveshaft', 'wheelaxleRL']);
      expect(t.engineAt, 0.2);
      expect(t.brokenBrakes, ['FL']);
      expect(t.brokenWheels, ['RR']);
      expect(t.fuelLeak, isTrue);
      expect(t.wheelSpin, 3.5);
    });

    test('electric cars', () {
      final t = Telemetry.fromJson({'powertrain': 'electric', 'motorPower': -12.5, 'fuel': 0.8});
      expect(t.isElectric, isTrue);
      expect(t.motorPower, -12.5);
      expect(Telemetry.fromJson({'powertrain': 'hybrid'}).isHybrid, isTrue);
      expect(Telemetry.empty.isElectric, isFalse);
    });

    test('wrong types become null instead of throwing', () {
      final t = Telemetry.fromJson({'rpm': 'fast', 'lowBeam': 'yes', 'gear': 3});
      expect(t.rpm, isNull);
      expect(t.lowBeam, isNull);
      expect(t.gear, isNull);
    });
  });

  group('derived values', () {
    test('speed conversions', () {
      const t = Telemetry(speed: 10);
      expect(t.speedKmh, closeTo(36, 1e-9));
      expect(t.speedIn(kmh: false), closeTo(22.3694, 1e-4));
      expect(Telemetry.empty.speedKmh, isNull);
    });

    test('gear label falls back on the index', () {
      expect(const Telemetry(gearIndex: -1).gearLabel, 'R');
      expect(const Telemetry(gearIndex: 0).gearLabel, 'N');
      expect(const Telemetry(gearIndex: 3).gearLabel, '3');
      expect(Telemetry.empty.gearLabel, 'N');
    });

    test('rpm ratio and low tyre pressure', () {
      expect(const Telemetry(rpm: 3500, maxRpm: 7000).rpmRatio, 0.5);
      expect(const Telemetry(rpm: 3500).rpmRatio, isNull);
      expect(const Telemetry(tirePressures: {'FL': 90}).lowTirePressure(), isTrue);
      expect(const Telemetry(tirePressures: {'FL': 200}).lowTirePressure(), isFalse);
    });

    test('low tyre pressure is judged against the pressure the car is set to', () {
      // A formula car running 110 kPa is fine, a road car at 110 kPa is not.
      const race = Telemetry(tirePressures: {'FL': 110, 'FR': 112}, tirePressuresNominal: {'FL': 117, 'FR': 117});
      expect(race.lowTirePressure(), isFalse);
      const road = Telemetry(tirePressures: {'FL': 110, 'FR': 230}, tirePressuresNominal: {'FL': 230, 'FR': 230});
      expect(road.lowPressureTires(), ['FL']);
    });
  });

  group('Telemetry.fromLegacyBytes (protocol v1)', () {
    Uint8List packet(List<double> values) {
      final d = ByteData(36);
      for (var i = 0; i < values.length; i++) {
        d.setFloat32(i * 4, values[i], Endian.little);
      }
      return d.buffer.asUint8List();
    }

    test('maps the 9 floats', () {
      final t = Telemetry.fromLegacyBytes(packet([20, 3000, 7000, 3, 0.4, 90, 1 + 8 + 128, 1, 101]));
      expect(t.speed, 20);
      expect(t.gearIndex, 2);
      expect(t.gearLabel, '2');
      expect(t.lowBeam, isTrue);
      expect(t.signalLeft, isTrue);
      expect(t.tcsActive, isTrue);
      expect(t.highBeam, isFalse);
      expect(t.shiftLight, isTrue);
      expect(t.oilTemp, closeTo(101, 1e-3));
    });

    test('neutralises NaN and treats oil temperature 0 as unknown', () {
      final t = Telemetry.fromLegacyBytes(packet([double.nan, double.infinity, 0, 1, 0, 0, 0, 0, 0]));
      expect(t.speed, 0);
      expect(t.rpm, 0);
      expect(t.oilTemp, isNull);
    });

    test('rejects short packets', () {
      expect(() => Telemetry.fromLegacyBytes(Uint8List(10)), throwsFormatException);
    });
  });
}
