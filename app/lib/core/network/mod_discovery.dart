import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../debug/debug_log.dart';
import '../protocol/mod_protocol.dart';
import 'broadcast.dart';

/// Automatic discovery: broadcasts `beamngremoteplus|discover` and waits for
/// the mod's `hello|<code>|<label>`. No QR code, no camera; needs the mod.
class ModDiscovery {
  ModDiscovery._();

  static Future<DiscoveredHost?> discover({
    Duration timeout = const Duration(milliseconds: ModProtocol.discoverTimeoutMs),
  }) async {
    RawDatagramSocket? receiver;
    RawDatagramSocket? sender;
    Timer? retry;
    final found = Completer<DiscoveredHost?>();
    try {
      final targets = await broadcastTargets();
      receiver = await RawDatagramSocket.bind(InternetAddress.anyIPv4, ModProtocol.clientPort, reuseAddress: true);
      sender = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0)..broadcastEnabled = true;

      final socket = receiver;
      socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final dg = socket.receive();
        if (dg == null || found.isCompleted) return;
        final host = DiscoveredHost.parseHello(utf8.decode(dg.data, allowMalformed: true), dg.address.address);
        if (host == null) return;
        DebugLog.log('discovery: ${host.label} at ${host.hostAddress}');
        found.complete(host);
      });

      final payload = utf8.encode(ModProtocol.discoverMessage);
      final out = sender;
      void sweep() {
        for (final target in targets) {
          try {
            out.send(payload, InternetAddress(target), ModProtocol.hostPort);
          } catch (e) {
            DebugLog.log('discovery: send to $target failed ($e)');
          }
        }
      }

      sweep();
      retry = Timer.periodic(const Duration(milliseconds: ModProtocol.discoverRetryMs), (_) => sweep());
      return await found.future.timeout(timeout, onTimeout: () => null);
    } catch (e) {
      DebugLog.log('discovery failed ($e)');
      return null;
    } finally {
      retry?.cancel();
      sender?.close();
      receiver?.close();
    }
  }
}
