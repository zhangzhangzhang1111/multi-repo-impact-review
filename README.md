# Multi-Repo Impact Review

面向 Codex 和 Claude Code 的当前 Git 分支代码影响评审 Skill。Skill 直接使用环境中已经配置好的
`codebase-memory-mcp` 知识图谱能力，不包含、不下载、也不安装图谱引擎或平台二进制。

Skill 保留原有项目知识、TransMid/Lua 业务知识、C/C++-Lua 绑定规则，并增加 C、C++、Lua
编码规范和基础审核清单。当前源码始终优先于知识库；Skill 不包含项目源码快照或预构建图谱。

发布只保留一个平台无关分支：`pure-skill-v2.4.0`。

## 使用

克隆 `pure-skill-v2.4.0` 分支后，可安装到 Codex、Claude Code 或两者：

```sh
sh install-skill.sh codex
sh install-skill.sh claude
sh install-skill.sh both
```

Windows PowerShell：

```powershell
.\install-skill.ps1 both
```

安装脚本只复制 `skills/multi-repo-impact-review/`，不会更改知识图谱环境。

使用时在 Codex 中调用 `$multi-repo-impact-review`，在 Claude Code 中调用
`/multi-repo-impact-review`。在待审核仓库的当前分支中直接执行；Skill 自动选择基线并读取 Git
分支变更，不需要额外任务文件、源码副本或 runner。评审会先使用已有图谱；图谱不存在或过期时
只执行初始化或更新，不会安装依赖，也不会自动克隆其他仓库。

最终结果写入 Markdown 文件，并在对话中输出同一份 Markdown 结论。图谱查询结果、索引日志和
JSON 只作为内部证据，不作为用户交付物。
