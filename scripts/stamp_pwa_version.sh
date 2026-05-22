#!/usr/bin/env bash
# Stamp build/web/version.json after `flutter build web` for local or custom deploys.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WEB_DIR="${1:-$ROOT/build/web}"
VERSION="$(grep '^version:' "$ROOT/pubspec.yaml" | sed 's/version:[[:space:]]*//')"
BUILD="${BUILD_NUMBER:-$(date +%s)}"

if [[ ! -d "$WEB_DIR" ]]; then
  echo "Web output not found: $WEB_DIR (run flutter build web first)" >&2
  exit 1
fi

printf '%s\n' \
  "{\"app_name\":\"uzita\",\"version\":\"${VERSION}\",\"build_number\":\"${BUILD}\",\"package_name\":\"uzita\"}" \
  > "$WEB_DIR/version.json"

if [[ -f "$WEB_DIR/index.html" ]]; then
  sed -i "s/manifest.json?v=[0-9]*/manifest.json?v=${BUILD}/g" "$WEB_DIR/index.html"
  sed -i "s/logouzita.png?v=[0-9]*/logouzita.png?v=${BUILD}/g" "$WEB_DIR/index.html"
fi

echo "PWA version stamped: ${VERSION}+${BUILD} -> $WEB_DIR/version.json"
