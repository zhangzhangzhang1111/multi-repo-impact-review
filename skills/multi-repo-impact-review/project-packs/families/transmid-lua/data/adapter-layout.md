# Adapter Directory Rules

Use this file as candidate guidance for Transmid project, broker, adapter, and script directory inference. Confirm every inferred path in the target repository.

If the user explicitly specifies a counter, broker, adapter, or script directory, follow the user-provided target. Only infer when the target is missing.

## Repository Shape

Typical repository layout:

```text
Transmid-git/
|-- <broker-pinyin>/
|   |-- <project-version>/
|   |   |-- Transmid/script/
|   |   `-- wt_service/bin/script/
```

## Broker Directory

The first-level directory usually names the broker in pinyin, for example:

| Directory | Broker |
|---|---|
| `zhongtianguofu` | 中天国富 |
| `hongxin` | 宏信/鸿信 |
| `zhongxinjiantou` | 中信建投 |
| `zhongjin` | 中金 |
| `huajin` | 华金 |
| `dongguan` | 东莞 |
| `guojin` | 国金 |
| `jiuzhou` | 九州 |
| `tianfeng` | 天风 |

This list is only a hint. Target project code and user input are authoritative.

## Project Version Directory

Common prefixes:

| Prefix | Meaning |
|---|---|
| `pc` | PC 客户端 |
| `sj` | 手机客户端 |
| `zy` | 自运营 |
| `mn` | 模拟 |

Common suffixes:

| Suffix | Meaning |
|---|---|
| `pt` | 普通交易 |
| `rzrq` | 融资融券 |
| `ks` / `ksgt` | 快速柜台 |
| `all` | 综合版 |
| `linux` | Linux 版本 |
| `uft` | UFT/快速柜台版本 |

Common examples:

| Directory | Meaning |
|---|---|
| `pc_all` | PC 综合版 |
| `pc_pt` | PC 普通版 |
| `pc_rzrq` | PC 融资融券版 |
| `pc_all_linux` | PC 综合 Linux 版 |
| `sj_all` | 手机综合版 |
| `sj_pt` | 手机普通版 |
| `sj_rzrq` | 手机融资融券版 |
| `zy_all` | 自运营综合版 |
| `zy_pt` | 自运营普通版 |
| `zy_rzrq` | 自运营融资融券版 |
| `pc_sj_all` | PC 和手机综合版 |
| `pc_sj_pt_ks` | PC 手机普通快速柜台版 |
| `pc_uft_rzrq` | PC 快速柜台融资融券版 |
| `ks_pt` | 快速柜台普通版 |

## Script Root

Prefer script roots in this order:

1. User-specified script root.
2. Windows-style Transmid root: `Transmid/script`.
3. Linux service root: `wt_service/bin/script`.
4. Project-specific equivalent roots confirmed by `comm/jmodel.lua`, `comm/comm.lua`, and request config files.

## Adapter Directory

Default adapter directory mapping:

| Adapter | Counter |
|---|---|
| `hsarapi` | 恒生柜台 |
| `kcbp` | 金证 W 柜台 |
| `jzzt` | 金证 U 柜台 |
| `aboss` / `aboss2` | 顶点柜台 |

When inferring from a workspace, match adapter directory names case-insensitively and prefer exact directory names under `Transmid/script/` or `wt_service/bin/script/`.

If multiple candidate adapters match, report candidates and continue only when the request can be localized safely from code evidence.

## Quick Search Hints

| Need | Search pattern |
|---|---|
| Broker project | `<repo>/<broker-pinyin>/**` |
| Self-operated version | `**/zy_*` |
| PC comprehensive version | `**/pc_all*` |
| Fast counter version | `**/*ks*`, `**/*uft*` |
| Linux version | `**/*linux*`, `**/wt_service/bin/script` |
| Mobile version | `**/sj_*` |
| Margin version | `**/*rzrq*` |

## Safety Rules

- Do not hard-code `hsarapi` as the business directory; detect actual adapter and request files from project features.
- If user input conflicts with inferred directory, use user input and record the conflict.
- If directory inference cannot identify a script root, report it as unresolved and avoid adapter-specific completeness claims; continue with repository-wide evidence when the requested review can still be performed safely.
