--!strict

--[[
	Robux purchases. ProcessReceipt grants developer products once each (a receipt id seen before is
	acknowledged without granting again), and game passes are checked on join and when bought, then
	recorded as "Pass_<key>" player attributes for Boosts.luau. Every grant adds the Robux spent to
	the profile for the leaderboard. Potions bought here are used later from the shop.
]]

const MarketplaceService = game:GetService("MarketplaceService")
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Balance = require("@game/ReplicatedStorage/Shared/Balance")
const Net = require("@game/ReplicatedStorage/Shared/Net")
const Pets = require("@game/ReplicatedStorage/Shared/Pets")
const Products = require("@game/ReplicatedStorage/Shared/Products")
const Types = require("@game/ReplicatedStorage/Shared/Types")
const Wheel = require("@game/ReplicatedStorage/Shared/Wheel")
const Boosts = require("./Boosts")
const Economy = require("./Economy")
const PlayerData = require("./PlayerData")
const QuestKeeper = require("./QuestKeeper")
const LobbyBuilder = require("./World/LobbyBuilder")
const RateLimit = require("./RateLimit")

local Shop = {}

-- Receipts kept per profile to spot a retried one.
const RECEIPTS_KEPT = 100
const SERVER_LUCK_SECONDS = 15 * 60
-- How much stronger a limited gun is than the player's best gun.
const LIMITED_GUN_EDGE = 1.6
const COIN_PACKS = { Coins1 = 300, Coins2 = 1500, Coins3 = 6000, Coins4 = 25000 }
-- Power packs as a share of the next rebirth's cost.
const POWER_PACKS = { Power1 = 0.1, Power2 = 0.4, Power3 = 1.2, Power4 = 4 }
type PotionPack = { potion: string, count: number }
const POTION_PACKS: { [string]: PotionPack } = {
	LuckPotion = { potion = "LuckPotion", count = 1 },
	LuckPotion5 = { potion = "LuckPotion", count = 5 },
	PowerPotion = { potion = "PowerPotion", count = 1 },
	PowerPotion5 = { potion = "PowerPotion", count = 5 },
	CoinPotion = { potion = "CoinPotion", count = 1 },
	CoinPotion5 = { potion = "CoinPotion", count = 5 },
}

const random = Random.new()
local notifyRemote: RemoteEvent
local hatchedRemote: RemoteEvent
local wheelRemote: RemoteEvent

local function notify(player: Player, text: string)
	notifyRemote:FireClient(player, text, Color3.fromRGB(140, 255, 120))
end

local function bestGun(profile: Types.Profile): Types.GunItem
	local best = profile.guns[1]
	for _, gun in profile.guns do
		if gun.power > best.power then
			best = gun
		end
	end
	return best
end

local function grantGun(player: Player, profile: Types.Profile, gunId: string)
	local best = bestGun(profile)
	local item: Types.GunItem = {
		uid = PlayerData.newGunUid(profile),
		id = gunId,
		power = math.max(10, math.floor(best.power * LIMITED_GUN_EDGE)),
		speed = math.max(1.2, best.speed),
		train = math.max(10, math.floor(best.train * LIMITED_GUN_EDGE)),
		grade = "S",
		locked = true,
	}
	table.insert(profile.guns, item)
	profile.gunIndex[gunId] = true
	notify(player, "Your limited gun is in your Backpack! 🔫")
end

local function bestEgg(profile: Types.Profile): Pets.EggDef
	local best = Pets.EGGS[1]
	for _, egg in Pets.EGGS do
		if profile.bestStage + 1 >= egg.unlockStage and egg.unlockStage >= best.unlockStage then
			best = egg
		end
	end
	return best
end

local function hatch(player: Player, profile: Types.Profile, count: number)
	local egg = bestEgg(profile)
	local last: Types.PetItem? = nil
	for _ = 1, count do
		local def = Pets.roll(egg, random:NextNumber())
		local pet: Types.PetItem =
			{ uid = PlayerData.newGunUid(profile), id = def.id, locked = false }
		table.insert(profile.pets, pet)
		last = pet
	end
	QuestKeeper.record(player, "Hatches", count)
	hatchedRemote:FireClient(player, { pet = last, eggId = egg.id, count = count })
end

-- Applies what a product gives. Passes are granted through attributes instead.
local function grant(player: Player, profile: Types.Profile, key: string)
	if key == "StarterPack" then
		profile.starterPackBought = true
		PlayerData.addCoins(player, Balance.enemyCoins(math.max(profile.bestStage, 1)) * 400)
		profile.potions.LuckPotion = (profile.potions.LuckPotion or 0) + 3
		profile.luckyForges += 1
		notify(player, "Starter Pack unlocked! 🎁")
	elseif key == "NovaReaper" or key == "DragonheartCannon" then
		grantGun(player, profile, key)
	elseif key == "ServerLuck" then
		local now = os.time()
		local current = ReplicatedStorage:GetAttribute("ServerLuckUntil")
		local start = if typeof(current) == "number" and current > now then current else now
		ReplicatedStorage:SetAttribute("ServerLuckUntil", start + SERVER_LUCK_SECONDS)
		for _, other in Players:GetPlayers() do
			notifyRemote:FireClient(
				other,
				`🍀 {player.DisplayName} bought Server Luck! 2× forge luck for everyone.`,
				Color3.fromRGB(140, 255, 120)
			)
		end
	elseif key == "LuckyForge" or key == "LuckyForge5" then
		profile.luckyForges += if key == "LuckyForge5" then 5 else 1
		notify(player, "Lucky Forge ready! Your next forge rolls with 3× luck.")
	elseif COIN_PACKS[key] then
		PlayerData.addCoins(
			player,
			Balance.enemyCoins(math.max(profile.bestStage, 1)) * COIN_PACKS[key]
		)
	elseif POWER_PACKS[key] then
		PlayerData.addPower(player, Balance.rebirthCost(profile.rebirths) * POWER_PACKS[key])
	elseif key == "Eggs3" or key == "Eggs10" then
		hatch(player, profile, if key == "Eggs10" then 10 else 3)
	elseif POTION_PACKS[key] then
		local pack = POTION_PACKS[key]
		local potion, count = pack.potion, pack.count
		profile.potions[potion] = (profile.potions[potion] or 0) + count
		notify(player, `+{count} potion{if count == 1 then "" else "s"}! Use them from the shop.`)
	elseif Wheel.PACKS[key] then
		profile.wheelSpins += Wheel.PACKS[key]
		notify(player, `+{Wheel.PACKS[key]} Lucky Wheel spins! 🎡`)
	elseif key == "NewQuests" then
		QuestKeeper.reroll(player)
		notify(player, "Fresh daily quests! 📜")
	end
	PlayerData.markState(player)
end

-- Grants a product as if it were bought, for Studio testing and the specs.
function Shop.grantForTest(player: Player, key: string)
	local profile = PlayerData.get(player)
	if profile then
		grant(player, profile, key)
	end
end

local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local profile = player and PlayerData.get(player)
	local def = Products.byId("product", receipt.ProductId)
	if not player or not profile or not def then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local receiptId = tostring(receipt.PurchaseId)
	if table.find(profile.receipts, receiptId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local ok, err = pcall(function()
		grant(player, profile, def.key)
	end)
	if not ok then
		warn(`[Shop] Granting {def.key} failed: {err}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	table.insert(profile.receipts, receiptId)
	while #profile.receipts > RECEIPTS_KEPT do
		table.remove(profile.receipts, 1)
	end
	profile.robuxSpent += receipt.CurrencySpent or def.price
	PlayerData.markState(player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function setPass(player: Player, def: Products.ProductDef)
	player:SetAttribute(`Pass_{def.key}`, true)
	PlayerData.LoadoutChanged:Fire(player)
end

local function checkPasses(player: Player)
	for _, def in Products.List do
		local id = Products.id(def)
		if def.kind == "pass" and id then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
			end)
			if ok and owns then
				setPass(player, def)
			end
		end
	end
end

local function onUsePotion(player: Player, key: unknown)
	if not RateLimit.allow(player, "UsePotion", 2, 4) or typeof(key) ~= "string" then
		return
	end
	local profile = PlayerData.get(player)
	local boost = Products.POTIONS[key]
	if not profile or not boost or (profile.potions[key] or 0) < 1 then
		return
	end
	profile.potions[key] -= 1
	local now = os.time()
	local current = profile.boosts[boost] or 0
	profile.boosts[boost] = math.max(current, now) + Products.POTION_SECONDS
	PlayerData.markState(player)
	notify(player, `{boost} boost on for 15 more minutes! 🧪`)
end

-- Gives a Lucky Wheel prize. Amounts scale with progress like the shop's packs.
local function grantPrize(player: Player, profile: Types.Profile, key: string)
	if key == "Coins" then
		PlayerData.addCoins(player, Balance.enemyCoins(math.max(profile.bestStage, 1)) * 600)
	elseif key == "LuckPotion" then
		profile.potions.LuckPotion = (profile.potions.LuckPotion or 0) + 1
	elseif key == "LuckyForge" then
		profile.luckyForges += 1
	elseif key == "Power" then
		PlayerData.addPower(player, Balance.rebirthCost(profile.rebirths) * 0.15)
	elseif key == "CoinPotion" then
		profile.potions.CoinPotion = (profile.potions.CoinPotion or 0) + 2
	elseif key == "PowerPotion" then
		profile.potions.PowerPotion = (profile.potions.PowerPotion or 0) + 2
	elseif key == "Eggs" then
		hatch(player, profile, 3)
	elseif key == "Exclusive" then
		grantGun(player, profile, Wheel.EXCLUSIVE_GUN)
	end
end

-- One spin: the daily free spin if it's ready, otherwise a paid spin. The client animates the
-- wheel onto the prize index it's sent back.
local function onSpin(player: Player)
	if not RateLimit.allow(player, "SpinWheel", 0.5, 1) then
		return
	end
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	local now = os.time()
	if Wheel.freeReady(profile.lastWheel, now) then
		profile.lastWheel = now
	elseif profile.wheelSpins > 0 then
		profile.wheelSpins -= 1
	else
		notifyRemote:FireClient(
			player,
			"No spins left! Get more below.",
			Color3.fromRGB(255, 200, 60)
		)
		return
	end
	local index = Wheel.pick(random:NextNumber(), profile.wheelPity)
	local prize = Wheel.PRIZES[index]
	profile.wheelPity = if index == Wheel.EXCLUSIVE then 0 else profile.wheelPity + 1
	grantPrize(player, profile, prize.key)
	PlayerData.markState(player)
	wheelRemote:FireClient(player, index)
end

function Shop:Init()
	notifyRemote = Net.event("Notify")
	hatchedRemote = Net.event("Hatched")
	wheelRemote = Net.event("WheelResult")
end

function Shop:Start()
	-- A lobby baked before the shop and wheel existed gets them now.
	local lobby = workspace:FindFirstChild("Lobby")
	if lobby and not lobby:FindFirstChild("Shop") then
		LobbyBuilder.shopStall(lobby)
	end
	if lobby and not lobby:FindFirstChild("Wheel") then
		LobbyBuilder.wheelStand(lobby)
	end
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, bought)
		local def = Products.byId("pass", passId)
		if not bought or not def then
			return
		end
		setPass(player, def)
		local profile = PlayerData.get(player)
		if profile then
			profile.robuxSpent += def.price
			PlayerData.markState(player)
		end
		notify(player, `{def.name} unlocked! Thank you! 💖`)
	end)
	Net.event("UsePotion").OnServerEvent:Connect(onUsePotion)
	Net.event("SpinWheel").OnServerEvent:Connect(onSpin)
	PlayerData.Loaded:Connect(checkPasses)
	for _, player in PlayerData.players() do
		task.spawn(checkPasses, player)
	end
	-- Auto Rebirth: with the pass and the setting on, rebirths players whenever they can afford it.
	task.spawn(function()
		while true do
			task.wait(3)
			for _, player in PlayerData.players() do
				local profile = PlayerData.get(player)
				if
					profile
					and profile.settings.autoRebirth
					and Boosts.hasPass(player, "AutoRebirth")
				then
					Economy.rebirth(player)
				end
			end
		end
	end)
end

return Shop
