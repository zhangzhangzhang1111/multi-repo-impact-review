# C/C++ and Lua binding verification

## Providers to inspect

Inspect Lua C API registrations (`lua_register`, `luaL_Reg`, `luaL_setfuncs`, `lua_pushcfunction`, `lua_pushcclosure`), module loading (`luaopen_*`, `luaL_requiref`, `package.preload`), calls into Lua (`lua_getglobal`, `lua_getfield`, `lua_pcall`), userdata/metatable registration (`luaL_newmetatable`, `__index`, `__gc`), LuaJIT FFI, and frameworks such as sol2, LuaBridge, tolua++, and SWIG.

Use CodeGraph to locate native and Lua symbols and candidate callers. Because registrations and string-selected functions are frequently dynamic, verify every retained cross-language relation in current source.

## Verification questions

- Which native symbol is exposed under which Lua-visible name?
- Which module, table, preload entry, userdata, or metatable owns the binding?
- Which Lua runtime and module search path are active?
- Is the binding conditional on a macro, platform, feature flag, or initialization order?
- Does native code call a fixed Lua global or a dynamically selected function?
- Are closure upvalues, arguments, returns, errors, lifetime, and ownership compatible?
- Does registration occur before the affected request, callback, or garbage-collection path can execute?

Record omitted bindings as `missing-added` with exact file, line, registration name, and native symbol. Mark conditional or runtime-selected relations `unresolved` unless current source and configuration establish the active path.
