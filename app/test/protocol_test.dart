import 'dart:typed_data';

import 'package:app/protocol/control_packet.dart';
import 'package:app/protocol/pairing_code.dart';
import 'package:app/protocol/telemetry_packet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ControlPacket', () {
    test('encode big-endian, 16 octets, ordre steering/throttle/brake/id', () {
      const packet = ControlPacket(
        steering: 0.75,
        throttle: 1.0,
        brake: 0.0,
        sequenceId: 5,
      );
      final bytes = packet.toBytes();
      expect(bytes.length, 16);

      final d = ByteData.sublistView(bytes);
      expect(d.getFloat32(0, Endian.big), closeTo(0.75, 1e-6));
      expect(d.getFloat32(4, Endian.big), closeTo(1.0, 1e-6));
      expect(d.getFloat32(8, Endian.big), closeTo(0.0, 1e-6));
      expect(d.getFloat32(12, Endian.big), closeTo(5.0, 1e-6));
    });

    test('clamp les valeurs hors 0-1 pour steering/throttle/brake', () {
      const packet = ControlPacket(
        steering: 1.5,
        throttle: -0.5,
        brake: 2.0,
        sequenceId: 0,
      );
      final d = ByteData.sublistView(packet.toBytes());
      expect(d.getFloat32(0, Endian.big), 1.0);
      expect(d.getFloat32(4, Endian.big), 0.0);
      expect(d.getFloat32(8, Endian.big), 1.0);
    });
  });

  group('TelemetryPacket', () {
    test('parse un paquet little-endian façon OutGauge', () {
      final bytes = Uint8List(100);
      final d = ByteData.sublistView(bytes);
      const le = Endian.little;

      d.setUint32(0, 12345, le); // time
      d.setUint16(8, 16384, le); // flags OG_KM
      bytes[10] = 3; // gear -> "2"
      bytes[11] = 1; // plid
      d.setFloat32(12, 27.7, le); // speed m/s
      d.setFloat32(16, 4200, le); // rpm
      d.setFloat32(24, 91.5, le); // engTemp
      d.setFloat32(28, 0.42, le); // fuel
      d.setUint32(44, 1 | 64, le); // showLights: shift + signal droit
      d.setInt32(92, 7, le); // id
      d.setUint32(96, 123456, le); // odometer

      final packet = TelemetryPacket.fromBytes(bytes);

      expect(packet.prefersKmh, isTrue);
      expect(packet.gearLabel, '2');
      expect(packet.speed, closeTo(27.7, 1e-4));
      expect(packet.speedKmh, closeTo(27.7 * 3.6, 1e-3));
      expect(packet.rpm, closeTo(4200, 1e-3));
      expect(packet.fuel, closeTo(0.42, 1e-4));
      expect(packet.shiftLight, isTrue);
      expect(packet.signalRight, isTrue);
      expect(packet.signalLeft, isFalse);
      expect(packet.id, 7);
      expect(packet.odometer, 123456);
    });

    test('rejette un paquet trop court', () {
      expect(
        () => TelemetryPacket.fromBytes(Uint8List(50)),
        throwsFormatException,
      );
    });
  });

  group('PairingCode', () {
    test('extrait le code après le #', () {
      final code = PairingCode.tryParse('beamng-drive#A1B2C3');
      expect(code, isNotNull);
      expect(code!.securityCode, 'A1B2C3');
    });

    test('rejette un texte sans #', () {
      expect(PairingCode.tryParse('pas-de-hash'), isNull);
    });
  });
}
