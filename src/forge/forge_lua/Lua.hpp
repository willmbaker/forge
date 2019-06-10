#ifndef FORGE_LUAFORGE_HPP_INCLUDED
#define FORGE_LUAFORGE_HPP_INCLUDED

#include <vector>
#include <string>
#include <lua.hpp>

struct lua_State;

namespace sweet
{
    
namespace forge
{

class Target;
class TargetPrototype;
class Forge;
class LuaFileSystem;
class LuaContext;
class LuaGraph;
class LuaSystem;
class LuaTarget;
class LuaTargetPrototype;

class Lua
{
    Forge* forge_;
    lua_State* lua_state_;
    LuaFileSystem* lua_file_system_;
    LuaContext* lua_context_;
    LuaGraph* lua_graph_;
    LuaSystem* lua_system_;
    LuaTarget* lua_target_;
    LuaTargetPrototype* lua_target_prototype_;

public:
    Lua( Forge* forge );
    ~Lua();
    lua_State* lua_state() const;
    LuaTarget* lua_target() const;
    LuaTargetPrototype* lua_target_prototype() const;
    void create( Forge* forge );
    void destroy();
    void assign_global_variables( const std::vector<std::string>& assignments );

private:
};
    
}

}

#endif