
local Ivy = forge:FilePrototype( 'Ivy' );

function Ivy.build( toolset, target )
	local settings = toolset.settings;
	local java = ('%s/bin/java'):format( settings.android.jdk_directory );
	local ivy = settings.android.ivy;
	local unzip = settings.android.unzip or '/usr/bin/unzip';
	local pattern = ('^%s/([^/]*)/.*/[aj]ars/(.*)(%%.[^%%.]*)$'):format( settings.ivy_cache_directory or home('.ivy2/cache') );
	local args = {
		'java';
		('-jar "%s"'):format( settings.android.ivy );
		('-settings "%s"'):format( target:dependency(2) or 'ivysettings.xml' );
		('-ivy "%s"'):format( target:dependency(1) or 'ivy.xml' );
		('-retrieve "%s/[organisation]/[artifact]-[revision].[ext]"'):format( target:directory() );
		('-cachepath "%s"'):format( target );
	};
	system( java, args );

	local file, error_message = io.open( target:filename(), 'rb' );
	assertf( file, 'Opening "%s" to read Apache Ivy classpath failed - %s', error_message );
	local paths = file:read( 'a' );
	file:close();
	file = nil;

	target:clear_implicit_dependencies();
	
	local directory = target:directory();
	for path in paths:gmatch('([^:]+)[:\n\r]') do 
		local organisation, artifact, extension = path:match( pattern );
		if extension == '.aar' then 
			local aar_directory = ('%s/%s/%s'):format( directory, organisation, artifact );
			local aar = ('%s%s'):format( aar_directory, extension );
			local args = {
				'unzip';
				('"%s"'):format( aar );
				('-d "%s"'):format( aar_directory );
			};
			rmdir( aar_directory );
			system( unzip, args );
			path = ('%s/%s/%s'):format( directory, organisation, artifact );
			target:add_implicit_dependency( toolset:Directory(path) );
		else
			path = ('%s/%s/%s%s'):format( directory, organisation, artifact, extension );
			target:add_implicit_dependency( toolset:File(path) );
		end
	end

	-- Touch the generated classpath file so that its timestamp is later than
	-- that of the *.aar* and *.jar* files added as implicit dependencies so
	-- that this `Ivy` target isn't outdated after being built.
	touch( target );
end

return Ivy;
