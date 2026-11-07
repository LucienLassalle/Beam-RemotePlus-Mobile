import 'dart:async';

import 'package:beam_remoteplus/core/network/beamng_connection.dart';
import 'package:beam_remoteplus/core/network/remote_link.dart';
import 'package:beam_remoteplus/core/protocol/mod_protocol.dart';
import 'package:beam_remoteplus/core/protocol/native_protocol.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_network.dart';
import '../../helpers/fake_pov_player.dart';

const pc = '192.168.1.20';
const second = Duration(seconds: 1);

/// A connection in fake time, on a fake network, to a game at [pc].
class Harness {
  final FakeAsync async;
  final network = FakeNetwork();
  final player = FakePovPlayer();
  late final BeamngConnection connection;
  final states = <LinkState>[];
  Object? error;

  Harness(this.async, {Future<List<String>> Function()? broadcastTargets}) {
    final start = DateTime(2026, 11, 7);
    connection = BeamngConnection(
      povPlayer: player,
      bind: network.bind,
      findBroadcastTargets: broadcastTargets ?? () async => ['192.168.1.255'],
      deviceName: () async => 'Pixel',
      appVersion: () async => '1.0.0',
      now: () => start.add(async.elapsed),
    );
    connection.states.listen(states.add);
  }

  void connect({bool display = false}) {
    unawaited(connection.connect('12345', display: display).catchError((Object e) => error = e));
    async.elapse(const Duration(milliseconds: NativeProtocol.discoveryRetryMs));
  }

  /// The game answers the handshake.
  void gameAnswers() {
    network.endpoints[NativeProtocol.clientPort]!.receive('beamng|12345', from: pc, fromPort: NativeProtocol.hostPort);
    async.flushMicrotasks();
  }

  void fromMod(String text) {
    network.endpoints[ModProtocol.clientPort]!.receive(text, from: pc);
    async.flushMicrotasks();
  }

  /// Paired with the game, and its mod answered.
  void paired() {
    connect();
    gameAnswers();
    fromMod('beamremoteplus|pong|12345|2');
  }

  int packetsTo(int port, int size) => network.bytesTo(port).where((b) => b.length == size).length;
}

void main() {
  test('drives through the game at 20 Hz until the mod answers, then through the mod at 60 Hz', () {
    fakeAsync((async) {
      final h = Harness(async)
        ..connect()
        ..gameAnswers();
      expect(h.states, [LinkState.connecting, LinkState.connected]);
      h.network.sent.clear();
      async.elapse(second);
      expect(h.packetsTo(NativeProtocol.hostPort, 16), 20);

      h.fromMod('beamremoteplus|pong|12345|2');
      expect(h.connection.modActive, isTrue);
      h.network.sent.clear();
      async.elapse(second);
      expect(h.packetsTo(ModProtocol.hostPort, ModControlPacket.sizeBytes), closeTo(62, 1));
      expect(h.packetsTo(NativeProtocol.hostPort, 16), 0);
    });
  });

  test('sends the latest controls, clamped', () {
    fakeAsync((async) {
      final h = Harness(async)..paired();
      h.connection.updateControls(steering: 0.2, throttle: 1.4, brake: -1);
      h.network.sent.clear();
      async.elapse(const Duration(milliseconds: ModProtocol.controlIntervalMs));
      final packet = h.network.bytesTo(ModProtocol.hostPort).single;
      expect(packet, const ModControlPacket(steering: 0.2, throttle: 1, brake: 0).toBytes());
    });
  });

  test('says when no game answers', () {
    fakeAsync((async) {
      final h = Harness(async)..connect();
      async.elapse(second * 6);
      expect(h.error, isA<TimeoutException>());
      expect(h.states.last, LinkState.timeout);
    });
  });

  test('a second screen only talks to the mod, and never drives', () {
    fakeAsync((async) {
      final h = Harness(async)..connect(display: true);
      expect(h.network.sentTo(NativeProtocol.hostPort), isEmpty);
      h.fromMod('beamremoteplus|pong|12345|2');
      expect(h.states.last, LinkState.connected);
      h.network.sent.clear();
      async.elapse(second);
      expect(h.packetsTo(ModProtocol.hostPort, ModControlPacket.sizeBytes), 0);
      expect(h.network.sentTo(ModProtocol.hostPort), isNotEmpty, reason: 'keep-alive pings');
    });
  });

  test('leaving tells the mod, so it stops the car, and stops sending', () {
    fakeAsync((async) {
      final h = Harness(async)..paired();
      unawaited(h.connection.disconnect());
      async.flushMicrotasks();
      expect(h.network.sentTo(ModProtocol.hostPort).last, 'cmd|${ModCommand.leave}');
      expect(h.states.last, LinkState.idle);
      h.network.sent.clear();
      async.elapse(second * 5);
      expect(h.network.sent, isEmpty);
    });
  });

  test('kicked by the game: stops everything and says so', () {
    fakeAsync((async) {
      final h = Harness(async)..paired();
      h.fromMod('{"type":"kicked"}');
      expect(h.states.last, LinkState.kicked);
      h.network.sent.clear();
      async.elapse(second * 5);
      expect(h.network.sent, isEmpty);
    });
  });

  test('the point of view video is asked of the mod and played from the PC', () {
    fakeAsync((async) {
      final h = Harness(async)..paired();
      const format = PovFormat(PovQuality.hd60, 1424, 640);
      h.connection.setPovVideo(format);
      expect(h.network.sentTo(ModProtocol.hostPort).last, 'cmd|pov|${format.wire}');
      expect(h.player.calls, ['start $pc:${ModProtocol.povPort} 1424x640']);
      h.connection.setPovVideo(null);
      expect(h.network.sentTo(ModProtocol.hostPort).last, 'cmd|pov|0');
      expect(h.player.calls.last, 'stop');
    });
  });

  group('reconnection', () {
    test('the mod goes silent: reconnecting, the PC is looked for on the network, found at a new address', () {
      fakeAsync((async) {
        final h = Harness(async)..paired();
        async.elapse(ModProtocol.modSilenceTimeout + second);
        expect(h.states.last, LinkState.reconnecting);
        expect(h.connection.modActive, isFalse);
        h.network.sent.clear();
        async.elapse(second);
        expect(h.network.sent.where((s) => s.text.contains('|ping|')).map((s) => s.host.address).toSet(), {pc, '192.168.1.255'});
        expect(h.packetsTo(NativeProtocol.hostPort, 16), greaterThan(0), reason: 'the native channel drives meanwhile');

        h.network.endpoints[ModProtocol.clientPort]!.receive('beamremoteplus|pong|12345|2', from: '192.168.1.42');
        async.flushMicrotasks();
        expect(h.states.last, LinkState.connected);
        h.network.sent.clear();
        async.elapse(second);
        final controls = h.network.sent.where((s) => s.data.length == ModControlPacket.sizeBytes);
        expect(controls, isNotEmpty);
        expect(controls.map((s) => s.host.address).toSet(), {'192.168.1.42'});
        expect(h.network.sent.map((s) => s.host.address), isNot(contains('192.168.1.255')), reason: 'search over');
      });
    });

    test('the video follows the PC to its new address', () {
      fakeAsync((async) {
        final h = Harness(async)..paired();
        h.connection.setPovVideo(const PovFormat(PovQuality.hd60, 1424, 640));
        async.elapse(ModProtocol.modSilenceTimeout + second);
        h.network.endpoints[ModProtocol.clientPort]!.receive('beamremoteplus|pong|12345|2', from: '192.168.1.42');
        async.flushMicrotasks();
        expect(h.player.calls.sublist(1), ['stop', 'start 192.168.1.42:${ModProtocol.povPort} 1424x640']);
      });
    });

    test('reads the broadcast addresses again while it searches: the phone may have changed network', () {
      fakeAsync((async) {
        var reads = 0;
        Harness(async, broadcastTargets: () async {
          reads++;
          return ['192.168.1.255'];
        }).paired();
        final before = reads;
        async.elapse(ModProtocol.modSilenceTimeout + second);
        async.elapse(BeamngConnection.searchRefresh * 2);
        expect(reads - before, 3);
      });
    });

    test('without the mod there is nothing to lose: no search', () {
      fakeAsync((async) {
        final h = Harness(async)
          ..connect()
          ..gameAnswers();
        h.network.sent.clear(); // the handshake itself is broadcast
        async.elapse(second * 20);
        expect(h.states.last, LinkState.connected);
        expect(h.network.sent.map((s) => s.host.address), isNot(contains('192.168.1.255')));
      });
    });

    test('leaving stops the search', () {
      fakeAsync((async) {
        final h = Harness(async)..paired();
        async.elapse(ModProtocol.modSilenceTimeout + second);
        unawaited(h.connection.disconnect());
        async.flushMicrotasks();
        h.network.sent.clear();
        async.elapse(BeamngConnection.searchRefresh * 2);
        expect(h.network.sent, isEmpty);
        expect(h.states.last, LinkState.idle);
      });
    });
  });
}

