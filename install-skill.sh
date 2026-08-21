#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SOURCE="$ROOT/skills/multi-repo-impact-review"
TARGET=${1:-}

case "$TARGET" in
  codex|claude|both) ;;
  *) printf '%s\n' 'Usage: install-skill.sh codex|claude|both' >&2; exit 2 ;;
esac

CODEX_DIR=${CODEX_HOME:-"$HOME/.codex"}/skills/multi-repo-impact-review
CLAUDE_DIR=${CLAUDE_CONFIG_DIR:-${CLAUDE_HOME:-"$HOME/.claude"}}/skills/multi-repo-impact-review
INSTALLED=""

install_one() {
  HOST=$1
  DEST=$2
  [ ! -e "$DEST" ] || {
    printf '# Skill 安装结论\n\n- **结论：失败**\n- **原因：目标目录已存在** `%s`\n' "$DEST" >&2
    exit 2
  }
  mkdir -p "$(dirname "$DEST")"
  STAGING=$(mktemp -d "$(dirname "$DEST")/.impact-skill.XXXXXX")
  trap 'rm -rf "$STAGING"' EXIT HUP INT TERM
  cp -R "$SOURCE/." "$STAGING/"
  mv "$STAGING" "$DEST"
  trap - EXIT HUP INT TERM
  INSTALLED="${INSTALLED}\n- **${HOST}**：\`${DEST}\`"
}

case "$TARGET" in
  codex) install_one Codex "$CODEX_DIR" ;;
  claude) install_one Claude "$CLAUDE_DIR" ;;
  both)
    [ ! -e "$CODEX_DIR" ] && [ ! -e "$CLAUDE_DIR" ] || {
      printf '%s\n' '# Skill 安装结论' '' '- **结论：失败**' '- **原因：Codex 或 Claude 目标目录已存在，未执行复制。' >&2
      exit 2
    }
    install_one Codex "$CODEX_DIR"
    install_one Claude "$CLAUDE_DIR"
    ;;
esac

printf '# Skill 安装结论\n\n- **结论：成功**%b\n- **知识图谱环境：未安装、未下载、未修改**\n' "$INSTALLED"
