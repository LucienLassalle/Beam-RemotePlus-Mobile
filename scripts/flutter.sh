#!/usr/bin/env bash
# Runs a Flutter command inside the Podman build image: nothing to install on
# the host besides Podman.
#
# Usage:
#   scripts/flutter.sh test                 # any flutter command
#   scripts/flutter.sh analyze
#   scripts/flutter.sh screenshots          # renders theme previews to app/test/screenshots/goldens/
#   scripts/flutter.sh --rebuild-image ...  # rebuilds docker/Containerfile first
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_NAME="beamng-remoteplus-flutter:latest"
CACHE_DIR="$ROOT_DIR/docker"
mkdir -p "$CACHE_DIR/.pub-cache" "$CACHE_DIR/.gradle-cache" "$CACHE_DIR/.android-home-cache"

if [[ "${1:-}" == "--rebuild-image" ]]; then
  shift
  podman build -t "$IMAGE_NAME" "$ROOT_DIR/docker"
elif ! podman image exists "$IMAGE_NAME"; then
  podman build -t "$IMAGE_NAME" "$ROOT_DIR/docker"
fi

if [[ "${1:-}" == "screenshots" ]]; then
  set -- test --update-goldens --tags screenshots --run-skipped test/screenshots
fi

podman run --rm \
  -v "$ROOT_DIR/app:/workspace:Z" \
  -v "$CACHE_DIR/.pub-cache:/root/.pub-cache:Z" \
  -v "$CACHE_DIR/.gradle-cache:/root/.gradle:Z" \
  -v "$CACHE_DIR/.android-home-cache:/root/.android:Z" \
  -w /workspace \
  -e CI=true \
  "$IMAGE_NAME" \
  -c "flutter --suppress-analytics pub get >/dev/null && flutter --suppress-analytics gen-l10n && flutter --suppress-analytics $(printf '%q ' "$@")"
