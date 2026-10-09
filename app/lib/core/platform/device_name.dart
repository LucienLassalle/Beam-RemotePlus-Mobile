import 'package:device_info_plus/device_info_plus.dart';

/// Human readable phone name ("Samsung Galaxy Z Fold5"), sent while pairing
/// so each player recognises their phone in game (local multiplayer).
Future<String> resolveDeviceName() async {
  try {
    final info = await DeviceInfoPlugin().androidInfo;
    return formatDeviceName(info.manufacturer, info.model);
  } catch (_) {
    return 'Beam-RemotePlus';
  }
}

String formatDeviceName(String manufacturer, String model) {
  String capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
  if (model.toLowerCase().startsWith(manufacturer.toLowerCase())) return capitalize(model);
  return '${capitalize(manufacturer)} $model'.trim();
}
