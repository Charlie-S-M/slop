--!strict

-- Forging, selling, equipping, upgrades, rebirths, and the daily reward. Every handler validates
-- its arguments and prices on the server.

const Balance = require("@game/ReplicatedStorage/Shared/Balance")
const Guns = require("@game/ReplicatedStorage/Shared/Guns")
const Net = require("@game/ReplicatedStorage/Shared/Net")
const Ores = require("@game/ReplicatedStorage/Shared/Ores")
const Rarity = require("@game/ReplicatedStorage/Shared/Rarity")
const Upgrades = require("@game/ReplicatedStorage/Shared/Upgrades")
const Loadout = require("./Loadout")
const PlayerData = require("./PlayerData")
const RateLimit = require("./RateLimit")

const FORGE_REACH = 45

local Economy = {}

local random = Random.new()
local notifyRemote: RemoteEvent
local forgeRemote: RemoteEvent
local rewardRemote: RemoteEvent

local function notify(player: Player, text: string, color: Color3?)
	notifyRemote:FireClient(player, text, color)
end

local function inLobby(player: Player): boolean
	return not player:GetAttribute("InRun")
end

local function nearStation(player: Player, path: { string }, reach: number): boolean
	local node: Instance? = workspace:FindFirstChild("Lobby")
	for _, name in path do
		node = node and node:FindFirstChild(name)
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not node or not node:IsA("BasePart") or not root or not root:IsA("BasePart") then
		return false
	end
	return (node.Position - root.Position).Magnitude <= reach
end

local function isUid(value: unknown): boolean
	return typeof(value) == "string" and #value > 0 and #value <= 40
end

------------------------------------------------------------------------------------------------
-- Guns
------------------------------------------------------------------------------------------------

local function onEquip(player: Player, uid: unknown)
	if not RateLimit.allow(player, "Equip", 3, 4) or not isUid(uid) then
		return
	end
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	local item = PlayerData.findGun(profile, uid :: string)
	if not item or profile.equipped == item.uid then
		return
	end
	profile.equipped = item.uid
	PlayerData.markState(player)
	Loadout.refreshGun(player)
end

local function onToggleLock(player: Player, uid: unknown)
	if not RateLimit.allow(player, "ToggleLock", 5, 6) or not isUid(uid) then
		return
	end
	local profile = PlayerData.get(player)
	local item = profile and PlayerData.findGun(profile, uid :: string)
	if item then
		item.locked = not item.locked
		PlayerData.markState(player)
	end
end

local function onSellGun(player: Player, uid: unknown)
	if not RateLimit.allow(player, "SellGun", 5, 6) or not isUid(uid) or not inLobby(player) then
		return
	end
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	local item, index = PlayerData.findGun(profile, uid :: string)
	if
		not item
		or not index
		or item.locked
		or item.uid == profile.equipped
		or #profile.guns <= 1
	then
		return
	end
	local def = Guns.get(item.id)
	local price = Balance.gunSellPrice(item.power, if def then def.rarity else 1)
	table.remove(profile.guns, index)
	PlayerData.addCoins(player, price)
	PlayerData.markState(player)
	rewardRemote:FireClient(player, { kind = "coins", coins = price })
end

------------------------------------------------------------------------------------------------
-- Ores and the forge
------------------------------------------------------------------------------------------------

local function onSellOres(player: Player, oreId: unknown)
	if not RateLimit.allow(player, "SellOres", 3, 4) or not inLobby(player) then
		return
	end
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	if typeof(oreId) ~= "string" then
		return
	end
	local coinLevel = profile.upgrades.CoinBoost or 0
	local total = 0
	local sold = 0
	for id, count in profile.bag do
		if oreId == "*" or oreId == id then
			local ore = Ores.get(id)
			if ore and count > 0 then
				total += Balance.oreSellPrice(ore, coinLevel) * count
				sold += count
			end
			profile.bag[id] = nil
		end
	end
	if sold == 0 then
		return
	end
	PlayerData.addCoins(player, total)
	PlayerData.markState(player)
	rewardRemote:FireClient(player, { kind = "coins", coins = total, sold = sold })
end

--[[
	The forge takes a table of ore id -> count, between one and five ores in all. The rarity roll
	uses the same odds the client previews, then a gun of that rarity is picked and its power
	rolled from the ores' value.
]]
local function onForge(player: Player, request: unknown)
	if not RateLimit.allow(player, "Forge", 0.5, 2) or not inLobby(player) then
		return
	end
	if typeof(request) ~= "table" then
		return
	end
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	if not nearStation(player, { "Forge", "Anvil" }, FORGE_REACH) then
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
	local multiplier = Rarity.get(rarity).powerMultiplier
	local roll = random:NextNumber(Balance.FORGE_ROLL_MIN, Balance.FORGE_ROLL_MAX)
	local power = math.max(1, math.floor(odds.basePower * multiplier * roll))

	for id, count in used do
		local remaining = (profile.bag[id] or 0) - count
		profile.bag[id] = if remaining > 0 then remaining else nil
	end
	local item = { uid = PlayerData.newGunUid(profile), id = def.id, power = power, locked = false }
	table.insert(profile.guns, item)
	local isNew = not profile.gunIndex[def.id]
	profile.gunIndex[def.id] = true
	profile.forges += 1
	PlayerData.markState(player)

	-- Is the new gun stronger than what the player holds? The client suggests equipping it.
	local current = PlayerData.equippedGun(profile)
	local currentDef = Guns.get(current.id)
	local better = currentDef == nil
		or Balance.shotDamage(0, item.power, def.kind, 0, 1)
				* Guns.kindStats(def.kind).fireRate
			> Balance.shotDamage(0, current.power, currentDef.kind, 0, 1) * Guns.kindStats(
				currentDef.kind
			).fireRate
	forgeRemote:FireClient(player, { item = item, new = isNew, better = better })
end

------------------------------------------------------------------------------------------------
-- Upgrades, rebirth, daily
------------------------------------------------------------------------------------------------

local function onBuyUpgrade(player: Player, id: unknown)
	if not RateLimit.allow(player, "BuyUpgrade", 6, 8) or typeof(id) ~= "string" then
		return
	end
	local def = Upgrades.get(id)
	local profile = PlayerData.get(player)
	if not def or not profile then
		return
	end
	local level = profile.upgrades[id] or 0
	if level >= def.maxLevel then
		return
	end
	local cost = Upgrades.cost(def, level)
	if not PlayerData.spendCoins(player, cost) then
		notify(player, "Not enough coins!", Color3.fromRGB(255, 120, 90))
		return
	end
	profile.upgrades[id] = level + 1
	PlayerData.markState(player)
	PlayerData.LoadoutChanged:Fire(player)
	rewardRemote:FireClient(player, { kind = "upgrade", id = id, level = level + 1 })
end

local function onRebirth(player: Player)
	if not RateLimit.allow(player, "Rebirth", 0.5, 1) or not inLobby(player) then
		return
	end
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	local cost = Balance.rebirthCost(profile.rebirths)
	if profile.power < cost then
		return
	end
	profile.power = 0
	profile.rebirths += 1
	PlayerData.markState(player)
	PlayerData.LoadoutChanged:Fire(player)
	rewardRemote:FireClient(player, { kind = "rebirth", rebirths = profile.rebirths })
end

local function onClaimDaily(player: Player)
	if not RateLimit.allow(player, "ClaimDaily", 0.5, 1) then
		return
	end
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	local now = os.time()
	local since = now - profile.lastDaily
	if since < Balance.DAILY_COOLDOWN then
		return
	end
	-- Claiming within two days keeps the streak going.
	if since > Balance.DAILY_COOLDOWN * 2.4 then
		profile.dailyStreak = 0
	end
	profile.dailyStreak += 1
	profile.lastDaily = now
	local streakBonus = 1 + math.min(profile.dailyStreak - 1, 6) * 0.5
	local coins =
		math.floor((150 + Balance.enemyCoins(math.max(1, profile.bestStage)) * 25) * streakBonus)
	PlayerData.addCoins(player, coins)
	-- Plus a few ores from the best biome the player has reached.
	local biome = math.clamp(math.floor(profile.bestStage / 10) + 1, 1, 6)
	local pool = Ores.forBiome(biome)
	local given = 0
	local capacity = Upgrades.value("BagSize", profile.upgrades.BagSize or 0)
	for _ = 1, 3 do
		if PlayerData.bagCount(profile) >= capacity or #pool == 0 then
			break
		end
		local ore = pool[random:NextInteger(1, math.min(#pool, 4))]
		profile.bag[ore.id] = (profile.bag[ore.id] or 0) + 1
		profile.oreIndex[ore.id] = true
		given += 1
	end
	PlayerData.markState(player)
	rewardRemote:FireClient(
		player,
		{ kind = "daily", coins = coins, ores = given, streak = profile.dailyStreak }
	)
end

function Economy:Start()
	notifyRemote = Net.event("Notify")
	forgeRemote = Net.event("ForgeResult")
	rewardRemote = Net.event("Reward")

	Net.event("Equip").OnServerEvent:Connect(onEquip)
	Net.event("ToggleLock").OnServerEvent:Connect(onToggleLock)
	Net.event("SellGun").OnServerEvent:Connect(onSellGun)
	Net.event("SellOres").OnServerEvent:Connect(onSellOres)
	Net.event("Forge").OnServerEvent:Connect(onForge)
	Net.event("BuyUpgrade").OnServerEvent:Connect(onBuyUpgrade)
	Net.event("Rebirth").OnServerEvent:Connect(onRebirth)
	Net.event("ClaimDaily").OnServerEvent:Connect(onClaimDaily)
end

return Economy
