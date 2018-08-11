
-- Reference Lua build scripts from within the source tree rather than 
-- relative to the build executable so that they can be edited in place during
-- development and are versioned along with the code that they are building.
package.path = forge:root('src/forge/lua/?.lua')..';'..forge:root('src/forge/lua/?/init.lua');

require "forge";
require "forge.cc";
require "forge.visual_studio";
require "forge.xcode";
require "forge.linux";
require "forge.macos";
require "forge.windows";

platform = platform or forge:operating_system();
variant = forge:lower( variant or "debug" );
version = version or ("%s %s %s"):format( os.date("%Y.%m.%d %H:%M:%S"), platform, variant );
goal = goal or "";
jobs = jobs or 4;

local settings = forge:initialize {
    variants = { "debug", "release", "shipping" };
    bin = forge:root( ('%s/bin'):format(variant) );
    lib = forge:root( ('%s/lib'):format(variant) );
    obj = forge:root( ('%s/obj'):format(variant) );
    include_directories = {
        forge:root( 'src' ),
        forge:root( 'src/boost' ),
        forge:root( 'src/lua/src' ),
        forge:root( 'src/unittest-cpp' )
    };
    library_directories = {
        forge:root( ('%s/lib'):format(variant) ),
    };
    visual_studio = {
        sln = forge:root( "forge.sln" );
    };
    xcode = {
        xcodeproj = forge:root( "forge.xcodeproj" );
    };
    zero_brane_studio = {
        mobdebug = forge:switch { forge:operating_system();
            macos = "/Applications/ZeroBraneStudio.app/Contents/ZeroBraneStudio/lualibs/mobdebug/mobdebug.lua";
            windows = "C:\\Program Files (x86)\\ZeroBraneStudio\\lualibs\\mobdebug\\mobdebug.lua";
        };
    };
};

-- Targets built when building from the root directory and as targets when
-- generating XCode projects and Visual Studio solutions.
forge:default_targets {
    'src/forge',
    'src/forge/forge',
    'src/forge/forge_hooks',
    'src/forge/forge_test'
};

buildfile 'src/assert/assert.build';
buildfile 'src/boost/boost.build';
buildfile 'src/cmdline/cmdline.build';
buildfile 'src/error/error.build';
buildfile 'src/forge/forge.build';
buildfile 'src/lua/lua.build';
buildfile 'src/luaxx/luaxx.build';
buildfile 'src/process/process.build';
buildfile 'src/unittest-cpp/unittest-cpp.build';

function install()
    prefix = prefix or forge:home( 'forge' );
    local failures = default();
    if failures == 0 then 
        forge:cpdir( '${prefix}/bin', '${bin}' );
        forge:cpdir( '${prefix}/lua', 'src/forge/lua' );
    end
end
