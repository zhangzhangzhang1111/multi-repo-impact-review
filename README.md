# Multi-Repo Impact Review

A Codex skill for impact-aware code review across one or more Git repositories or source snapshots. It uses the host's installed CodeGraph environment directly and verifies graph candidates against current source before reporting business impact or defects.

## Requirements

- Codex with CodeGraph tools available.
- The `codegraph` CLI on `PATH`.
- Git when reviewing repositories or remote branches.

The skill checks every source root with `codegraph_status`. When a root is not initialized, it runs `codegraph init -i` by default, while honoring higher-priority repository instructions and the host permission mechanism.

## Install

Install the skill folder from this branch:

```powershell
python <skill-installer>/install-skill-from-github.py `
  --repo zhangzhangzhang1111/multi-repo-impact-review `
  --ref agent/pure-skill-v2.1.0 `
  --path skills/multi-repo-impact-review
```

The installed directory is `$CODEX_HOME/skills/multi-repo-impact-review`.

## What it reviews

- Local Git branches, commits, and dirty worktrees.
- Explicit remote Git URLs and branches.
- Extracted current-source snapshots paired with `changes.diff`.
- Multi-repository API, message, configuration, generated-client, data-contract, and C/C++-Lua boundaries.

## Evidence workflow

The skill uses:

- `codegraph_status` for index health.
- `codegraph_context` for focused change-area context.
- `codegraph_search` for unresolved symbols.
- `codegraph_impact` for blast radius.
- `codegraph_trace` for concrete source-to-boundary paths.
- `codegraph_explore` for bounded source inspection.

Stale or pending files are read directly. Dynamic dispatch, cross-index joins, generated code, and other graph gaps remain explicit limitations until verified in current source.

## Validate

```powershell
node --test tests/skill-contract.test.mjs
```

The repository intentionally contains no bundled graph engine, portable graph database, vendor runtime, or package-manager dependency.
