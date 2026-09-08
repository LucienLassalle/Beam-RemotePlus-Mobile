#!/usr/bin/env bash
# Build l'APK Flutter avec Podman (sans rien installer sur l'hôte).
# Sortie dans ../../Package/BeamNG-RemotePlus.apk (usage local/install
# téléphone) ET dans out/BeamNG-RemotePlus.apk, à la racine de CE dépôt et
# suivi par Git : permet à n'importe qui de récupérer la dernière version
# buildée directement depuis GitHub, sans passer par les Releases ou la CI.
#
# Attention : out/ est committé tel quel, donc chaque build ajoute ~65 Mo à
# l'historique Git de façon permanente (pas de nettoyage automatique). Choix
# assumé pour la simplicité du téléchargement direct — voir README si ça
# devient un problème (Git LFS ou GitHub Releases sont les alternatives).
#
# Pré-requis : podman installé, image buildée (ou disponible en cache).
# Usage    : bash scripts/build_apk.sh [--rebuild-image]
set -euo pipefail

MOBILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$MOBILE_DIR/app"
DOCKER_DIR="$MOBILE_DIR/docker"
PACKAGE_DIR="$(cd "$MOBILE_DIR/.." && pwd)/Package"
OUT_DIR="$MOBILE_DIR/out"
IMAGE_NAME="beamng-remoteplus-flutter:latest"
APK_NAME="BeamNG-RemotePlus.apk"
# Le conteneur tourne en root (voir Containerfile) et n'a pas de config de
# signature release custom : Gradle retombe sur le debug keystore par
# défaut, auto-généré sous ~/.android au premier build. Sans ce montage
# persistant, chaque `podman run --rm` en génère un nouveau -> signature
# différente à chaque build -> `adb install` échoue en
# INSTALL_FAILED_UPDATE_INCOMPATIBLE sur une install déjà présente sur le
# téléphone.
ANDROID_HOME_CACHE="$MOBILE_DIR/docker/.android-home-cache"
# Cache Gradle persistant : sans lui, chaque `podman run --rm` re-télécharge
# la distribution Gradle (~150 Mo) via le wrapper. Un téléchargement tronqué
# fait échouer le build sur "zip END header not found" (vécu). Le montage
# évite le re-téléchargement et rend les builds reproductibles/rapides.
GRADLE_CACHE="$MOBILE_DIR/docker/.gradle-cache"

mkdir -p "$PACKAGE_DIR" "$OUT_DIR" "$ANDROID_HOME_CACHE" "$GRADLE_CACHE"

# --- Construire l'image si absente ou si --rebuild-image est passé ---
REBUILD=false
for arg in "$@"; do
  [[ "$arg" == "--rebuild-image" ]] && REBUILD=true
done

if $REBUILD || ! podman image exists "$IMAGE_NAME" 2>/dev/null; then
  echo "==> Construction de l'image Podman ($IMAGE_NAME)…"
  podman build -t "$IMAGE_NAME" "$DOCKER_DIR"
else
  echo "==> Image $IMAGE_NAME déjà présente, on la réutilise."
fi

# --- Build APK ---
echo "==> Build de l'APK (flutter build apk --release)…"
podman run --rm \
  -v "$APP_DIR:/workspace:Z" \
  -v "$ANDROID_HOME_CACHE:/root/.android:Z" \
  -v "$GRADLE_CACHE:/root/.gradle:Z" \
  -w /workspace \
  "$IMAGE_NAME" \
  -c "flutter pub get && flutter build apk --release"

APK_SRC="$APP_DIR/build/app/outputs/flutter-apk/app-release.apk"
if [[ ! -f "$APK_SRC" ]]; then
  echo "ERREUR: APK introuvable à $APK_SRC" >&2
  exit 1
fi

cp "$APK_SRC" "$PACKAGE_DIR/$APK_NAME"
echo "APK copié: $PACKAGE_DIR/$APK_NAME"

cp "$APK_SRC" "$OUT_DIR/$APK_NAME"
echo "APK copié: $OUT_DIR/$APK_NAME (à committer/pousser manuellement pour publier sur GitHub)"
