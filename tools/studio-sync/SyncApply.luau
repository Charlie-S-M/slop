--[[
	Paste into a ModuleScript at ServerStorage.__SyncApply. Moves the models imported into
	ServerStorage.__Sync over the live copies: Shared replaces ReplicatedStorage.Shared, and the
	server and client models replace their children in ServerScriptService and StarterPlayerScripts.
]]
local function replaceChildren(source: Instance, target: Instance)
	for _, child in source:GetChildren() do
		local old = target:FindFirstChild(child.Name)
		if old then
			old:Destroy()
		end
		child.Parent = target
	end
end

return function(): string
	local sync = game:GetService("ServerStorage"):FindFirstChild("__Sync")
	assert(sync, "ServerStorage.__Sync is missing")
	-- Keep only the newest import of each part.
	local seen = {}
	local children = sync:GetChildren()
	for index = #children, 1, -1 do
		local child = children[index]
		if seen[child.Name] then
			child:Destroy()
		else
			seen[child.Name] = true
		end
	end
	local moved = {}
	local shared = sync:FindFirstChild("shared")
	if shared then
		local old = game:GetService("ReplicatedStorage"):FindFirstChild("Shared")
		if old then
			old:Destroy()
		end
		shared.Name = "Shared"
		shared.Parent = game:GetService("ReplicatedStorage")
		table.insert(moved, "shared")
	end
	local server = sync:FindFirstChild("server")
	if server then
		replaceChildren(server, game:GetService("ServerScriptService"))
		server:Destroy()
		table.insert(moved, "server")
	end
	local client = sync:FindFirstChild("client")
	if client then
		replaceChildren(
			client,
			game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
		)
		client:Destroy()
		table.insert(moved, "client")
	end
	return table.concat(moved, ",")
end
