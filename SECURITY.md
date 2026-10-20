# Security policy

Please **do not open a public issue** for a vulnerability. Use
[GitHub private vulnerability reporting](https://github.com/LucienLassalle/Beam-RemotePlus-Mobile/security/advisories/new)
instead; you will get an answer within a week.

## Threat model

The app talks to the game over UDP on the local network (ports in the
[README](README.md#network)), and plays the driver's view video only when it
comes from the paired PC. To send inputs, it needs the 5-digit pairing code
shown in the game; automatic discovery gets that code from the mod, so any
device on the same network can get it too: only use the app on a network you
trust (home LAN or your phone's hotspot). What the PC accepts from phones
(locking out new phones, kicking one, commands) is described in the
[mod's security policy](https://github.com/LucienLassalle/Beam-RemotePlus-Mod/blob/master/SECURITY.md).
