
ExtensionsModule = require ("extensions")

function getSolutionName()
	print("Type your solution name: ")
	return io.read()
end

function getPremakeAction()
	print("Choose environment from the list below (type idx): ")
	local vsArr = {"vs2005", "vs2008", "vs2010", "vs2012", "vs2013", "vs2015", "vs2017"}
	for i=1, table.getn(vsArr) do
		print(string.format("%d) %s", i, vsArr[i]))
	end
	local userEnv = io.read()
	return vsArr[tonumber(userEnv)]
end

function getLibOptions()
	local function getOptionMsg(option)
		local optionFmtStrBasic = "%d) %s\n"
		local optionFmtStrEx = "%d) %s - %s\n"
		local comment = option["comment"]
		if comment == nil then
			comment = ""
		end
		
		local optionLibs = option["libs"]
		local optionMsg = ""
		if optionLibs then
			local libsStr = ""	
			for j = 1, table.getn(optionLibs) do
				libsStr = libsStr .. optionLibs[j] .. " "
			end
			libsStr = ExtensionsModule.trim(libsStr)
			return ExtensionsModule.trim(libsStr .. " " .. comment)
		else
			return comment
		end
	end
	
	local function processBasic(option)
		return option["libs"]
	end
	
	local function processUserDefined(option)
		local libs = {}
		print("Do you want to include SDL? (y/n) ")
		local hasSDL = io.read() == 'y'
		if hasSDL then
			table.insert(libs, "SDL")
		else
			table.insert(libs, "Win32")
		end
		print("Do you want to use DirectX11 in your project? (y/n)")
		local useDirectX = io.read() == 'y'
		if useDirectX then
			table.insert(libs, "DirectX11")
		end
		return libs
	end

	local options = 
	{
		{ 
			libs={ "SDL" }, 
			func=processBasic 
		},
		{
			libs={ "SDL", "DirectX11", "assimp", "imgui" },
			func=processBasic
		},
		{
			libs={ "Win32" },
			comment="Empty win32 project, no additional libs included",
			func=processBasic
		},
		{
			comment="Create your own configuration",
			func=processUserDefined
		}
	}
	
	print("Pick one of the following configuration presets:")
	for i=1, table.getn(options) do
		local optionRow = options[i]
		local optionMsg = getOptionMsg(optionRow)
		print(string.format("%d) %s", i, optionMsg))
	end
	local selectedOption = options[tonumber(io.read())]
	local processFunc = selectedOption["func"]
	return processFunc(selectedOption)
end

function copyDir(locationPath, folderToCopy, destination)
	local srcDir = path.join('..',  folderToCopy)
	local destinationDir = nil
	if destination == nil then
		destinationDir = path.join(locationPath, folderToCopy)
	else
		destinationDir = path.join(locationPath, destination)
	end
	local isOk, err = ExtensionsModule.copydir(srcDir, destinationDir)
	print(srcDir, destinationDir)
	if not isOk then
		print(string.format("Copying folder %s failed with the following error: %s", folderToCopy, err))
		return false
	end
	return true
end

function createSolution(actionName, solutionName, libs)
	print(string.format("Creating solution %s for %s", solutionName, actionName))
	_ACTION = actionName
	
	local locationPath = path.join("..", solutionName)
	workspace (solutionName .. "_" .. actionName)
		location (locationPath)
		configurations { "Debug", "Release" }
		platforms { "x32", "x64" }
		
	local libConfigurations = 
	{
		imgui=
		{
			srcDir="imgui/src"
		},
		
		assimp=
		{
			includeDir="assimp/include",
			binDir="assimp/bin",
			includeLibs={"assimp-vc140-mt", "zlibstatic"},
			hasDLL=true
		},
		
		SDL= 
		{
			includeDir="SDL/include",
			binDir="SDL/bin",
			srcDir="SDL/src",
			includeLibs={ "SDL2", "SDL2main" },
			hasDLL=true
		},
		
		DirectX11=
		{
			includeLibs={ "d3d11", "d3dcompiler" }
		},
		
		Win32=
		{
			srcDir="Win32/src"
		}
	}
	
	local function getXCopyCmd(libName)
		local dllPath = "libs\\" .. libName .. "\\bin\\%{cfg.platform}\\*.dll"
		local dllDest = "bin\\%{cfg.platform}_%{cfg.buildcfg}"
		return string.format("xcopy /Y /D \"%s\" \"%s\"", dllPath, dllDest)
	end
	
	local allIncludeLibs = {}
	local allIncludeDirs = {}
	local allLibDirs = {}
	local allDlls = {}
	

	
	for i=1, table.getn(libs) do
		local lib = libs[i]
		local function makeLibsPath(lastPart)
			return path.join("libs", lib, lastPart)
		end
	
		local includePath = makeLibsPath("include")
		local binPath = makeLibsPath("bin")
		local srcPath = makeLibsPath("src")
		
		if os.isdir(includePath) then
			copyDir(locationPath, path.join("libs", "include"))
		end
		
	end
	
	for i=1, table.getn(libs) do
		local lib = libs[i]
		local libConfig = libConfigurations[lib]
		
		print (path.join(locationPath, lib, "include"))
		if os.isdir(path.join(locationPath, lib, "include")) then
			print ("LUL")
		end
		
		if libConfig["includeDir"] then
			copyDir(locationPath, path.join("libs", libConfig["includeDir"]))
			table.insert(allIncludeDirs, path.join(locationPath, "libs", libConfig["includeDir"]))
		end
		
		if libConfig["binDir"] then
			copyDir(locationPath, path.join("libs", libConfig["binDir"]))
			table.insert(allLibDirs, path.join(locationPath, "libs", libConfig["binDir"], "%{cfg.platform}"))
		end
		
		if libConfig["srcDir"] then
			copyDir(locationPath, path.join("libs", libConfig["srcDir"]), "src")
		end
		
		if libConfig["includeLibs"] then
			table.insert(allIncludeLibs, libConfig["includeLibs"])
		end
		
		if libConfig["hasDLL"] then
			table.insert(allDlls, getXCopyCmd(lib))
		end
	end

	project (solutionName)
		location (locationPath)
		kind "WindowedApp"
		language "C++"
		targetdir (path.join(locationPath, "bin/%{cfg.platform}_%{cfg.buildcfg}"))
		objdir (path.join(locationPath, "obj/%{cfg.platform}_%{cfg.buildcfg}"))
		
		local srcPath = path.join(locationPath, "src")
		files { 
			srcPath .. "/**.h", 
			srcPath .. "/**.cpp",
		}
		
		local libsDir = path.join(locationPath, "libs")
		local includeDir = path.join(locationPath, "include")
		
		libdirs { allLibDirs }	
		includedirs { allIncludeDirs }
		links { allIncludeLibs }
		
		filter "configurations:Debug"
			defines { "DEBUG" }
			symbols "On"
			
		filter "configurations:Release"
			defines { "NDEBUG" }
			optimize "On"
			
		configuration "windows"
			postbuildcommands { allDlls }

end

local solutionName = getSolutionName()
local premakeAction = getPremakeAction()
local libs = getLibOptions()

createSolution(premakeAction, solutionName, libs)

