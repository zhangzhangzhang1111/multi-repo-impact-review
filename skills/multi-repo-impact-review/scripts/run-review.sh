#!/bin/sh
set -eu

SKILL_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
if [ -f "$SKILL_DIR/project-packs/project-map.tsv" ]; then
  PACKAGE_ROOT=$SKILL_DIR
else
  PACKAGE_ROOT=$(CDPATH= cd -- "$SKILL_DIR/../.." && pwd)
fi

CBM_LAUNCHER="$PACKAGE_ROOT/runtime/launch-engine.sh"
PROJECT_MAP="$PACKAGE_ROOT/project-packs/project-map.tsv"
DIFF_NORMALIZER="$SKILL_DIR/scripts/normalize-diff.awk"
REPORT_TEMPLATE="$SKILL_DIR/assets/report-template.md"

TASK_ROOT=""
REPO=""
OUT=""
REPORT_DIR=""
MODE=""
DIFF_FILE=""
BASE=""
HEAD_REF=""
PROJECT_ID=""
REPOSITORY_ID=""
DEPTH=2
NODE_BUDGET=120
TRACE_LIMIT=30
REBUILD_GRAPH=0

usage() {
  cat <<'USAGE'
Usage:
  run-review.sh --task-root <task_id_dir> [--mode auto|git|patch]
  run-review.sh --repo <path> --out <codegraph_dir> [--mode git|patch] [options]

Options:
  --diff <file>         Unified diff for patch mode
  --base <ref>          Git base ref (default HEAD~1)
  --head <ref>          Git head ref (default HEAD; WORKTREE is accepted)
  --report <dir>        Report directory
  --project-id <id>     Force a project knowledge pack
  --repository <id>     Original Git URL/name for archive routing
  --depth <1..4>        Call-chain depth (default 2)
  --node-budget <n>     Global unique-node budget (default 120, max 400)
  --trace-limit <n>     Rows per trace/search (default 30, max 100)
  --rebuild-graph       Ignore a packaged baseline graph
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --task-root) TASK_ROOT=$2; shift 2 ;;
    --repo) REPO=$2; shift 2 ;;
    --out) OUT=$2; shift 2 ;;
    --report) REPORT_DIR=$2; shift 2 ;;
    --mode) MODE=$2; shift 2 ;;
    --diff) DIFF_FILE=$2; shift 2 ;;
    --base) BASE=$2; shift 2 ;;
    --head) HEAD_REF=$2; shift 2 ;;
    --project-id) PROJECT_ID=$2; shift 2 ;;
    --repository) REPOSITORY_ID=$2; shift 2 ;;
    --depth) DEPTH=$2; shift 2 ;;
    --node-budget) NODE_BUDGET=$2; shift 2 ;;
    --trace-limit) TRACE_LIMIT=$2; shift 2 ;;
    --rebuild-graph) REBUILD_GRAPH=1; shift ;;
    --help|-h) usage; exit 0 ;;
    --path) echo "FATAL: --path is unsupported; provide a scoped repo/ snapshot instead" >&2; exit 2 ;;
    *) echo "FATAL: unknown option $1" >&2; usage >&2; exit 2 ;;
  esac
done

json_field() {
  JSON_FILE=$1
  JSON_KEY=$2
  [ -f "$JSON_FILE" ] || return 0
  sed -n 's/.*"'"$JSON_KEY"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$JSON_FILE" | sed -n '1p'
}

normalize_repository() {
  VALUE=$1
  VALUE=${VALUE%/}
  VALUE=${VALUE%.git}
  case "$VALUE" in
    *://*) VALUE=${VALUE#*://}; case "$VALUE" in *@*) VALUE=${VALUE#*@} ;; esac ;;
    *@*:*) VALUE=${VALUE#*@}; HOST=${VALUE%%:*}; PATH_PART=${VALUE#*:}; VALUE="$HOST/$PATH_PART" ;;
  esac
  printf '%s' "$VALUE"
}

resolve_from_task() {
  [ -n "$TASK_ROOT" ] || return 0
  TASK_ROOT=$(CDPATH= cd -- "$TASK_ROOT" && pwd)
  TASK_JSON="$TASK_ROOT/task.json"

  if [ -z "$REPO" ]; then
    CONFIG_REPO=$(json_field "$TASK_JSON" sourceDirectory)
    [ -n "$CONFIG_REPO" ] || CONFIG_REPO=$(json_field "$TASK_JSON" source_directory)
    REPO=${CONFIG_REPO:-repo}
    case "$REPO" in /*) ;; *) REPO="$TASK_ROOT/$REPO" ;; esac
  fi
  [ -n "$OUT" ] || OUT="$TASK_ROOT/codegraph"
  [ -n "$REPORT_DIR" ] || REPORT_DIR="$TASK_ROOT/report"
  if [ -z "$DIFF_FILE" ]; then
    CONFIG_DIFF=$(json_field "$TASK_JSON" diffFile)
    [ -n "$CONFIG_DIFF" ] || CONFIG_DIFF=$(json_field "$TASK_JSON" diff_file)
    DIFF_FILE=${CONFIG_DIFF:-diff/changes.diff}
    case "$DIFF_FILE" in /*) ;; *) DIFF_FILE="$TASK_ROOT/$DIFF_FILE" ;; esac
  fi
  if [ -z "$MODE" ]; then
    MODE=$(json_field "$TASK_JSON" changeMode)
    [ -n "$MODE" ] || MODE=$(json_field "$TASK_JSON" change_mode)
  fi
  if [ -z "$BASE" ]; then
    BASE=$(json_field "$TASK_JSON" baseRef)
    [ -n "$BASE" ] || BASE=$(json_field "$TASK_JSON" base_ref)
    [ -n "$BASE" ] || BASE=$(json_field "$TASK_JSON" baseCommit)
  fi
  if [ -z "$HEAD_REF" ]; then
    HEAD_REF=$(json_field "$TASK_JSON" headRef)
    [ -n "$HEAD_REF" ] || HEAD_REF=$(json_field "$TASK_JSON" head_ref)
    [ -n "$HEAD_REF" ] || HEAD_REF=$(json_field "$TASK_JSON" headCommit)
  fi
  if [ -z "$PROJECT_ID" ]; then
    PROJECT_ID=$(json_field "$TASK_JSON" projectId)
    [ -n "$PROJECT_ID" ] || PROJECT_ID=$(json_field "$TASK_JSON" project_id)
  fi
  if [ -z "$REPOSITORY_ID" ]; then REPOSITORY_ID=$(json_field "$TASK_JSON" repository); fi
}

resolve_from_task
[ -n "$REPO" ] || { echo "FATAL: --task-root or --repo is required" >&2; exit 2; }
[ -n "$OUT" ] || { echo "FATAL: --out is required when --task-root is not used" >&2; exit 2; }
[ -d "$REPO" ] || { echo "FATAL: source directory does not exist: $REPO" >&2; exit 2; }
[ -x "$CBM_LAUNCHER" ] || { echo "FATAL: missing bundled graph-engine launcher: $CBM_LAUNCHER" >&2; exit 1; }
[ -f "$PROJECT_MAP" ] || { echo "FATAL: missing project routing map" >&2; exit 1; }
[ -f "$DIFF_NORMALIZER" ] || { echo "FATAL: missing diff normalizer" >&2; exit 1; }

case "$DEPTH" in *[!0-9]*|'') echo "FATAL: depth must be an integer" >&2; exit 2 ;; esac
case "$NODE_BUDGET" in *[!0-9]*|'') echo "FATAL: node budget must be an integer" >&2; exit 2 ;; esac
case "$TRACE_LIMIT" in *[!0-9]*|'') echo "FATAL: trace limit must be an integer" >&2; exit 2 ;; esac
[ "$DEPTH" -ge 1 ] && [ "$DEPTH" -le 4 ] || { echo "FATAL: depth must be between 1 and 4" >&2; exit 2; }
[ "$NODE_BUDGET" -ge 1 ] && [ "$NODE_BUDGET" -le 400 ] || { echo "FATAL: node budget must be between 1 and 400" >&2; exit 2; }
[ "$TRACE_LIMIT" -ge 1 ] && [ "$TRACE_LIMIT" -le 100 ] || { echo "FATAL: trace limit must be between 1 and 100" >&2; exit 2; }

REPO_ROOT=$(CDPATH= cd -- "$REPO" && pwd)
if [ -z "$MODE" ] || [ "$MODE" = "auto" ]; then
  if [ -n "$DIFF_FILE" ] && [ -s "$DIFF_FILE" ]; then MODE=patch
  elif [ -d "$REPO_ROOT/.git" ]; then MODE=git
  else echo "FATAL: auto mode found neither diff/changes.diff nor repo/.git" >&2; exit 2
  fi
fi
case "$MODE" in git|patch) ;; *) echo "FATAL: mode must be auto, git, or patch" >&2; exit 2 ;; esac

if [ "$MODE" = "patch" ]; then
  [ -n "$DIFF_FILE" ] && [ -s "$DIFF_FILE" ] || { echo "FATAL: patch mode requires a non-empty changes.diff" >&2; exit 2; }
fi
if [ "$MODE" = "git" ]; then
  BASE=${BASE:-HEAD~1}
  HEAD_REF=${HEAD_REF:-HEAD}
  [ "$HEAD_REF" != "WORKTREE" ] || HEAD_REF=HEAD
  command -v git >/dev/null 2>&1 || { echo "FATAL: git mode requires git" >&2; exit 1; }
  REPO_ROOT=$(CDPATH= cd -- "$(git -C "$REPO_ROOT" rev-parse --show-toplevel)" && pwd)
fi

mkdir -p "$OUT"
OUT=$(CDPATH= cd -- "$OUT" && pwd)
case "$OUT/" in "$REPO_ROOT/"*) echo "FATAL: codegraph output must be outside repo/" >&2; exit 2 ;; esac
[ -n "$REPORT_DIR" ] || REPORT_DIR="$OUT/report"
mkdir -p "$REPORT_DIR"
REPORT_DIR=$(CDPATH= cd -- "$REPORT_DIR" && pwd)

SHADOW="$OUT/analysis-source"
[ ! -e "$SHADOW" ] || { echo "FATAL: $SHADOW already exists; use an empty codegraph directory" >&2; exit 2; }
SOURCE_DIFF="$OUT/changes.diff"
CHANGED_FILES="$OUT/changed-files.txt"
CHANGES_JSON="$OUT/changes.json"
DIRTY=0
BASE_SHA=""
HEAD_SHA=""
REMOTE=${REPOSITORY_ID:-$REPO_ROOT}

if [ "$MODE" = "git" ]; then
  BASE_SHA=$(git -C "$REPO_ROOT" rev-parse "$BASE")
  HEAD_SHA=$(git -C "$REPO_ROOT" rev-parse "$HEAD_REF")
  CURRENT_SHA=$(git -C "$REPO_ROOT" rev-parse HEAD)
  [ -n "$REPOSITORY_ID" ] || REMOTE=$(git -C "$REPO_ROOT" remote get-url origin 2>/dev/null || printf '%s' "$REPO_ROOT")
  git -C "$REPO_ROOT" diff --quiet || DIRTY=1
  git -C "$REPO_ROOT" diff --cached --quiet || DIRTY=1
  [ -z "$(git -C "$REPO_ROOT" ls-files --others --exclude-standard)" ] || DIRTY=1
  if [ "$DIRTY" -eq 1 ] && [ "$HEAD_SHA" != "$CURRENT_SHA" ]; then
    echo "FATAL: a dirty worktree can only be reviewed at HEAD/WORKTREE" >&2
    exit 2
  fi

  git clone --quiet --no-hardlinks --no-checkout "$REPO_ROOT" "$SHADOW"
  git -C "$SHADOW" checkout --quiet --detach "$HEAD_SHA"
  if [ "$DIRTY" -eq 1 ]; then
    WORKTREE_PATCH="$OUT/.worktree.patch"
    git -C "$REPO_ROOT" diff HEAD --binary --output="$WORKTREE_PATCH"
    [ ! -s "$WORKTREE_PATCH" ] || git -C "$SHADOW" apply --whitespace=nowarn "$WORKTREE_PATCH"
    git -C "$REPO_ROOT" ls-files --others --exclude-standard > "$OUT/.untracked-files"
    while IFS= read -r FILE; do
      [ -n "$FILE" ] || continue
      mkdir -p "$SHADOW/$(dirname "$FILE")"
      cp "$REPO_ROOT/$FILE" "$SHADOW/$FILE"
      git -C "$SHADOW" add -N -- "$FILE"
    done < "$OUT/.untracked-files"
  fi
  git -C "$SHADOW" diff --binary "$BASE_SHA" -- > "$SOURCE_DIFF"
  awk -v source=git -v base="$BASE_SHA" -v head="$HEAD_SHA" -v diff_file="changes.diff" -v list_file="$CHANGED_FILES" -f "$DIFF_NORMALIZER" "$SOURCE_DIFF" > "$CHANGES_JSON"
else
  mkdir "$SHADOW"
  cp -R "$REPO_ROOT/." "$SHADOW/"
  rm -rf "$SHADOW/.codebase-memory"
  cp "$DIFF_FILE" "$SOURCE_DIFF"
  PATCH_SUM=$(cksum "$SOURCE_DIFF" | awk '{print $1}')
  BASE_SHA=${BASE:-unknown-base}
  HEAD_SHA=${HEAD_REF:-snapshot-$PATCH_SUM}
  awk -v source=patch -v base="$BASE_SHA" -v head="$HEAD_SHA" -v diff_file="changes.diff" -v list_file="$CHANGED_FILES" -f "$DIFF_NORMALIZER" "$SOURCE_DIFF" > "$CHANGES_JSON"
fi
REMOTE=$(normalize_repository "$REMOTE")

sort -u "$CHANGED_FILES" -o "$CHANGED_FILES"
[ -s "$CHANGED_FILES" ] || { echo "FATAL: no changed files could be parsed from $SOURCE_DIFF" >&2; exit 2; }
if [ -d "$SHADOW/.git/info" ]; then
  printf '.codebase-memory/\n' >> "$SHADOW/.git/info/exclude"
fi

json_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

cbm_to_file() {
  CBM_OUTPUT=$1; shift; CBM_ATTEMPT=1
  while [ "$CBM_ATTEMPT" -le 3 ]; do
    if CBM_LOG_LEVEL=error "$CBM_LAUNCHER" "$@" > "$CBM_OUTPUT.tmp"; then mv "$CBM_OUTPUT.tmp" "$CBM_OUTPUT"; return 0; fi
    rm -f "$CBM_OUTPUT.tmp"
    if [ "$CBM_ATTEMPT" -lt 3 ]; then echo "WARN: graph query not ready; retrying ($CBM_ATTEMPT/3)" >&2; sleep 1; fi
    CBM_ATTEMPT=$((CBM_ATTEMPT + 1))
  done
  echo "FATAL: codebase-memory-mcp failed after 3 attempts: $*" >&2
  return 1
}

MATCHES="$OUT/.matches.jsonl"
IGNORE_FILES="$OUT/.cbmignore-files"
: > "$MATCHES"; : > "$IGNORE_FILES"
TAB=$(printf '\t')
sed '1d' "$PROJECT_MAP" | while IFS="$TAB" read -r KIND ID PRIORITY REMOTE_GLOB PATH_GLOB MARKERS KNOWLEDGE IGNORE_FILE; do
  IDENTITY_OK=0
  if [ "$REMOTE_GLOB" = "*" ] && [ "$PATH_GLOB" = "*" ]; then IDENTITY_OK=1
  else
    if [ "$REMOTE_GLOB" != "*" ]; then case "$REMOTE" in $REMOTE_GLOB) IDENTITY_OK=1 ;; esac; fi
    if [ "$PATH_GLOB" != "*" ]; then case "$REPO_ROOT" in $PATH_GLOB) IDENTITY_OK=1 ;; esac; fi
  fi
  if [ -n "$PROJECT_ID" ] && [ "$KIND" = "project" ] && [ "$ID" != "$PROJECT_ID" ]; then IDENTITY_OK=0; fi
  if [ -n "$PROJECT_ID" ] && [ "$KIND" = "project" ] && [ "$ID" = "$PROJECT_ID" ]; then IDENTITY_OK=1; fi
  MARKERS_OK=1
  if [ "$MARKERS" != "*" ]; then
    OLD_IFS=$IFS; IFS=','
    for MARKER in $MARKERS; do [ -e "$REPO_ROOT/$MARKER" ] || MARKERS_OK=0; done
    IFS=$OLD_IFS
  fi
  if [ "$IDENTITY_OK" -eq 1 ] && [ "$MARKERS_OK" -eq 1 ]; then
    printf '{"kind":"%s","id":"%s","priority":%s,"knowledge":"%s"}\n' "$(json_escape "$KIND")" "$(json_escape "$ID")" "$PRIORITY" "$(json_escape "$KNOWLEDGE")" >> "$MATCHES"
    if [ -n "$IGNORE_FILE" ] && [ "$IGNORE_FILE" != "-" ]; then printf '%s\n' "$IGNORE_FILE" >> "$IGNORE_FILES"; fi
    if [ "$KIND" = "project" ]; then printf '%s\t%s\n' "$PRIORITY" "$ID" >> "$OUT/.project-candidates"; fi
  fi
done

BEST_PROJECT_ID=""
if [ -s "$OUT/.project-candidates" ]; then
  sort -rn "$OUT/.project-candidates" | sed -n '1p' > "$OUT/.best-project"
  BEST_PROJECT_ID=$(cut -f2 "$OUT/.best-project")
fi
if [ -n "$PROJECT_ID" ] && [ "$BEST_PROJECT_ID" != "$PROJECT_ID" ]; then
  echo "FATAL: project pack '$PROJECT_ID' did not match its required marker files" >&2
  exit 2
fi

{
  printf '{\n  "schemaVersion": 3,\n'
  printf '  "changeMode": "%s",\n' "$(json_escape "$MODE")"
  printf '  "root": "%s",\n' "$(json_escape "$REPO_ROOT")"
  printf '  "analysisRoot": "%s",\n' "$(json_escape "$SHADOW")"
  printf '  "repository": "%s",\n' "$(json_escape "$REMOTE")"
  printf '  "head": "%s",\n  "matches": [' "$(json_escape "$HEAD_SHA")"
  FIRST=1
  while IFS= read -r ENTRY; do
    [ -n "$ENTRY" ] || continue
    [ "$FIRST" -eq 1 ] || printf ','
    printf '\n    %s' "$ENTRY"; FIRST=0
  done < "$MATCHES"
  [ "$FIRST" -eq 1 ] || printf '\n  '
  printf ']\n}\n'
} > "$OUT/project-detection.json"

if [ -s "$IGNORE_FILES" ]; then
  : > "$SHADOW/.cbmignore"
  while IFS= read -r IGNORE_FILE; do
    [ -f "$PACKAGE_ROOT/$IGNORE_FILE" ] || { echo "FATAL: missing configured cbmignore $IGNORE_FILE" >&2; exit 1; }
    sed -n 'p' "$PACKAGE_ROOT/$IGNORE_FILE" >> "$SHADOW/.cbmignore"
  done < "$IGNORE_FILES"
  if [ -d "$SHADOW/.git/info" ]; then printf '.cbmignore\n' >> "$SHADOW/.git/info/exclude"; fi
fi

ROOT_SUM=$(printf '%s' "$REPO_ROOT" | cksum | awk '{print $1}')
HEAD_SHORT=$(printf '%s' "$HEAD_SHA" | tr -cs 'A-Za-z0-9' '-' | cut -c1-12)
[ -n "$HEAD_SHORT" ] || HEAD_SHORT=snapshot
if [ -n "$BEST_PROJECT_ID" ]; then CBM_PROJECT="$BEST_PROJECT_ID-$HEAD_SHORT-$ROOT_SUM"
else REPO_BASENAME=$(basename "$REPO_ROOT"); REPO_NAME=$(printf '%s' "$REPO_BASENAME" | tr -cs 'A-Za-z0-9._-' '-'); CBM_PROJECT="$REPO_NAME-$HEAD_SHORT-$ROOT_SUM"
fi

PACKAGED_GRAPH=""
if [ "$MODE" = "git" ] && [ "$REBUILD_GRAPH" -eq 0 ] && [ "$DIRTY" -eq 0 ] && [ -n "$BEST_PROJECT_ID" ]; then
  CANDIDATE="$PACKAGE_ROOT/project-packs/projects/$BEST_PROJECT_ID/codebase-memory/$HEAD_SHA/graph.db.zst"
  if [ -s "$CANDIDATE" ]; then mkdir -p "$SHADOW/.codebase-memory"; cp "$CANDIDATE" "$SHADOW/.codebase-memory/graph.db.zst"; PACKAGED_GRAPH="$CANDIDATE"; fi
fi

cbm_to_file "$OUT/index-result.json" cli index_repository --repo-path "$SHADOW" --mode full --name "$CBM_PROJECT" --persistence true
cbm_to_file "$OUT/schema.json" cli get_graph_schema --project "$CBM_PROJECT"
cbm_to_file "$OUT/index-status.json" cli index_status --project "$CBM_PROJECT"

if [ "$MODE" = "git" ]; then
  cbm_to_file "$OUT/official-impact-review.json" cli detect_changes --project "$CBM_PROJECT" --since "$BASE_SHA" --direction inbound --depth "$DEPTH" --limit "$NODE_BUDGET" --format json
  printf '{"schemaVersion":1,"changeSource":"git","strategy":"official-detect_changes-plus-ai-verification","officialResult":"official-impact-review.json"}\n' > "$OUT/impact-review.json"
else
  printf '{"schemaVersion":1,"changeSource":"patch","strategy":"diff-hunks-plus-search_graph-plus-bounded-trace_path","requiresAiTrace":true,"reason":"detect_changes requires Git history; current snapshot was indexed successfully"}\n' > "$OUT/impact-review.json"
fi

[ -s "$SHADOW/.codebase-memory/graph.db.zst" ] || { echo "FATAL: official graph artifact was not produced" >&2; exit 1; }
cp "$SHADOW/.codebase-memory/graph.db.zst" "$OUT/graph.db.zst"
[ ! -f "$SHADOW/.codebase-memory/artifact.json" ] || cp "$SHADOW/.codebase-memory/artifact.json" "$OUT/artifact.json"
printf '%s\n' "$CBM_PROJECT" > "$OUT/engine-project.txt"

mkdir -p "$OUT/symbol-candidates"
PACKET="$OUT/verification-packet.md"
{
  printf '# AI verification packet\n\n'
  printf -- '- Change source: `%s`\n' "$MODE"
  printf -- '- Graph engine: codebase-memory-mcp 0.10.2\n'
  printf -- '- Project: `%s`\n' "$CBM_PROJECT"
  printf -- '- Effective depth: %s (hard maximum 4)\n' "$DEPTH"
  printf -- '- Per-trace row budget: %s\n' "$TRACE_LIMIT"
  printf -- '- Global unique-node budget: %s\n' "$NODE_BUDGET"
  printf -- '- Packaged graph reused: %s\n\n' "${PACKAGED_GRAPH:-no}"
  printf '## Changed-file symbol candidates\n'
} > "$PACKET"

FILE_NUMBER=0
while IFS= read -r FILE; do
  [ -n "$FILE" ] || continue
  FILE_NUMBER=$((FILE_NUMBER + 1)); NUMBER=$(printf '%03d' "$FILE_NUMBER")
  SAFE_NAME=$(printf '%s' "$FILE" | tr '/\\ :' '----' | tr -cd 'A-Za-z0-9._-'); [ -n "$SAFE_NAME" ] || SAFE_NAME=file
  CANDIDATE_FILE="$OUT/symbol-candidates/$NUMBER-$SAFE_NAME.json"
  COVERAGE_FILE="$OUT/symbol-candidates/$NUMBER-$SAFE_NAME-coverage.json"
  cbm_to_file "$CANDIDATE_FILE" cli search_graph --project "$CBM_PROJECT" --file-pattern "$FILE" --limit "$TRACE_LIMIT" --format json || printf '{"results":[],"error":"search failed"}\n' > "$CANDIDATE_FILE"
  cbm_to_file "$COVERAGE_FILE" cli check_index_coverage --project "$CBM_PROJECT" --paths "$FILE" || printf '{"error":"coverage query failed"}\n' > "$COVERAGE_FILE"
  {
    printf '\n### `%s`\n\n' "$FILE"
    printf -- '- Symbol candidates: `%s`\n' "symbol-candidates/$(basename "$CANDIDATE_FILE")"
    printf -- '- Coverage: `%s`\n' "symbol-candidates/$(basename "$COVERAGE_FILE")"
  } >> "$PACKET"
done < "$CHANGED_FILES"

cat >> "$PACKET" <<'PACKET_END'

## Required AI action

1. Map each diff hunk in `changes.json` to the smallest current symbol that contains its new-line range. For deleted code, inspect the old side of `changes.diff` and mark the symbol deleted when it no longer exists in the snapshot.
2. For each prioritized changed symbol, call `trace_path` at depth 1 with `include_evidence=true`; expand one level at a time only while within the recorded budgets.
3. Read the cited source bodies and verify every retained edge. Add missing callback, configuration, function-pointer, macro, metatable, dynamic module, and C/C++-Lua binding edges.
4. Load the matched knowledge files from `project-detection.json`; use them only to interpret verified source facts.
5. Replace the draft under `report/review-report.md` with the human-facing result.
PACKET_END

{
  printf '{\n  "schemaVersion": 3,\n'
  printf '  "engine": {"name":"codebase-memory-mcp","version":"0.10.2","license":"MIT"},\n'
  printf '  "changeMode": "%s",\n' "$MODE"
  printf '  "sourceRoot": "%s",\n' "$(json_escape "$REPO_ROOT")"
  printf '  "analysisRoot": "%s",\n' "$(json_escape "$SHADOW")"
  printf '  "project": "%s",\n' "$(json_escape "$CBM_PROJECT")"
  printf '  "base": "%s",\n  "head": "%s",\n' "$(json_escape "$BASE_SHA")" "$(json_escape "$HEAD_SHA")"
  printf '  "requestedDepth": %s,\n  "effectiveDepth": %s,\n  "hardDepthLimit": 4,\n' "$DEPTH" "$DEPTH"
  printf '  "perTraceRowBudget": %s,\n  "globalUniqueNodeBudget": %s,\n' "$TRACE_LIMIT" "$NODE_BUDGET"
  printf '  "graphArtifact": "graph.db.zst",\n  "targetRepositoryModified": false\n}\n'
} > "$OUT/analysis-metadata.json"

{
  printf '# Deterministic pre-review summary\n\n'
  printf -- '- Change source: %s\n' "$MODE"
  printf -- '- Engine: codebase-memory-mcp 0.10.2 (MIT)\n'
  printf -- '- Base: `%s`\n' "$BASE_SHA"
  printf -- '- Head/snapshot: `%s`\n' "$HEAD_SHA"
  printf -- '- Changed files: %s\n' "$(wc -l < "$CHANGED_FILES" | tr -d ' ')"
  printf -- '- Traversal: depth %s, per trace %s rows, global %s unique nodes\n' "$DEPTH" "$TRACE_LIMIT" "$NODE_BUDGET"
  printf -- '- AI source verification and final report: required\n'
} > "$OUT/summary.md"

if [ ! -f "$REPORT_DIR/review-report.md" ]; then cp "$REPORT_TEMPLATE" "$REPORT_DIR/review-report.md"; fi
rm -f "$MATCHES" "$IGNORE_FILES" "$OUT/.best-project" "$OUT/.project-candidates" "$OUT/.worktree.patch" "$OUT/.untracked-files"
echo "OK: $MODE review evidence written to $OUT"
echo "NEXT: AI must verify call paths and complete $REPORT_DIR/review-report.md"
