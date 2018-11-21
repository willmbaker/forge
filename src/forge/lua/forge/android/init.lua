
local android = {};

local directory_by_architecture = {
    ["armv5"] = "armeabi";
    ["armv7"] = "armeabi-v7a";
    ["mips"] = "mips";
    ["x86"] = "x86";
};

function android.configure( settings )
    local function autodetect_ndk_directory()
        if forge:operating_system() == 'windows' then
            return 'C:/android/android-ndk';
        else
            return forge:home( 'Library/Android/ndk' );
        end
    end

    local function autodetect_sdk_directory()
        if forge:operating_system() == 'windows' then
            return 'C:/Program Files (x86)/Android/android-sdk';
        else
            return forge:home( 'Library/Android/sdk' );
        end
    end

    local function autodetect_proguard_directory()
        return forge:home( 'proguard-6.0.3' );
    end

    local function autodetect_manifest_merger()
        return forge:home( 'android-manifest-merger/target/manifest-merger-jar-with-dependencies.jar' );
    end

    local local_settings = forge.local_settings;
    if not local_settings.android then
        local_settings.updated = true;
        local_settings.android = {
            ndk_directory = autodetect_ndk_directory();
            sdk_directory = autodetect_sdk_directory();
            build_tools_directory = ('%s/build-tools/28.0.0'):format( autodetect_sdk_directory() );
            proguard_directory = autodetect_proguard_directory();
            manifest_merger = autodetect_manifest_merger();
            toolchain_version = '4.9';
            ndk_platform = 'android-21';
            sdk_platform = 'android-22';
            architectures = { 'armv5', 'armv7' };
        };
    end
end

function android.toolchain_directory( settings, architecture )
    local android = settings.android;
    local toolchain_by_architecture = {
        ["armv5"] = "arm-linux-androideabi",
        ["armv7"] = "arm-linux-androideabi",
        ["mips"] = "mipsel-linux-android",
        ["x86"] = "x86"
    };
    local prebuilt_by_operating_system = {
        windows = "windows";
        macos = "darwin-x86_64";
    };
    return ("%s/toolchains/%s-%s/prebuilt/%s"):format( 
        android.ndk_directory, 
        toolchain_by_architecture [architecture], 
        android.toolchain_version, 
        prebuilt_by_operating_system [forge:operating_system()]
    );
end

function android.platform_directory( settings, architecture )
    local android = settings.android;
    local arch_by_architecture = {
        ["armv5"] = "arm",
        ["armv7"] = "arm",
        ["mips"] = "mips",
        ["x86"] = "x86"
    };
    return ("%s/platforms/%s/arch-%s"):format( android.ndk_directory, android.ndk_platform, arch_by_architecture[architecture] );
end

function android.include_directories( settings )
    local android = settings.android;
    local architecture = settings.architecture;
    local runtime_library = settings.runtime_library;
    if runtime_library:match("gnustl.*") then
        return {
            ("%s/sources/cxx-stl/gnu-libstdc++/%s/libs/%s/include"):format( android.ndk_directory, android.toolchain_version, directory_by_architecture[architecture] ),
            ("%s/sources/cxx-stl/gnu-libstdc++/%s/include"):format( android.ndk_directory, android.toolchain_version )
        };
    elseif runtime_library:match("stlport.*") then
        return {
            ("%s/sources/cxx-stl/stlport/stlport"):format( android.ndk_directory )
        };
    elseif runtime_library:match("c++.*") then
        return {
            ("%s/sources/cxx-stl/llvm-libc++/libcxx/include"):format( android.ndk_directory )
        };
    elseif runtime_library:match("gabi++.*") then 
        return {
            ("%s/sources/cxx-stl/gabi++/include"):format( android.ndk_directory )
        };
    else 
        assertf( false, "Unrecognized C++ runtime library '%s'", tostring(runtime_library) );
    end
end

function android.library_directories( settings, architecture )
    local runtime_library = settings.runtime_library;
    if runtime_library:match("gnustl.*") then
        return {
            ("%s/usr/lib"):format( android.platform_directory(settings, architecture) ),
            ("%s/sources/cxx-stl/gnu-libstdc++/%s/libs/%s"):format( settings.android.ndk_directory, settings.android.toolchain_version, directory_by_architecture[architecture] )
        };
    elseif runtime_library:match("stlport.*") then
        return {
            ("%s/usr/lib"):format( android.platform_directory(settings, architecture) ),
            ("%s/sources/cxx-stl/stlport/libs/%s"):format( settings.android.ndk_directory, directory_by_architecture[architecture] )
        };
    elseif runtime_library:match("c++.*") then 
        return {
            ("%s/usr/lib"):format( android.platform_directory(settings, architecture) ),
            ("%s/sources/cxx-stl/llvm-libc++/libs/%s"):format( settings.android.ndk_directory, directory_by_architecture[architecture] )
        };
    elseif runtime_library:match("gabi++.*") then 
        return {
            ("%s/usr/lib"):format( android.platform_directory(settings, architecture) ),
            ("%s/sources/cxx-stl/gabi++/libs/%s"):format( settings.android.ndk_directory, directory_by_architecture[architecture] )
        };
    else 
        assertf( false, "Unrecognized C++ runtime library '%s'", tostring(runtime_library) );
    end
end

function android.initialize( settings )
    if forge:operating_system() == 'windows' then
        local path = {
            ('%s/bin'):format( android.toolchain_directory(settings, 'armv5') )
        };
        android.environment = {
            PATH = table.concat( path, ';' );
        };
    else
        local path = {
            '/usr/bin',
            '/bin',
            ('%s/bin'):format( android.toolchain_directory(settings, 'armv5') )
        };
        android.environment = {
            PATH = table.concat( path, ':' );
        };
    end

    settings.android.proguard_enabled = settings.android.proguard_enabled or variant == 'shipping';
    
    for _, architecture in ipairs(settings.android.architectures) do 
        local android_ndk_forge = forge:configure {
            obj = ('%s/cc_android_%s'):format( settings.obj, architecture );
            platform = 'android';
            architecture = architecture;
            arch_directory = directory_by_architecture[architecture];
            runtime_library = 'gnustl_shared';
            obj_directory = android.obj_directory;
        };
        local android_ndk_gcc = require 'forge.cc.android_ndk_gcc';
        android_ndk_gcc.register( android_ndk_forge );
        forge:add_default_build( ('cc_android_%s'):format(architecture), android_ndk_forge );
    end

    local android_java_forge = forge:configure {
        classes = forge:root( ('%s/classes/java_android'):format(variant) );
        gen = forge:root( ('%s/gen/java_android'):format(variant) );
        system_jars = {
            ('%s/platforms/%s/android.jar'):format( settings.android.sdk_directory, settings.android.sdk_platform );
        };
    };
    forge:add_default_build( 'java_android', android_java_forge );
end

function android.cc( target )
    local flags = {
        "-DBUILD_OS_ANDROID";
        "-D__ARM_ARCH_5__",
        "-D__ARM_ARCH_5T__",
        "-D__ARM_ARCH_5E__",
        "-D__ARM_ARCH_5TE__",
        "-DANDROID"
    };

    gcc.append_defines( target, flags );
    gcc.append_version_defines( target, flags );

    table.insert( flags, ("--sysroot=%s"):format(android.platform_directory(target.settings, target.architecture)) );

    gcc.append_include_directories( target, flags );
    for _, directory in ipairs(android.include_directories(target.settings, target.architecture)) do
        assert( forge:exists(directory), ("The include directory '%s' does not exist"):format(directory) );
        table.insert( flags, ([[-I"%s"]]):format(directory) );
    end

    table.insert( flags, "-ffunction-sections" );
    table.insert( flags, "-funwind-tables" );
    table.insert( flags, "-no-canonical-prefixes" );
    table.insert( flags, "-fomit-frame-pointer" );
    table.insert( flags, "-fno-strict-aliasing" );
    table.insert( flags, "-finline" );
    table.insert( flags, "-finline-limit=64" );
    table.insert( flags, "-Wa,--noexecstack" );

    local language = target.language or "c++";
    if language then
        if string.find(language, "c++", 1, true) then
            table.insert( flags, "-Wno-deprecated" );
            table.insert( flags, "-fpermissive" );
        end
    end

    gcc.append_compile_flags( target, flags );

    local ccflags = table.concat( flags, " " );
    local gcc_ = ("%s/bin/arm-linux-androideabi-gcc"):format( android.toolchain_directory(target.settings, target.architecture) );
    for _, object in target:dependencies() do
        if object:outdated() then
            object:set_built( false );
            object:clear_implicit_dependencies();
            local source = object:dependency();
            print( forge:leaf(source:id()) );
            local output = object:filename();
            local input = forge:relative( source:filename() );
            forge:system( 
                gcc_, 
                ('arm-linux-androideabi-gcc %s -o "%s" "%s"'):format(ccflags, output, input), 
                android.environment,
                forge:dependencies_filter(object)
            );
            object:set_built( true );
        end
    end
end

function android.build_library( target )
    local flags = {
        "-rcs"
    };
    
    local settings = target.settings;
    forge:pushd( settings.obj_directory(forge, target) );
    local objects = {};
    for _, compile in target:dependencies() do
        local prototype = compile:prototype();
        if prototype == forge.Cc or prototype == forge.Cxx then
            for _, object in compile:dependencies() do
                table.insert( objects, forge:relative(object:filename()) )
            end
        end
    end
    
    if #objects > 0 then
        local arflags = table.concat( flags, " " );
        local arobjects = table.concat( objects, '" "' );
        local ar = ("%s/bin/arm-linux-androideabi-ar"):format( android.toolchain_directory(target.settings, target.architecture) );
        forge:system( ar, ('ar %s "%s" "%s"'):format(arflags, forge:native(target:filename()), arobjects), android.environment );
    end
    forge:popd();
end

function android.clean_library( target )
    forge:rm( target );
    local settings = target.settings;
    forge:rmdir( settings.obj_directory(forge, target) );
end

function android.build_executable( target )
    local flags = { 
        ("--sysroot=%s"):format( android.platform_directory(target.settings, target.architecture) ),
        ("-Wl,-soname,%s"):format( forge:leaf(target:filename()) ),
        "-shared",
        "-no-canonical-prefixes",
        "-Wl,--no-undefined",
        "-Wl,-z,noexecstack",
        "-Wl,-z,relro",
        "-Wl,-z,now",
        ('-o "%s"'):format( forge:native(target:filename()) )
    };

    gcc.append_link_flags( target, flags );
    gcc.append_library_directories( target, flags );
    for _, directory in ipairs(android.library_directories(target.settings, target.architecture)) do
        table.insert( flags, ('-L"%s"'):format(directory) );
    end

    local objects = {};
    local libraries = {};

    local settings = target.settings;
    forge:pushd( settings.obj_directory(forge, target) );
    for _, dependency in target:dependencies() do
        local prototype = dependency:prototype();
        if prototype == forge.Cc or prototype == forge.Cxx then
            for _, object in dependency:dependencies() do
                if object:prototype() == nil then
                    table.insert( objects, forge:relative(object:filename()) );
                end
            end
        elseif prototype == forge.StaticLibrary or prototype == forge.DynamicLibrary then
            if dependency.whole_archive then
                table.insert( libraries, ("-Wl,--whole-archive") );
            end
            table.insert( libraries, ("-l%s"):format(dependency:id()) );
            if dependency.whole_archive then
                table.insert( libraries, ("-Wl,--no-whole-archive") );
            end
        end
    end

    gcc.append_link_libraries( target, libraries );
    local runtime_library = target.settings.runtime_library;
    if runtime_library then 
        table.insert( flags, ("-l%s"):format(runtime_library) );
    end

    if #objects > 0 then
        local ldflags = table.concat( flags, " " );
        local ldobjects = table.concat( objects, '" "' );
        local ldlibs = table.concat( libraries, " " );
        local gxx = ("%s/bin/arm-linux-androideabi-g++"):format( android.toolchain_directory(target.settings, target.architecture) );
        forge:system( gxx, ('arm-linux-androideabi-g++ %s "%s" %s'):format(ldflags, ldobjects, ldlibs), android.environment );
    end
    forge:popd();
end 

function android.clean_executable( target )
    forge:rm( target );
    local settings = target.settings;
    forge:rmdir( settings.obj_directory(forge, target) );
end

-- Find the first Android .apk package found in the dependencies of the
-- passed in directory.
function android.find_apk( directory )
    local directory = directory or forge:find_target( forge:initial("all") );
    for _, dependency in directory:dependencies() do
        if dependency:prototype() == android.Apk then 
            return dependency;
        end
    end
end

-- Deploy the fist Android .apk package found in the dependencies of the 
-- current working directory.
function android.deploy( apk )
    local sdk_directory = forge.settings.android.sdk_directory;
    if sdk_directory then 
        assertf( apk, "No android.Apk target to deploy" );
        local adb = ("%s/platform-tools/adb"):format( sdk_directory );
        assertf( forge:is_file(adb), "No 'adb' executable found at '%s'", adb );

        local device_connected = false;
        local function adb_get_state_filter( state )
            device_connected = string.find( state, "device" ) ~= nil;
        end
        forge:system( adb, ('adb get-state'), android.environment, nil, adb_get_state_filter );
        if device_connected then
            forge:system( adb, ('adb install -r "%s"'):format(apk:filename()), android.environment );
        end
    end
end

function android.obj_directory( forge, target )
    local relative_path = forge:relative( target:working_directory():path(), forge:root() );
    return forge:absolute( relative_path, forge.settings.obj );
end

function android.cc_name( name )
    return ("%s.c"):format( forge:basename(name) );
end

function android.cxx_name( name )
    return ("%s.cpp"):format( forge:basename(name) );
end

function android.obj_name( name )
    return ('%s.o'):format( name );
end

function android.lib_name( name )
    return ("lib%s.a"):format( name );
end

function android.dll_name( name )
    return ('lib%s.so'):format( forge:basename(name) );
end

function android.exe_name( name, architecture )
    return ("%s_%s_%s_%s"):format( name, architecture, platform, variant );
end

function android.android_jar( settings )
    return ("%s/platforms/%s/android.jar"):format( settings.android.sdk_directory, settings.android.sdk_platform );
end

function android.DynamicLibrary( build, name, architecture )
    local settings = forge:current_settings();
    local architecture = architecture or settings.architecture;
    assertf( architecture, 'Missing architecture for Android dynamic library "%s"', name );
    local dynamic_library = forge:DynamicLibrary( ("${apk}/lib/%s/%s"):format(directory_by_architecture[architecture], name), architecture );
    dynamic_library.architecture = architecture;

    local group = forge:Target( forge:anonymous() );
    group:add_dependency( dynamic_library );
    group.depend = function( build, group, ... )
        return dynamic_library.depend( dynamic_library.forge, dynamic_library, ... );
    end

    local runtime_library = dynamic_library.settings.runtime_library;
    if runtime_library then 
        if runtime_library:match(".*_shared") then 
            local destination = ("%s/lib%s.so"):format( forge:branch(dynamic_library:filename()), runtime_library );
            for _, directory in ipairs(android.library_directories(dynamic_library.settings, dynamic_library.architecture)) do
                local source = ("%s/lib%s.so"):format( directory, runtime_library );
                if forge:exists(source) then
                    local copy = forge:Copy (destination) (source);
                    group:add_dependency( copy );
                    break;
                end
            end
        end
    end

    return group;
end

require 'forge.android.Aidl';
require 'forge.android.AndroidManifest';
require 'forge.android.Apk';
require 'forge.android.BuildConfig';
require 'forge.android.Dex';
require 'forge.android.R';

forge:register_module( android );
forge.android = android;
return android;
