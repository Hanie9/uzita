#!/usr/bin/env bash
# Build PWA and create uzita-pwa-build.zip at repo root.
#
# Liara / root hosting (ellaro.liara.run):
#   ./scripts/build_pwa_zip.sh
#
# GitHub Pages subpath (/uzita/):
#   BASE_HREF=/uzita/ ./scripts/build_pwa_zip.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE_HREF="${BASE_HREF:-/}"
ZIP="$ROOT/uzita-pwa-build.zip"
BUILD="${BUILD_NUMBER:-$(date +%s)}"

cd "$ROOT"
echo "Building web with base-href: ${BASE_HREF}, build: ${BUILD}"

flutter build web --release \
  --base-href "$BASE_HREF" \
  --build-name="$(grep '^version:' pubspec.yaml | sed 's/version:[[:space:]]*//')" \
  --build-number="$BUILD"

export BUILD_NUMBER="$BUILD"
./scripts/stamp_pwa_version.sh

rm -f "$ZIP"
(cd build/web && zip -qr "$ZIP" .)

echo "Created: $ZIP ($(du -h "$ZIP" | cut -f1))"
cat build/web/version.json
grep -o '__UZITA_BUILD__.*' build/web/index.html 2>/dev/null | head -1 || grep "UZITA_BUILD" build/web/index.html | head -1
