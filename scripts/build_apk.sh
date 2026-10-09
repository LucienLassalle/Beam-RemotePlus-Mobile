#!/usr/bin/env bash
# Builds the release APKs in the Podman image (nothing to install on the host).
#
# Usage: scripts/build_apk.sh [version]     e.g. scripts/build_apk.sh v0.0.3
#   version: the release tag (a leading "v" is stripped); without it the
#   APKs are a "0.0.0-dev" test build.
# Output: dist/ (one small APK per CPU architecture + a universal APK).
#
# Signing: if app/android/key.properties exists (see app/android/key.properties.example)
# the APKs are signed with that key; otherwise with the debug key, which is
# fine for testing but cannot update an APK signed by another machine.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-0.0.0-dev}"
VERSION="${VERSION#v}"
IFS='.' read -r MAJOR MINOR PATCH <<< "${VERSION%%-*}"
BUILD_NUMBER=$(( MAJOR * 10000 + MINOR * 100 + PATCH ))
(( BUILD_NUMBER > 0 )) || BUILD_NUMBER=1 # Android needs a positive versionCode
FLAGS=(--release --obfuscate --split-debug-info=build/symbols --build-name="$VERSION" --build-number="$BUILD_NUMBER")

"$ROOT_DIR/scripts/flutter.sh" build apk "${FLAGS[@]}" --split-per-abi
"$ROOT_DIR/scripts/flutter.sh" build apk "${FLAGS[@]}"

OUT="$ROOT_DIR/app/build/app/outputs/flutter-apk"
mkdir -p "$ROOT_DIR/dist"
cp "$OUT/app-arm64-v8a-release.apk" "$ROOT_DIR/dist/BeamNG-RemotePlus-$VERSION-arm64-v8a.apk"
cp "$OUT/app-armeabi-v7a-release.apk" "$ROOT_DIR/dist/BeamNG-RemotePlus-$VERSION-armeabi-v7a.apk"
cp "$OUT/app-x86_64-release.apk" "$ROOT_DIR/dist/BeamNG-RemotePlus-$VERSION-x86_64.apk"
cp "$OUT/app-release.apk" "$ROOT_DIR/dist/BeamNG-RemotePlus-$VERSION-universal.apk"
ls -lh "$ROOT_DIR/dist"
