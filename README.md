# BeamNG RemotePlus — Android app

Turns your phone into a **steering wheel, pedals and live dashboard** for
[BeamNG.drive](https://www.beamng.com/) over the local network. A modern
replacement for BeamNG's unmaintained official
[remote control app](https://github.com/BeamNG/remotecontrol).

Works alone with the game's built-in remote control (steering + on/off
pedals); install the companion mod
**[Beam-RemotePlus-Mod](https://github.com/LucienLassalle/Beam-RemotePlus-Mod)**
for everything else.

## Features

- **Tilt or touch steering**, adjustable rotation range (360°–900°),
  stabilisation, recalibration, optional pitch gear shifting.
- **Analog pedals on the whole screen**: left half brakes, right half
  accelerates, slide up to press harder; both thumbs at once.
- **Dashboard themes**: Default, Civetta (Scintilla instrument screen), F4
  (single-seater wheel display). Community themes welcome: [THEMES.md](THEMES.md).
- **Vehicle buttons**: horn and headlight flash (held), indicators, hazards,
  lights, parking brake, ignition, drive/ESC mode, cruise control, camera,
  vehicle switching, hold-to-reset.
- **Volume buttons**: volume up = horn, volume down = headlight flash.
- **Local multiplayer**: one phone per player, each phone shows up under its
  own name in the game.
- **Automatic connection** (no QR code), manual code or QR scan.
- **English and French**, following the phone language: [TRANSLATING.md](TRANSLATING.md).
- **Debug mode**: shows on screen the values the vehicle does not send and the
  commands the game refused.

## Installation

1. Download the APK from the
   [latest release](https://github.com/LucienLassalle/Beam-RemotePlus-Mobile/releases/latest)
   (`arm64-v8a` for almost every recent phone, `universal` if unsure) and
   install it.
2. Install and enable the mod in BeamNG.drive.
3. Put the phone on the same Wi-Fi as the PC (or share the phone's hotspot
   with the PC), start a level, tap **Automatic connection**.

## Development

Only Podman is required, see [CONTRIBUTING.md](CONTRIBUTING.md):

```bash
scripts/flutter.sh test
scripts/flutter.sh screenshots   # renders every theme to PNG
scripts/build_apk.sh 2.1.0
```

Releases: publish a GitHub release with a `vX.Y.Z` tag; CI attaches the APKs,
SBOMs (SPDX + CycloneDX) and checksums.

## License

[CC BY-NC-SA 4.0](LICENSE): share and adapt for non-commercial purposes, with
attribution, under the same license.
