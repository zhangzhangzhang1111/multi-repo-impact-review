# Task input contract

## Standard directory

```text
task_id/
├── task.json
├── repo/
├── diff/
│   └── changes.diff
├── codegraph/
└── report/
```

`repo/` must contain the current source corresponding to the new side of `changes.diff`. It may be a full Git checkout or an extracted archive.

## task.json

All fields are optional because CLI flags take precedence:

```json
{
  "taskId": "TASK-123",
  "changeMode": "auto",
  "sourceDirectory": "repo",
  "diffFile": "diff/changes.diff",
  "repository": "ssh://git.example/team/scriptswtlua.git",
  "projectId": "scriptswtlua",
  "baseRef": "origin/main",
  "headRef": "HEAD"
}
```

- `changeMode`: `auto`, `git`, or `patch`.
- `repository`: optionally override the Git remote identity. Patch routing does not require it: TransMid uses changed paths and project-specific packs use the extracted project directory name.
- `projectId`: explicitly select a configured project pack when repository identity is unavailable. Marker files must still match.
- `baseRef` and `headRef`: Git refs in Git mode; optional provenance strings in patch mode.

## Precedence and detection

1. Explicit command-line values.
2. `task.json` values.
3. Standard directory defaults.

In `auto` mode, a non-empty configured diff selects patch mode even if `.git` exists. Without a diff, `.git` selects Git mode. Otherwise stop because there is no reliable change set.

In patch mode, `repo/` may be the source root or a container with one extracted project directory. The runner selects the unique immediate child containing the changed paths, so `repo/zy_all/Transmid/...` aligns with diff paths such as `Transmid/...`. Set `sourceDirectory` explicitly when more than one child matches.

## Output

`codegraph/` contains `changes.json`, copied `changes.diff`, the official `graph.db.zst`, graph/index evidence, symbol candidates, traversal instructions, and analysis metadata. `report/review-report.md` is a draft until the AI finishes source verification and writes the final human review.
