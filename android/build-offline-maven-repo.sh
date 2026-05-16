#!/usr/bin/env bash
set -euo pipefail

# Build a local Maven-style repository from Gradle cache.
# Usage:
#   ./build-offline-maven-repo.sh            # copy from existing cache
#   ./build-offline-maven-repo.sh --warm     # resolve deps first, then copy

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$ROOT_DIR/offline-maven-repo"
GRADLE_USER_HOME="${GRADLE_USER_HOME:-$HOME/.gradle}"
CACHE_DIR="$GRADLE_USER_HOME/caches/modules-2/files-2.1"

if [[ "${1:-}" == "--warm" ]]; then
  echo "[1/3] Warming Gradle dependency cache (using configured mirrors)..."
  (
    cd "$ROOT_DIR"
    ./gradlew :app:dependencies --configuration releaseRuntimeClasspath --no-daemon >/dev/null
    ./gradlew :app:dependencies --configuration releaseCompileClasspath --no-daemon >/dev/null
    ./gradlew help --no-daemon >/dev/null
  )
fi

if [[ ! -d "$CACHE_DIR" ]]; then
  echo "Gradle cache not found: $CACHE_DIR"
  exit 1
fi

mkdir -p "$REPO_DIR"
echo "[2/3] Exporting cache artifacts to: $REPO_DIR"

copied=0
skipped=0

while IFS= read -r -d '' f; do
  rel="${f#$CACHE_DIR/}"
  # Expected format: group/artifact/version/hash/filename.ext
  IFS='/' read -r group artifact version _hash filename <<<"$rel"
  if [[ -z "${group:-}" || -z "${artifact:-}" || -z "${version:-}" || -z "${filename:-}" ]]; then
    ((skipped+=1))
    continue
  fi

  case "$filename" in
    *.jar|*.aar|*.pom|*.module)
      target_dir="$REPO_DIR/$group/$artifact/$version"
      mkdir -p "$target_dir"
      cp -n "$f" "$target_dir/$filename" || true
      ((copied+=1))
      ;;
    *)
      ((skipped+=1))
      ;;
  esac
done < <(find "$CACHE_DIR" -type f -print0)

echo "[3/3] Done."
echo "Copied files: $copied"
echo "Skipped files: $skipped"
echo "Offline repo path: $REPO_DIR"
