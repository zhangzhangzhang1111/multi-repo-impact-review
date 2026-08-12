# C/C++ and Lua binding verification

## Built-in providers

Inspect Lua C API registrations (`lua_register`, `luaL_Reg`, `luaL_setfuncs`, `lua_pushcfunction`), calls into Lua (`lua_getglobal`, `lua_getfield`, `lua_pcall`), LuaJIT FFI, and common binding frameworks such as sol2, LuaBridge, tolua++, and SWIG.

## Verification questions

- Which native symbol is exposed under which Lua-visible name?
- Which module/table owns the binding?
- Which Lua runtime and module search path are active?
- Is the binding conditional on a macro, platform, feature flag, or initialization order?
- Does C/C++ call a fixed Lua global or a dynamically selected function?
- Are arguments, return values, errors, lifetime, and ownership compatible?

## Custom providers

Add organization-specific registration functions to `project-packs/binding-patterns.tsv` rather than hard-coding project names in the engine. Each pattern must declare the registration function, Lua-name argument, native-symbol argument, and optional module argument.
