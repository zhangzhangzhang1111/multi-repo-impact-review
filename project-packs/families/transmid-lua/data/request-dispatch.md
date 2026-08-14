# Request Dispatch Rules

Use this file as candidate guidance for Transmid request-key, request registration, runtime dispatch, and handler-chain analysis.

Final facts must still be confirmed in the target broker project.

## Request Key

Common request-key shape:

```text
[moneytype][REQTYPE]-[MMLB][history]-[cmd]-[extend]
```

Common parts:

| Part | Meaning |
|---|---|
| `moneytype` | Usually empty for normal A-share requests; `$` can appear in download/small-wealth style requests; `@` can appear in asset-management download requests. |
| `REQTYPE` | Request type, often `T`, `L`, or a direct normal command depending on framework path. |
| `MMLB` | Buy/sell/category segment such as `0`, `:`, or `=`. |
| `history` | Historical marker such as `H`; absence usually means current-day/current-state query. |
| `cmd` | Business command, for example `rzrq_mairu` or `ggt_query_zijin`. |
| `extend` | Optional extension segment. |

`FillCommand`-style logic in projects may complete partial command keys with wildcard segments before `CompareString`-style matching.

## Runtime Path

Common flow:

1. `jiekou.lua` sets `package.path` and loads `comm`.
2. Counter adapter entry loads config files, commonly `hscomm.lua`, `kcbpcomm.lua`, `jzztcomm.lua`, or `aboss2comm.lua`.
3. Adapter calls `JModelInit(g_all_request_handle_config, g_special_handle_request)`.
4. `comm/jmodel.lua` builds the request key from request type, buy/sell type, history flag, command, extension, and sometimes money type.
5. The framework matches `g_special_handle_request` first, then `g_all_request_handle_config`.
6. The matched value is either a function or a request config table processed by `HandleNormalRequest`.

## Handler Lookup Order

When locating a command, check in this order:

1. Broker special table, usually `config_<broker>.lua`, such as `config_cc.lua`, `config_db.lua`, `config_dg.lua`, `config_hl.lua`, `config_pa.lua`, `config_zt.lua`, or `config_zjcf.lua`.
2. Main config table, such as `hsconfig.lua`, `kcbpconfig.lua`, `jzztconfig.lua`, or `aboss2config.lua`.
3. Module request tables merged by `AddBussinessModule(g_xxx_request_handle_config)`.
4. Derived helpers and wrapper functions such as `MakeMySelfRequest`, `UpdateDefRequest`, `Combine_Data`, `CombineTwoTable`, or local functions that call `HandleNormalRequest`.

## Common Module Tables

| Table | Domain |
|---|---|
| `g_rzrq_request_handle_config` | 融资融券 |
| `g_ggt_request_handle_config` | 港股通 |
| `g_gfzr_request_handle_config` | 股转/北交所相关请求 |
| `g_sdxgl_handle_config`, `g_sdxgl_request_handle_config`, `g_Appropriate_Manage_request_handle_config` | 适当性、风险揭示、签署 |
| `g_qxkt_Manage_request_handle_config` | 权限开通 |
| `g_asset_request_handle_config` | 资产数据 |
| `g_zjgl_request_handle_config` | 资金管理 |
| `g_hbjj_request_handle_config` | 货币基金 |
| `g_yhlc_request_handle_config` | 银行理财 |
| `g_otc_request_handle_config` | OTC |
| `g_zrt_request_handle_config` | 转融通 |
| `g_dzjy_request_handle_config` | 大宗交易 |

Variants are common. Search by table suffix, module registration, and nearby domain functions instead of assuming exact names.

## Mount Surfaces

For filtering, blocking, merging, caching, pagination, sorting, de-duplication, permissions, field hiding, and route wrapping, enumerate all likely mount surfaces:

- Request config tables.
- `SKIPFUNC`.
- `OTHERHANDLE`.
- Wrapper functions that mutate config before `HandleNormalRequest`.
- Common helper functions.
- Broker-specific override tables.
- Combined-query and multi-step query paths.

If a requirement asks to remove or disable a behavior for a specific path, distinguish target mount surfaces from non-target surfaces that must remain unchanged.
