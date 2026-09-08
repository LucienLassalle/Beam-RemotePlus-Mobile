import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';

import '../debug/app_debug.dart';
import '../platform/hotspot_network_info.dart';
import 'protocol_constants.dart';

/// Résultat d'une découverte automatique : le PC a répondu avec son code
/// d'appairage et un nom lisible.
class ModDiscoveryResult {
  final String securityCode;
  final String hostAddress;
  final String label;

  const ModDiscoveryResult({
    required this.securityCode,
    required this.hostAddress,
    required this.label,
  });
}

/// Découverte automatique de BeamNG.drive + mod Beam-RemotePlus sur le
/// réseau local, sans QR code ni caméra.
///
/// L'app diffuse `beamngremoteplus|discover` sur le port 4446 ; le mod
/// répond `beamngremoteplus|hello|<code>|<label>` sur le port 4447. C'est le
/// remplacement du scan du QR code natif de BeamNG, dont l'UI cassée depuis
/// la 0.39 n'affiche plus rien de scannable de façon fiable.
///
/// Nécessite que le mod soit installé et actif : sans lui, personne ne
/// répond et l'app retombe sur le scan QR ou la saisie manuelle.
class ModDiscovery {
  const ModDiscovery._();

  /// Parse `beamngremoteplus|hello|<code>|<label...>`. Le label peut
  /// contenir des espaces (jamais de `|`, retiré côté mod). Renvoie null si
  /// le message n'est pas un hello valide.
  @visibleForTesting
  static ModDiscoveryResult? parseHello(String msg, String hostAddress) {
    if (!msg.startsWith(ModProtocol.helloPrefix)) return null;
    final rest = msg.substring(ModProtocol.helloPrefix.length);
    final sep = rest.indexOf('|');
    final code = sep >= 0 ? rest.substring(0, sep) : rest;
    final label = sep >= 0 ? rest.substring(sep + 1) : 'BeamNG.drive';
    if (code.isEmpty) return null;
    return ModDiscoveryResult(
      securityCode: code,
      hostAddress: hostAddress,
      label: label.isEmpty ? 'BeamNG.drive' : label,
    );
  }

  static Future<ModDiscoveryResult?> discover({
    Duration timeout = const Duration(
      milliseconds: ModProtocol.discoverTimeoutMs,
    ),
  }) async {
    final info = NetworkInfo();
    final broadcastIp = await info.getWifiBroadcast() ?? '255.255.255.255';
    final extraBroadcastIp =
        await HotspotNetworkInfo.getLikelyHotspotBroadcast();
    final targets = <String>{
      broadcastIp,
      if (extraBroadcastIp != null) extraBroadcastIp,
      '255.255.255.255',
    }.toList();

    RawDatagramSocket? recvSocket;
    RawDatagramSocket? sendSocket;
    Timer? retryTimer;
    final completer = Completer<ModDiscoveryResult?>();

    try {
      recvSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        ModProtocol.clientPort,
        reuseAddress: true,
      );
      sendSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      sendSocket.broadcastEnabled = true;

      recvSocket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final dg = recvSocket!.receive();
        if (dg == null) return;
        final msg = utf8.decode(dg.data, allowMalformed: true);
        final result = parseHello(msg, dg.address.address);
        if (result == null) return;

        AppDebug.log(
          'ModDiscovery: hello de ${result.hostAddress} '
          'code=${result.securityCode} label=${result.label}',
        );
        if (!completer.isCompleted) completer.complete(result);
      });

      final payload = utf8.encode(ModProtocol.discoverMessage);
      void sweep() {
        for (final target in targets) {
          try {
            sendSocket!.send(
              payload,
              InternetAddress(target),
              ModProtocol.hostPort,
            );
          } catch (e) {
            AppDebug.log('ModDiscovery: envoi vers $target échoué ($e)');
          }
        }
      }

      sweep();
      retryTimer = Timer.periodic(
        const Duration(milliseconds: ModProtocol.discoverRetryMs),
        (_) => sweep(),
      );

      return await completer.future.timeout(timeout, onTimeout: () => null);
    } catch (e) {
      AppDebug.log('ModDiscovery: échec ($e)');
      return null;
    } finally {
      retryTimer?.cancel();
      sendSocket?.close();
      recvSocket?.close();
    }
  }
}
