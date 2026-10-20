import 'dart:convert';
import 'dart:typed_data';

import 'package:beam_remoteplus/core/protocol/mod_message.dart';
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
    test('qualities the mod knows', () {
      expect([for (final q in PovQuality.values) q.wire], ['720p60', '1080p30', '1080p60']);
      expect(PovQuality.fullHd30.width, 1920);
    });

    test('a 16:9 screen gets the 16:9 picture of the quality', () {
      expect(PovFormat.forScreen(PovQuality.hd60, 16 / 9), const PovFormat(PovQuality.hd60, 1280, 720));
      expect(PovFormat.forScreen(PovQuality.fullHd60, 16 / 9), const PovFormat(PovQuality.fullHd60, 1920, 1080));
    });

    test('other screens get their shape, with at most the pixels of the quality', () {
      for (final quality in PovQuality.values) {
        for (final aspect in [1.0, 4 / 3, 16 / 10, 2176 / 1812, 20 / 9, 21 / 9, 2.5]) {
          final f = PovFormat.forScreen(quality, aspect);
          expect(f.width * f.height, lessThanOrEqualTo(quality.width * quality.height));
          expect(f.width % PovFormat.sizeStep + f.height % PovFormat.sizeStep, 0);
          expect(f.width / f.height, closeTo(aspect, 0.02));
        }
      }
      expect(PovFormat.forScreen(PovQuality.hd60, 20 / 9).wire, '720p60|1424x640');
    });

    test('screens out of the usual shapes are cropped', () {
      expect(PovFormat.forScreen(PovQuality.hd60, 0.5), PovFormat.forScreen(PovQuality.hd60, PovFormat.minAspect));
      expect(PovFormat.forScreen(PovQuality.hd60, 4), PovFormat.forScreen(PovQuality.hd60, PovFormat.maxAspect));
      expect(PovFormat.forScreen(PovQuality.hd60, double.nan), const PovFormat(PovQuality.hd60, 1280, 720));
    });

    test('reads the state of the video', () {
      ModMessage? decode(String json) => ModMessage.decode(Uint8List.fromList(utf8.encode(json)), 2);
      final live = decode('{"type":"pov","state":"live","inside":true,"quality":"720p60"}')! as PovMessage;
      expect(live.state, PovMessage.live);
      expect(live.inside, isTrue);
      final failed = decode('{"type":"pov","state":"error","error":"encoder"}')! as PovMessage;
      expect(failed.state, PovMessage.failed);
      expect(failed.error, PovMessage.errorEncoder);
      expect(failed.inside, isFalse);
    });
  });
}
