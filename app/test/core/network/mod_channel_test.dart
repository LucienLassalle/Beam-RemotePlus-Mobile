import 'dart:async';
import 'dart:io';

import 'package:beam_remoteplus/core/network/mod_channel.dart';
import 'package:beam_remoteplus/core/protocol/mod_message.dart';
import 'package:beam_remoteplus/core/protocol/mod_protocol.dart';
import 'package:beam_remoteplus/core/protocol/telemetry.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_network.dart';

const pc = '192.168.1.20';
const identity = ModIdentity(code: '12345', deviceName: 'Pixel', appVersion: '1.0.0');
const pingEvery = Duration(milliseconds: ModProtocol.pingRetryMs);
const keepAlive = Duration(milliseconds: ModProtocol.pingRetryMs * ModProtocol.keepAlivePingEvery);

String pong({String prefix = ModProtocol.prefix, int version = 2, String code = '12345'}) => '$prefix|pong|$code|$version';

/// A channel to the mod of [pc], opened in fake time.
class Harness {
  final FakeAsync async;
  final network = FakeNetwork();
  late final ModChannel channel;
  final start = DateTime(2026, 11, 7);

  Harness(this.async) {
    channel = ModChannel(network.bind, now: () => start.add(async.elapsed));
  }

  FakeEndpoint get endpoint => network.endpoints[ModProtocol.clientPort]!;

  void open() {
    unawaited(channel.open(InternetAddress(pc), identity));
    async.flushMicrotasks();
  }

  void fromMod(String text) {
    endpoint.receive(text, from: pc);
    async.flushMicrotasks();
  }

  /// Opened, and the mod answered.
  void paired() {
    open();
    fromMod(pong());
  }

  List<String> get pings => [for (final s in network.sentTo(ModProtocol.hostPort)) if (s.contains('|ping|')) s];
}

void main() {
  test('pings with both prefixes until the mod answers, then with the one of its answer', () {
    fakeAsync((async) {
      final h = Harness(async)..open();
      expect(h.pings, [
        'beamremoteplus|ping|12345|2|Pixel|controller|1.0.0',
        'beamngremoteplus|ping|12345|2|Pixel|controller|1.0.0',
      ]);
      h.fromMod(pong(prefix: ModProtocol.legacyPrefix));
      expect(h.channel.active, isTrue);
      expect(h.channel.protocolVersion, 2);
      h.network.sent.clear();
      async.elapse(keepAlive);
      expect(h.pings, ['beamngremoteplus|ping|12345|2|Pixel|controller|1.0.0']);
    });
  });

  test('pings every 500 ms while the mod is not there, every 2 s once it answers', () {
    fakeAsync((async) {
      final h = Harness(async)..open();
      h.network.sent.clear();
      async.elapse(keepAlive);
      expect(h.pings, hasLength(4 * 2), reason: 'both prefixes, 4 times');
      h.fromMod(pong());
      h.network.sent.clear();
      async.elapse(keepAlive);
      expect(h.pings, hasLength(1));
    });
  });

  test('ignores the pong of another pairing code', () {
    fakeAsync((async) {
      final h = Harness(async)..open();
      h.fromMod(pong(code: '99999'));
      expect(h.channel.active, isFalse);
    });
  });

  test('measures the round trip of the keep-alive pings', () {
    fakeAsync((async) {
      final h = Harness(async)..paired();
      expect(h.channel.latencyMs, isNull, reason: 'the first ping was sent before the mod answered');
      final changes = <void>[];
      h.channel.qualityChanges.listen(changes.add);
      async.elapse(keepAlive);
      async.elapse(const Duration(milliseconds: 23));
      h.fromMod(pong());
      expect(h.channel.latencyMs, 23);
      expect(changes, hasLength(1));
    });
  });

  test('tells the signal is lost after 3 s of silence, and back with the next message', () {
    fakeAsync((async) {
      final h = Harness(async)..paired();
      async.elapse(ModProtocol.signalLostAfter);
      expect(h.channel.signalLost, isFalse, reason: 'not more than 3 s yet');
      async.elapse(pingEvery);
      expect(h.channel.signalLost, isTrue);
      h.fromMod('{"type":"telemetry","speed":1}');
      expect(h.channel.signalLost, isFalse);
    });
  });

  test('falls back to the native channel when the mod goes silent, and probes both prefixes again', () {
    fakeAsync((async) {
      final h = Harness(async)..open();
      h.fromMod(pong(prefix: ModProtocol.legacyPrefix));
      final changes = <bool>[];
      h.channel.activeChanges.listen(changes.add);
      async.elapse(ModProtocol.modSilenceTimeout + pingEvery);
      expect(h.channel.active, isFalse);
      expect(h.channel.protocolVersion, 0);
      expect(changes, [false]);
      h.network.sent.clear();
      async.elapse(pingEvery);
      expect(h.pings.map(ModProtocol.prefixOf), [ModProtocol.prefix, ModProtocol.legacyPrefix]);
    });
  });

  test('a mod that comes back is active again', () {
    fakeAsync((async) {
      final h = Harness(async)..paired();
      async.elapse(ModProtocol.modSilenceTimeout + pingEvery);
      h.fromMod(pong());
      expect(h.channel.active, isTrue);
      expect(h.channel.signalLost, isFalse);
    });
  });

  test('forwards telemetry and events only once the mod answered', () {
    fakeAsync((async) {
      final h = Harness(async);
      final telemetry = <Telemetry>[];
      final events = <ModMessage>[];
      h.channel.telemetry.listen(telemetry.add);
      h.channel.events.listen(events.add);
      h.open();
      h.fromMod('{"type":"telemetry","speed":10}');
      expect(telemetry, isEmpty);
      h.fromMod(pong());
      h.fromMod('{"type":"telemetry","speed":10}');
      h.fromMod('{"type":"ack","cmd":"horn|1","ok":false,"error":"no_vehicle"}');
      expect(telemetry.single.speed, 10);
      expect(events.single, isA<AckMessage>().having((a) => a.error, 'error', 'no_vehicle'));
    });
  });

  test('a malformed frame never breaks the channel', () {
    fakeAsync((async) {
      final h = Harness(async)..paired();
      final telemetry = <Telemetry>[];
      h.channel.telemetry.listen(telemetry.add);
      h.fromMod('{"type":"telemetry","speed":');
      h.fromMod('{"type":"telemetry","speed":12}');
      expect(telemetry.single.speed, 12);
    });
  });

  test('kicked: tells, and stops pinging so the phone is not paired again', () {
    fakeAsync((async) {
      final h = Harness(async)..paired();
      var kicked = 0;
      h.channel.onKicked = () => kicked++;
      h.fromMod('{"type":"kicked"}');
      expect(kicked, 1);
      expect(h.channel.active, isFalse);
      expect(h.endpoint.closed, isTrue);
      h.network.sent.clear();
      async.elapse(const Duration(seconds: 10));
      expect(h.network.sent, isEmpty);
    });
  });

  test('commands only reach a mod that answers', () {
    fakeAsync((async) {
      final h = Harness(async)..open();
      h.channel.sendCommand(ModCommand.horn, '1');
      h.fromMod(pong());
      h.channel.sendCommand(ModCommand.horn, '1');
      expect(h.network.sentTo(ModProtocol.hostPort).where((s) => s.startsWith('cmd|')), ['cmd|horn|1']);
    });
  });

  test('asks for the debug acks as soon as the mod answers, when they are on', () {
    fakeAsync((async) {
      final h = Harness(async);
      h.channel.debugAcks = true;
      h.paired();
      expect(h.network.sentTo(ModProtocol.hostPort), contains('cmd|debug|1'));
    });
  });

  test('a phone whose port is taken stays on the native channel', () {
    fakeAsync((async) {
      final h = Harness(async);
      h.network.busyPorts.add(ModProtocol.clientPort);
      h.open();
      async.elapse(keepAlive);
      expect(h.channel.active, isFalse);
      expect(h.network.sent, isEmpty);
    });
  });

  group('search', () {
    test('also pings the broadcast addresses until the mod answers', () {
      fakeAsync((async) {
        final h = Harness(async)..open();
        h.channel.search(['192.168.1.255', 'not an address']);
        h.network.sent.clear();
        async.elapse(pingEvery);
        expect(h.network.sent.map((s) => s.host.address).toSet(), {pc, '192.168.1.255'});
        h.fromMod(pong());
        expect(h.channel.searching, isFalse);
        h.network.sent.clear();
        async.elapse(keepAlive);
        expect(h.network.sent.map((s) => s.host.address).toSet(), {pc});
      });
    });

    test('follows the PC to its new address', () {
      fakeAsync((async) {
        final h = Harness(async)..paired();
        async.elapse(ModProtocol.modSilenceTimeout + pingEvery);
        InternetAddress? moved;
        h.channel.onHostChanged = (host) => moved = host;
        h.channel.search(['192.168.1.255']);
        h.endpoint.receive(pong(), from: '192.168.1.42');
        async.flushMicrotasks();
        expect(moved?.address, '192.168.1.42');
        expect(h.channel.active, isTrue);
        h.network.sent.clear();
        h.channel.sendCommand(ModCommand.horn, '1');
        expect(h.network.sent.single.host.address, '192.168.1.42');
      });
    });

    test('is ignored while the mod answers', () {
      fakeAsync((async) {
        final h = Harness(async)..paired();
        h.channel.search(['192.168.1.255']);
        expect(h.channel.searching, isFalse);
        h.endpoint.receive(pong(), from: '192.168.1.42');
        async.flushMicrotasks();
        h.network.sent.clear();
        h.channel.sendCommand(ModCommand.horn, '1');
        expect(h.network.sent.single.host.address, pc, reason: 'no search, no move');
      });
    });
  });

  group('second screen', () {
    const display = ModIdentity(code: '12345', deviceName: 'Tab', display: true, appVersion: '1.0.0');

    test('finds the PC whose mod answers, then keeps the session', () {
      fakeAsync((async) {
        final h = Harness(async);
        InternetAddress? found;
        unawaited(h.channel.find(display, ['192.168.1.255']).then((a) => found = a));
        async.elapse(const Duration(milliseconds: 250));
        expect(h.network.sent.first.host.address, '192.168.1.255');
        expect(h.network.sent.first.text, 'beamremoteplus|ping|12345|2|Tab|display|1.0.0');
        h.fromMod(pong());
        expect(found?.address, pc);
        expect(h.channel.active, isFalse, reason: 'the first pong only finds the PC');
        async.elapse(keepAlive);
        h.fromMod(pong());
        expect(h.channel.active, isTrue);
      });
    });

    test('gives up when no mod answers', () {
      fakeAsync((async) {
        final h = Harness(async);
        Object? error;
        unawaited(h.channel.find(display, ['192.168.1.255']).catchError((Object e) {
          error = e;
          return InternetAddress.anyIPv4;
        }));
        async.elapse(const Duration(seconds: 7));
        expect(error, isA<TimeoutException>());
      });
    });
  });
}
