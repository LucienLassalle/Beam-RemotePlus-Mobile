#!/usr/bin/env bash
# Build l'APK Flutter avec Podman (sans rien installer sur l'hôte).
# Sortie dans ../../Package/BeamNG-RemotePlus.apk
#
# Pré-requis : podman installé, image buildée (ou disponible en cache).
# Usage    : bash scripts/build_apk.sh [--rebuild-image]
set -euo pipefail

MOBILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$MOBILE_DIR/app"
DOCKER_DIR="$MOBILE_DIR/docker"
PACKAGE_DIR="$(cd "$MOBILE_DIR/.." && pwd)/Package"
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

mkdir -p "$PACKAGE_DIR" "$ANDROID_HOME_CACHE"

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
