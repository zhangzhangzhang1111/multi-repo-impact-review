# Graph verification

Use graph results to find evidence, not as proof by themselves.

## Trace discipline

1. Map each changed hunk to the smallest current symbol. Include deleted or renamed symbols from the old side of the diff.
2. Trace inbound callers and outbound dependencies from depth 1. Expand one level only while a relevant path has not reached an entry point, business boundary, external system, repository boundary, or cycle.
3. Verify every retained edge in current source with `get_code_snippet` or a direct file read. Confirm calls, imports, registrations, routes, argument transformations, error handling, callbacks, and configuration conditions.
4. Mark an edge `confirmed`, `inferred`, `rejected`, or `unresolved`. Only confirmed edges and explicitly justified high-confidence inferences may support the conclusion.
5. Treat truncated results, stale indexes, skipped files, parse failures, missing repositories, and exhausted budgets as limitations.

Default to depth 2, at most 30 rows per trace, 120 unique nodes, and 20 changed seeds. Hard limits are depth 4, 100 rows per trace, and 400 unique nodes.

## Common gaps

- C/C++: macros, templates, overloads, virtual dispatch, function pointers, conditional compilation, generated code, `dlopen`, and `dlsym`.
- Lua: table dispatch, function values, metatables, `:` versus `.`, dynamic `require`, `dofile`, `loadfile`, coroutines, and overwritten globals. Use [cpp-lua-bindings.md](cpp-lua-bindings.md) for native/script boundaries.
- Frameworks: callbacks, event registries, dependency injection, routes, message topics, generated clients, and configuration-selected handlers.
- Cross-repository: shared protocol identifiers, RPC endpoints, schemas, configuration keys, database fields, and message contracts.
