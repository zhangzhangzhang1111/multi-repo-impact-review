#include <lua.h>
#include <lauxlib.h>

static int native_submit(lua_State* state) {
    return 0;
}

static const luaL_Reg exports[] = {
    {"submit", native_submit},
    {nullptr, nullptr}
};
