import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:beam_remoteplus/core/network/native_channel.dart';
import 'package:beam_remoteplus/core/protocol/native_protocol.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_network.dart';

const pc = '192.168.1.20';
const retry = Duration(milliseconds: NativeProtocol.discoveryRetryMs);

void main() {
  test('sends the handshake to every target and pairs with the game that answers with the code', () {
    fakeAsync((async) {
      final network = FakeNetwork();
      final channel = NativeChannel(network.bind);
      InternetAddress? host;
      unawaited(channel.pair('12345', 'Pixel', ['192.168.1.255', '255.255.255.255']).then((h) => host = h));
      async.elapse(retry);
      expect(network.sent.map((s) => '${s.host.address}:${s.port} ${s.text}'), [
        '192.168.1.255:4444 beamng|Pixel|12345',
        '255.255.255.255:4444 beamng|Pixel|12345',
      ]);
      final handshake = network.endpoints[NativeProtocol.clientPort]!;
      handshake.receive('beamng|99999', from: '192.168.1.66', fromPort: 4444);
      async.flushMicrotasks();
      expect(host, isNull, reason: 'another game, another code');
      handshake.receive('beamng|12345', from: pc, fromPort: 4444);
      async.flushMicrotasks();
      expect(host?.address, pc);
      expect(handshake.closed, isTrue, reason: 'nothing more comes on the handshake port');
    });
  });

  test('gives up when no game answers', () {
    fakeAsync((async) {
      final network = FakeNetwork();
      Object? error;
      unawaited(NativeChannel(network.bind).pair('12345', 'Pixel', ['192.168.1.255']).catchError((Object e) {
        error = e;
        return InternetAddress.anyIPv4;
      }));
      async.elapse(retry * (NativeProtocol.discoveryMaxRetries + 2));
      expect(error, isA<TimeoutException>());
      expect(network.sent, hasLength(NativeProtocol.discoveryMaxRetries));
      expect(network.endpoints[NativeProtocol.clientPort]!.closed, isTrue);
    });
  });

  test('sends the controls to the paired game only, numbered like the official app (0..127)', () {
    fakeAsync((async) {
      final network = FakeNetwork();
      final channel = NativeChannel(network.bind)..sendControls(steering: 0.5, throttle: 1, brake: 0);
      expect(network.sent, isEmpty);
      unawaited(channel.pair('12345', 'Pixel', [pc]));
      async.elapse(retry);
      network.endpoints[NativeProtocol.clientPort]!.receive('beamng|12345', from: pc, fromPort: 4444);
      async.flushMicrotasks();
      network.sent.clear();
      for (var i = 0; i < 130; i++) {
        channel.sendControls(steering: 0.25, throttle: 1, brake: 0);
      }
      final packets = network.bytesTo(NativeProtocol.hostPort).map((b) => ByteData.sublistView(Uint8List.fromList(b))).toList();
      expect(packets, hasLength(130));
      expect(packets.first.getFloat32(0), 0.25);
      expect([for (final p in packets.sublist(126, 130)) p.getFloat32(12)], [126, 127, 0, 1]);
    });
  });

  test('sends through a new socket once the system closed the old one', () {
    fakeAsync((async) {
      final network = FakeNetwork();
      final channel = NativeChannel(network.bind);
      unawaited(channel.pair('12345', 'Pixel', [pc]));
      async.elapse(retry);
      network.endpoints[NativeProtocol.clientPort]!.receive('beamng|12345', from: pc, fromPort: 4444);
      async.flushMicrotasks();
      network.offline = true;
      channel.sendControls(steering: 0.5, throttle: 0, brake: 0);
      network.offline = false;
      channel.sendControls(steering: 0.5, throttle: 0, brake: 0); // notices, binds a new one soon
      async.elapse(NativeChannel.reopenDelay);
      network.sent.clear();
      channel.sendControls(steering: 0.5, throttle: 1, brake: 0);
      expect(network.bytesTo(NativeProtocol.hostPort), hasLength(1));
    });
  });
}

