---
id: scriptswtlua
title: scriptswtlua 项目知识快照
source_path: /Users/xilong/Documents/codegit/scriptswtlua/SCRIPTSWTLUA_PROJECT_KNOWLEDGE.md
source_commit: 94664a9a91edccdbfb031145807c51859f27a3b7
runtime_host: mobiwtlua
source_encoding: GB18030/GBK 与 UTF-8 混用
packaged_for: 多仓库代码影响面评审
---

# scriptswtlua 项目介绍

`scriptswtlua` 是由 C++ 宿主 `mobiwtlua` 加载的 Lua 业务项目。它把移动交易请求路由到证券业务实现，将客户端和会话字段转换为柜台请求，处理异步柜台应答，并组装客户端响应。项目单独交付，再同步到宿主的 `project` 目录。

## 稳定的跨组件边界

- Lua 主入口是 `deploy/wt_handleclientreq.lua`。
- 客户端请求从 `OnHandleClientReqMsg(...)` 进入。
- 柜台应答从 `DoScriptHandleFromGate(...)` 进入。
- C++ 宿主调用固定的 Lua 全局函数，传入五个参数并期望三个返回值。
- 序列化表的字段名、PageId、FetchType、CommandId 和客户端字段标识是跨组件契约。
- 协程请求的关联标识必须贯穿一次柜台请求与应答。
- 券商专属 `qsconfig` 文件可能覆盖响应字段，分析影响面时必须纳入。
- 许多文件使用 GB18030/GBK。ASCII 结构索引通常安全，但未核对编码前不得重写解码后的源码。

## 评审路线

从改动的 PageId、FetchType、命令、URL、模块导入或公开函数入手，分别追踪请求分发与应答分发。核实路径是否进入旧函数、ReProject 命令对象或协程模块；在确定业务影响前，继续检查配置和券商分支。

## 跨仓库关系

`mobiwtlua` 是运行时宿主。若改动涉及 Lua 入口签名、序列化字段、原生函数、返回对象、加载/重载行为、部署同步或共享协议标识，应把它作为必须核对的关联仓库。

## 时效性

比较知识包的 `source_commit` 与被分析仓库的提交。若不同，本文件只用于定位；所有项目事实都应以当前源码复核。
