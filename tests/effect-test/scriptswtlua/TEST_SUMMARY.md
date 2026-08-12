# scriptswtlua effect test

- Source repository: `/Users/xilong/Downloads/thswork/scriptswtlua` (tested through a clean local clone)
- Base: `4de66dfb09c618cab8eb44eba29a7ab8ccf7dde4`
- Head: `2c9bee33b0b2a4708ae9416797ffa8a57cb2fc85`
- Official engine: `codebase-memory-mcp 0.10.2`
- Official graph: 3274 nodes, 15000 edges
- Portable graph artifact: `project-packs/projects/scriptswtlua/codebase-memory/2c9bee33b0b2a4708ae9416797ffa8a57cb2fc85/graph.db.zst`
- Shell runner: passed
- PowerShell runner: passed with identical deterministic impact JSON
- AI call-chain verification: passed; two Lua variable-dispatch edges were absent from the graph and added from source evidence
- Traversal: started at depth 1, expanded only to depth 2, 5 core unique nodes, global budget 120, hard maximum depth 4
- Target repository modified: no

Read `AI_VERIFIED_EFFECT_REPORT.md` for the human-facing result and `ai-call-chain-verification.json` for machine-readable verification evidence.
