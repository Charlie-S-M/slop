--!strict

-- Selling, equipping, upgrades, rebirths, and the daily reward. Every handler validates its
-- arguments and prices on the server. Forging lives in Forge.

const Attachments = require("@game/ReplicatedStorage/Shared/Attachments")
const Armor = require("@game/ReplicatedStorage/Shared/Armor")
const Balance = require("@game/ReplicatedStorage/Shared/Balance")
const Biomes = require("@game/ReplicatedStorage/Shared/Biomes")
const Guns = require("@game/ReplicatedStorage/Shared/Guns")
const Net = require("@game/ReplicatedStorage/Shared/Net")
const Ores = require("@game/ReplicatedStorage/Shared/Ores")
const Types = require("@game/ReplicatedStorage/Shared/Types")
const Upgrades = require("@game/ReplicatedStorage/Shared/Upgrades")
const Loadout = require("./Loadout")
const PlayerData = require("./PlayerData")
const RateLimit = require("./RateLimit")

local Economy = {}

local random = Random.new()
local notifyRemote: RemoteEvent
local rewardRemote: RemoteEvent

local function notify(player: Player, text: string, color: Color3?)
	notifyRemote:FireClient(player, text, color)
end

local function inLobby(player: Player): boolean
	return not player:GetAttribute("InRun")
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
	-- Its parts go back to the pile.
	const returned: { [string]: string } = item.parts or {}
	for _, partId in returned do
		profile.attachments[partId] = (profile.attachments[partId] or 0) + 1
	end
	PlayerData.addCoins(player, price)
	PlayerData.markState(player)
	rewardRemote:FireClient(player, { kind = "coins", coins = price })
end

------------------------------------------------------------------------------------------------
-- Attachments
------------------------------------------------------------------------------------------------

-- Puts an owned part on the equipped gun, returning whatever was in that slot to the pile.
local function onEquipPart(player: Player, partId: unknown)
	if
		not RateLimit.allow(player, "EquipPart", 4, 5)
		or typeof(partId) ~= "string"
		or not inLobby(player)
	then
		return
	end
	local profile = PlayerData.get(player)
	local def = Attachments.get(partId)
	if not profile or not def or (profile.attachments[def.id] or 0) < 1 then
		return
	end
	local gun = PlayerData.equippedGun(profile)
	local parts = gun.parts or {}
	local old = parts[def.slot]
	if old == def.id then
		return
	end
	profile.attachments[def.id] -= 1
	if profile.attachments[def.id] <= 0 then
		profile.attachments[def.id] = nil
	end
	if old then
		profile.attachments[old] = (profile.attachments[old] or 0) + 1
	end
	parts[def.slot] = def.id
	gun.parts = parts
	PlayerData.markState(player)
	Loadout.refreshGun(player)
end

local function onUnequipPart(player: Player, slot: unknown)
	if
		not RateLimit.allow(player, "EquipPart", 4, 5)
		or not Attachments.isSlot(slot)
		or not inLobby(player)
	then
		return
	end
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	local gun = PlayerData.equippedGun(profile)
	local old = gun.parts and gun.parts[slot :: string]
	if not old or not gun.parts then
		return
	end
	gun.parts[slot :: string] = nil
	profile.attachments[old] = (profile.attachments[old] or 0) + 1
	PlayerData.markState(player)
	Loadout.refreshGun(player)
end

------------------------------------------------------------------------------------------------
-- Armor
------------------------------------------------------------------------------------------------

local function findArmor(profile: Types.Profile, uid: string): (Types.ArmorItem?, number?)
	for index, item in profile.armor do
		if item.uid == uid then
			return item, index
		end
	end
	return nil, nil
end

-- Wears an owned piece in the slot it was made for, replacing whatever was there.
local function onEquipArmor(player: Player, uid: unknown)
	if not RateLimit.allow(player, "EquipArmor", 3, 4) or not isUid(uid) then
		return
	end
	local profile = PlayerData.get(player)
	local item = profile and findArmor(profile, uid :: string)
	local def = item and Armor.get(item.id)
	if not profile or not item or not def or profile.equippedArmor[def.slot] == item.uid then
		return
	end
	profile.equippedArmor[def.slot] = item.uid
	PlayerData.markState(player)
	Loadout.refreshArmor(player)
end

local function onUnequipArmor(player: Player, slot: unknown)
	if not RateLimit.allow(player, "EquipArmor", 3, 4) or not Armor.isSlot(slot) then
		return
	end
	local profile = PlayerData.get(player)
	if not profile or profile.equippedArmor[slot :: string] == nil then
		return
	end
	profile.equippedArmor[slot :: string] = nil
	PlayerData.markState(player)
	Loadout.refreshArmor(player)
end

local function onLockArmor(player: Player, uid: unknown)
	if not RateLimit.allow(player, "ToggleLock", 5, 6) or not isUid(uid) then
		return
	end
	local profile = PlayerData.get(player)
	local item = profile and findArmor(profile, uid :: string)
	if item then
		item.locked = not item.locked
		PlayerData.markState(player)
	end
end

-- Sells a piece that isn't worn or locked.
local function onSellArmor(player: Player, uid: unknown)
	if not RateLimit.allow(player, "SellGun", 5, 6) or not isUid(uid) or not inLobby(player) then
		return
	end
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	local item, index = findArmor(profile, uid :: string)
	if not item or not index or item.locked then
		return
	end
	for _, worn in profile.equippedArmor do
		if worn == item.uid then
			return
		end
	end
	local price = Balance.armorSellPrice(item.worth or 0)
	table.remove(profile.armor, index)
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
	local pool = Ores.forBiome(Biomes.bestReached(profile.bestStage))
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
	rewardRemote = Net.event("Reward")

	Net.event("Equip").OnServerEvent:Connect(onEquip)
	Net.event("ToggleLock").OnServerEvent:Connect(onToggleLock)
	Net.event("SellGun").OnServerEvent:Connect(onSellGun)
	Net.event("EquipArmor").OnServerEvent:Connect(onEquipArmor)
	Net.event("EquipPart").OnServerEvent:Connect(onEquipPart)
	Net.event("UnequipPart").OnServerEvent:Connect(onUnequipPart)
	Net.event("UnequipArmor").OnServerEvent:Connect(onUnequipArmor)
	Net.event("LockArmor").OnServerEvent:Connect(onLockArmor)
	Net.event("SellArmor").OnServerEvent:Connect(onSellArmor)
	Net.event("SellOres").OnServerEvent:Connect(onSellOres)
	Net.event("BuyUpgrade").OnServerEvent:Connect(onBuyUpgrade)
	Net.event("Rebirth").OnServerEvent:Connect(onRebirth)
	Net.event("ClaimDaily").OnServerEvent:Connect(onClaimDaily)
end

return Economy
