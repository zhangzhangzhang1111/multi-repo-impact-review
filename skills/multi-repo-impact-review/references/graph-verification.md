# Graph verification

## Required procedure

1. Read `analysis-metadata.json`; reject requested depth above 4 and retain its global/per-trace budgets.
2. Start from changed symbols and, only in Git mode, the official `detect_changes` result. In patch mode start from normalized diff hunks and symbol candidates. Prioritize externally reachable, state-changing, security-sensitive, persistence, protocol, and cross-language symbols.
3. Call `trace_path` at depth 1 with `limit` no greater than the per-trace budget, `include_tests=false`, and `include_evidence=true`.
4. Expand one level at a time only when the current frontier has not reached an entry point, business boundary, external boundary, repository boundary, or already-visited cycle. Never exceed depth 4.
5. Stop adding paths when the global unique-node budget is exhausted. Do not follow `next` pagination merely to be exhaustive; paginate only for an unresolved high-risk path and deduct every returned row from the same budget.
6. Open exact source bodies for every retained edge. Confirm the call expression, import, registration, binding, route, or configuration relation.
7. Inspect branch conditions, argument transformation, return/error handling, async handoff, and callback registration. Search specifically for missing dynamic and cross-language edges.
8. Run `check_index_coverage` for every cited file and relevant scope before any completeness or no-impact claim.
9. Assign one status: `confirmed`, `rejected`, `inferred`, `missing-added`, or `unresolved`.

## Anti-expansion policy

- Defaults: depth 2, 30 rows per trace, 120 unique graph nodes for the review.
- Hard limits: depth 4, 100 rows per trace, 400 unique graph nodes.
- At most 20 changed seed symbols receive individual traces. When more exist, use `impacted_modules` to prioritize and report sampling.
- Deduplicate qualified names across directions and seeds before charging the global budget.
- Do not expand test-only branches unless the changed production path depends on them.
- Treat `truncated`, `has_more`, skipped files, partial parses, and budget exhaustion as explicit limitations, never as evidence of no impact.
- Prefer one verified business path over many unverified graph branches.

## Common graph gaps

- C/C++ macros, templates, overloads, virtual dispatch, function pointers, conditional compilation, generated code, and `dlopen`/`dlsym`.
- Lua function values, table dispatch, `:` versus `.`, metatables, `require` search paths, `dofile`, `loadfile`, coroutine resume, and overwritten globals.
- Framework callbacks, event registries, dependency injection, configuration-selected handlers, HTTP/RPC routes, message topics, shared tables, and generated clients.

## Evidence

Record repository, file, line, symbol, evidence type, detector, and confidence. A final business-impact statement may use only confirmed edges and explicitly justified high-confidence inferred edges.

## Coverage

Verify all prioritized modified symbols, all cross-language and cross-repository boundaries, and complete high-risk paths to a business or external boundary within the declared budget. Mark the report partially verified when a budget truncates a still-relevant frontier, or when build metadata/runtime configuration is missing.
