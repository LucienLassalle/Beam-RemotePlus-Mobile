import 'dart:typed_data';

import 'package:beam_remoteplus/core/protocol/mod_protocol.dart';
import 'package:beam_remoteplus/core/protocol/native_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ModProtocol', () {
    test('ping announces version 2 and the phone name without separators', () {
      expect(ModProtocol.ping('20367', 'Galaxy|Fold'), 'beamremoteplus|ping|20367|2|Galaxy Fold');
      expect(ModProtocol.ping('1', 'Tab', display: true, withPrefix: ModProtocol.legacyPrefix), 'beamngremoteplus|ping|1|2|Tab|display');
    });

    test('ping sends the app version after the role', () {
      expect(ModProtocol.ping('1', 'Tab', appVersion: '0.0.5-0.39'), 'beamremoteplus|ping|1|2|Tab|controller|0.0.5-0.39');
      expect(ModProtocol.ping('1', 'Tab', display: true, appVersion: '0.0.5'), 'beamremoteplus|ping|1|2|Tab|display|0.0.5');
    });

    test('parses pongs of v1 and v2 mods, with either prefix', () {
      expect(ModProtocol.parsePong('beamremoteplus|pong|20367|2', '20367'), 2);
      expect(ModProtocol.parsePong('beamngremoteplus|pong|20367|2', '20367'), 2);
      expect(ModProtocol.parsePong('beamngremoteplus|pong|20367|1', '20367'), 1);
      expect(ModProtocol.parsePong('beamngremoteplus|pong|20367', '20367'), 1);
    });

    test('ignores pongs for another code', () {
      expect(ModProtocol.parsePong('beamngremoteplus|pong|11111|2', '20367'), isNull);
      expect(ModProtocol.parsePong('beamngremoteplus|pong|203670|2', '20367'), isNull);
      expect(ModProtocol.parsePong('beamremote|pong|20367|2', '20367'), isNull);
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
      final host = DiscoveredHost.parseHello("beamremoteplus|hello|20367|Loka's PC", '192.168.1.10')!;
      expect(host.securityCode, '20367');
      expect(host.label, "Loka's PC");
      expect(host.hostAddress, '192.168.1.10');
    });

    test('defaults the label, accepts the legacy prefix', () {
      expect(DiscoveredHost.parseHello('beamngremoteplus|hello|1', 'x')!.label, DiscoveredHost.defaultLabel);
      expect(DiscoveredHost.parseHello('beamngremoteplus|hello|7|PC', 'x')!.securityCode, '7');
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

  group('point of view video', () {
    Uint8List datagram(int number, List<int> jpeg, {int part = 0, int parts = 1, int flags = 0}) {
      final b = BytesBuilder()
        ..add(PovFrame.magic)
        ..add((ByteData(4)..setUint32(0, number)).buffer.asUint8List())
        ..add([part, parts, flags])
        ..add(jpeg);
      return b.toBytes();
    }

    PovFrame? join(PovAssembler a, Uint8List data) => a.add(PovPart.parse(data)!);

    test('reads the frame number, the part and the flags', () {
      final p = PovPart.parse(datagram(258, [0xFF, 0xD8, 1], part: 1, parts: 2, flags: 1))!;
      expect(p.number, 258);
      expect([p.part, p.parts, p.flags], [1, 2, 1]);
      expect(p.data, [0xFF, 0xD8, 1]);
    });

    test('ignores anything else', () {
      expect(PovPart.parse(Uint8List.fromList('{"type":"telemetry"}'.codeUnits)), isNull);
      expect(PovPart.parse(datagram(1, [])), isNull);
      expect(PovPart.parse(datagram(1, [1], part: 2, parts: 2)), isNull);
    });

    test('joins the parts of a frame, in any order', () {
      final a = PovAssembler();
      expect(join(a, datagram(1, [3, 4], part: 1, parts: 2, flags: 1)), isNull);
      final f = join(a, datagram(1, [1, 2], part: 0, parts: 2, flags: 1))!;
      expect(f.number, 1);
      expect(f.jpeg, [1, 2, 3, 4]);
      expect(f.inside, isTrue);
      expect(join(a, datagram(2, [5]))!.inside, isFalse);
    });

    test('drops a frame missing a part when a newer one arrives, and late parts', () {
      final a = PovAssembler();
      expect(join(a, datagram(1, [1], parts: 2)), isNull);
      expect(join(a, datagram(2, [9]))!.number, 2);
      expect(join(a, datagram(1, [2], part: 1, parts: 2)), isNull);
      expect(join(a, datagram(2, [9])), isNull);
    });

    test('takes a much smaller number as a new video', () {
      final a = PovAssembler();
      expect(join(a, datagram(500, [1])), isNotNull);
      expect(join(a, datagram(1, [1]))!.number, 1);
    });
  });
}
