# C/C++ 与 Lua 绑定核验

## 需要检查的绑定入口

检查 Lua C API 注册（`lua_register`、`luaL_Reg`、`luaL_setfuncs`、`lua_pushcfunction`、`lua_pushcclosure`）、模块加载（`luaopen_*`、`luaL_requiref`、`package.preload`）、C/C++ 调用 Lua（`lua_getglobal`、`lua_getfield`、`lua_pcall`）、userdata/元表注册（`luaL_newmetatable`、`__index`、`__gc`）、LuaJIT FFI，以及 sol2、LuaBridge、tolua++、SWIG 等框架。

使用 CodeGraph 定位原生代码和 Lua 符号及候选调用者。注册与按字符串选择的函数通常是动态的；跨语言关系必须回到当前源码逐条核实。

## 核验问题

- 哪个原生符号以什么 Lua 可见名称暴露？
- 绑定属于哪个模块、表、预加载入口、userdata 或元表？
- 实际使用哪个 Lua 运行时与模块搜索路径？
- 绑定是否受宏、平台、功能开关或初始化顺序限制？
- 原生代码调用固定的 Lua 全局函数，还是动态选择的函数？
- 闭包上值、参数、返回值、错误、生命周期和所有权是否兼容？
- 在受影响请求、回调或垃圾回收路径执行前，绑定是否已注册？

遗漏的绑定标记为 `missing-added`，并记录准确文件、行号、注册名与原生符号。条件性或运行时选择的关系，若当前源码和配置不足以确定活动路径，则标记为 `unresolved`。
