import 'package:network_info_plus/network_info_plus.dart';

import '../platform/hotspot_network_info.dart';

/// Directed broadcast address of an IPv4 subnet, e.g. 192.168.1.20/24 ->
/// 192.168.1.255. Returns null for malformed input.
String? directedBroadcast(String address, int prefixLength) {
  if (prefixLength < 0 || prefixLength > 32) return null;
  final parts = address.split('.');
  if (parts.length != 4) return null;
  var value = 0;
  for (final part in parts) {
    final octet = int.tryParse(part);
    if (octet == null || octet < 0 || octet > 255) return null;
    value = (value << 8) | octet;
  }
  final hostBits = 32 - prefixLength;
  final broadcast = hostBits == 0 ? value : value | ((1 << hostBits) - 1);
  return [24, 16, 8, 0].map((shift) => (broadcast >> shift) & 0xFF).join('.');
}

/// Every address worth broadcasting discovery/handshake packets to: the
/// Wi-Fi broadcast, the hotspot interface broadcast (phone as access point)
/// and the global broadcast as a last resort.
Future<List<String>> broadcastTargets() async {
  // Some Android versions prefix the address with '/'.
  final wifi = (await NetworkInfo().getWifiBroadcast())?.replaceFirst('/', '');
  final hotspot = await HotspotNetworkInfo.getLikelyHotspotBroadcast();
  return <String>{
    if (wifi != null) wifi,
    if (hotspot != null) hotspot,
    '255.255.255.255',
  }.toList();
}
