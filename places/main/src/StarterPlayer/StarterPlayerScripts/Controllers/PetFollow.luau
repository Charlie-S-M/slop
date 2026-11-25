--!strict
--[[
	Draws every player's equipped pets on this client. The server lists them in each player's "Pets"
	attribute; each pet floats beside its owner, trailing a little behind and bobbing. The models are
	local, so they cost the server nothing.
]]

const Players = game:GetService("Players")
const RunService = game:GetService("RunService")

const PetBuilder = require("@game/ReplicatedStorage/Shared/PetBuilder")
const Pets = require("@game/ReplicatedStorage/Shared/Pets")

local PetFollow = {}

type Follower = { model: Model, slot: number, at: CFrame }

local folder: Folder
local followers: { [Player]: { Follower } } = {}

-- Where each pet slot sits relative to its owner: behind and to the sides.
const OFFSETS = {
	Vector3.new(-3.2, 1.2, 2.2),
	Vector3.new(3.2, 1.2, 2.2),
	Vector3.new(0, 2.4, 3.6),
}

local function clear(player: Player)
	const list: { Follower } = followers[player] or {}
	for _, follower in list do
		follower.model:Destroy()
	end
	followers[player] = nil
end

local function rebuild(player: Player)
	clear(player)
	local list = player:GetAttribute("Pets")
	if typeof(list) ~= "string" or list == "" then
		return
	end
	local made: { Follower } = {}
	for _, id in string.split(list, ",") do
		local def = Pets.get(id)
		if def and #made < #OFFSETS then
			local model = PetBuilder.build(def)
			model.Parent = folder
			table.insert(made, { model = model, slot = #made + 1, at = model:GetPivot() })
		end
	end
	followers[player] = made
end

local function watch(player: Player)
	player:GetAttributeChangedSignal("Pets"):Connect(function()
		rebuild(player)
	end)
	rebuild(player)
end

local function step(delta: number)
	local now = os.clock()
	for player, list in followers do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			for _, follower in list do
				local offset = OFFSETS[follower.slot]
				local bob = math.sin(now * 3 + follower.slot) * 0.25
				local goal = root.CFrame * CFrame.new(offset + Vector3.new(0, bob, 0))
				follower.at = follower.at:Lerp(goal, math.min(1, delta * 8))
				follower.model:PivotTo(follower.at)
			end
		end
	end
end

function PetFollow:Start()
	folder = Instance.new("Folder")
	folder.Name = "Pets"
	folder.Parent = workspace
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(clear)
	RunService.RenderStepped:Connect(step)
end

return PetFollow
