# Multi-Repo Impact Review Skill

面向 Codex、Claude Code 等支持 `SKILL.md` 的 Agent 的离线代码影响评审 Skill。它不是插件，不需要 `.mcp.json`、插件市场或 MCP 服务注册。

Skill 使用随包携带的官方开源 [`codebase-memory-mcp v0.10.2`](https://github.com/DeusData/codebase-memory-mcp) 命令行程序建立知识图谱，支持 Lua、C、C++ 及上游引擎覆盖的其他语言。图谱给出候选调用关系，AI 必须再次读取源码核验动态分派、回调和 C/C++-Lua 跨语言链路。

## 支持的输入

完整 Git 仓库：

```text
task_id/
├── repo/                 # 包含 .git
├── codegraph/
└── report/
```

源码快照和外部 diff：

```text
task_id/
├── task.json             # 可选
├── repo/                 # 当前版本源码，无需 .git
├── diff/
│   └── changes.diff
├── codegraph/
└── report/
```

`auto` 模式优先使用非空 `changes.diff`，否则在存在 `.git` 时进入 Git 模式。两种模式都会生成统一的 `codegraph/changes.json`、官方 `graph.db.zst`、符号候选和 AI 核验材料。

## 安装

下载对应操作系统的离线包，把压缩包中的 `multi-repo-impact-review/` 整个目录放到 Skill 目录：

```text
Codex:       ~/.codex/skills/multi-repo-impact-review/
Claude Code: ~/.claude/skills/multi-repo-impact-review/
```

验证：

```sh
~/.codex/skills/multi-repo-impact-review/scripts/verify-offline.sh
```

Windows：

```powershell
& "$HOME\.codex\skills\multi-repo-impact-review\scripts\verify-offline.ps1"
```

## 使用

在 Agent 中说：

```text
使用 $multi-repo-impact-review 评审 /data/tasks/TASK-123，
输出测试关注的业务功能影响和开发需要修改的具体代码问题。
```

也可以直接生成机器证据：

```sh
scripts/run-review.sh --task-root /data/tasks/TASK-123 --mode auto
```

完整 Git 仓库也保留原有入口：

```sh
scripts/run-review.sh \
  --repo /data/repositories/project \
  --base origin/main \
  --head HEAD \
  --out /data/tasks/TASK-123/codegraph \
  --report /data/tasks/TASK-123/report \
  --mode git
```

## 离线平台包

- `darwin-arm64`
- `darwin-amd64`
- `linux-amd64`
- `linux-arm64`
- `windows-amd64`
- `windows-arm64`

源仓库不提交大型原生程序。使用 `scripts/build-offline-skill.sh` 将官方平台程序装入纯 Skill 分发包。

## 产物

- `codegraph/changes.json`：Git 或 patch 统一变更清单。
- `codegraph/graph.db.zst`：官方知识图谱产物。
- `codegraph/official-impact-review.json`：Git 模式的官方 `detect_changes` 结果。
- `codegraph/symbol-candidates/`：按变更文件生成的符号与覆盖率证据。
- `codegraph/verification-packet.md`：AI 调用链和源码核验任务。
- `report/review-report.md`：面向测试和开发的最终报告。

许可证、上游校验和、SBOM 和来源记录保存在 Skill 包的 `vendor/codebase-memory-mcp/`。
