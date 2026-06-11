#!/usr/bin/env bash
# Download Neshan Android SDK AARs into android/app/libs/ (offline-friendly builds).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIBS="$ROOT/android/app/libs"
mkdir -p "$LIBS"

BASE="https://maven.neshan.org/artifactory/public-maven/neshan-android-sdk"

curl -fsSL -o "$LIBS/mobile-sdk-1.0.3.aar" \
  "$BASE/mobile-sdk/1.0.3/mobile-sdk-1.0.3.aar"

curl -fsSL -o "$LIBS/services-sdk-1.0.0.aar" \
  "$BASE/services-sdk/1.0.0/services-sdk-1.0.0.aar"

curl -fsSL -o "$LIBS/common-sdk-0.0.3.aar" \
  "$BASE/common-sdk/0.0.3/common-sdk-0.0.3.aar"

echo "Downloaded Neshan SDK AARs (mobile + services + common) -> android/app/libs/"
