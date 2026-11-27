--!strict

--[[
	Shooting the lobby's farm animals: the shot animal is knocked off the map for everyone, the
	shooter gets a coin, and it comes back RESPAWN_SECONDS later where it was shot. Where an animal
	is comes from server time (FarmRoutes), so the server checks the shooter is close to it.
]]

const ReplicatedStorage = game:GetService("ReplicatedStorage")

const FarmRoutes = require("@game/ReplicatedStorage/Shared/FarmRoutes")
const Net = require("@game/ReplicatedStorage/Shared/Net")
const Boosts = require("./Boosts")
const PlayerData = require("./PlayerData")
const RateLimit = require("./RateLimit")

-- How far from the shooter an animal may be; a little past the lobby camera's view.
const MAX_RANGE = 220

local Animals = {}

local function shiftOf(index: number): Vector2
	local value = ReplicatedStorage:GetAttribute(`AnimalShift{index}`)
	return if typeof(value) == "Vector2" then value else Vector2.zero
end

local function onShoot(player: Player, index: unknown)
	if not RateLimit.allow(player, "ShootAnimal", 4, 4) then
		return
	end
	if typeof(index) ~= "number" or index ~= math.floor(index) then
		return
	end
	local route = FarmRoutes.ROUTES[index]
	if not route or player:GetAttribute("InRun") then
		return
	end
	local now = workspace:GetServerTimeNow()
	local down = ReplicatedStorage:GetAttribute(`AnimalDown{index}`)
	if typeof(down) == "number" and down > now then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local at = FarmRoutes.position(route, now, shiftOf(index))
	local offset = at - root.Position
	if Vector3.new(offset.X, 0, offset.Z).Magnitude > MAX_RANGE then
		return
	end
	local respawnAt = now + FarmRoutes.RESPAWN_SECONDS
	ReplicatedStorage:SetAttribute(
		`AnimalShift{index}`,
		FarmRoutes.shiftFor(route, respawnAt, Vector2.new(at.X, at.Z))
	)
	-- Where it was hit, for the knock-off animation on every client.
	ReplicatedStorage:SetAttribute(`AnimalHitAt{index}`, at)
	ReplicatedStorage:SetAttribute(`AnimalDown{index}`, respawnAt)
	local profile = PlayerData.get(player)
	if profile then
		PlayerData.addCoins(player, math.max(1, FarmRoutes.COINS * Boosts.coins(player, profile)))
	end
end

function Animals:Start()
	Net.event("ShootAnimal").OnServerEvent:Connect(onShoot)
end

return Animals
