# 影响面 JSON 文件设计

## 目标

每次完成影响面评审时，除 Markdown 报告外，再生成一个独立的 `impact-report.json`。文件根节点直接是 Kafka 消息中 `rawReportContent` 解码后的 JSON 对象，不是 Kafka 消息，也不是转义后的 JSON 字符串。

## 输出约定

- JSON 与 Markdown 报告放在同一目录，且都在被评审的源码目录之外。
- 顶层只包含 10 个字段：`summary`、`changed_modules`、`changed_symbols`、`direct_impacts`、`indirect_impacts`、`impact_chains`、`risk_level`、`risks`、`test_suggestions`、`api_changes`。
- `summary` 为非空字符串，`risk_level` 只能为 `low`、`medium` 或 `high`；其余字段均为数组。没有已核实内容时使用空数组，但不能因此声称该范围已完整验证。
- 用户示例中有些数组为空，无法推定其元素结构；模板使用空数组，格式校验只约束这些字段是数组，不臆造元素类型。
- 不加入 `packUser`、`jiraInfo`、`status`、`aiAssessmentType`、`rawReportContent` 等 Kafka 外层字段。

## 生成与校验

在可安装的 skill 内提供 JSON 模板和 JSON Schema，并由 `SKILL.md` 链接。Markdown 与 JSON 必须来自同一份已核实证据，摘要、影响链、风险和风险等级应一致；不为填满数组而写入未经核实的候选影响。

交付前运行 skill 随附的 Python 标准库校验脚本。脚本解析 JSON，并依据随附 Schema 检查字段集合、类型和风险等级；失败时不得交付。最终回复给出 Markdown 与 JSON 的路径。仓库测试校验模板、Schema 及脚本的正反例。

## 范围

不涉及 Kafka 发布、消息封装、接口集成，也不对示例中提到的提交做实际影响面分析。
