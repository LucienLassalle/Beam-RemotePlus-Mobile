# BeamNG RemotePlus — application mobile

Transforme un téléphone Android en **volant + tableau de bord temps réel** pour
[BeamNG.drive](https://www.beamng.com/), via le réseau Wi-Fi local.

C'est un **remplacement moderne de l'application officielle
[remotecontrol](https://github.com/BeamNG/remotecontrol) de BeamNG**, qui n'est
plus maintenue. L'app fonctionne avec le contrôle à distance intégré au jeu, et
débloque un tableau de bord bien plus riche (télémétrie live, changement de
véhicule, récupération…) quand on installe le mod compagnon
[Beam-RemotePlus-Mod](https://github.com/LucienLassalle/Beam-RemotePlus-Mod).

---

## Sommaire

- [Ce qu'il faut](#ce-quil-faut)
- [Installation](#installation)
- [Connexion à BeamNG.drive](#connexion-à-beamngdrive)
- [Utiliser l'app (conduite)](#utiliser-lapp-conduite)
- [Le mod compagnon : pourquoi et comment](#le-mod-compagnon--pourquoi-et-comment)
- [Réglages et calibration](#réglages-et-calibration)
- [Dépannage](#dépannage)
- [Compatibilité BeamNG 0.39+](#compatibilité-beamng-039)
- [Développement](#développement)

---

## Ce qu'il faut

- Un téléphone **Android 6.0 (API 23)** ou plus récent.
- **BeamNG.drive** sur un PC connecté au **même réseau Wi-Fi** que le téléphone.
- *(Fortement recommandé)* le mod [Beam-RemotePlus-Mod](https://github.com/LucienLassalle/Beam-RemotePlus-Mod)
  installé et activé dans BeamNG.

> ⚠️ **Données mobiles :** si le téléphone a les données mobiles **et** le Wi-Fi
> activés, Android peut router l'app par la 4G/5G au lieu du Wi-Fi et la
> connexion échoue silencieusement. Coupez les données mobiles pendant l'usage,
> ou utilisez le mode point d'accès (voir plus bas).

---

## Installation

1. Téléchargez le dernier `.apk` :
   - soit depuis la [page Releases](https://github.com/LucienLassalle/Beam-RemotePlus-Mobile/releases),
   - soit directement depuis `out/BeamNG-RemotePlus.apk` dans ce dépôt (buildé et
     suivi par Git).
2. Ouvrez le fichier sur le téléphone pour l'installer. Android demandera
   d'autoriser « installer des applications inconnues » la première fois.
3. À la première ouverture, accordez la **permission caméra** (utilisée
   uniquement pour le scan du QR code, méthode de secours).

---

## Connexion à BeamNG.drive

Lancez BeamNG.drive, chargez un niveau avec un véhicule, puis ouvrez l'app.
Trois méthodes, de la plus simple à la plus manuelle :

### 1. Connexion automatique (recommandée — nécessite le mod)

Appuyez sur **« Connexion automatique »**. L'app diffuse une sonde sur le réseau
local ; le mod répond avec l'adresse du PC et le code d'appairage, et la
connexion se fait en quelques secondes. **Aucun QR code, aucune caméra.**

C'est la méthode conseillée depuis BeamNG 0.39 (voir
[Compatibilité BeamNG 0.39+](#compatibilité-beamng-039)).

### 2. Saisie manuelle du code

Le mod affiche le **code d'appairage à 5 chiffres** dans un message in-game au
démarrage (« Code d'appairage : 54688 »). Tapez ce code dans le champ **« Code
d'appairage »** de l'app et appuyez sur **Connexion**.

Sans le mod, le code est aussi visible dans BeamNG sous
**Options > Contrôles > Matériel > Application de contrôle à distance** (si l'UI
s'affiche — voir dépannage).

### 3. Scan du QR code (méthode historique)

Dans BeamNG : **Options > Contrôles > Matériel > Application de contrôle à
distance**. Visez le QR code affiché avec l'appareil photo de l'app.

> Depuis BeamNG 0.39, cette UI est boguée côté jeu et le QR code ne s'affiche pas
> toujours. Les méthodes 1 et 2 la contournent complètement.

### Jouer à plusieurs (multijoueur local)

Pour connecter plusieurs téléphones, activez d'abord le **multijoueur local**
dans les réglages de BeamNG sur le PC. Chaque joueur répète ensuite une des
méthodes de connexion avec son téléphone.

### Mode point d'accès mobile (sans routeur Wi-Fi)

L'app gère le cas où le **téléphone est lui-même le point d'accès** et le PC s'y
connecte : elle calcule l'adresse de broadcast dirigée du sous-réseau du hotspot
(ex. `192.168.43.255`) même quand l'API Android ne renvoie rien d'exploitable.

---

## Utiliser l'app (conduite)

Une fois connecté, l'écran de conduite s'affiche (verrouillé en paysage) :

| Élément | Rôle |
|---|---|
| **Inclinaison du téléphone** | Direction (par défaut). Sinon : glisser le doigt horizontalement. |
| **Pédale gauche / droite** | Frein / accélérateur. Analogiques **avec le mod**, tout-ou-rien sans. |
| **Boutons de rapport** | Montée / descente de vitesse (boîte manuelle). Nécessite le mod. |
| **Boutons véhicule** | Véhicule précédent / suivant. Nécessite le mod. |
| **Bouton récupération** | Reset / désembourbage. Appui bref = petit repositionnement, appui long = rembobinage plus loin. Nécessite le mod. |
| **Tableau de bord** | Vitesse, régime, rapport engagé, carburant, température, témoins (feux, clignotants, frein à main, ABS, antipatinage, shift light). Nécessite le mod. |

Le bouton **⚙️ paramètres** ouvre les réglages sans couper la conduite.

L'app **détecte automatiquement le mod** : si le mod est activé après la
connexion, elle bascule seule sur son canal (pédales analogiques + télémétrie)
sans rien faire de plus côté téléphone.

---

## Le mod compagnon : pourquoi et comment

Sans le mod, l'app utilise le contrôle à distance **natif** de BeamNG, qui a deux
limites côté jeu :

- **pas de télémétrie** (l'appel natif est cassé et n'envoie jamais rien) ;
- **accélérateur / frein tout-ou-rien** (un seul axe + deux boutons).

Le [Beam-RemotePlus-Mod](https://github.com/LucienLassalle/Beam-RemotePlus-Mod)
débloque : pédales **analogiques**, **télémétrie complète** (RPM, vitesse,
rapport, carburant, températures eau/huile, témoins), **changement de
véhicule**, **récupération**, **rotation caméra**, **passage de rapports**.

Installation du mod :

1. Récupérez `Beam-RemotePlus.zip` (Releases du dépôt mod, ou `out/` du dépôt).
2. Placez-le dans le dossier `mods/` de BeamNG (ou glissez-le sur la fenêtre du
   jeu / le gestionnaire de mods).
3. Dans le **gestionnaire de mods**, vérifiez que **Beam-RemotePlus** est activé.
   Une fois activé, il **se relance automatiquement à chaque démarrage** du jeu.
4. Chargez un niveau. Le mod affiche le code d'appairage in-game et répond à la
   connexion automatique.

---

## Réglages et calibration

Icône ⚙️ sur l'écran de conduite :

- Direction par inclinaison : on/off, sensibilité, inversion.
- Plage de rotation du volant à l'écran.
- Unités de vitesse (km/h ou mph).
- Retour haptique aux passages de rapport (mod requis).
- Passage de rapport par inclinaison (pitch) — nécessite la direction par
  inclinaison.
- Interface en lecture seule (coupe volant/pédales, garde réglages et aide).
- Thème du tableau de bord.

**Recalibrer la position neutre du téléphone :** tout en bas de la feuille de
réglages, section « Options avancées » → **Recalibrer la direction**. À utiliser
si le « centre » ne correspond plus à votre prise en main.

---

## Dépannage

| Symptôme | Solution |
|---|---|
| **« Connexion automatique » échoue** | Vérifiez que le jeu tourne, que le mod est **activé**, et que téléphone + PC sont sur le **même Wi-Fi**. Coupez les données mobiles. Repli : saisie manuelle du code. |
| **Le scan du QR code ne fait rien** | Bug de l'UI BeamNG 0.39. Utilisez la connexion automatique ou la saisie manuelle. |
| **Connexion établie mais pas de télémétrie / pédales tout-ou-rien** | Le mod n'est pas actif. Activez-le dans le gestionnaire de mods ; l'app basculera seule. |
| **L'app dit « installez le mod » alors qu'il est activé** | BeamNG ne recharge pas toujours l'extension du mod juste après activation. Désactivez puis réactivez le mod dans le gestionnaire. |
| **« Aucune réponse de BeamNG.drive »** | Pare-feu / antivirus du PC qui bloque le jeu, ou mauvais réseau. Autorisez BeamNG.drive dans le pare-feu. |
| **Timeout en mode point d'accès** | Assurez-vous que le PC est bien connecté au hotspot du téléphone (et pas l'inverse). |

Le **mode debug** (icône 🐛 en haut à droite de l'écran d'appairage) affiche les
logs réseau à l'écran, utile pour diagnostiquer une connexion.

---

## Compatibilité BeamNG 0.39+

BeamNG 0.39 **n'a pas changé le protocole** de contrôle à distance (handshake
UDP 4444/4445 et canal mod 4446/4447 identiques). En revanche :

- l'**UI in-game** « Remote Control » (Options > Contrôles > Matériel) est
  **boguée** : le QR code ne se rend pas de façon fiable (race condition au
  rendu du canvas côté jeu) ;
- quand il se rend, le QR encode désormais une **URL Play Store** avec le code en
  fragment (`…/details?id=com.beamng.remotecontrol#54688`).

Cette version de l'app gère les deux :

- **connexion automatique** et **saisie manuelle** contournent entièrement l'UI
  cassée ;
- le **parsing du QR** accepte le nouveau format d'URL comme l'ancien
  `texte#code`, et tolère un code tapé à la main.

Côté mod : `getQRCode()` (qui fournit le code) fonctionne toujours ; le mod
l'appelle au démarrage pour ouvrir le socket natif et afficher le code, même si
l'utilisateur n'ouvre jamais le panneau Options.

---

## Développement

```bash
# Build de l'APK (Podman, rien à installer sur l'hôte)
bash scripts/build_apk.sh                 # sortie : Package/ et out/
bash scripts/build_apk.sh --rebuild-image # reconstruit l'image de build

# Analyse + tests (dans le conteneur)
podman run --rm -v "$PWD/app:/workspace:Z" -w /workspace \
  localhost/beamng-remoteplus-flutter:latest \
  -c "flutter pub get && flutter analyze && flutter test"
```

Structure :

| Chemin | Rôle |
|---|---|
| `app/lib/protocol/beamng_client.dart` | Client UDP : handshake natif + sonde/bascule mod. |
| `app/lib/protocol/mod_discovery.dart` | Découverte auto (`discover` → `hello`). |
| `app/lib/protocol/pairing_code.dart` | Extraction tolérante du code (QR / URL / saisie). |
| `app/lib/protocol/protocol_constants.dart` | Ports et messages des deux protocoles. |
| `app/lib/protocol/mod_packets.dart` | Struct binaires du canal mod (contrôle 12 o, télémétrie 36 o). |
| `app/lib/screens/pairing_screen.dart` | Écran d'appairage (auto / manuel / QR). |
| `app/lib/screens/control_screen.dart` | Écran de conduite + tableau de bord. |

Le protocole binaire est un **miroir exact** des structs FFI Lua du mod
(little-endian) ; les tests des deux dépôts documentent le format.

---

## Signaler un problème

[Ouvrez une issue](https://github.com/LucienLassalle/Beam-RemotePlus-Mobile/issues)
sur ce dépôt, en **français ou en anglais**.
