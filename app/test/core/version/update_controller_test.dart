import 'package:beam_remoteplus/core/settings/settings_store.dart';
import 'package:beam_remoteplus/core/version/update_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSource implements ReleaseSource {
  final Map<String, LatestRelease?> releases;
  _FakeSource(this.releases);

  @override
  Future<LatestRelease?> latest(String repository) async => releases[repository];
}

const _app5 = LatestRelease(version: '0.0.5-0.39', url: 'https://example.org/app');
const _mod5 = LatestRelease(version: '0.0.5-0.39', url: 'https://example.org/mod');

UpdateController _controller(Map<String, LatestRelease?> releases, {MemorySettingsStore? cache, String? app = '0.0.4-0.39'}) =>
    UpdateController(source: _FakeSource(releases), cache: cache ?? MemorySettingsStore(), appVersion: app);

void main() {
  group('LatestRelease.fromGitHubJson', () {
    test('keeps the tag without its v and the release page', () {
      final r = LatestRelease.fromGitHubJson({'tag_name': 'v0.0.5-0.39', 'html_url': 'https://github.com/x/y/releases/tag/v0.0.5-0.39'});
      expect(r?.version, '0.0.5-0.39');
      expect(r?.url, 'https://github.com/x/y/releases/tag/v0.0.5-0.39');
    });

    test('ignores answers that are not a release', () {
      expect(LatestRelease.fromGitHubJson({'message': 'Not Found'}), isNull);
      expect(LatestRelease.fromGitHubJson({'tag_name': 'PoC', 'html_url': 'u'}), isNull);
      expect(LatestRelease.fromGitHubJson([]), isNull);
    });
  });

  group('UpdateController', () {
    test('offers a newer app and a newer mod', () async {
      final c = _controller({UpdateController.appRepository: _app5, UpdateController.modRepository: _mod5});
      await c.check();
      expect(c.appUpdate?.url, _app5.url);
      expect(c.modUpdate('0.0.4-0.39')?.url, _mod5.url);
      expect(c.modUpdate('0.0.5'), isNull);
    });

    test('says nothing for an up-to-date app or an unknown version', () async {
      final upToDate = _controller({UpdateController.appRepository: _app5}, app: '0.0.5-0.39');
      await upToDate.check();
      expect(upToDate.appUpdate, isNull);
      final unknown = _controller({UpdateController.appRepository: _app5, UpdateController.modRepository: _mod5}, app: null);
      await unknown.check();
      expect(unknown.appUpdate, isNull);
      expect(unknown.modUpdate(null), isNull);
    });

    test('remembers the releases for the next launch without internet', () async {
      final cache = MemorySettingsStore();
      await _controller({UpdateController.appRepository: _app5, UpdateController.modRepository: _mod5}, cache: cache).check();
      final offline = _controller({}, cache: cache);
      await offline.load();
      await offline.check();
      expect(offline.appUpdate?.version, '0.0.5-0.39');
      expect(offline.latestMod?.version, '0.0.5-0.39');
    });

    test('keeps the cached release of a repository that cannot be reached', () async {
      final cache = MemorySettingsStore();
      await _controller({UpdateController.appRepository: _app5, UpdateController.modRepository: _mod5}, cache: cache).check();
      const app6 = LatestRelease(version: '0.0.6', url: 'u6');
      final c = _controller({UpdateController.appRepository: app6}, cache: cache);
      await c.load();
      await c.check();
      expect(c.latestApp?.version, '0.0.6');
      expect(c.latestMod?.version, '0.0.5-0.39');
    });
  });
}
