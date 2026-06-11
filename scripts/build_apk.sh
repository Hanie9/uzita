#!/usr/bin/env bash
# Build Android APK with Neshan API key from secrets.local.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

./scripts/download_neshan_sdk.sh
./scripts/sync_neshan_secrets.sh
./scripts/sync_neshan_license.sh

if [[ -f "$ROOT/secrets.local.sh" ]]; then
  # shellcheck source=/dev/null
  source "$ROOT/secrets.local.sh"
fi

DART_DEFINES=()
if [[ -n "${NESHAN_API_KEY:-}" ]]; then
  DART_DEFINES+=(--dart-define="NESHAN_API_KEY=${NESHAN_API_KEY}")
fi
if [[ -n "${NESHAN_ANDROID_KEY:-}" ]]; then
  DART_DEFINES+=(--dart-define="NESHAN_ANDROID_KEY=${NESHAN_ANDROID_KEY}")
fi
if [[ -n "${NESHAN_MAP_KEY:-}" ]]; then
  DART_DEFINES+=(--dart-define="NESHAN_MAP_KEY=${NESHAN_MAP_KEY}")
fi

echo "Building APK..."
flutter build apk --release "${DART_DEFINES[@]}"

echo "APK: build/app/outputs/flutter-apk/app-release.apk"
