#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TARGET=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --target) TARGET=$2; shift 2 ;;
    *) echo "FATAL: unknown option $1" >&2; exit 2 ;;
  esac
done
[ -n "$TARGET" ] || { echo "FATAL: --target is required" >&2; exit 2; }
"$ROOT/scripts/verify-offline.sh"
mkdir -p "$TARGET"
[ ! -e "$TARGET/multi-repo-impact-review" ] || { echo "FATAL: target already exists: $TARGET/multi-repo-impact-review" >&2; exit 1; }
cp -R "$ROOT" "$TARGET/multi-repo-impact-review"
echo "OK: installed offline plugin at $TARGET/multi-repo-impact-review"
