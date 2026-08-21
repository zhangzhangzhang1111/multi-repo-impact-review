# TransMid_Lua 知识地图

本目录提供 Broker/Transmid 的候选结构和转换知识。它来自用户提供的 `transmid.zip`（收录日期：2026-08-14，来源提交号未知），已完成目录、链接、重复规则和内部一致性核验，但未获得对应目标仓库源码做逐项事实核验。

目标仓库当前源码始终是请求链与业务行为的最终事实来源。文档中的路径、行号、命令含义、字段 ID、默认值、处理顺序和券商示例都只用于缩小搜索范围；与源码冲突时以源码为准，并在评审报告中记录知识差异。

仅当仓库身份或源码布局符合 `TransMid_Lua` 项目族时加载该知识包。无法确认身份时不要套用项目族结论。

按当前 diff 和问题只读取一项或少量直接相关资料，不要一次加载整个 `data/` 目录：

| 需要确认 | 读取文件 |
|---|---|
| 客户端请求命令的静态含义 | `data/request-command-catalog.md` |
| 脚本根、适配目录和版本布局 | `data/adapter-layout.md` |
| 注册表、handler 分发和挂载面 | `data/request-dispatch.md` |
| 行转换阶段与 handler 职责 | `data/conversion-lifecycle.md` |
| `_D` 默认字段映射 | `data/default-field-mapping.md` |
| 客户端到柜台的请求参数转换 | `data/pre-handle.md` |
| 柜台列表到客户端的行与字段转换 | `data/table-handle.md` |
| 柜台单条结果到客户端字段的转换 | `data/post-handle.md` |
| 分页、多表与缓存数据合并 | `data/data-merge.md` |
| 无法由更具体资料覆盖的整体项目结构 | `data/project-layout.md` |

使用知识结论时，必须回到目标仓库确认实际文件、请求、handler、配置或函数；正式事实必须引用目标代码证据。优先使用知识图谱定位注册表、函数和调用链，再读取具体源码；仅在查找字符串、配置键或图谱不足时使用 `rg`。`request-command-catalog.md` 中的命令只作为候选，不得据此直接声明目标项目支持某业务。
