import 'dart:typed_data';

import 'package:beam_remoteplus/protocol/mod_discovery.dart';
import 'package:beam_remoteplus/protocol/mod_packets.dart';
import 'package:beam_remoteplus/protocol/protocol_constants.dart';
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

  group('ModProtocol commands', () {
    final allCmds = [
      ModProtocol.cmdNextVehicle,
      ModProtocol.cmdPrevVehicle,
      ModProtocol.cmdCamNext,
      ModProtocol.cmdCamPrev,
      ModProtocol.cmdGearUp,
      ModProtocol.cmdGearDown,
    ];

    test('toutes les commandes commencent par cmdPrefix', () {
      for (final cmd in allCmds) {
        expect(
          cmd.startsWith(ModProtocol.cmdPrefix),
          isTrue,
          reason: '$cmd ne commence pas par ${ModProtocol.cmdPrefix}',
        );
      }
    });

    test('valeurs exactes des constantes', () {
      expect(ModProtocol.cmdNextVehicle, 'cmd|next_vehicle');
      expect(ModProtocol.cmdPrevVehicle, 'cmd|prev_vehicle');
      expect(ModProtocol.cmdCamNext, 'cmd|cam_next');
      expect(ModProtocol.cmdCamPrev, 'cmd|cam_prev');
      expect(ModProtocol.cmdGearUp, 'cmd|gear_up');
      expect(ModProtocol.cmdGearDown, 'cmd|gear_down');
    });

    // La discrimination vis-à-vis du binaire se fait par préfixe 'cmd|',
    // pas par longueur. Le premier octet 'c' (0x63) ne peut pas apparaître
    // en byte[0] d'un paquet de contrôle binaire valide : float32 steering
    // ∈ [0,1] → byte[0] (LSB little-endian) ∈ [0x00, 0x3F].
    test('le premier octet du préfixe est hors de la plage float32 [0,1]', () {
      final prefixFirstByte = ModProtocol.cmdPrefix.codeUnitAt(0); // 'c' = 0x63
      // Tout float32 ∈ [0.0, 1.0] en little-endian a son LSB ≤ 0x3F
      const maxLsbForValidSteering = 0x3F;
      expect(prefixFirstByte, greaterThan(maxLsbForValidSteering));
    });

    test('toutes les commandes sont distinctes (pas de collision)', () {
      final set = allCmds.toSet();
      expect(set.length, allCmds.length);
    });
  });

  group('ModTelemetryPacket', () {
    test('parse un paquet little-endian de 9 floats (miroir du struct FFI Lua)', () {
      final bytes = Uint8List(36);
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
      d.setFloat32(32, 95.0, le); // oilTemp

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
      expect(packet.oilTemp, closeTo(95.0, 1e-2));
    });

    test('rejette un paquet trop court', () {
      expect(
        () => ModTelemetryPacket.fromBytes(Uint8List(10)),
        throwsFormatException,
      );
    });

    test('neutralise NaN/Infinity au lieu de planter (régression)', () {
      // Cas réel observé : juste après un spawn/changement/récupération de
      // véhicule, electrics.values peut transitoirement remonter NaN côté
      // jeu (ex: gearIndex). double.round() lève UnsupportedError sur une
      // valeur non finie -> fromBytes ne doit donc JAMAIS appeler round()
      // sur une valeur brute non assainie.
      final bytes = Uint8List(36);
      final d = ByteData.sublistView(bytes);
      const le = Endian.little;

      d.setFloat32(0, double.nan, le); // speed
      d.setFloat32(4, double.infinity, le); // rpm
      d.setFloat32(8, double.negativeInfinity, le); // redlineRpm
      d.setFloat32(12, double.nan, le); // gear (le cas qui plantait)
      d.setFloat32(16, double.nan, le); // fuel
      d.setFloat32(20, double.infinity, le); // engineTemp
      d.setFloat32(24, double.nan, le); // lights (le cas qui plantait)
      d.setFloat32(28, double.nan, le); // shiftLight
      d.setFloat32(32, double.nan, le); // oilTemp

      late ModTelemetryPacket packet;
      expect(() => packet = ModTelemetryPacket.fromBytes(bytes), returnsNormally);

      expect(packet.speed, 0.0);
      expect(packet.rpm, 0.0);
      expect(packet.redlineRpm, 0.0);
      expect(packet.gear, 1); // point mort par défaut, pas -1/'R'
      expect(packet.fuel, 0.0);
      expect(packet.engineTemp, 0.0);
      expect(packet.lights, 0);
      expect(packet.shiftLight, isFalse); // NaN >= 0.5 est déjà false
      expect(packet.oilTemp, 0.0);
    });
  });

  group('ModDiscovery.parseHello', () {
    test('parse code + label', () {
      final r = ModDiscovery.parseHello(
        'beamngremoteplus|hello|54688|BeamNG de Loka',
        '192.168.1.42',
      );
      expect(r, isNotNull);
      expect(r!.securityCode, '54688');
      expect(r.label, 'BeamNG de Loka');
      expect(r.hostAddress, '192.168.1.42');
    });

    test('label par défaut si absent', () {
      final r = ModDiscovery.parseHello(
        'beamngremoteplus|hello|54688',
        '10.0.0.1',
      );
      expect(r, isNotNull);
      expect(r!.securityCode, '54688');
      expect(r.label, 'BeamNG.drive');
    });

    test('rejette un message non-hello', () {
      expect(
        ModDiscovery.parseHello('beamngremoteplus|pong|54688|1', '10.0.0.1'),
        isNull,
      );
      expect(ModDiscovery.parseHello('', '10.0.0.1'), isNull);
      expect(
        ModDiscovery.parseHello('beamngremoteplus|hello|', '10.0.0.1'),
        isNull,
      );
    });

    test('le message discover a le bon format', () {
      expect(ModProtocol.discoverMessage, 'beamngremoteplus|discover');
    });
  });
}
