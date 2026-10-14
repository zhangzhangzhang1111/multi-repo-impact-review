# 多仓库代码影响面评审

这是面向一个或多个 Git 仓库或源码快照的 Codex skill。它直接使用当前环境中的 CodeGraph，结合当前源码核实图谱候选关系，输出业务影响、代码问题和回归建议。

## 环境要求

- 可使用 CodeGraph 工具的 Codex 环境。
- `PATH` 中可运行 `codegraph` 命令。
- 评审 Git 仓库或远端分支时需要 Git。
- Python 3（运行 JSON 格式校验脚本，仅使用标准库）。

skill 会对每个源码根目录调用 `codegraph_status`；未初始化时默认运行 `codegraph init -i`，同时遵守优先级更高的仓库指令和宿主权限机制。

## 安装

从此分支安装 skill 目录：

```powershell
python <skill-installer>/install-skill-from-github.py `
  --repo zhangzhangzhang1111/multi-repo-impact-review `
  --ref agent/pure-skill-v2.1.0 `
  --path skills/multi-repo-impact-review
```

安装目录为 `$CODEX_HOME/skills/multi-repo-impact-review`。

## 随 skill 安装的项目介绍

项目及家族知识快照随 skill 一起安装。根据[项目知识匹配规则](skills/multi-repo-impact-review/references/project-routing.md)只读取匹配资料：

- [scriptswtlua 项目简介](skills/multi-repo-impact-review/project-packs/projects/scriptswtlua/knowledge/project.md)与[详细项目知识](skills/multi-repo-impact-review/project-packs/projects/scriptswtlua/knowledge/SCRIPTSWTLUA_PROJECT_KNOWLEDGE.md)。
- [mobiwtlua 项目知识](skills/multi-repo-impact-review/project-packs/projects/mobiwtlua/knowledge/MOBIWTLUA_PROJECT_KNOWLEDGE.md)。
- [TransMid_Lua 家族知识地图](skills/multi-repo-impact-review/project-packs/families/transmid-lua/knowledge-map.md)。

这些资料是有日期的定位快照，最终以目标仓库的当前源码为准；旧的便携图数据库和图引擎配置不再随包提供。

## 支持的评审输入

- 本地 Git 分支、提交及未提交改动。
- 用户明确提供的远端 Git URL 与分支。
- 当前源码快照及配套的 `changes.diff`。
- 跨仓库 API、消息、配置、生成客户端、数据契约和 C/C++—Lua 边界。

## 证据与产物

skill 使用 `codegraph_status` 检查索引，`codegraph_context` 定位改动区域，`codegraph_search` 处理未确定符号，`codegraph_impact` 分析影响范围，`codegraph_trace` 追踪具体路径，`codegraph_explore` 检查源码。过期文件直接读取；动态分发、跨索引连接、生成代码等缺口应在报告中说明。

每次评审同时生成 Markdown 报告与 `impact-report.json`。JSON 根节点直接是 `rawReportContent` 解码后的影响面对象，不含 Kafka 外层字段；格式见 [JSON 模板](skills/multi-repo-impact-review/assets/impact-report.template.json)与 [JSON Schema](skills/multi-repo-impact-review/assets/impact-report.schema.json)。两份报告须依据相同证据，放在被评审源码目录之外。交付前运行 [格式校验脚本](skills/multi-repo-impact-review/scripts/validate-impact-json.py)：`python skills/multi-repo-impact-review/scripts/validate-impact-json.py <报告路径>`。

## 验证

```powershell
node --test tests/skill-contract.test.mjs
```

此仓库不包含捆绑的图引擎、便携图数据库、供应商运行时或包管理器依赖。
