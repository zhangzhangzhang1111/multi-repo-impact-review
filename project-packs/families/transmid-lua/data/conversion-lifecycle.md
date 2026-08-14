# Conversion Lifecycle Rules

Use this file as candidate guidance for the Transmid request conversion lifecycle. Confirm the effective order in the target project's framework code.

Detailed field behavior remains in `pre-handle.md`, `table-handle.md`, `post-handle.md`, `default-field-mapping.md`, and `data-merge.md`.

## HandleNormalRequest Lifecycle

`HandleNormalRequest` usually performs:

1. Reset `ANSTYPE` and clear table data unless `save_old_data` is enabled.
2. Convert client input through `pre_handle`, unless `_USE_SELF_DATA_` is set.
3. Call the counter request implementation.
4. Handle errors through standard or custom `error_handle`.
5. Convert list rows through `table_handle`.
6. Convert single-result fields through `post_handle`.
7. Build `T_ADD_DATA` through `extend_handle`.
8. Save user cache through `userinfo_handle`.
9. Build structured `extend_data` through `extern_data_handle` and sometimes extra data handlers.

For list conversion, confirm the target framework implementation rather than assuming a generic order. A common order is:

```text
table_handle.handle mappings -> OTHERHANDLE callbacks -> SKIPFUNC callbacks -> add_row -> TABLEHANDLE callbacks
```

`OTHERHANDLE` can read mapped fields, create or overwrite `item` fields, and feed later callbacks. `SKIPFUNC` commonly consumes both mapped fields and fields created by earlier `OTHERHANDLE` callbacks. Named callbacks may live in common files, so follow them to their bodies.

## Handler Roles

| Handler | Direction | Purpose |
|---|---|---|
| `pre_handle` | client request -> counter request | Static values, field rename, defaults, cache values, market conversion, date conversion, client id conversion, or custom change functions. |
| `table_handle` | counter list rows -> client table rows | List row conversion. Adding/removing list columns must check both `table_handle.head` and `table_handle.handle`. |
| `post_handle` | counter single result -> client reply fields | Single-row or summary field conversion. |
| `extend_handle` | counter/client data -> `T_ADD_DATA` | Key-value extension data. |
| `extern_data_handle` | data -> `extend_data` | Structured `EX=2.0&EXL=...` style extension data. |
| `userinfo_handle` | counter result -> user cache | User/cache state persistence. |
| `error_handle` | counter error -> client error | Error normalization or custom error handling. |

## Mapping Rules

- `_D("field")` is a project-local default mapping. Never assume it is the same across `hsarapi`, `kcbp`, `jzzt`, `aboss2`, or broker forks.
- Inspect `defines.lua`, `tools.lua`, `_R_D.lua`, `tableHead.lua`, or module-local `DEF_DATA_DEF_CHANGE` before using field IDs or default mappings.
- Field IDs in the `2001-2100` range are often project/request-specific.
- Dictionary conversion should be traced to the actual dictionary table or conversion helper used by the target request.
- `save_old_data` and `save_cur_data` are table preservation flags used by multi-step or merge flows. If a wrapper mutates them, the implementation must preserve or restore them according to the existing project pattern.
- Resolve the effective request config after copy, merge, replace, delete, wrapper mutation, module registration, and broker override operations. A source-level base table is not necessarily the runtime handle.
- Keep protocol visibility separate from internal production. Removing a column from `table_handle.head` does not prove that its `table_handle.handle` producer can be removed when callbacks still consume the internal field.
- Determine whether the framework allocates `item` per row or reuses it. When it reuses `item` and only mapped fields are reset, conditionally written callback-only fields can leak from a prior row unless every path initializes or clears them.

## Evidence Rules

For each target field or conversion, record:

- Client field and field ID when known.
- Counter field and direction.
- Default value, fixed value, dictionary mapping, or function transform.
- Source file and line evidence from the target project.
- Whether the evidence came from `pre_handle`, `table_handle`, `post_handle`, `extend_handle`, `extern_data_handle`, `userinfo_handle`, common mapping, or wrapper logic.
