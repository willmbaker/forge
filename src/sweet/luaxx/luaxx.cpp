//
// luaxx.cpp
// Copyright (c) Charles Baker. All rights reserved.
//

#include <sweet/luaxx/luaxx.hpp>
#include <sweet/assert/assert.hpp>
#include <lua/lua.hpp>

using namespace sweet::luaxx;

namespace sweet
{

namespace lua
{

extern void lua_dump_stack( lua_State* lua );

}

namespace luaxx
{

/** 
// The keyword used to store the address of objects. 
*/
const char* THIS_KEYWORD = "__luaxx_this";

/** 
// The keyword used to store the type of an object.
*/
const char* TYPE_KEYWORD = "__luaxx_type";

/** 
// The keyword used to store the weak objects table in the %Lua registry.
*/
const char* WEAK_OBJECTS_KEYWORD = "__luaxx_weak_objects";

/**
// Create a Lua object in \e lua identified by \e object.
//
// @param lua
//  The lua_State to create the object in.
//
// @param object
//  The address to use to identify the object.
//
// @param tname
//  The name of the type used to identify the attached object.
*/
void luaxx_create( lua_State* lua, void* object, const char* tname )
{
    SWEET_ASSERT( lua );
    SWEET_ASSERT( object );
    SWEET_ASSERT( tname );
    lua_newtable( lua );
    luaxx_attach( lua, object, tname );
    lua_pop( lua, 1 );
}

/**
// Inject a C++ object to Lua table relationship into the Lua table at the top
// of the stack.
//
// @param lua
//  The lua_State to create the object in.
//
// @param object
//  The address to use to identify the object.
//
// @param tname
//  The identifier that specifies the type of the object to attach to.
*/
void luaxx_attach( lua_State* lua, void* object, const char* tname )
{
    SWEET_ASSERT( lua );
    SWEET_ASSERT( lua_istable(lua, -1) );
    SWEET_ASSERT( object );
    SWEET_ASSERT( tname );

    // Set the this pointer stored in the Lua table to point to `object`.
    lua_pushstring( lua, THIS_KEYWORD );
    lua_pushlightuserdata( lua, object );
    lua_rawset( lua, -3 );

    // Set the type stored in the Lua table to the value of `tname`.
    lua_pushstring( lua, TYPE_KEYWORD );
    lua_pushstring( lua, tname );
    lua_rawset( lua, -3 );

    // Store the Lua table in the registry accessed by `object`.
    lua_pushlightuserdata( lua, object );
    lua_pushvalue( lua, -2 );
    lua_rawset( lua, LUA_REGISTRYINDEX );
}

/**
// Destroy the Lua object in \e lua identified by \e object.
//
// Sets the value of the field stored under the THIS_POINTER key to nil.
// This stops the object being able to be used to refer back to an object
// in C++ after that C++ object has been destroyed even though the Lua 
// table will exist until it is garbage collected.
//
// Also removes references to the Lua table for the object from the Lua 
// registry and the weak references table so that the Lua table can't be
// reached via the C++ object address anymore.
//
// @param lua
//  The lua_State to destroy the object in.
//
// @param object
//  The address to use to identify the object.
*/
void luaxx_destroy( lua_State* lua, void* object )
{
    SWEET_ASSERT( lua );
    luaxx_push( lua, object );
    if ( lua_istable(lua, -1) )
    {
        lua_pushstring( lua, THIS_KEYWORD );
        lua_pushnil( lua );
        lua_rawset( lua, -3 );

        lua_pushstring( lua, TYPE_KEYWORD );
        lua_pushnil( lua );
        lua_rawset( lua, -3 );
    }   
    lua_pop( lua, 1 );
    luaxx_remove( lua, object );
}

/**
// Remove references to Lua tables from \e object.
//
// @param lua
//  The lua_State to remove references to Lua tables from \e object in 
//  (assumed not null).
//
// @param object
//  The address to remove the associated Lua tables of.
//
// @param weak
//  A pointer to a boolean that is set to true if the object was removed from
//  the weak objects table (null to ignore)
*/
void luaxx_remove( lua_State* lua, void* object, bool* weak )
{
    // Remove any reference to the object from the Lua registry.
    lua_pushlightuserdata( lua, object );
    lua_pushnil( lua );
    lua_rawset( lua, LUA_REGISTRYINDEX );

    // Remove any reference to the object from the weak objects table.
    lua_getfield( lua, LUA_REGISTRYINDEX, WEAK_OBJECTS_KEYWORD );
    if ( lua_istable(lua, -1) )
    {
        lua_pushlightuserdata( lua, object );
        lua_pushnil( lua );
        lua_rawset( lua, -3 );
        if ( weak )
        {
            *weak = true;
        }
    }
    lua_pop( lua, 1 );
}

/**
// Swap the Lua objects associated with \e object and \e other_object.
//
// Swaps the values referenced by the two addresses in the Lua registry so 
// that the Lua table that is associated with \e object is swapped with the
// Lua table that is associated with \e other_object and vice versa.
//
// The strong/weak relationship from the C++ address to the Lua table is 
// *not* swapped.  For example if \e object has a strong relationship from 
// C++ to the first Lua table and \e other_object has a weak relationship 
// from C++ to the second Lua table then, after swapping, \e object has a 
// strong relationship from C++ to the second Lua table and \e other_object 
// has a weak relationship from C++ to the first Lua table.  The values are 
// swapped but the strength/weakness of the relationship from \e object and
// \e other_object to their Lua tables remains unchanged.
//
// @param lua
//  The Lua state to swap the objects in.
//
// @param object
//  The address used to associate with the first Lua object.
//
// @param other_object
//  The address used to associate with the second Lua object.
*/
void luaxx_swap( lua_State* lua, void* object, void* other_object )
{
    // Push the Lua table associated with the first object onto the stack and 
    // remove it from the Lua registry or weak objects table.
    lua_pushlightuserdata( lua, other_object );
    luaxx_push( lua, object );
    bool object_weak = false;
    luaxx_remove( lua, object, &object_weak );

    // Push the Lua table associated with the second object onto the stack and
    // remove it from the Lua registry or weak objects table.
    lua_pushlightuserdata( lua, object );
    luaxx_push( lua, other_object );
    bool other_object_weak = false;
    luaxx_remove( lua, other_object, &other_object_weak );

    // Swap associations between `object` and `other_object` and their entries
    // in the Lua registry.
    lua_rawset( lua, LUA_REGISTRYINDEX );
    lua_rawset( lua, LUA_REGISTRYINDEX );

    // Restore weak relationships from the first and second objects to their
    // associated Lua tables.  The strength of the relationship remains as it
    // was before this function was called; i.e. the values are swapped but 
    // the strengths of the relationships from C++ to those values are not.   
    if ( object_weak )
    {
        luaxx_weaken( lua, object );
    }

    if ( other_object_weak )
    {
        luaxx_weaken( lua, other_object );
    }
}

/**
// Weaken the object in \e lua identified by \e object.
//
// This moves the table associated with \e object from the Lua registry into
// the weak objects table.  The weak objects table stores only weak references
// to its contents.  This means that the table associated with \e object will
// be able to be garbage collected once there are no more references to it
// from Lua.
//
// @param lua
//  The lua_State to weaken the object in.
//
// @param object
//  The address to use to identify the object.
*/
void luaxx_weaken( lua_State* lua, void* object )
{
    SWEET_ASSERT( lua );
    if ( object )
    {
        // Get the weak objects table from the Lua registry.
        lua_getfield( lua, LUA_REGISTRYINDEX, WEAK_OBJECTS_KEYWORD );
        SWEET_ASSERT( lua_istable(lua, -1) );

        // If there is a table for the object in the Lua registry then move that
        // table from the registry to the weak objects table otherwise assume that
        // the object is already weakened and its table already exists in the
        // weak objects table and quietly do nothing.
        lua_pushlightuserdata( lua, object );
        lua_rawget( lua, LUA_REGISTRYINDEX );
        if ( lua_istable(lua, -1) )
        {
            // Add the object's table to the weak objects table.
            lua_pushlightuserdata( lua, object );
            lua_pushvalue( lua, -2 );
            lua_rawset( lua, -4 );

            // Remove the object's table from the Lua registry.
            lua_pushlightuserdata( lua, object );
            lua_pushnil( lua );
            lua_rawset( lua, LUA_REGISTRYINDEX );
        }
        lua_pop( lua, 2 );
    }
}

/**
// Strengthen the object in \e lua identified by \e object.
//
// This moves the table associated with \e object from the weak objects
// table back to the Lua registry.
//
// @param lua
//  The lua_State to strengthen the object in.
//
// @param object
//  The address to use to identify the object.
*/
void luaxx_strengthen( lua_State* lua, void* object )
{
    SWEET_ASSERT( lua );
    if ( object )
    {
        // Get the weak objects table from the Lua registry.
        lua_getfield( lua, LUA_REGISTRYINDEX, WEAK_OBJECTS_KEYWORD );
        SWEET_ASSERT( lua_istable(lua, -1) );

        // If there is a table for the object in the weak objects table then 
        // move that table from the weak objects table to the registry 
        // otherwise assume that the object is already weakened and its table
        // already exists in the weak objects table and quietly do nothing.
        lua_pushlightuserdata( lua, object );
        lua_rawget( lua, -2 );
        if ( lua_istable(lua, -1) )
        {
            // Add the object's table to the Lua registry.
            lua_pushlightuserdata( lua, object );
            lua_pushvalue( lua, -2 );
            lua_rawset( lua, LUA_REGISTRYINDEX );

            // Remove the object's table from the weak objects table.
            lua_pushlightuserdata( lua, object );
            lua_pushnil( lua );
            lua_rawset( lua, -4 );
        }
        lua_pop( lua, 2 );
    }
}

/**
// Push \e object's equivalent table onto the stack in \e lua.
//
// @param lua
//  The lua_State to push the object onto the stack of.
//
// @param object
//  The address that identifies the object previously passed to 
//  `luaxx_create()` (can be null).
//
// @return
//  True if there was a table corresponding to \e object in \e lua otherwise
//  false.
*/
bool luaxx_push( lua_State* lua, void* object )
{
    SWEET_ASSERT( lua );
    
    if ( object )
    {
        lua_pushlightuserdata( lua, object );
        lua_rawget( lua, LUA_REGISTRYINDEX );
        SWEET_ASSERT( lua_istable(lua, -1) || lua_isnil(lua, -1) );
        if ( lua_isnil(lua, -1) )
        {
            lua_pop( lua, 1 );
            lua_getfield( lua, LUA_REGISTRYINDEX, WEAK_OBJECTS_KEYWORD );
            SWEET_ASSERT( lua_istable(lua, -1) );
            lua_pushlightuserdata( lua, object );
            lua_rawget( lua, -2 );
            lua_remove( lua, -2 );
        }

        // If anything other than a table ends up on the top of the stack
        // after looking for tables in the Lua registry and the weak 
        // objects table then pop that and push nil in its place to allow 
        // later error handling to report a problem.  This usually means 
        // that no table has been created for the C++ object via 
        // `luaxx_create()` or `luaxx_attach()`.
        if ( !lua_istable(lua, -1) && !lua_isnil(lua, -1) )
        {
            lua_pop( lua, 1 );
            lua_pushnil( lua );
        }         
    }
    else
    {
        lua_pushnil( lua );
    }
    return lua_istable( lua, -1 );
}

/**
// Get the address of the object at \e position in \e lua's stack.
//
// @param lua
//  The lua_State to push the object onto the stack of.
//
// @param position
//  The absolute position in the stack to get the object from (it is assumed
//  that this position is an absolute position; that is \e position > 0 or
//  position < LUA_REGISTRYINDEX (-10000)).
//
// @param tname
//  The type to check that the object is (set luaL_newmetatable()).
//
// @return
//  The address of the object or null if there is no value at that position
//  on the stack or if the value at that position is nil.
*/
void* luaxx_to( lua_State* lua, int position, const char* tname )
{
    SWEET_ASSERT( lua );
    SWEET_ASSERT( position > 0 || position < LUA_REGISTRYINDEX );

    void* object = nullptr;
    lua_pushstring( lua, tname );
    lua_pushstring( lua, TYPE_KEYWORD );
    lua_gettable( lua, position );
    if ( lua_rawequal(lua, -1, -2) )
    {
        lua_pushstring( lua, THIS_KEYWORD );
        lua_gettable( lua, position );
        if ( lua_islightuserdata(lua, -1) )
        {
            object = lua_touserdata( lua, -1 );
        }
        lua_pop( lua, 1 );
    }
    lua_pop( lua, 2 );
    return object;
}

/**
// Get the address of the object at \e position in \e lua's stack.
//
// If the object at \e position in the stack can't be converted to a C++ 
// object pointer because it is nil, isn't a table, doesn't have a matching
// type, or has no this pointer then an error is generated.
//
// @param lua
//  The lua_State to push the object onto the stack of.
//
// @param position
//  The absolute position in the stack to get the object from (it is assumed
//  that this position is an absolute position; that is \e position > 0 or
//  position < LUA_REGISTRYINDEX (-10000)).
//
// @param tname
//  The type to check that the object is (set luaL_newmetatable()).
//
// @return
//  The address of the object.
*/
void* luaxx_check( lua_State* lua, int position, const char* tname )
{
    void* object = luaxx_to( lua, position, tname );
    luaL_argcheck( lua, object != nullptr, position, "this pointer not set or C++ object has been destroyed" );
    return object;
}

}

}
