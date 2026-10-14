# Task input

## Repository set

Resolve every repository before analysis. Record for each one:

- repository identity and exact source root;
- Git or patch mode;
- base/head refs and SHAs, or patch path;
- changed files and dirty-worktree scope;
- CodeGraph status and stale/pending files.

Run the CodeGraph preflight independently for every source root.

## Local Git checkout

Use each repository root as `projectPath`. Resolve requested base/head refs, include relevant dirty-worktree changes, and record the exact SHAs and diff command. When no base is specified, prefer the tracked default branch such as `origin/main` or `origin/master`.

## Remote Git URL

Only clone when the user explicitly supplies a Git URL. Use the requested branch and configured credentials; never embed credentials in the URL or task metadata. After cloning, treat the checkout as a local Git input.

## Extracted snapshot plus patch

Patch mode requires a current source directory and a `changes.diff` file. If the source directory contains one wrapper directory, select the unique child containing the changed paths. If no unique match exists, stop and ask for the source root.

Do not use Git-only change detection in patch mode. Normalize patch hunks, map them to current symbols, and report deleted-symbol evidence from the old side.

## Required preflight

For each root:

1. Resolve the exact source root.
2. Run `codegraph_status`.
3. If uninitialized, follow higher-priority repository instructions and the host permission mechanism; ask once if they require confirmation, otherwise run `codegraph init -i` directly, then re-check status.
4. Keep generated reports outside reviewed source. Repository-local `.codegraph` is the only analysis artifact allowed inside it.
