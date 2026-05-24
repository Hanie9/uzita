#!/usr/bin/env bash
# Build PWA and serve from build/web (not the web/ source folder).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${PORT:-8000}"

cd "$ROOT"
./scripts/build_pwa_zip.sh

echo ""
echo "Serving PWA at http://127.0.0.1:${PORT}/"
echo "Output directory: ${ROOT}/build/web"
echo "Press Ctrl+C to stop."
echo ""

cd build/web
python3 -m http.server "$PORT"
