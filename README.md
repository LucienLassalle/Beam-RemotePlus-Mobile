# BeamNG RemotePlus — mobile app

Turns an Android phone into a **steering wheel + real-time dashboard** for
[BeamNG.drive](https://www.beamng.com/), over the local Wi-Fi network.

It is a **modern replacement for BeamNG's official
[remotecontrol](https://github.com/BeamNG/remotecontrol) app**, which is no
longer maintained. The app works with the game's built-in remote control, and
unlocks a much richer dashboard (live telemetry, vehicle switching, recovery…)
once you install the companion mod
[Beam-RemotePlus-Mod](https://github.com/LucienLassalle/Beam-RemotePlus-Mod).

---

## Contents

- [What you need](#what-you-need)
- [Installation](#installation)
- [Connecting to BeamNG.drive](#connecting-to-beamngdrive)
- [Using the app (driving)](#using-the-app-driving)
- [The companion mod: why and how](#the-companion-mod-why-and-how)
- [Settings and calibration](#settings-and-calibration)
- [Troubleshooting](#troubleshooting)
- [BeamNG 0.39+ compatibility](#beamng-039-compatibility)
- [Development](#development)

---

## What you need

- An **Android 6.0 (API 23)** phone or newer.
- **BeamNG.drive** on a PC connected to the **same Wi-Fi network** as the phone.
- *(Strongly recommended)* the [Beam-RemotePlus-Mod](https://github.com/LucienLassalle/Beam-RemotePlus-Mod)
  installed and enabled in BeamNG.

> ⚠️ **Mobile data:** if the phone has mobile data **and** Wi-Fi enabled,
> Android may route the app over 4G/5G instead of Wi-Fi and the connection
> fails silently. Turn mobile data off while using the app, or use hotspot
> mode (see below).

---

## Installation

1. Download the latest `.apk`:
   - either from the [Releases page](https://github.com/LucienLassalle/Beam-RemotePlus-Mobile/releases),
   - or directly from `out/BeamNG-RemotePlus.apk` in this repo (built and
     tracked by Git).
2. Open the file on the phone to install it. Android will ask you to allow
   "install unknown apps" the first time.
3. On first launch, grant the **camera permission** (used only for QR code
   scanning, the fallback method).

---

## Connecting to BeamNG.drive

Start BeamNG.drive, load a level with a vehicle, then open the app. Three
methods, from the simplest to the most manual:

### 1. Automatic connection (recommended — requires the mod)

Tap **"Automatic connection"**. The app broadcasts a probe on the local
network; the mod replies with the PC's address and the pairing code, and the
connection completes within a few seconds. **No QR code, no camera.**

This is the recommended method since BeamNG 0.39 (see
[BeamNG 0.39+ compatibility](#beamng-039-compatibility)).

### 2. Manual code entry

The mod shows the **5-digit pairing code** in an in-game message at startup
("Pairing code: 54688"). Type that code into the app's **"Pairing code"**
field and tap **Connect**.

Without the mod, the code is also visible in BeamNG under
**Options > Controls > Hardware > Remote control app** (if the UI renders —
see troubleshooting).

### 3. QR code scan (legacy method)

In BeamNG: **Options > Controls > Hardware > Remote control app**. Point the
app's camera at the displayed QR code.

> Since BeamNG 0.39, this UI is buggy on the game side and the QR code does not
> always render. Methods 1 and 2 bypass it entirely.

### Playing with several people (local multiplayer)

To connect several phones, first enable **local multiplayer** in BeamNG's
settings on the PC. Each player then repeats one of the connection methods
with their phone.

### Mobile hotspot mode (no Wi-Fi router)

The app handles the case where the **phone is itself the hotspot** and the PC
connects to it: it computes the directed broadcast address of the hotspot
subnet (e.g. `192.168.43.255`) even when the Android API returns nothing
usable.

---

## Using the app (driving)

Once connected, the driving screen appears (locked to landscape):

| Element | Role |
|---|---|
| **Phone tilt** | Steering (default). Otherwise: swipe horizontally. |
| **Left / right pedal** | Brake / throttle. Analog **with the mod**, on/off without. |
| **Gear buttons** | Shift up / down (manual gearbox). Requires the mod. |
| **Vehicle buttons** | Previous / next vehicle. Requires the mod. |
| **Recovery button** | Reset / unstuck. Short press = small reposition, long press = rewind further. Requires the mod. |
| **Dashboard** | Speed, RPM, engaged gear, fuel, temperature, indicators (lights, turn signals, handbrake, ABS, traction control, shift light). Requires the mod. |

The **⚙️ settings** button opens the settings without interrupting driving.

The app **detects the mod automatically**: if the mod is enabled after the
connection is established, it switches to the mod channel on its own (analog
pedals + telemetry) with nothing else to do on the phone side.

---

## The companion mod: why and how

Without the mod, the app uses BeamNG's **native** remote control, which has two
limitations on the game side:

- **no telemetry** (the native call is broken and never sends anything);
- **on/off throttle / brake** (a single axis + two buttons).

The [Beam-RemotePlus-Mod](https://github.com/LucienLassalle/Beam-RemotePlus-Mod)
unlocks: **analog** pedals, **full telemetry** (RPM, speed, gear, fuel, water/oil
temperatures, indicators), **vehicle switching**, **recovery**, **camera
rotation**, **gear shifting**.

Installing the mod:

1. Get `Beam-RemotePlus.zip` (mod repo Releases, or the repo's `out/`).
2. Put it in BeamNG's `mods/` folder (or drag it onto the game window / the
   mod manager).
3. In the **mod manager**, check that **Beam-RemotePlus** is enabled. Once
   enabled, it **reloads automatically on every game startup**.
4. Load a level. The mod shows the pairing code in-game and answers automatic
   connection.

---

## Settings and calibration

⚙️ icon on the driving screen:

- Tilt steering: on/off, sensitivity, inversion.
- On-screen steering wheel rotation range.
- Speed units (km/h or mph).
- Haptic feedback on gear shifts (mod required).
- Tilt (pitch) gear shifting — requires tilt steering.
- Read-only interface (disables wheel/pedals, keeps settings and help).
- Dashboard theme.

**Recalibrate the phone's neutral position:** at the very bottom of the
settings sheet, "Advanced options" section → **Recalibrate steering**. Use it
if the "center" no longer matches how you hold the phone.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| **"Automatic connection" fails** | Check that the game is running, that the mod is **enabled**, and that phone + PC are on the **same Wi-Fi**. Turn mobile data off. Fallback: manual code entry. |
| **QR code scan does nothing** | BeamNG 0.39 UI bug. Use automatic connection or manual code entry. |
| **Connected but no telemetry / on-off pedals** | The mod is not active. Enable it in the mod manager; the app will switch over on its own. |
| **The app says "install the mod" while it is enabled** | BeamNG does not always reload the mod's extension right after enabling. Disable then re-enable the mod in the mod manager. |
| **"No response from BeamNG.drive"** | PC firewall / antivirus blocking the game, or wrong network. Allow BeamNG.drive through the firewall. |
| **Timeout in hotspot mode** | Make sure the PC is connected to the phone's hotspot (and not the other way around). |

**Debug mode** (🐛 icon at the top right of the pairing screen) shows network
logs on screen, useful for diagnosing a connection.

---

## BeamNG 0.39+ compatibility

BeamNG 0.39 **did not change the remote control protocol** (UDP handshake
4444/4445 and mod channel 4446/4447 unchanged). However:

- the in-game **"Remote Control" UI** (Options > Controls > Hardware) is
  **buggy**: the QR code does not render reliably (canvas render race
  condition on the game side);
- when it does render, the QR now encodes a **Play Store URL** with the code
  in the fragment (`…/details?id=com.beamng.remotecontrol#54688`).

This version of the app handles both:

- **automatic connection** and **manual entry** fully bypass the broken UI;
- the **QR parser** accepts the new URL format as well as the old
  `text#code`, and tolerates a hand-typed code.

On the mod side: `getQRCode()` (which provides the code) still works; the mod
calls it at startup to open the native socket and show the code, even if the
user never opens the Options panel.

---

## Development

```bash
# Build the APK (Podman, nothing to install on the host)
bash scripts/build_apk.sh                 # output: Package/ and out/
bash scripts/build_apk.sh --rebuild-image # rebuilds the build image

# Analyze + test (inside the container)
podman run --rm -v "$PWD/app:/workspace:Z" -w /workspace \
  localhost/beamng-remoteplus-flutter:latest \
  -c "flutter pub get && flutter analyze && flutter test"
```

Structure:

| Path | Role |
|---|---|
| `app/lib/protocol/beamng_client.dart` | UDP client: native handshake + mod probe/switch. |
| `app/lib/protocol/mod_discovery.dart` | Auto discovery (`discover` → `hello`). |
| `app/lib/protocol/pairing_code.dart` | Tolerant code extraction (QR / URL / manual entry). |
| `app/lib/protocol/protocol_constants.dart` | Ports and messages of both protocols. |
| `app/lib/protocol/mod_packets.dart` | Binary structs of the mod channel (control 12 B, telemetry 36 B). |
| `app/lib/screens/pairing_screen.dart` | Pairing screen (auto / manual / QR). |
| `app/lib/screens/control_screen.dart` | Driving screen + dashboard. |

The binary protocol is an **exact mirror** of the mod's Lua FFI structs
(little-endian); the tests in both repos document the format.

---

## Reporting an issue

[Open an issue](https://github.com/LucienLassalle/Beam-RemotePlus-Mobile/issues)
on this repo, in **French or English**.
