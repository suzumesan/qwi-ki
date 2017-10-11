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

function copyDir(solutionDirPath, folderToCopy, destination)
	local srcDir = path.join('..',  folderToCopy)
	local destinationDir = nil
	if destination == nil then
		destinationDir = path.join(solutionDirPath, folderToCopy)
	else
		destinationDir = path.join(solutionDirPath, destination)
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
	
	local solutionDirPath = path.join("..", solutionName)
	workspace (solutionName .. "_" .. actionName)
		location (solutionDirPath)
		configurations { "Debug", "Release" }
		platforms { "x32", "x64" }
		
	local libConfigurations = 
	{
		DirectX11=
		{
			includeLibs={ "d3d11", "d3dcompiler" }
		},
	}
	
	local function getXCopyCmd(libName)
		local dllPath = "libs\\" .. libName .. "\\bin\\%{cfg.platform}\\*.dll"
		local dllDest = "bin\\%{cfg.platform}_%{cfg.buildcfg}"
		return string.format("xcopy /Y /D \"%s\" \"%s\"", dllPath, dllDest)
	end
	
	local function solutionCopyDir(toCopy, destinationPath)
		return copyDir(solutionDirPath, toCopy, destinationPath)
	end
	
	local additionalLibs = {}
	
	for i=1, table.getn(libs) do
		local lib = libs[i]
		
		local function makeLibsPath(lastPart)
			return path.join("libs", lib, lastPart)
		end
		
		local function isDir(dir)
			return os.isdir(path.join("..", dir))
		end
	
		local includePath = makeLibsPath("include")
		local binPath = makeLibsPath("bin")
		local srcPath = makeLibsPath("src")
		local projectFilesPath = makeLibsPath("project")
		
		if isDir(includePath) then
			local copyDestination = path.join("libs", "include", lib)
			solutionCopyDir(includePath, copyDestination)
		end
		
		if isDir(binPath) then
			-- copy all bins to one dir. Names might clash
			local copyDestination = path.join("libs", "bin")
			solutionCopyDir(binPath, copyDestination)
		end
		
		if isDir(srcPath) then
			solutionCopyDir(srcPath, path.join("src", lib))
		end
		
		if isDir(projectFilesPath) then
			solutionCopyDir(projectFilesPath, "src")
		end
		
		if libConfigurations[lib] then
			libCfg = libConfigurations[lib]
			if libCfg["includeLibs"] then
				table.insert(additionalLibs, libCfg["includeLibs"])
			end
		end
		
	end
	
	-- get all libs and dlls
	local allIncludeLibs = {}
	for k,v in pairs(os.matchfiles(path.join(solutionDirPath, "libs", "bin", "**.lib"))) do 
		table.insert(allIncludeLibs, path.getname(v))
	end
	local allLibDirs = { path.join(solutionDirPath, "libs", "bin"), 
						 path.join(solutionDirPath, "libs", "bin", "%{cfg.platform}") }
	local allIncludeDirs = path.join(solutionDirPath, "libs", "include")

	project (solutionName)
		location (solutionDirPath)
		kind "WindowedApp"
		language "C++"
		targetdir (path.join(solutionDirPath, "bin/%{cfg.platform}_%{cfg.buildcfg}"))
		objdir (path.join(solutionDirPath, "obj/%{cfg.platform}_%{cfg.buildcfg}"))
		
		local srcPath = path.join(solutionDirPath, "src")
		files { 
			srcPath .. "/**.h", 
			srcPath .. "/**.cpp",
		}
		
		libdirs { allLibDirs }	
		includedirs { allIncludeDirs }
		links { allIncludeLibs, additionalLibs }
		
		filter "configurations:Debug"
			defines { "DEBUG" }
			symbols "On"
			
		filter "configurations:Release"
			defines { "NDEBUG" }
			optimize "On"
			
		local dllPath = "libs\\bin\\%{cfg.platform}\\*.dll"
		local dllDest = "bin\\%{cfg.platform}_%{cfg.buildcfg}"
		local platformDlls = string.format("xcopy /Y /D \"%s\" \"%s\"", dllPath, dllDest)
		local dllPath = "libs\\bin\\*.dll"
		local globalDlls = string.format("xcopy /Y /D \"%s\" \"%s\"", dllPath, dllDest)
		configuration "windows"
			postbuildcommands { platformDlls, globalDlls }

end

local solutionName = getSolutionName()
local premakeAction = getPremakeAction()
local libs = getLibOptions()

createSolution(premakeAction, solutionName, libs)


