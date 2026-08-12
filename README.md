# Multi-Repo Impact Review

面向 Codex 与 Claude Code 的离线多项目代码影响评审插件，支持 Lua、C、C++ 及其他由图谱引擎覆盖的语言。

知识图谱只使用开源 [`codebase-memory-mcp v0.10.2`](https://github.com/DeusData/codebase-memory-mcp)，不包含自研图谱引擎。插件负责 Git 项目匹配、项目/项目族知识加载、业务影响分析、深度受限的调用链查询，以及 AI 对图谱调用边的源码复核。

## 下载

请从 [`v2.0.0 Release`](https://github.com/zhangzhangzhang1111/multi-repo-impact-review/releases/tag/v2.0.0) 下载与运行环境一致的完整离线包：

| 运行环境 | Release 文件 |
|---|---|
| macOS Apple Silicon | `multi-repo-impact-review-offline-v2.0.0-darwin-arm64.tar.gz` |
| macOS Intel | `multi-repo-impact-review-offline-v2.0.0-darwin-amd64.tar.gz` |
| Linux x86_64 | `multi-repo-impact-review-offline-v2.0.0-linux-amd64.tar.gz` |
| Linux ARM64 | `multi-repo-impact-review-offline-v2.0.0-linux-arm64.tar.gz` |
| Windows x86_64 | `multi-repo-impact-review-offline-v2.0.0-windows-amd64.zip` |
| Windows ARM64 | `multi-repo-impact-review-offline-v2.0.0-windows-arm64.zip` |

本仓库保存可审查的插件源文件，不提交大型原生程序。直接运行请使用 Release 包，包内包含官方平台可执行程序、逐文件校验和、许可证、SBOM 和项目图谱。

## 安装

解压后先验证：

```sh
./scripts/verify-distribution.sh
```

Windows PowerShell：

```powershell
.\scripts\verify-distribution.ps1
```

安装到 Codex：

```sh
codex plugin marketplace add /absolute/path/to/extracted-package
codex plugin add multi-repo-impact-review@impact-review-offline
```

安装到 Claude Code：

```sh
claude plugin marketplace add /absolute/path/to/extracted-package
claude plugin install multi-repo-impact-review@impact-review-offline
```

## 使用

在项目目录中直接告诉 Codex 或 Claude：

```text
使用 multi-repo-impact-review 评审当前分支相对 origin/main 的改动，
分析业务功能影响和具体代码问题，调用链最多分析 2 层。
```

Claude Code 也可以显式调用：

```text
/multi-repo-impact-review:multi-repo-impact-review
```

底层可执行程序是：

```text
runtime/<platform>/codebase-memory-mcp[.exe]
```

`run-review.sh` / `run-review.ps1` 构建只读分析镜像并生成官方 `graph.db.zst`、影响结果和 AI 核验材料。调用链默认深度 2、硬上限 4，并同时限制单次结果和全局唯一节点数量。

## 测试结果

`scriptswtlua` 效果测试生成 3274 个节点、15000 条边。官方图谱定位到两个变更函数，但漏掉 Lua 局部函数变量分派；AI 依据源码补全调用边并核验到客户端请求入口。调用链仅从深度 1 扩展到深度 2，共 5 个核心节点。

- [完整验证报告](docs/VALIDATION_REPORT.md)
- [scriptswtlua 人类可读评审报告](docs/scriptswtlua-ai-verified-effect-report.md)
- [Release 文件 SHA256](release/SHA256SUMS)

## 许可证与来源

插件代码使用 MIT License。`vendor/codebase-memory-mcp/` 保存上游许可证、第三方声明、SBOM、发布校验和及来源记录。Release 中的平台程序来自官方 v0.10.2 发布资产。
