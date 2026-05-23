#!/usr/bin/env bash
# Stamp build/web/version.json and patch bootstrap for cache busting.
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
  sed -i "s/UZITA_STAMP_BUILD/${BUILD}/g" "$WEB_DIR/index.html"
fi

if [[ -f "$WEB_DIR/flutter_bootstrap.js" ]]; then
  sed -i "s|\"mainJsPath\":\"main.dart.js\"|\"mainJsPath\":\"main.dart.js?v=${BUILD}\"|g" \
    "$WEB_DIR/flutter_bootstrap.js"
fi

if [[ -f "$ROOT/web/.htaccess" ]]; then
  cp "$ROOT/web/.htaccess" "$WEB_DIR/.htaccess"
fi

echo "PWA version stamped: ${VERSION}+${BUILD} -> $WEB_DIR/version.json"
