# app/ — module Flutter de BeamNG RemotePlus

Le code source de l'application Android. La documentation d'usage et
d'installation est dans le [README du dépôt](../README.md).

```bash
# depuis la racine du dépôt
bash scripts/build_apk.sh

# analyse + tests (conteneur Podman, rien à installer sur l'hôte)
podman run --rm -v "$PWD/app:/workspace:Z" -w /workspace \
  localhost/beamng-remoteplus-flutter:latest \
  -c "flutter pub get && flutter analyze && flutter test"
```

| Dossier | Rôle |
|---|---|
| `lib/protocol/` | Protocoles UDP (natif BeamNG + canal mod), découverte, parsing du code. |
| `lib/screens/` | Écrans : appairage, conduite. |
| `lib/widgets/` | Volant, pédales, boutons, tableau de bord. |
| `lib/themes/` | Thèmes du tableau de bord. |
| `lib/platform/` | Ponts natifs Android (infos réseau hotspot, exclusion de gestes). |
| `test/` | Tests unitaires du protocole et de l'UI. |
