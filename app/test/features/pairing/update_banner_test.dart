import 'package:beam_remoteplus/core/settings/settings_store.dart';
import 'package:beam_remoteplus/core/version/update_controller.dart';
import 'package:beam_remoteplus/core/version/update_scope.dart';
import 'package:beam_remoteplus/features/pairing/widgets/update_banner.dart';
import 'package:beam_remoteplus/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Source implements ReleaseSource {
  @override
  Future<LatestRelease?> latest(String repository) async =>
      const LatestRelease(version: '0.0.5-0.39', url: 'https://example.org');
}

Future<void> _pump(WidgetTester tester, {UpdateController? updates}) async {
  const banner = MaterialApp(
    locale: Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Scaffold(body: UpdateBanner()),
  );
  await tester.pumpWidget(updates == null ? banner : UpdateScope(controller: updates, child: banner));
}

void main() {
  testWidgets('shows a newer release with its download link', (tester) async {
    final updates = UpdateController(source: _Source(), cache: MemorySettingsStore(), appVersion: '0.0.4');
    await updates.check();
    await _pump(tester, updates: updates);
    expect(find.text('Beam-RemotePlus 0.0.5-0.39 is available'), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);
  });

  testWidgets('nothing when up to date or without update information', (tester) async {
    final updates = UpdateController(source: _Source(), cache: MemorySettingsStore(), appVersion: '0.0.5');
    await updates.check();
    await _pump(tester, updates: updates);
    expect(find.byType(ListTile), findsNothing);
    await _pump(tester);
    expect(find.byType(ListTile), findsNothing);
  });
}
