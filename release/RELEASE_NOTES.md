# Multi-Repo Impact Review v2.0.0

首个使用官方开源 `codebase-memory-mcp` 的完整离线版本。

## 主要内容

- 完全移除自研 `impact-graph`；唯一图谱引擎为官方 `codebase-memory-mcp 0.10.2`。
- 同时支持 Codex 与 Claude Code。
- 提供 macOS、Linux、Windows 的 x86_64/ARM64 六个平台包。
- 支持按 Git remote、本地路径和标志文件匹配项目知识。
- 内置 Lua/C/C++ 项目族规则，以及 scriptswtlua、mobiwtlua 项目知识。
- 随包提供 scriptswtlua 官方 `graph.db.zst` 图谱产物。
- 图谱结果必须经过 AI 源码复核，能够补充 Lua 动态分派及 C/C++-Lua 绑定边。
- 调用链默认深度 2、硬上限 4，并设置单次和全局节点预算防止膨胀。

## 验证

- scriptswtlua：3274 个节点、15000 条边。
- Shell 与 PowerShell 评审流程通过。
- macOS ARM64 包完成实际运行验证。
- 其余平台完成官方资产校验、文件架构识别和压缩包完整性验证。
- 六个平台包的 SHA256 见附件 `SHA256SUMS` 或仓库 `release/SHA256SUMS`。

请下载与操作系统和 CPU 架构一致的包，解压后先运行包内 `verify-distribution` 脚本。
