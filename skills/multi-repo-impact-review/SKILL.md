---
name: multi-repo-impact-review
description: Review the current Git branch and its related business impact with an already configured codebase-memory-mcp knowledge graph. Use for C, C++, or Lua branch review, call-chain and blast-radius analysis, coding-standard checks, and a source-verified Markdown conclusion.
compatibility: Requires a current Git checkout and configured codebase-memory-mcp graph tools.
---

# Multi-Repo Impact Review

Use the environment's existing knowledge-graph tools. Do not install, download, vendor, register, or reconfigure `codebase-memory-mcp`.

## Review workflow

1. Resolve the current repository with `git rev-parse --show-toplevel` and current branch with `git branch --show-current`. If the directory is not a Git checkout or HEAD is detached, produce a Markdown `无法完成` conclusion instead of switching branches or inventing a change set.
2. Select the baseline in this order: a user-specified ref; the remote default branch from `refs/remotes/origin/HEAD`; then an existing `origin/main`, `main`, `origin/master`, or `master`. Compute `git merge-base <base> HEAD` and review committed changes from that commit through `HEAD`. If no unambiguous base exists, stop and request a base ref in the Markdown conclusion.
3. Read the branch change directly with Git. Also inspect staged and unstaged changes when present, but label them separately from committed branch changes. Do not create auxiliary task inputs, source snapshots, or evidence bundles. Do not clone another repository.
4. Check the current repository graph with `get_architecture` or the available status operation. If it is missing or stale, initialize or refresh it with the environment's existing index operation. When only the CLI is available, use:

   ```sh
   codebase-memory-mcp cli index_repository --repo-path <repo> --mode full --name <project> --persistence true
   ```

   Do not attempt dependency installation when initialization fails. Report the exact blocker in the final Markdown.
5. Load `project-packs/common/review.md`, every language pack matching the changed files, matching family knowledge, then matching project knowledge, in priority order from `project-packs/project-map.tsv`. Read [references/project-routing.md](references/project-routing.md) when routing is not obvious. Load only the TransMid topics relevant to the change. Current source always overrides packaged knowledge.
6. Use `search_graph` to map changed code to symbols, `trace_path` for inbound and outbound impact, `get_code_snippet` for exact source, `query_graph` for focused structural questions, and `get_architecture` for repository boundaries. Use already indexed related repositories only when a verified contract crosses the current repository boundary; do not fetch them automatically.
7. Start traces at depth 1 and expand only unresolved high-risk paths. Default to depth 2; never exceed depth 4 or 20 changed seed symbols. Prioritize externally reachable, state-changing, protocol, persistence, security, cross-language, and cross-repository paths.
8. Verify every retained graph edge against current source. Treat dynamic dispatch, callbacks, macros, configuration routing, generated code, and C/C++-Lua bindings as possible graph gaps. Read [references/graph-verification.md](references/graph-verification.md) when a traced path affects a conclusion, and [references/cpp-lua-bindings.md](references/cpp-lua-bindings.md) for native/script boundaries.
9. Separate confirmed defects from risks and unknowns. Never turn graph reachability alone into a business-impact claim.

## Markdown result contract

Use [assets/report-template.md](assets/report-template.md) as the shape, then replace every placeholder with an actual conclusion.

- Write the completed report to the user-requested path. If none is specified, write `impact-review.md` in the current repository root and exclude that generated file from its own review scope.
- The file is the final conclusion, not a draft, evidence packet, task list, or template.
- Return the exact same Markdown body in the final response. Do not finish with raw JSON, index logs, `OK`, `NEXT`, or a pointer that requires opening the file to learn the conclusion.
- Put findings first, ordered by severity. Every finding must include a source location, failure mechanism, concrete impact, required change, and verification criterion.
- Include a coding-standard and basic-review checklist for each changed language. Use `通过`, `不通过`, `不适用`, or `未验证`, give source evidence for every non-obvious result, and remove sections for untouched languages.
- Give testers a business-language regression scope with observable expected results. Keep code identifiers out of that section.
- If no defect is proven, say so explicitly and list residual risks or unverified scope.
- If the graph or change set is unavailable, still produce Markdown with the conclusion `无法完成`, the exact blocker, and the minimum next action. Do not imply that analysis succeeded.
- Cite only paths verified in current source. State truncation, stale indexes, unsupported files, runtime-only behavior, and missing repositories as limitations.

Do not expose intermediate graph artifacts as deliverables unless the user explicitly requests them.
