#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
case "$(uname -s)-$(uname -m)" in
  Darwin-arm64) PLATFORM="darwin-arm64" ;;
  Darwin-x86_64) PLATFORM="darwin-amd64" ;;
  Linux-x86_64) PLATFORM="linux-amd64" ;;
  Linux-aarch64|Linux-arm64) PLATFORM="linux-arm64" ;;
  *) echo "FATAL: unsupported platform $(uname -s)-$(uname -m)" >&2; exit 1 ;;
esac

CBM="$ROOT/runtime/$PLATFORM/codebase-memory-mcp"
[ -x "$CBM" ] || { echo "FATAL: package does not contain runtime $PLATFORM" >&2; exit 1; }
exec "$CBM" "$@"
