# Multi-Repo Impact Review v2.0.0 验证报告

## v2.2.1 Git patch 路径兼容验证

- 使用真实 `changes.diff` 验证 Git patch 模式；完整识别 5 个 Lua 修改文件和 1 个中文文件名的二进制 Excel 删除记录。
- Shell 与 PowerShell 解析器均从 `diff --git` 头读取路径，支持 Git 双引号、反斜杠转义和 UTF-8 八进制字节序列。
- 二进制文件即使没有 `---`、`+++` 和 hunk，也会进入 `changes.json` 与 `changed-files.txt`，并保留 `deleted` 状态。
- 混合 CRLF/LF 的 patch 输入不影响文件、状态和 hunk 识别。

## v2.2.0 TransMid_Lua 增量验证

- 收录 `transmid.zip` 的 1 个知识地图和 10 个专题文档，并将未经目标源码验证的命令、字段、默认值、路径和处理顺序明确降级为候选知识。
- 修正知识地图中不存在的 `request-cmd-resolver` 依赖，以及 `_save_old_data_` 的相互矛盾说明。
- 新增 `*/TransMid_Lua/<broker>/<project>` 家族路由；示例 `.../TransMid_Lua/pingan/zy_all.git` 在 Git 模式和 patch 模式均命中 `common + transmid-lua`，对照路径未误命中。
- 六个平台 v2.2.0 离线包均通过外层和包内校验和；macOS ARM64 额外通过官方运行时自检。其他平台受当前主机架构限制，未执行原生程序。

## 结论

六个平台离线包均构建成功并通过压缩包完整性、逐文件校验和、清单和架构检查。macOS ARM64 包完成了实际解压、官方运行时自检、Codex 插件校验、Claude 插件与 marketplace 校验。`scriptswtlua` 的 Shell 与 PowerShell 评审流程均成功，且没有向被评审仓库写入文件。

## 官方图谱集成

| 项目 | 结果 |
|---|---|
| 唯一图谱引擎 | `codebase-memory-mcp 0.10.2` |
| 来源 | `DeusData/codebase-memory-mcp` 官方 v0.10.2 Release |
| 许可证 | MIT；许可证和第三方声明已随包提供 |
| 上游完整性 | 六个下载资产均按官方 `checksums.txt` 验证 |
| 自研引擎 | 已移除；包内不存在 `impact-graph`、其源码或旧校验项 |
| 离线图谱产物 | 官方 `.codebase-memory/graph.db.zst` 格式，已随项目包提供 |

## scriptswtlua 效果测试

| 项目 | 结果 |
|---|---|
| 测试提交 | `4de66dfb` → `2c9bee33`（SJCGZZ-21023） |
| 项目匹配 | common + embedded-lua-services + scriptswtlua，路径匹配成功 |
| 图谱规模 | 3274 个节点、15000 条边 |
| 变更定位 | 1 个 Lua 文件、2 个变更函数 |
| 图谱覆盖 | 目标 Lua 文件无已记录解析问题；6 个无关配置/脚本文件为部分解析，1 个二进制扩展未索引 |
| Shell 流程 | 通过 |
| PowerShell 流程 | 通过；确定性影响 JSON 与 Shell 一致 |
| 原项目写入 | 无；分析在输出目录的本地镜像中完成 |

官方图谱对两个变更函数的深度 1 反向追踪均返回 0 个调用者。AI 随后从源码发现两个函数通过 Lua 局部函数变量分派，并补出完整请求路径。上游静态部分再由官方图谱核验：客户端入口 → 总分发 → 两融分发；动态分派到两个变更函数由精确源码行确认。

调用链从深度 1 开始，只在确认结果很小后扩展到深度 2；核心唯一节点 5 个，低于全局预算 120，单次结果上限 30，硬深度上限 4，未截断。这证明当前流程能够发现官方图谱对动态 Lua 分派的漏边，同时避免无界展开。

人类可读结果见 `scriptswtlua-ai-verified-effect-report.md`。

## 跨平台验证

| 平台 | 文件格式检查 | 包完整性 |
|---|---|---|
| macOS ARM64 | Mach-O arm64；已实际执行 `--version` 和 CLI 自检 | 通过 |
| macOS Intel | Mach-O x86_64 | 通过 |
| Linux x86_64 | 静态链接 ELF x86-64 | 通过 |
| Linux ARM64 | 静态链接 ELF AArch64 | 通过 |
| Windows x86_64 | PE32+ x86-64 | 通过 |
| Windows ARM64 | PE32+ AArch64 | 通过 |

非当前主机架构的程序无法在本机实际执行，因此验证范围为官方资产校验和、包内校验和、压缩包解压测试和二进制架构识别。PowerShell 评审逻辑已用 PowerShell 7 实际运行；Windows 原生进程启动仍应在目标 Windows 机器上执行包内自检脚本。

## 主机与清单验证

- Agent Skill 快速校验：通过。
- Codex 插件结构校验：通过。
- Claude 插件清单校验：通过。
- Claude marketplace 清单校验：通过。
- macOS ARM64 最终归档解压后的 `verify-distribution.sh`：通过。
- 官方默认账户缓存下的完整评审复跑：通过；启动常驻 daemon 后再执行 CLI 图谱查询：通过，确认 MCP/CLI 共享缓存策略可用。
- 六个压缩包 `gzip -t` / `unzip -t`：通过。
- 六个包的内部逐文件 `SHA256SUMS`：通过。
