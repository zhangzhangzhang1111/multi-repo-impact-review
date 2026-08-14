#!/bin/sh
set -eu

SOURCE_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PLATFORM=""
ENGINE=""
OUT_DIR="$SOURCE_ROOT/dist"
VERSION=2.2.2

while [ "$#" -gt 0 ]; do
  case "$1" in
    --platform) PLATFORM=$2; shift 2 ;;
    --engine) ENGINE=$2; shift 2 ;;
    --out-dir) OUT_DIR=$2; shift 2 ;;
    --version) VERSION=$2; shift 2 ;;
    *) echo "FATAL: unknown option $1" >&2; exit 2 ;;
  esac
done

case "$PLATFORM" in darwin-arm64|darwin-amd64|linux-amd64|linux-arm64|windows-amd64|windows-arm64) ;; *) echo "FATAL: unsupported --platform" >&2; exit 2 ;; esac
[ -f "$ENGINE" ] || { echo "FATAL: --engine must point to the official platform executable" >&2; exit 2; }

mkdir -p "$OUT_DIR"
OUT_DIR=$(CDPATH= cd -- "$OUT_DIR" && pwd)
BUILD_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/impact-skill-build.XXXXXX")
trap 'rm -rf "$BUILD_ROOT"' EXIT HUP INT TERM
SKILL="$BUILD_ROOT/multi-repo-impact-review"
mkdir -p "$SKILL" "$SKILL/runtime/$PLATFORM" "$SKILL/checksums"

cp "$SOURCE_ROOT/skills/multi-repo-impact-review/SKILL.md" "$SKILL/"
cp -R "$SOURCE_ROOT/skills/multi-repo-impact-review/agents" "$SKILL/"
cp -R "$SOURCE_ROOT/skills/multi-repo-impact-review/assets" "$SKILL/"
cp -R "$SOURCE_ROOT/skills/multi-repo-impact-review/references" "$SKILL/"
cp -R "$SOURCE_ROOT/skills/multi-repo-impact-review/scripts" "$SKILL/"
cp -R "$SOURCE_ROOT/project-packs" "$SKILL/"
cp -R "$SOURCE_ROOT/vendor" "$SKILL/"
cp "$SOURCE_ROOT/LICENSE" "$SKILL/"
cp "$SOURCE_ROOT/SBOM.json" "$SKILL/"
cp "$SOURCE_ROOT/MANIFEST.json" "$SKILL/"
cp "$SOURCE_ROOT/runtime/launch-engine.sh" "$SKILL/runtime/"
cp "$SOURCE_ROOT/runtime/launch-engine.ps1" "$SKILL/runtime/"

if [ "$PLATFORM" = "windows-amd64" ] || [ "$PLATFORM" = "windows-arm64" ]; then
  cp "$ENGINE" "$SKILL/runtime/$PLATFORM/codebase-memory-mcp.exe"
else
  cp "$ENGINE" "$SKILL/runtime/$PLATFORM/codebase-memory-mcp"
  chmod +x "$SKILL/runtime/$PLATFORM/codebase-memory-mcp"
fi
chmod +x "$SKILL/scripts/run-review.sh" "$SKILL/scripts/verify-offline.sh" "$SKILL/runtime/launch-engine.sh"

(cd "$SKILL" && find . -type f ! -path './checksums/SHA256SUMS' | sort | while IFS= read -r FILE; do
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$FILE"; else sha256sum "$FILE"; fi
done > checksums/SHA256SUMS)

ARCHIVE_BASE="multi-repo-impact-review-skill-v$VERSION-$PLATFORM"
if [ "$PLATFORM" = "windows-amd64" ] || [ "$PLATFORM" = "windows-arm64" ]; then
  (cd "$BUILD_ROOT" && zip -qr "$OUT_DIR/$ARCHIVE_BASE.zip" multi-repo-impact-review)
  echo "OK: $OUT_DIR/$ARCHIVE_BASE.zip"
else
  (cd "$BUILD_ROOT" && tar -czf "$OUT_DIR/$ARCHIVE_BASE.tar.gz" multi-repo-impact-review)
  echo "OK: $OUT_DIR/$ARCHIVE_BASE.tar.gz"
fi
