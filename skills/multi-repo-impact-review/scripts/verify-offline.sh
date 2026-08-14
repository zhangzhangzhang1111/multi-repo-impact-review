#!/bin/sh
set -eu

SKILL_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
case "$(uname -s)-$(uname -m)" in
  Darwin-arm64) PLATFORM=darwin-arm64 ;;
  Darwin-x86_64) PLATFORM=darwin-amd64 ;;
  Linux-x86_64) PLATFORM=linux-amd64 ;;
  Linux-aarch64|Linux-arm64) PLATFORM=linux-arm64 ;;
  *) echo "FATAL: unsupported platform $(uname -s)-$(uname -m)" >&2; exit 1 ;;
esac

ENGINE=${MULTI_REPO_IMPACT_CBM:-"$SKILL_ROOT/runtime/$PLATFORM/codebase-memory-mcp"}
test -x "$ENGINE"
test -f "$SKILL_ROOT/SKILL.md"
test -f "$SKILL_ROOT/agents/openai.yaml"
test -f "$SKILL_ROOT/project-packs/project-map.tsv"
test -f "$SKILL_ROOT/vendor/codebase-memory-mcp/LICENSE"
test -f "$SKILL_ROOT/vendor/codebase-memory-mcp/THIRD_PARTY_NOTICES.md"
test ! -e "$SKILL_ROOT/.mcp.json"
test ! -e "$SKILL_ROOT/.codex-plugin"
test ! -e "$SKILL_ROOT/.claude-plugin"

if [ -f "$SKILL_ROOT/checksums/SHA256SUMS" ]; then
  if command -v shasum >/dev/null 2>&1; then
    (cd "$SKILL_ROOT" && shasum -a 256 -c checksums/SHA256SUMS)
  elif command -v sha256sum >/dev/null 2>&1; then
    (cd "$SKILL_ROOT" && sha256sum -c checksums/SHA256SUMS)
  else
    echo "FATAL: shasum or sha256sum is required for package verification" >&2
    exit 1
  fi
fi

VERSION=$($ENGINE --version 2>/dev/null)
printf '%s\n' "$VERSION" | grep 'codebase-memory-mcp 0.10.2' >/dev/null
$ENGINE cli index_repository --help >/dev/null 2>&1
$ENGINE cli trace_path --help >/dev/null 2>&1
echo "OK: pure Skill and official runtime verified for $PLATFORM"
