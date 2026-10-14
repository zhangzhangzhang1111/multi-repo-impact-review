---
id: scriptswtlua
title: scriptswtlua packaged project knowledge
source_path: /Users/xilong/Documents/codegit/scriptswtlua/SCRIPTSWTLUA_PROJECT_KNOWLEDGE.md
source_commit: 94664a9a91edccdbfb031145807c51859f27a3b7
runtime_host: mobiwtlua
source_encoding: GB18030/GBK and UTF-8 mixed
packaged_for: offline impact review
---

# scriptswtlua project knowledge snapshot

`scriptswtlua` is the Lua business project loaded by the `mobiwtlua` C++ host. It routes mobile trading requests to security-business implementations, transforms client and session fields into gateway requests, handles asynchronous gateway replies, and assembles client responses. The project is delivered separately and synchronized into the host's `project` directory.

## Stable boundaries

- The main Lua entry is `deploy/wt_handleclientreq.lua`.
- Client requests enter through `OnHandleClientReqMsg(...)`.
- Gateway replies enter through `DoScriptHandleFromGate(...)`.
- The C++ host calls fixed Lua globals with five arguments and expects three return values.
- Serialized table field names, PageId, FetchType, CommandId, and client field identifiers are cross-component contracts.
- Coroutine requests require a correlation identifier that survives the gateway round trip.
- Broker-specific `qsconfig` files can override response fields and must be included in impact analysis.
- Many files use GB18030/GBK; ASCII structural indexing is safe, but rewriting decoded source without encoding checks is not.

## Review routing

Start with the changed PageId, FetchType, command, URL, module import, or public function. Trace request and reply dispatch separately. Verify whether the path enters legacy functions, ReProject command objects, or coroutine modules. Follow configuration and broker-specific branches before concluding business impact.

## Cross-repository relation

Treat `mobiwtlua` as the runtime host and a mandatory related repository when a change affects Lua entry signatures, serialized fields, native functions, return objects, loading/reload behavior, deployment synchronization, or shared protocol identifiers.

## Staleness rule

Compare the packaged `source_commit` with the analyzed repository. When they differ, use this file as orientation only and verify all project-specific claims against current source.
