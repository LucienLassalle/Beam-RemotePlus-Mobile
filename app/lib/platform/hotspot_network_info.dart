import 'package:flutter/services.dart';

/// Contournement pour le mode point d'accès mobile (hotspot) : dans ce
/// mode, NetworkInfo().getWifiIP()/getWifiBroadcast() (network_info_plus)
/// renvoient null car ils s'appuient sur les infos de connexion WiFi côté
/// station (WifiManager.getConnectionInfo()), qui n'existent pas quand le
/// téléphone est lui-même le point d'accès. L'adresse existe pourtant bien
/// au niveau interface système ; ce canal la récupère côté natif Android en
/// énumérant les interfaces réseau (voir MainActivity.kt), et calcule ici
/// l'adresse de broadcast dirigée du sous-réseau (ex: 192.168.43.255),
/// nettement plus fiable en pratique que le broadcast global
/// 255.255.255.255 pour atteindre les clients du hotspot.
class HotspotNetworkInfo {
  static const _channel = MethodChannel(
    'com.beamngremoteplus.app/network_info',
  );

  /// Renvoie l'adresse de broadcast dirigée (ex: "192.168.43.255"), ou null
  /// si aucune interface plausible n'a été trouvée côté natif.
  static Future<String?> getLikelyHotspotBroadcast() async {
    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        'getLikelyHotspotAddress',
      );
      if (result == null) return null;
      final address = result['address'] as String?;
      final prefixLength = result['prefixLength'] as int?;
      if (address == null || prefixLength == null) return null;
      return _directedBroadcast(address, prefixLength);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  static String? _directedBroadcast(String address, int prefixLength) {
    if (prefixLength < 0 || prefixLength > 32) return null;
    final parts = address.split('.');
    if (parts.length != 4) return null;
    final octets = <int>[];
    for (final p in parts) {
      final v = int.tryParse(p);
      if (v == null || v < 0 || v > 255) return null;
      octets.add(v);
    }
    var addrInt = 0;
    for (final o in octets) {
      addrInt = (addrInt << 8) | o;
    }
    final hostBits = 32 - prefixLength;
    final broadcastInt = hostBits == 0
        ? addrInt
        : addrInt | ((1 << hostBits) - 1);
    return [
      (broadcastInt >> 24) & 0xFF,
      (broadcastInt >> 16) & 0xFF,
      (broadcastInt >> 8) & 0xFF,
      broadcastInt & 0xFF,
    ].join('.');
  }
}
