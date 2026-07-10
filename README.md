# BeamNG RemotePlus — Mobile App

An Android app that turns your phone into a wireless dashboard and controller for [BeamNG.drive](https://www.beamng.com/), connecting over your local network via a QR code scan.

This project is a modern **replacement for BeamNG's official [remotecontrol](https://github.com/BeamNG/remotecontrol) app, which is no longer maintained**. It works with BeamNG's built-in remote control feature out of the box, and unlocks a much richer dashboard (live telemetry, vehicle switching, recovery, and more) when paired with the companion [Beam-RemotePlus-Mod](https://github.com/LucienLassalle/Beam-RemotePlus-Mod).

## Requirements

- An Android phone, Android 6.0 (API 23) or newer.
- BeamNG.drive running on a PC connected to the **same local network / Wi-Fi** as your phone.

## Installation

1. Go to the [Releases page](https://github.com/LucienLassalle/Beam-RemotePlus-Mobile/releases) of this repository and download the latest `.apk` file.
2. On your phone, open the downloaded file to install it. You may need to allow "install from unknown sources" for your browser or file manager — Android will prompt you for this the first time.
3. Grant the camera permission when asked; it's required to scan the pairing QR code.

## Connecting to BeamNG.drive

1. Launch BeamNG.drive on your PC and load into a level with a vehicle.
2. In-game, open **Options > Controls > Hardware > Remote Control App**. A QR code will be displayed.
3. Open the BeamNG RemotePlus app on your phone and scan the QR code on screen.
4. Once paired, the control screen appears and you can start driving with your phone.

### Playing with friends (local multiplayer)

If you want multiple people to connect their phones and play together, enable **local multiplayer** in BeamNG.drive's settings on the PC first, so the game accepts more than one remote connection. Each additional player then repeats steps 3–4 above with their own phone.

## Getting the full experience: install the companion mod

By default, the app works with BeamNG's native remote control feature, but that feature has long-standing limitations on BeamNG's side: no live telemetry, and only digital (on/off) throttle and brake instead of analog pedals.

Installing the [Beam-RemotePlus-Mod](https://github.com/LucienLassalle/Beam-RemotePlus-Mod) in BeamNG.drive unlocks:

- Analog throttle and brake (instead of on/off)
- Live telemetry: **RPM**, **speed**, and **current gear**
- **Vehicle switching** from your phone
- **Vehicle recovery** (reset/unstuck) from your phone
- Camera cycling
- Overall smoother, more responsive controls

The app automatically detects the mod once it's active in-game — no extra setup is needed on the phone side, it reuses the same QR code and pairing flow.

## Settings and calibration

Tap the settings icon on the control screen to adjust:

- Tilt-steering on/off, sensitivity, and steering inversion
- Speed units (km/h or mph)
- Haptic feedback on gear shifts (requires the mod)
- Pitch-based gear shifting (requires tilt-steering)

**To recalibrate your phone's steering (tilt) orientation**, scroll all the way to the **bottom of the settings sheet**, under "Advanced options", and tap **Recalibrate steering**. Use this if "center" no longer matches how you're holding the phone, or after switching how you hold the device.

## Troubleshooting

- **App shows "install the mod" even though the mod is enabled**: this is a known bug in the mod's activation flow. In BeamNG's mod manager, **disable the mod, then re-enable it**. This forces the game to reload the mod correctly. See the [mod's README](https://github.com/LucienLassalle/Beam-RemotePlus-Mod) for details.
- **Can't connect / QR code not scanning**: make sure your phone and PC are on the same local network, and that the QR code shown in BeamNG is fully visible and well lit on screen.

## Reporting issues

If you run into a problem, please [open an issue](https://github.com/LucienLassalle/Beam-RemotePlus-Mobile/issues) on this repository. You can write it in **English or French**.
