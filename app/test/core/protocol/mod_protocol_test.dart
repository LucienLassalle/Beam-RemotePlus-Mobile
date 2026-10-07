import 'dart:typed_data';

import 'package:beam_remoteplus/core/protocol/mod_protocol.dart';
import 'package:beam_remoteplus/core/protocol/native_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ModProtocol', () {
    test('ping announces version 2 and the phone name without separators', () {
      expect(ModProtocol.ping('20367', 'Galaxy|Fold'), 'beamngremoteplus|ping|20367|2|Galaxy Fold');
    });

    test('parses pongs of v1 and v2 mods', () {
      expect(ModProtocol.parsePong('beamngremoteplus|pong|20367|2', '20367'), 2);
      expect(ModProtocol.parsePong('beamngremoteplus|pong|20367|1', '20367'), 1);
      expect(ModProtocol.parsePong('beamngremoteplus|pong|20367', '20367'), 1);
    });

    test('ignores pongs for another code', () {
      expect(ModProtocol.parsePong('beamngremoteplus|pong|11111|2', '20367'), isNull);
      expect(ModProtocol.parsePong('beamngremoteplus|pong|203670|2', '20367'), isNull);
    });

    test('builds commands with and without argument', () {
      expect(ModProtocol.command(ModCommand.hazard), 'cmd|hazard');
      expect(ModProtocol.command(ModCommand.horn, '1'), 'cmd|horn|1');
    });

    test('a control packet can never start with the command prefix', () {
      // The mod checks the "cmd|" prefix before the packet size (some
      // commands are 12 bytes long too). Clamped floats keep the last byte of
      // each value <= 0x3F, so the prefix bytes can never appear.
      for (final v in [0.0, 0.25, 0.5, 0.9999, 1.0]) {
        final bytes = ModControlPacket(steering: v, throttle: v, brake: v).toBytes();
        expect(String.fromCharCodes(bytes.take(4)), isNot(ModProtocol.cmdPrefix));
        expect(bytes[3], lessThanOrEqualTo(0x3F));
      }
    });
  });

  group('DiscoveredHost.parseHello', () {
    test('parses code and label', () {
      final host = DiscoveredHost.parseHello('beamngremoteplus|hello|20367|BeamNG of Loka', '192.168.1.10')!;
      expect(host.securityCode, '20367');
      expect(host.label, 'BeamNG of Loka');
      expect(host.hostAddress, '192.168.1.10');
    });

    test('defaults the label', () {
      expect(DiscoveredHost.parseHello('beamngremoteplus|hello|1', 'x')!.label, DiscoveredHost.defaultLabel);
    });

    test('rejects other messages', () {
      expect(DiscoveredHost.parseHello('beamngremoteplus|pong|1|2', 'x'), isNull);
      expect(DiscoveredHost.parseHello('beamngremoteplus|hello|', 'x'), isNull);
    });
  });

  group('control packets', () {
    test('mod packet: 12 bytes little-endian, clamped', () {
      final bytes = const ModControlPacket(steering: 0.25, throttle: 2, brake: -1).toBytes();
      final d = ByteData.sublistView(bytes);
      expect(bytes.length, 12);
      expect(d.getFloat32(0, Endian.little), 0.25);
      expect(d.getFloat32(4, Endian.little), 1);
      expect(d.getFloat32(8, Endian.little), 0);
    });

    test('native packet: 16 bytes big-endian with the sequence id', () {
      final d = ByteData.sublistView(const NativeControlPacket(steering: 0.5, throttle: 1, brake: 0, sequenceId: 7).toBytes());
      expect(d.getFloat32(0), 0.5);
      expect(d.getFloat32(4), 1);
      expect(d.getFloat32(12), 7);
    });

    test('native handshake strings', () {
      expect(NativeProtocol.handshake('Pixel', '1234'), 'beamng|Pixel|1234');
      expect(NativeProtocol.expectedAnswer('1234'), 'beamng|1234');
    });
  });
}
