#!/usr/bin/env bash
# Copies neshan.license into android/app/src/main/res/raw/ for Neshan Android SDK.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/android/app/src/main/res/raw/neshan.license"
mkdir -p "$(dirname "$DEST")"

if [[ -f "$ROOT/secrets.local.sh" ]]; then
  # shellcheck source=/dev/null
  source "$ROOT/secrets.local.sh"
fi

SRC="${NESHAN_LICENSE_FILE:-$HOME/Downloads/neshan.license}"

if [[ ! -f "$SRC" ]]; then
  if [[ -f "$DEST" ]]; then
    echo "Neshan license already present at res/raw/neshan.license"
    exit 0
  fi
  echo "Neshan license not found: $SRC"
  echo "Download from Neshan panel (ANDROID key + SHA-1) or set NESHAN_LICENSE_FILE in secrets.local.sh"
  exit 1
fi

cp "$SRC" "$DEST"
echo "Synced Neshan license -> android/app/src/main/res/raw/neshan.license"
