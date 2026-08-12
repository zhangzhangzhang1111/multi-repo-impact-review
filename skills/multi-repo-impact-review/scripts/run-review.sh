#!/bin/sh
set -eu

SKILL_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PLUGIN_ROOT=$(CDPATH= cd -- "$SKILL_DIR/../.." && pwd)
CBM_LAUNCHER="$PLUGIN_ROOT/runtime/launch-mcp.sh"
PROJECT_MAP="$PLUGIN_ROOT/project-packs/project-map.tsv"

REPO=""
BASE="HEAD~1"
HEAD_REF="HEAD"
OUT=""
DEPTH=2
NODE_BUDGET=120
TRACE_LIMIT=30
REBUILD_GRAPH=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) REPO=$2; shift 2 ;;
    --base) BASE=$2; shift 2 ;;
    --head) HEAD_REF=$2; shift 2 ;;
    --out) OUT=$2; shift 2 ;;
    --depth) DEPTH=$2; shift 2 ;;
    --node-budget) NODE_BUDGET=$2; shift 2 ;;
    --trace-limit) TRACE_LIMIT=$2; shift 2 ;;
    --rebuild-graph) REBUILD_GRAPH=1; shift ;;
    --path) echo "FATAL: --path is not supported by codebase-memory-mcp detect_changes; review a scoped checkout instead" >&2; exit 2 ;;
    *) echo "FATAL: unknown option $1" >&2; exit 2 ;;
  esac
done

[ -n "$REPO" ] || { echo "FATAL: --repo is required" >&2; exit 2; }
[ -n "$OUT" ] || { echo "FATAL: --out is required and must be outside the reviewed repository" >&2; exit 2; }
[ -x "$CBM_LAUNCHER" ] || { echo "FATAL: missing bundled codebase-memory-mcp launcher" >&2; exit 1; }
command -v git >/dev/null 2>&1 || { echo "FATAL: git is required" >&2; exit 1; }

case "$DEPTH" in *[!0-9]*|'') echo "FATAL: depth must be an integer" >&2; exit 2 ;; esac
case "$NODE_BUDGET" in *[!0-9]*|'') echo "FATAL: node budget must be an integer" >&2; exit 2 ;; esac
case "$TRACE_LIMIT" in *[!0-9]*|'') echo "FATAL: trace limit must be an integer" >&2; exit 2 ;; esac
[ "$DEPTH" -ge 1 ] && [ "$DEPTH" -le 4 ] || { echo "FATAL: depth must be between 1 and 4" >&2; exit 2; }
[ "$NODE_BUDGET" -ge 1 ] && [ "$NODE_BUDGET" -le 400 ] || { echo "FATAL: node budget must be between 1 and 400" >&2; exit 2; }
[ "$TRACE_LIMIT" -ge 1 ] && [ "$TRACE_LIMIT" -le 100 ] || { echo "FATAL: trace limit must be between 1 and 100" >&2; exit 2; }

REPO_ROOT=$(CDPATH= cd -- "$(git -C "$REPO" rev-parse --show-toplevel)" && pwd)
mkdir -p "$OUT"
OUT=$(CDPATH= cd -- "$OUT" && pwd)
case "$OUT/" in "$REPO_ROOT/"*) echo "FATAL: output must be outside the reviewed repository" >&2; exit 2 ;; esac

SHADOW="$OUT/analysis-source"
[ ! -e "$SHADOW" ] || { echo "FATAL: output already contains analysis-source; use a new output directory" >&2; exit 2; }
BASE_SHA=$(git -C "$REPO_ROOT" rev-parse "$BASE")
HEAD_SHA=$(git -C "$REPO_ROOT" rev-parse "$HEAD_REF")
CURRENT_SHA=$(git -C "$REPO_ROOT" rev-parse HEAD)
HEAD_SHORT=$(printf '%s' "$HEAD_SHA" | cut -c1-12)
REMOTE=$(git -C "$REPO_ROOT" remote get-url origin 2>/dev/null || printf '%s' "$REPO_ROOT")

DIRTY=0
git -C "$REPO_ROOT" diff --quiet || DIRTY=1
git -C "$REPO_ROOT" diff --cached --quiet || DIRTY=1
[ -z "$(git -C "$REPO_ROOT" ls-files --others --exclude-standard)" ] || DIRTY=1
if [ "$DIRTY" -eq 1 ] && [ "$HEAD_SHA" != "$CURRENT_SHA" ]; then
  echo "FATAL: dirty worktree can only be reviewed with --head HEAD/WORKTREE" >&2
  exit 2
fi

git clone --quiet --no-hardlinks --no-checkout "$REPO_ROOT" "$SHADOW"
git -C "$SHADOW" checkout --quiet --detach "$HEAD_SHA"

if [ "$DIRTY" -eq 1 ]; then
  PATCH_FILE="$OUT/worktree.patch"
  git -C "$REPO_ROOT" diff HEAD --binary --output="$PATCH_FILE"
  if [ -s "$PATCH_FILE" ]; then
    git -C "$SHADOW" apply --whitespace=nowarn "$PATCH_FILE"
  fi
  git -C "$REPO_ROOT" ls-files --others --exclude-standard > "$OUT/untracked-files.txt"
  while IFS= read -r FILE; do
    [ -n "$FILE" ] || continue
    mkdir -p "$SHADOW/$(dirname "$FILE")"
    cp "$REPO_ROOT/$FILE" "$SHADOW/$FILE"
  done < "$OUT/untracked-files.txt"
fi

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

cbm_to_file() {
  CBM_OUTPUT=$1
  shift
  CBM_ATTEMPT=1
  while [ "$CBM_ATTEMPT" -le 3 ]; do
    if CBM_LOG_LEVEL=error "$CBM_LAUNCHER" "$@" > "$CBM_OUTPUT.tmp"; then
      mv "$CBM_OUTPUT.tmp" "$CBM_OUTPUT"
      return 0
    fi
    rm -f "$CBM_OUTPUT.tmp"
    if [ "$CBM_ATTEMPT" -lt 3 ]; then
      echo "WARN: codebase-memory-mcp query not ready; retrying ($CBM_ATTEMPT/3)" >&2
      sleep 1
    fi
    CBM_ATTEMPT=$((CBM_ATTEMPT + 1))
  done
  echo "FATAL: codebase-memory-mcp failed after 3 attempts: $*" >&2
  return 1
}

MATCHES="$OUT/.matches.jsonl"
IGNORE_FILES="$OUT/.cbmignore-files"
: > "$MATCHES"
: > "$IGNORE_FILES"
BEST_PROJECT_ID=""
BEST_PROJECT_PRIORITY=-1
TAB=$(printf '\t')
sed '1d' "$PROJECT_MAP" | while IFS="$TAB" read -r KIND ID PRIORITY REMOTE_GLOB PATH_GLOB MARKERS KNOWLEDGE IGNORE_FILE; do
  IDENTITY_OK=0
  if [ "$REMOTE_GLOB" = "*" ] && [ "$PATH_GLOB" = "*" ]; then
    IDENTITY_OK=1
  else
    if [ "$REMOTE_GLOB" != "*" ]; then
      case "$REMOTE" in $REMOTE_GLOB) IDENTITY_OK=1 ;; esac
    fi
    if [ "$PATH_GLOB" != "*" ]; then
      case "$REPO_ROOT" in $PATH_GLOB) IDENTITY_OK=1 ;; esac
    fi
  fi
  MARKERS_OK=1
  if [ "$MARKERS" != "*" ]; then
    OLD_IFS=$IFS
    IFS=','
    for MARKER in $MARKERS; do
      [ -e "$REPO_ROOT/$MARKER" ] || MARKERS_OK=0
    done
    IFS=$OLD_IFS
  fi
  if [ "$IDENTITY_OK" -eq 1 ] && [ "$MARKERS_OK" -eq 1 ]; then
    printf '{"kind":"%s","id":"%s","priority":%s,"knowledge":"%s"}\n' \
      "$(json_escape "$KIND")" "$(json_escape "$ID")" "$PRIORITY" "$(json_escape "$KNOWLEDGE")" >> "$MATCHES"
    if [ -n "$IGNORE_FILE" ] && [ "$IGNORE_FILE" != "-" ]; then
      printf '%s\n' "$IGNORE_FILE" >> "$IGNORE_FILES"
    fi
    if [ "$KIND" = "project" ] && [ "$PRIORITY" -gt "$BEST_PROJECT_PRIORITY" ]; then
      printf '%s\t%s\n' "$PRIORITY" "$ID" > "$OUT/.best-project"
    fi
  fi
done

if [ -s "$OUT/.best-project" ]; then
  BEST_PROJECT_PRIORITY=$(cut -f1 "$OUT/.best-project")
  BEST_PROJECT_ID=$(cut -f2 "$OUT/.best-project")
fi

{
  printf '{\n  "schemaVersion": 2,\n'
  printf '  "root": "%s",\n' "$(json_escape "$REPO_ROOT")"
  printf '  "analysisRoot": "%s",\n' "$(json_escape "$SHADOW")"
  printf '  "remote": "%s",\n' "$(json_escape "$REMOTE")"
  printf '  "commit": "%s",\n  "matches": [' "$HEAD_SHA"
  FIRST=1
  while IFS= read -r ENTRY; do
    [ -n "$ENTRY" ] || continue
    [ "$FIRST" -eq 1 ] || printf ','
    printf '\n    %s' "$ENTRY"
    FIRST=0
  done < "$MATCHES"
  [ "$FIRST" -eq 1 ] || printf '\n  '
  printf ']\n}\n'
} > "$OUT/project-detection.json"

if [ -s "$IGNORE_FILES" ]; then
  : > "$SHADOW/.cbmignore"
  while IFS= read -r IGNORE_FILE; do
    [ -f "$PLUGIN_ROOT/$IGNORE_FILE" ] || { echo "FATAL: missing configured cbmignore $IGNORE_FILE" >&2; exit 1; }
    sed -n 'p' "$PLUGIN_ROOT/$IGNORE_FILE" >> "$SHADOW/.cbmignore"
  done < "$IGNORE_FILES"
  printf '.cbmignore\n.codebase-memory/\n' >> "$SHADOW/.git/info/exclude"
fi

ROOT_SUM=$(printf '%s' "$REPO_ROOT" | cksum | awk '{print $1}')
if [ -n "$BEST_PROJECT_ID" ]; then
  CBM_PROJECT="$BEST_PROJECT_ID-$HEAD_SHORT"
else
  REPO_NAME=$(basename "$REPO_ROOT" | tr -cs 'A-Za-z0-9._-' '-')
  CBM_PROJECT="$REPO_NAME-$HEAD_SHORT-$ROOT_SUM"
fi

PACKAGED_GRAPH=""
if [ "$REBUILD_GRAPH" -eq 0 ] && [ "$DIRTY" -eq 0 ] && [ -n "$BEST_PROJECT_ID" ]; then
  CANDIDATE="$PLUGIN_ROOT/project-packs/projects/$BEST_PROJECT_ID/codebase-memory/$HEAD_SHA/graph.db.zst"
  if [ -s "$CANDIDATE" ]; then
    mkdir -p "$SHADOW/.codebase-memory"
    cp "$CANDIDATE" "$SHADOW/.codebase-memory/graph.db.zst"
    PACKAGED_GRAPH="$CANDIDATE"
  fi
fi

mkdir -p "$OUT/graph"
cbm_to_file "$OUT/graph/index-result.json" cli index_repository \
  --repo-path "$SHADOW" --mode full --name "$CBM_PROJECT" --persistence true
cbm_to_file "$OUT/graph/schema.json" cli get_graph_schema --project "$CBM_PROJECT"
cbm_to_file "$OUT/graph/index-status.json" cli index_status --project "$CBM_PROJECT"
cbm_to_file "$OUT/impact-review.json" cli detect_changes --project "$CBM_PROJECT" \
  --since "$BASE_SHA" --direction inbound --depth "$DEPTH" --limit "$NODE_BUDGET" --format json

[ -s "$SHADOW/.codebase-memory/graph.db.zst" ] || { echo "FATAL: official graph artifact was not produced" >&2; exit 1; }
cp "$SHADOW/.codebase-memory/graph.db.zst" "$OUT/graph/graph.db.zst"
[ ! -f "$SHADOW/.codebase-memory/artifact.json" ] || cp "$SHADOW/.codebase-memory/artifact.json" "$OUT/graph/artifact.json"

{
  git -C "$SHADOW" diff --name-only "$BASE_SHA"...HEAD
  git -C "$SHADOW" diff --name-only HEAD
  git -C "$SHADOW" ls-files --others --exclude-standard
} | sort -u | sed '/^$/d' > "$OUT/changed-files.txt"

{
  printf '# AI verification packet\n\n'
  printf -- '- Graph engine: codebase-memory-mcp 0.10.2\n'
  printf -- '- Project: `%s`\n' "$CBM_PROJECT"
  printf -- '- Effective depth: %s (hard maximum 4)\n' "$DEPTH"
  printf -- '- Per-trace row budget: %s\n' "$TRACE_LIMIT"
  printf -- '- Global unique-node budget: %s\n' "$NODE_BUDGET"
  printf -- '- Packaged graph reused: %s\n\n' "${PACKAGED_GRAPH:-no}"
  printf '## Changed-file symbol candidates\n'
  while IFS= read -r FILE; do
    [ -n "$FILE" ] || continue
    printf '\n### `%s`\n\n```text\n' "$FILE"
    CBM_LOG_LEVEL=error "$CBM_LAUNCHER" cli search_graph --project "$CBM_PROJECT" \
      --file-pattern "$FILE" --limit "$TRACE_LIMIT" --format tree || true
    printf '```\n\nCoverage:\n\n```text\n'
    CBM_LOG_LEVEL=error "$CBM_LAUNCHER" cli check_index_coverage --project "$CBM_PROJECT" \
      --paths "$FILE" || true
    printf '```\n'
  done < "$OUT/changed-files.txt"
  printf '\n## Required AI action\n\n'
  printf 'For each prioritized changed symbol, call `trace_path` first at depth 1 with `include_evidence=true`; expand one level at a time only while within the recorded budgets. Verify every retained edge against source and add missing dynamic or C/C++-Lua binding edges.\n'
} > "$OUT/verification-packet.md"

cat > "$OUT/analysis-metadata.json" <<EOF
{
  "schemaVersion": 2,
  "engine": {"name": "codebase-memory-mcp", "version": "0.10.2", "license": "MIT"},
  "sourceRoot": "$(json_escape "$REPO_ROOT")",
  "analysisRoot": "$(json_escape "$SHADOW")",
  "project": "$(json_escape "$CBM_PROJECT")",
  "base": "$BASE_SHA",
  "head": "$HEAD_SHA",
  "requestedDepth": $DEPTH,
  "effectiveDepth": $DEPTH,
  "hardDepthLimit": 4,
  "perTraceRowBudget": $TRACE_LIMIT,
  "globalUniqueNodeBudget": $NODE_BUDGET,
  "graphArtifact": "graph/graph.db.zst",
  "targetRepositoryModified": false
}
EOF

{
  printf '# Deterministic pre-review summary\n\n'
  printf -- '- Engine: codebase-memory-mcp 0.10.2 (MIT)\n'
  printf -- '- Source commit: `%s`\n' "$HEAD_SHA"
  printf -- '- Changed files: %s\n' "$(wc -l < "$OUT/changed-files.txt" | tr -d ' ')"
  printf -- '- Traversal: depth %s, per trace %s rows, global %s unique nodes\n' "$DEPTH" "$TRACE_LIMIT" "$NODE_BUDGET"
  printf -- '- AI source verification: required\n'
} > "$OUT/summary.md"

rm -f "$MATCHES" "$IGNORE_FILES" "$OUT/.best-project"
echo "OK: codebase-memory-mcp review artifacts written to $OUT"
