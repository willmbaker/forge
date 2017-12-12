
local StaticLibrary = build.TargetPrototype( "StaticLibrary" );

function StaticLibrary.create( _, id, architecture, settings )
    local settings = settings or build.current_settings();
    local static_library = build.Target( ("%s_%s"):format(id, architecture), StaticLibrary );
    static_library.settings = settings;
    static_library.architecture = architecture;
    static_library:set_filename( ("%s/%s"):format(settings.lib, lib_name(id, architecture)) );
    static_library:add_dependency( Directory(branch(static_library:get_filename())) );
    working_directory():add_dependency( static_library );
    return static_library;
end

function StaticLibrary.call( static_library, definition )
    build.merge( static_library, definition );
    for _, dependency in ipairs(definition) do 
        dependency.module = static_library;
        static_library:add_dependency( dependency );
    end
end

function StaticLibrary.build( static_library )
    if static_library:is_outdated() then
        build_library( static_library );
    end    
end

function StaticLibrary.clean( static_library )
    clean_library( static_library );
end

_G.StaticLibrary = StaticLibrary;