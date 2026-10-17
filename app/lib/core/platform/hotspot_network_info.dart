import 'package:flutter/services.dart';

import '../network/broadcast.dart';

/// When the phone is itself the Wi-Fi hotspot, network_info_plus returns
/// null (it only knows the station-side connection). The native side
/// (MainActivity.kt) enumerates the network interfaces instead; this returns
/// the directed broadcast address of that interface (e.g. 192.168.43.255).
class HotspotNetworkInfo {
  HotspotNetworkInfo._();

  static const _channel = MethodChannel('com.beamremoteplus.app/network_info');

  /// Directed broadcast addresses of the USB tethering interfaces (phone
  /// sharing its connection with the PC over the cable), empty without.
  static Future<List<String>> getUsbTetheringBroadcasts() async {
    try {
      final result = await _channel.invokeListMethod<Object?>('getUsbTetheringAddresses');
      return [
        for (final entry in result ?? const <Object?>[])
          if (entry is Map && entry['address'] is String && entry['prefixLength'] is int)
            if (directedBroadcast(entry['address'] as String, entry['prefixLength'] as int) case final b?) b,
      ];
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }

  static Future<String?> getLikelyHotspotBroadcast() async {
    try {
      final result = await _channel.invokeMapMethod<String, Object?>('getLikelyHotspotAddress');
      final address = result?['address'];
      final prefixLength = result?['prefixLength'];
      if (address is! String || prefixLength is! int) return null;
      return directedBroadcast(address, prefixLength);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
