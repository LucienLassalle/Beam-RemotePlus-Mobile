# Security policy

Please **do not open a public issue** for a vulnerability. Use
[GitHub private vulnerability reporting](https://github.com/LucienLassalle/Beam-RemotePlus-Mobile/security/advisories/new)
instead; you will get an answer within a week.

## Threat model

The app talks to the game over UDP on the local network (ports 4444-4448). A phone must know the
5-digit pairing code of the game's native remote control to send inputs.
Automatic discovery returns that code to any device on the same network: only
use the mod on a network you trust (home LAN or your phone's hotspot), and lock
out new phones from the mod's in-game panel once yours are connected (the
player can also kick a phone there). Commands only ever run predefined vehicle
functions; no text sent by the phone is executed as code.
