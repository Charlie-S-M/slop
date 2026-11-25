--!strict

--[[
	Every remote in the game, created by the server from these lists. Client code calls
	Net.event(name) and waits for the server to have made it.
]]

const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")

export type EventName =
	-- Client to server
	"Shoot"
	| "Reload"
	| "Equip"
	| "SellGun"
	| "ToggleLock"
	| "SellOres"
	| "Forge"
	| "ForgeFinish"
	| "Evolve"
	| "BuyUpgrade"
	| "Rebirth"
	| "ClaimDaily"
	| "EnterArena"
	| "LeaveArena"
	-- Server to client
	| "State"
	| "Stats"
	| "Notify"
	| "Run"
	| "ForgeStart"
	| "ForgeResult"
	| "EvolveResult"
	| "Reward"
	| "EnemyAttack"

-- High-volume effects that can drop a packet without harm.
export type UnreliableName = "HitFx" | "ShotFx" | "TrainFx"

const EVENTS: { EventName } = {
	"Shoot",
	"Reload",
	"Equip",
	"SellGun",
	"ToggleLock",
	"SellOres",
	"Forge",
	"ForgeFinish",
	"Evolve",
	"BuyUpgrade",
	"Rebirth",
	"ClaimDaily",
	"EnterArena",
	"LeaveArena",
	"State",
	"Stats",
	"Notify",
	"Run",
	"ForgeStart",
	"ForgeResult",
	"EvolveResult",
	"Reward",
	"EnemyAttack",
}

const UNRELIABLE: { UnreliableName } = { "HitFx", "ShotFx", "TrainFx" }

const FOLDER_NAME = "Remotes"

local Net = {}

local folder: Folder

if not RunService:IsRunning() then
	-- Outside a running game (the command bar, plugins, specs) there is nothing to talk to, so
	-- requiring Net hands back an empty folder instead of waiting forever.
	folder = Instance.new("Folder")
elseif RunService:IsServer() then
	folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	for _, name in EVENTS do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	for _, name in UNRELIABLE do
		local remote = Instance.new("UnreliableRemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

function Net.event(name: EventName): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

function Net.unreliable(name: UnreliableName): UnreliableRemoteEvent
	return folder:WaitForChild(name) :: UnreliableRemoteEvent
end

return Net
