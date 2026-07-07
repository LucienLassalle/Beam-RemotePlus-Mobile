import 'dart:typed_data';

import 'package:app/protocol/mod_packets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ModControlPacket', () {
    test('encode little-endian, 12 octets, ordre steering/throttle/brake', () {
      const packet = ModControlPacket(steering: 0.3, throttle: 0.8, brake: 0.1);
      final bytes = packet.toBytes();
      expect(bytes.length, 12);

      final d = ByteData.sublistView(bytes);
      expect(d.getFloat32(0, Endian.little), closeTo(0.3, 1e-6));
      expect(d.getFloat32(4, Endian.little), closeTo(0.8, 1e-6));
      expect(d.getFloat32(8, Endian.little), closeTo(0.1, 1e-6));
    });

    test('clamp les valeurs hors 0-1', () {
      const packet = ModControlPacket(steering: -1, throttle: 5, brake: 0.5);
      final d = ByteData.sublistView(packet.toBytes());
      expect(d.getFloat32(0, Endian.little), 0.0);
      expect(d.getFloat32(4, Endian.little), 1.0);
    });
  });

  group('ModTelemetryPacket', () {
    test('parse un paquet little-endian de 8 floats (miroir du struct FFI Lua)', () {
      final bytes = Uint8List(32);
      final d = ByteData.sublistView(bytes);
      const le = Endian.little;

      d.setFloat32(0, 25.0, le); // speed m/s
      d.setFloat32(4, 3500, le); // rpm
      d.setFloat32(8, 7000, le); // redlineRpm
      d.setFloat32(12, 3, le); // gear -> "2"
      d.setFloat32(16, 0.6, le); // fuel
      d.setFloat32(20, 88.5, le); // engineTemp
      d.setFloat32(24, ModTelemetryPacket.lightBitSignalRight.toDouble(), le);
      d.setFloat32(28, 1.0, le); // shiftLight

      final packet = ModTelemetryPacket.fromBytes(bytes);

      expect(packet.speed, closeTo(25.0, 1e-4));
      expect(packet.speedKmh, closeTo(90.0, 1e-2));
      expect(packet.rpm, closeTo(3500, 1e-2));
      expect(packet.redlineRpm, closeTo(7000, 1e-2));
      expect(packet.gearLabel, '2');
      expect(packet.fuel, closeTo(0.6, 1e-4));
      expect(packet.signalRight, isTrue);
      expect(packet.signalLeft, isFalse);
      expect(packet.shiftLight, isTrue);
    });

    test('rejette un paquet trop court', () {
      expect(
        () => ModTelemetryPacket.fromBytes(Uint8List(10)),
        throwsFormatException,
      );
    });
  });
}
