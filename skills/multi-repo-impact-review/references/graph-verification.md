# CodeGraph verification

## Per-repository procedure

1. Run `codegraph_status(projectPath=<root>)`. When uninitialized, follow higher-priority repository instructions and the host permission mechanism; ask once if they require confirmation, otherwise run `codegraph init -i` directly, then re-check status.
2. Start from changed symbols and normalized diff hunks. Map stale-file hunks from current source, not from the stale graph.
3. Call `codegraph_context` once per independent change area.
4. Call `codegraph_impact(symbol=<changed symbol>, depth=2, projectPath=<root>)`. Expand to depth 3 or 4 only when the frontier has not reached an entry, business, external, or repository boundary.
5. Call `codegraph_trace(from=<changed or entry symbol>, to=<known boundary symbol>, projectPath=<root>)` only after both endpoints are identified. The tool has no depth or limit parameter; use one call for the complete candidate path.
6. Call `codegraph_explore(query=<specific symbols/files>, maxFiles=12, projectPath=<root>)` once per retained path or independent change area. If capped or truncated, split the query or read exact current files.
7. Confirm calls, imports, registrations, bindings, routes, configuration, branch conditions, argument transformations, return/error handling, callbacks, and async handoffs in current source.
8. Assign each cited relation one status: `confirmed`, `rejected`, `inferred`, `missing-added`, or `unresolved`.

A path crossing any stale or pending node remains a candidate or `unresolved` until every affected relation is verified in current source.

## Cross-repository joins

CodeGraph indexes are repository-local. Join repositories only with concrete source evidence on both sides: API route/client pair, RPC schema, message topic, shared configuration key, generated interface, file/data contract, or native/Lua binding. Record both repositories, files, lines, transformation, and error behavior. Without both sides, mark the join `inferred` or `unresolved`.

## Budgets

- Default impact depth: 2; hard maximum: 4.
- At most 20 changed seed symbols across the review.
- Stop expanding when a path reaches an entry point, business boundary, external boundary, repository boundary, or already-visited cycle.
- Prefer one verified business path over many unverified branches.

## Common graph gaps

- C/C++ macros, templates, overloads, virtual dispatch, function pointers, conditional compilation, generated code, and dynamic loading.
- Lua function values, table dispatch, `:` versus `.`, metatables, module loaders, coroutines, and overwritten globals.
- Framework callbacks, event registries, dependency injection, configuration-selected handlers, routes, message topics, shared tables, generated clients, and cross-index relations.

## Coverage language

Pending indexing, stale nodes, parse gaps, capped/truncated results, unresolved dynamic dispatch, cross-index joins, or exhausted budgets are explicit limitations, never evidence of no impact. Business-impact statements may use confirmed relations and explicitly justified high-confidence inferred relations only.
