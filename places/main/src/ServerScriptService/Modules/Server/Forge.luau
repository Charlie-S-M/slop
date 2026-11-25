--!strict

--[[
	Forging, in two steps. `Forge` takes the player's ores and rolls the gun's rarity, catalog
	entry, base Power, and Training Power, then hands the client a one-use token so it can play the
	cutscene. `ForgeFinish` brings back the four timing-game strikes, which set the grade that
	finishes Power and Speed.

	The forge in progress is kept in the profile, so ores are never lost: a forge left unfinished
	for too long, or by a player who leaves, or found on load after a crash, finishes with every
	unplayed strike counted as a miss.
]]

const HttpService = game:GetService("HttpService")

const Balance = require("@game/ReplicatedStorage/Shared/Balance")
const GunStats = require("@game/ReplicatedStorage/Shared/GunStats")
const Guns = require("@game/ReplicatedStorage/Shared/Guns")
const Net = require("@game/ReplicatedStorage/Shared/Net")
const Ores = require("@game/ReplicatedStorage/Shared/Ores")
const Rarity = require("@game/ReplicatedStorage/Shared/Rarity")
const Types = require("@game/ReplicatedStorage/Shared/Types")
const Upgrades = require("@game/ReplicatedStorage/Shared/Upgrades")
const PlayerData = require("./PlayerData")
const RateLimit = require("./RateLimit")

const FORGE_REACH = 45

local Forge = {}

local random = Random.new()
local notifyRemote: RemoteEvent
local startRemote: RemoteEvent
local resultRemote: RemoteEvent

local function notify(player: Player, text: string, color: Color3?)
	notifyRemote:FireClient(player, text, color)
end

local function nearAnvil(player: Player): boolean
	local lobby = workspace:FindFirstChild("Lobby")
	local forge = lobby and lobby:FindFirstChild("Forge")
	local anvil = forge and forge:FindFirstChild("Anvil")
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not anvil or not anvil:IsA("BasePart") or not root or not root:IsA("BasePart") then
		return false
	end
	return (anvil.Position - root.Position).Magnitude <= FORGE_REACH
end

-- Damage per second at zero Power, the yardstick for "is the new gun better?".
local function rawDps(item: Types.GunItem): number
	local def = Guns.get(item.id)
	if not def then
		return 0
	end
	return Balance.shotDamage(0, item.power, def.kind, 0, 1, def.id)
		* GunStats.fireRate(def.kind, item.speed)
end

--[[
	Turns a profile's pending forge into a gun with the given strikes. Strikes that are missing or
	malformed count as misses. Returns the new gun, or nil when there was nothing pending.
]]
local function finishProfile(
	profile: Types.Profile,
	accuracies: { any }
): (Types.GunItem?, boolean, boolean)
	local pending = profile.pendingForge
	if not pending then
		return nil, false, false
	end
	profile.pendingForge = nil
	local grade = GunStats.gradeFor(accuracies)
	local speedRoll = random:NextNumber(Balance.SPEED_ROLL_MIN, Balance.SPEED_ROLL_MAX)
	local power, speed = GunStats.finalize(pending.basePower, grade, speedRoll)
	local item: Types.GunItem = {
		uid = PlayerData.newGunUid(profile),
		id = pending.gunId,
		power = power,
		speed = speed,
		train = pending.train,
		grade = grade,
		locked = false,
	}
	local current = PlayerData.equippedGun(profile)
	table.insert(profile.guns, item)
	local isNew = not profile.gunIndex[pending.gunId]
	profile.gunIndex[pending.gunId] = true
	profile.forges += 1
	return item, isNew, rawDps(item) > rawDps(current)
end

-- Finishes a player's pending forge and tells their client. Used by ForgeFinish and by timeouts.
function Forge.finishPending(player: Player, accuracies: { any }?): Types.GunItem?
	local profile = PlayerData.get(player)
	if not profile then
		return nil
	end
	local item, isNew, better = finishProfile(profile, accuracies or {})
	if not item then
		return nil
	end
	PlayerData.markState(player)
	resultRemote:FireClient(player, { item = item, new = isNew, better = better })
	return item
end

--[[
	Step one. The request is a table of ore id -> count, one to five ores in all. Validates and
	spends the ores, rolls everything but the grade, and sends the client a token.
]]
local function onForge(player: Player, request: unknown)
	if not RateLimit.allow(player, "Forge", 0.5, 2) or player:GetAttribute("InRun") then
		return
	end
	if typeof(request) ~= "table" then
		return
	end
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	if profile.pendingForge then
		notify(player, "Finish your current forge first!")
		return
	end
	if not nearAnvil(player) then
		notify(player, "Head to the forge to craft a gun!")
		return
	end
	if #profile.guns >= Balance.MAX_GUNS then
		notify(
			player,
			"Your backpack is full of guns. Sell a few first!",
			Color3.fromRGB(255, 200, 60)
		)
		return
	end

	local list: { Ores.OreDef } = {}
	local used: { [string]: number } = {}
	local entries = 0
	for key, value in request :: { [any]: any } do
		entries += 1
		if entries > Balance.MAX_FORGE_ORES then
			return
		end
		if typeof(key) ~= "string" or typeof(value) ~= "number" or value ~= value then
			return
		end
		if value ~= math.floor(value) or value < 1 or value > Balance.MAX_FORGE_ORES then
			return
		end
		local ore = Ores.get(key)
		if not ore or (profile.bag[key] or 0) < value then
			return
		end
		used[key] = value
		for _ = 1, value do
			table.insert(list, ore)
		end
	end
	if #list < 1 or #list > Balance.MAX_FORGE_ORES then
		return
	end

	local luck = Upgrades.value("Luck", profile.upgrades.Luck or 0)
	local odds = Balance.forgeOdds(list, luck)
	local rarity = Balance.pickRarity(odds, random:NextNumber())
	local pool = Guns.pool(rarity)
	if #pool == 0 then
		return
	end
	local def = pool[random:NextInteger(1, #pool)]
	local roll = random:NextNumber(Balance.FORGE_ROLL_MIN, Balance.FORGE_ROLL_MAX)
	local basePower = math.max(1, odds.basePower * Rarity.get(rarity).powerMultiplier * roll)

	for id, count in used do
		local remaining = (profile.bag[id] or 0) - count
		profile.bag[id] = if remaining > 0 then remaining else nil
	end
	local oreIds = {}
	for _, ore in list do
		table.insert(oreIds, ore.id)
	end
	local pending: Types.PendingForge = {
		token = HttpService:GenerateGUID(false),
		gunId = def.id,
		rarity = rarity,
		basePower = basePower,
		train = math.max(1, math.floor(basePower * GunStats.oreTrainingFactor(list) + 0.5)),
		oreIds = oreIds,
		startedAt = os.time(),
	}
	profile.pendingForge = pending
	PlayerData.markState(player)
	startRemote:FireClient(player, {
		token = pending.token,
		gunId = pending.gunId,
		rarity = pending.rarity,
		oreIds = pending.oreIds,
	})
end

-- Step two. The token must match the pending forge, and enough time must have passed for the
-- cutscene to really have played.
local function onForgeFinish(player: Player, token: unknown, accuracies: unknown)
	if not RateLimit.allow(player, "ForgeFinish", 1, 2) or typeof(token) ~= "string" then
		return
	end
	local profile = PlayerData.get(player)
	local pending = profile and profile.pendingForge
	if not pending or pending.token ~= token then
		return
	end
	if os.time() - pending.startedAt < Balance.FORGE_MIN_SECONDS then
		return
	end
	Forge.finishPending(player, if typeof(accuracies) == "table" then accuracies :: { any } else {})
end

function Forge:Start()
	notifyRemote = Net.event("Notify")
	startRemote = Net.event("ForgeStart")
	resultRemote = Net.event("ForgeResult")
	Net.event("Forge").OnServerEvent:Connect(onForge)
	Net.event("ForgeFinish").OnServerEvent:Connect(onForgeFinish)

	-- A forge found on load was cut off by a crash or a leave the server couldn't settle.
	local function settleOnLoad(player: Player)
		local profile = PlayerData.get(player)
		if profile and profile.pendingForge then
			Forge.finishPending(player, {})
		end
	end
	PlayerData.Loaded:Connect(settleOnLoad)
	for _, player in PlayerData.players() do
		settleOnLoad(player)
	end

	-- A leaving player's forge settles into the profile before its final save.
	PlayerData.onBeforeRelease(function(_player, profile)
		finishProfile(profile, {})
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.time()
			for _, player in PlayerData.players() do
				local profile = PlayerData.get(player)
				local pending = profile and profile.pendingForge
				if pending and now - pending.startedAt >= Balance.FORGE_TIMEOUT_SECONDS then
					Forge.finishPending(player, {})
				end
			end
		end
	end)
end

return Forge
