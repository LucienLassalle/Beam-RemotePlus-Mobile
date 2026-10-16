import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../debug/debug_log.dart';
import '../settings/settings_store.dart';
import 'release_version.dart';

/// Latest published release of a repository.
class LatestRelease {
  /// Release tag without the leading "v" (`0.0.5-0.39`).
  final String version;

  /// Release page, where the APK / mod zip can be downloaded.
  final String url;

  const LatestRelease({required this.version, required this.url});

  /// GitHub "latest release" answer; null when it is not usable.
  static LatestRelease? fromGitHubJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final tag = json['tag_name'], url = json['html_url'];
    if (tag is! String || url is! String || ReleaseVersion.tryParse(tag) == null) return null;
    return LatestRelease(version: tag.startsWith('v') ? tag.substring(1) : tag, url: url);
  }

  static LatestRelease? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final version = json['version'], url = json['url'];
    return version is String && url is String ? LatestRelease(version: version, url: url) : null;
  }

  Map<String, Object?> toJson() => {'version': version, 'url': url};
}

/// Where the latest releases come from (abstract so tests stay offline).
abstract class ReleaseSource {
  /// Latest release of `owner/name`, null when it cannot be known now.
  Future<LatestRelease?> latest(String repository);
}

/// GitHub REST API, no account needed (60 requests per hour per IP, the app
/// makes two per launch).
class GitHubReleaseSource implements ReleaseSource {
  static const timeout = Duration(seconds: 5);

  @override
  Future<LatestRelease?> latest(String repository) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.getUrl(Uri.https('api.github.com', '/repos/$repository/releases/latest'));
      request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      final response = await request.close().timeout(timeout);
      if (response.statusCode != HttpStatus.ok) {
        DebugLog.log('update check: $repository answered ${response.statusCode}');
        return null;
      }
      final body = await response.transform(utf8.decoder).join().timeout(timeout);
      return LatestRelease.fromGitHubJson(jsonDecode(body));
    } catch (e) {
      // Offline, or on the PC's Wi-Fi without internet: the cached
      // releases of the last successful check stay in use.
      DebugLog.log('update check: $repository unreachable ($e)');
      return null;
    } finally {
      client.close(force: true);
    }
  }
}

/// Latest releases of the app and of the mod, checked on GitHub when the
/// app starts. The last known ones are cached, so a phone without internet
/// (on the PC's network) still knows about the releases it saw before.
class UpdateController extends ChangeNotifier {
  static const appRepository = 'LucienLassalle/Beam-RemotePlus-Mobile';
  static const modRepository = 'LucienLassalle/Beam-RemotePlus-Mod';

  final ReleaseSource _source;
  final SettingsStore _cache;

  /// Version of this build (see resolveAppVersion), null when unknown.
  final String? appVersion;

  LatestRelease? _app;
  LatestRelease? _mod;

  UpdateController({required ReleaseSource source, required SettingsStore cache, required this.appVersion})
      : _source = source,
        _cache = cache;

  LatestRelease? get latestApp => _app;
  LatestRelease? get latestMod => _mod;

  /// A newer app than this one was released (never when the version of this
  /// one is unknown).
  LatestRelease? get appUpdate => ReleaseVersion.isNewer(_app?.version, appVersion) ? _app : null;

  /// A newer mod than [modVersion] (as sent by the mod) was released.
  LatestRelease? modUpdate(String? modVersion) => ReleaseVersion.isNewer(_mod?.version, modVersion) ? _mod : null;

  /// Reads the releases cached by the last successful check.
  Future<void> load() async {
    final json = await _cache.load();
    _app = LatestRelease.fromJson(json['app']);
    _mod = LatestRelease.fromJson(json['mod']);
    notifyListeners();
  }

  /// Asks GitHub; what cannot be fetched keeps its cached value.
  Future<void> check() async {
    final results = await Future.wait([_source.latest(appRepository), _source.latest(modRepository)]);
    final app = results[0], mod = results[1];
    if (app == null && mod == null) return;
    _app = app ?? _app;
    _mod = mod ?? _mod;
    notifyListeners();
    await _cache.save({'app': _app?.toJson(), 'mod': _mod?.toJson()});
  }
}
