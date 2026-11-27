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

const Armor = require("@game/ReplicatedStorage/Shared/Armor")
const ArmorStats = require("@game/ReplicatedStorage/Shared/ArmorStats")
const Balance = require("@game/ReplicatedStorage/Shared/Balance")
const GunStats = require("@game/ReplicatedStorage/Shared/GunStats")
const Guns = require("@game/ReplicatedStorage/Shared/Guns")
const Net = require("@game/ReplicatedStorage/Shared/Net")
const Ores = require("@game/ReplicatedStorage/Shared/Ores")
const Quests = require("@game/ReplicatedStorage/Shared/Quests")
const Rarity = require("@game/ReplicatedStorage/Shared/Rarity")
const Types = require("@game/ReplicatedStorage/Shared/Types")
const Loadout = require("./Loadout")
const Boosts = require("./Boosts")
const PlayerData = require("./PlayerData")
const RateLimit = require("./RateLimit")

const FORGE_REACH = 45

local Forge = {}

local random = Random.new()
local notifyRemote: RemoteEvent
local startRemote: RemoteEvent
local resultRemote: RemoteEvent
local evolveRemote: RemoteEvent

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

-- What a finished forge made: a gun in `item` or an armor piece in `armor`.
export type Outcome = {
	item: Types.GunItem?,
	armor: Types.ArmorItem?,
	new: boolean,
	better: boolean,
}

-- Turns a pending armor forge into the piece, and says whether it beats what's worn in its slot.
local function finishArmor(
	profile: Types.Profile,
	pending: Types.PendingForge,
	slot: Types.ArmorSlot,
	grade: Types.Grade
): Outcome?
	local def = Armor.get(pending.gunId)
	if not def then
		return nil
	end
	local roll = random:NextNumber(Balance.ARMOR_ROLL_MIN, Balance.ARMOR_ROLL_MAX)
	local piece = ArmorStats.makeItem(PlayerData.newGunUid(profile), def, grade, roll)
	local worth = 0
	for _, oreId in pending.oreIds do
		local ore = Ores.get(oreId)
		if ore then
			worth += Balance.oreSellPrice(ore, 0)
		end
	end
	piece.worth = worth
	local worn = ArmorStats.equippedIn(profile.armor, profile.equippedArmor, slot)
	local isNew = true
	for _, owned in profile.armor do
		if owned.id == piece.id then
			isNew = false
			break
		end
	end
	table.insert(profile.armor, piece)
	profile.forges += 1
	Quests.record(profile.quests, "Forges", 1)
	return {
		armor = piece,
		new = isNew,
		better = piece.defense > (if worn then worn.defense else 0),
	}
end

--[[
	Turns a profile's pending forge into a gun or armor piece with the given strikes. Strikes that
	are missing or malformed count as misses. Returns nil when there was nothing pending.
]]
local function finishProfile(profile: Types.Profile, accuracies: { any }): Outcome?
	local pending = profile.pendingForge
	if not pending then
		return nil
	end
	profile.pendingForge = nil
	local grade: Types.Grade = GunStats.gradeFor(accuracies)
	if pending.slot then
		return finishArmor(profile, pending, pending.slot, grade)
	end
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
	Quests.record(profile.quests, "Forges", 1)
	return { item = item, new = isNew, better = rawDps(item) > rawDps(current) }
end

-- Finishes a player's pending forge and tells their client. Used by ForgeFinish and by timeouts.
function Forge.finishPending(player: Player, accuracies: { any }?): Outcome?
	local profile = PlayerData.get(player)
	if not profile then
		return nil
	end
	local scores = if Boosts.hasPass(player, "AutoPerfectForge")
		then table.create(Balance.STRIKES, 1)
		else accuracies or {}
	local outcome = finishProfile(profile, scores)
	if not outcome then
		return nil
	end
	PlayerData.markState(player)
	resultRemote:FireClient(player, outcome)
	return outcome
end

--[[
	Step one. The request is a table of ore id -> count, one to five ores in all. Validates and
	spends the ores, rolls everything but the grade, and sends the client a token. With a `slot`
	the forge makes that armor piece instead of a gun.
]]
local function startForge(player: Player, request: unknown, slot: Types.ArmorSlot?)
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
		notify(player, "Head to the forge to craft!")
		return
	end
	if slot and #profile.armor >= Balance.MAX_ARMOR then
		notify(
			player,
			"Your armor rack is full. Sell a few pieces first!",
			Color3.fromRGB(255, 200, 60)
		)
		return
	elseif not slot and #profile.guns >= Balance.MAX_GUNS then
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

	-- A Lucky Forge charge from the shop adds its luck to this one roll.
	const charge = profile.luckyForges > 0
	if charge then
		profile.luckyForges -= 1
	end
	const luck, eternalBoost = Balance.forgeLuck(Boosts.luckSources(player, profile, charge))
	local odds = Balance.forgeOdds(list, luck, eternalBoost)
	local rarity = Balance.pickRarity(odds, random:NextNumber())
	local itemId: string
	if slot then
		itemId = Armor.forSlot(slot, rarity).id
	else
		local pool = Guns.pool(rarity)
		if #pool == 0 then
			return
		end
		itemId = pool[random:NextInteger(1, #pool)].id
	end
	local roll = random:NextNumber(Balance.FORGE_ROLL_MIN, Balance.FORGE_ROLL_MAX)
	local basePower = math.max(1, odds.basePower * Rarity.get(rarity).powerMultiplier * roll)

	for id, count in used do
		local remaining = (profile.bag[id] or 0) - count
		if remaining > 0 then
			profile.bag[id] = remaining
		else
			profile.bag[id] = nil
		end
	end
	local oreIds = {}
	for _, ore in list do
		table.insert(oreIds, ore.id)
	end
	local pending: Types.PendingForge = {
		token = HttpService:GenerateGUID(false),
		gunId = itemId,
		slot = slot,
		rarity = rarity,
		basePower = basePower,
		train = math.max(
			1,
			math.floor(
				basePower * GunStats.oreTrainingFactor(list) * Balance.focusTraining(itemId) + 0.5
			)
		),
		oreIds = oreIds,
		startedAt = os.time(),
	}
	profile.pendingForge = pending
	PlayerData.markState(player)
	startRemote:FireClient(player, {
		token = pending.token,
		gunId = pending.gunId,
		slot = pending.slot,
		rarity = pending.rarity,
		oreIds = pending.oreIds,
	})
end

local function onForge(player: Player, request: unknown)
	startForge(player, request, nil)
end

local function onForgeArmor(player: Player, slot: unknown, request: unknown)
	if not Armor.isSlot(slot) then
		return
	end
	startForge(player, request, slot :: Types.ArmorSlot)
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

--[[
	Evolves an owned Legendary-and-up gun into its evolved catalog entry for one boss material (Balance.evolveMaterial) and coins.
	The same owned gun changes id and grows its stats; its uid, grade, and lock stay, so an equipped
	gun stays equipped.
]]
local function onEvolve(player: Player, uid: unknown)
	if not RateLimit.allow(player, "Evolve", 1, 2) or player:GetAttribute("InRun") then
		return
	end
	if typeof(uid) ~= "string" or #uid == 0 or #uid > 40 then
		return
	end
	local profile = PlayerData.get(player)
	if not profile or profile.pendingForge then
		return
	end
	if not nearAnvil(player) then
		notify(player, "Head to the forge to evolve a gun!")
		return
	end
	local item, index = PlayerData.findGun(profile, uid)
	local def = item and Guns.get(item.id)
	local evolution = item and Guns.evolutionOf(item.id)
	local cost = def and Balance.evolveCost(def.rarity)
	if not item or not index or not def or not evolution or not cost then
		return
	end
	local material = Balance.evolveMaterial(def.rarity)
	if (profile.materials[material] or 0) < 1 then
		local source = if material == "AuroraShard"
			then "the Aurora Reach boss"
			else "the Glassfall Foundry boss"
		notify(
			player,
			`You need a {Balance.MATERIAL_NAMES[material] or material} from {source}.`,
			Color3.fromRGB(255, 150, 200)
		)
		return
	end
	if not PlayerData.spendCoins(player, cost) then
		notify(player, "Not enough coins to evolve!", Color3.fromRGB(255, 120, 90))
		return
	end
	profile.materials[material] -= 1
	local evolved = GunStats.evolve(item, evolution.id)
	profile.guns[index] = evolved
	profile.gunIndex[evolution.id] = true
	PlayerData.markState(player)
	if profile.equipped == evolved.uid then
		Loadout.refreshGun(player)
	end
	evolveRemote:FireClient(player, { item = evolved })
end

--[[
	Tempers an owned armor piece for one Aurora Shard and coins: it blocks TEMPER_MULTIPLIER times as
	much, once. Checks run before anything is spent, and the Aurora Shard goes only once coins have.
]]
local function onTemper(player: Player, uid: unknown)
	if not RateLimit.allow(player, "Temper", 1, 2) or player:GetAttribute("InRun") then
		return
	end
	if typeof(uid) ~= "string" or #uid == 0 or #uid > 40 then
		return
	end
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	if not nearAnvil(player) then
		notify(player, "Head to the forge to temper armor!")
		return
	end
	local index: number? = nil
	for i, item in profile.armor do
		if item.uid == uid then
			index = i
			break
		end
	end
	local item = if index then profile.armor[index] else nil
	local def = item and Armor.get(item.id)
	if not index or not item or not def or not ArmorStats.canTemper(item) then
		return
	end
	if ArmorStats.temperGain(profile.armor, profile.equippedArmor, item) < 0.0001 then
		notify(player, "Your set is already at the 75% block cap, so tempering would add nothing.")
		return
	end
	if (profile.materials.AuroraShard or 0) < 1 then
		notify(player, "You need an Aurora Shard from the Aurora Sentinel!")
		return
	end
	if not PlayerData.spendCoins(player, Balance.temperCost(def.rarity)) then
		notify(player, "Not enough coins to temper that piece!")
		return
	end
	profile.materials.AuroraShard -= 1
	profile.armor[index] = ArmorStats.temper(item)
	PlayerData.markState(player)
	Loadout.refreshArmor(player)
	notify(player, `{def.name} tempered! It blocks more now.`, Color3.fromRGB(150, 230, 255))
end

function Forge:Start()
	notifyRemote = Net.event("Notify")
	startRemote = Net.event("ForgeStart")
	resultRemote = Net.event("ForgeResult")
	Net.event("Forge").OnServerEvent:Connect(onForge)
	Net.event("ForgeArmor").OnServerEvent:Connect(onForgeArmor)
	Net.event("TemperArmor").OnServerEvent:Connect(onTemper)
	Net.event("ForgeFinish").OnServerEvent:Connect(onForgeFinish)
	evolveRemote = Net.event("EvolveResult")
	Net.event("Evolve").OnServerEvent:Connect(onEvolve)

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
