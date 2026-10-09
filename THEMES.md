# Creating a theme

A theme is the dashboard drawn on the driving screen. **It only draws**: the
app places the pedals, steering and buttons on top of it, so a theme can never
break the controls. Touching the dashboard presses the brake (left half) or
the throttle (right half).

You need basic [Flutter](https://docs.flutter.dev/get-started) knowledge;
building a dashboard is mostly stacking `Row`, `Column`, `Text` and the
ready-made gauges of `lib/themes/kit/`.

## 1. Create the files

```
app/lib/themes/
  my_theme/             <- lower_snake_case folder
    my_theme.dart       <- your theme (split into more files if it grows)
```

```dart
import 'package:flutter/material.dart';

import '../kit/kit.dart';

class MyTheme extends ControlTheme {
  const MyTheme();

  @override
  String get name => 'My Theme'; // unique, shown in the settings

  @override
  String get author => 'your-github-name';

  @override
  Widget buildDashboard(BuildContext context, DashboardData data) {
    final t = data.telemetry;
    return Center(
      child: Text(
        '${DashFormat.speed(t, kmh: data.useKmh)} ${DashFormat.speedUnit(kmh: data.useKmh)}  ${t.gearLabel}',
        style: const TextStyle(fontSize: 64, color: Colors.white),
      ),
    );
  }
}
```

## 2. Register it

Add one line to `app/lib/themes/theme_registry.dart`:

```dart
const List<ControlTheme> availableThemes = [
  DefaultTheme(),
  CivettaTheme(),
  F4Theme(),
  MyTheme(), // <-
];
```

## 3. See it without a phone

```bash
scripts/flutter.sh screenshots   # writes app/test/screenshots/goldens/My Theme.png
scripts/flutter.sh test          # checks the pedals still work on every theme
```

Attach the PNG to your pull request.

## What you can display

`data.telemetry` (`lib/core/protocol/telemetry.dart`) holds every value sent
by the mod: speed, RPM, max RPM, gear label, fuel, temperatures, boost,
warning lights, indicators, ABS/ESC/TCS, cruise control, odometer, g-forces,
tyre pressures, drive mode... **Every value can be `null`** when the vehicle
does not have it: show `DashFormat.missing` ("–") or hide the gauge, never
pretend it is 0. `data.modActive` is false without the mod (no telemetry at
all).

Temperatures are sent in °C and tyre pressures in kPa: show them in the
units the user picked with `DashFormat.temperature(value,
data.temperatureUnit)` and `DashFormat.pressure(value, data.pressureUnit)`
(and `data.useKmh` for speeds and distances).

Text shown by a theme is translated like the rest of the app: add the
string to `app/lib/l10n/app_en.arb` and `app_fr.arb` and read it with
`AppLocalizations.of(context)` (see the Road theme). Only replicas of an
in-game screen (Civetta, F4) keep the labels of the game, in English.

Ready-made blocks in `lib/themes/kit/`:

| Widget | Use |
|---|---|
| `ShiftLights` | row of shift LEDs (green → red → blue at the shift point) |
| `SegmentBar` | segmented bar gauge (temperatures, fuel, boost) |
| `WarningLamp` | telltale icon, bright when on, dim when off |
| `ValueBox` | framed label + value cell (race displays) |
| `DashFormat` | consistent number formatting (speed, fuel %, distance...) |
| `RadarView` | top-down radar of the cars around |
| `DamageView` | body damage zones, radiator, engine, shafts, fuel tank, brakes, flat tyres and tyre temperatures |

## Colors of the controls and vehicle buttons

Override `style` to match the pedal and button colors with your design, and
to choose which vehicle buttons your theme offers at the bottom of the screen
(none by default; users can still hide each one in the settings):

```dart
@override
ThemeStyle get style => const ThemeStyle(
      brakeColor: Colors.red,
      throttleColor: Colors.cyan,
      actions: {VehicleAction.signals, VehicleAction.hazard, VehicleAction.lights},
    );
```

The app always adds the vehicle switch (top left), hold-to-reset (top
centre), camera buttons (bottom centre), settings and warning lights.

## Rules for a theme pull request

- One folder, no new dependency, no network, no file access, no images
  copied from the game or another copyrighted source (draw them in code or use
  your own assets).
- `buildDashboard` is called ~30 times per second: no heavy work, no async.
- Lay the dashboard out in a fixed design size wrapped in `FittedBox` (see
  `civetta/`) so it scales to every phone.
- English code and comments; dashboard labels are free (real dashes use
  "RPM", "OIL"...).
