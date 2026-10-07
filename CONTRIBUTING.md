# Contributing

Issues and pull requests are welcome in **English or French**. New themes and
translations are especially welcome: see [THEMES.md](THEMES.md) and
[TRANSLATING.md](TRANSLATING.md).

## Ground rules

- **Sign off every commit** (`git commit -s`, [DCO 1.1](https://developercertificate.org)):
  you certify you wrote the change or have the right to submit it under the
  project license. The `DCO` check blocks unsigned commits; fix them with
  `git rebase --signoff master`.
- **Conventional Commits**: `feat(themes): add the Bolide theme`, `fix(pairing): ...`.
- **Code and comments in English**, user-facing texts in the `.arb` files.
- **Tests**: `scripts/flutter.sh analyze` and `scripts/flutter.sh test` must pass.
- License: **CC BY-NC-SA 4.0**; contributions are accepted under the same license.

## Development setup

Only [Podman](https://podman.io) is needed: Flutter and the Android SDK run in
`docker/Containerfile`.

```bash
scripts/flutter.sh test          # unit + widget tests
scripts/flutter.sh analyze       # lints
scripts/flutter.sh screenshots   # theme previews in app/test/screenshots/goldens/
scripts/build_apk.sh 2.1.0       # release APKs in dist/
adb install -r dist/BeamNG-RemotePlus-2.1.0-arm64-v8a.apk
```

## Architecture

```
app/lib/
  main.dart, app.dart        bootstrap, localization, settings scope
  core/                      no UI
    protocol/                wire formats (pure Dart, unit-tested)
    network/                 sockets: BeamngConnection, discovery
    settings/                AppSettings (model), SettingsController, store
    platform/                Android channels (volume keys, gestures, hotspot)
    debug/                   DebugMonitor (debug overlay data)
  features/                  one folder per screen: *_controller.dart (logic,
    pairing/                 ChangeNotifier, unit-tested) + *_screen.dart /
    driving/                 *_view.dart (widgets) + widgets/
    settings/ help/ debug/
  themes/                    dashboards (see THEMES.md)
  l10n/                      translations (see TRANSLATING.md)
```

Rules of thumb: logic in controllers or pure classes (testable without
Flutter widgets), widgets stay dumb, files under ~250 lines, platform access
behind a small class that tests can replace.

The wire protocol is specified in the mod repository:
[docs/PROTOCOL.md](https://github.com/LucienLassalle/Beam-RemotePlus-Mod/blob/master/docs/PROTOCOL.md).
