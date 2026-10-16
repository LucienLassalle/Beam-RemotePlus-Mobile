import 'package:package_info_plus/package_info_plus.dart';

/// Version of this build, as given to the build (`--build-name`, e.g.
/// `0.0.5-0.39`); null if Android cannot tell it.
Future<String?> resolveAppVersion() async {
  try {
    return (await PackageInfo.fromPlatform()).version;
  } catch (_) {
    return null;
  }
}
