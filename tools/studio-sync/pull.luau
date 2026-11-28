--[[
	Pulls code edited directly in Studio back into the repo. Export ReplicatedStorage.Shared,
	ServerScriptService.Modules, ServerScriptService.Tests.Specs, and StarterPlayer.StarterPlayerScripts
	to one .rbxm (the Studio MCP export_rbxm does this), then run:
	lune run tools/studio-sync/pull.luau <file.rbxm> places/main/src
	It writes every script whose source differs and lists what changed or was added.
]]
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local rbxm, base = process.args[1], process.args[2]
local roots = roblox.deserializeModel(fs.readFile(rbxm))
local map = {
	Shared = base .. "/ReplicatedStorage/Shared",
	Modules = base .. "/ServerScriptService/Modules",
	Specs = base .. "/ServerScriptService/Tests/Specs",
	StarterPlayerScripts = base .. "/StarterPlayer/StarterPlayerScripts",
}
local changed, added = {}, {}
for _, root in roots do
	local dir = map[root.Name]
	for _, d in root:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			local parts = {}
			local p = d.Parent
			while p ~= root do
				table.insert(parts, 1, p.Name)
				p = p.Parent
			end
			local folder = dir .. (if #parts > 0 then "/" .. table.concat(parts, "/") else "")
			local suffix = if d.ClassName == "Script"
				then ".server.luau"
				elseif d.ClassName == "LocalScript" then ".client.luau"
				else ".luau"
			local file = folder .. "/" .. d.Name .. suffix
			if
				not fs.isFile(file)
				and fs.isDir(folder .. "/" .. d.Name)
				and fs.isFile(folder .. "/" .. d.Name .. "/init.luau")
			then
				file = folder .. "/" .. d.Name .. "/init.luau"
			end
			local src = d.Source
			if fs.isFile(file) then
				if fs.readFile(file) ~= src then
					fs.writeFile(file, src)
					table.insert(changed, file)
				end
			else
				if not fs.isDir(folder) then
					fs.writeDir(folder)
				end
				fs.writeFile(file, src)
				table.insert(added, file)
			end
		end
	end
end
print("CHANGED " .. #changed)
for _, f in changed do
	print("  " .. f)
end
print("ADDED " .. #added)
for _, f in added do
	print("  " .. f)
end
