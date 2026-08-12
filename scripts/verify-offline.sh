#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
case "$(uname -s)-$(uname -m)" in
  Darwin-arm64) PLATFORM="darwin-arm64" ;;
  Darwin-x86_64) PLATFORM="darwin-amd64" ;;
  Linux-x86_64) PLATFORM="linux-amd64" ;;
  Linux-aarch64|Linux-arm64) PLATFORM="linux-arm64" ;;
  *) echo "FATAL: unsupported platform" >&2; exit 1 ;;
esac

ENGINE="$ROOT/runtime/$PLATFORM/codebase-memory-mcp"
test -x "$ENGINE"
test -f "$ROOT/.codex-plugin/plugin.json"
test -f "$ROOT/.claude-plugin/plugin.json"
test -f "$ROOT/.mcp.json"
test -f "$ROOT/skills/multi-repo-impact-review/SKILL.md"
test -f "$ROOT/vendor/codebase-memory-mcp/LICENSE"
test -f "$ROOT/vendor/codebase-memory-mcp/THIRD_PARTY_NOTICES.md"
test -f "$ROOT/checksums/SHA256SUMS"
if command -v shasum >/dev/null 2>&1; then
  (cd "$ROOT" && shasum -a 256 -c checksums/SHA256SUMS)
elif command -v sha256sum >/dev/null 2>&1; then
  (cd "$ROOT" && sha256sum -c checksums/SHA256SUMS)
else
  echo "FATAL: shasum or sha256sum is required" >&2
  exit 1
fi
VERSION=$($ENGINE --version)
printf '%s\n' "$VERSION" | grep 'codebase-memory-mcp 0.10.2' >/dev/null
$ENGINE cli trace_path --help >/dev/null
echo "OK: official codebase-memory-mcp offline package verified for $PLATFORM"
