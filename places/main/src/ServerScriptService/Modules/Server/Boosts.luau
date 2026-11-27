--!strict

--[[
	What purchases change in play: game passes (recorded as "Pass_<key>" player attributes by
	Shop.luau), potions running (profile.boosts, by the os.time they end), and Server Luck (the
	"ServerLuckUntil" attribute on ReplicatedStorage, so every client can show it). Gameplay code
	asks here instead of reading passes itself.
]]

const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Balance = require("@game/ReplicatedStorage/Shared/Balance")
const PrestigeShop = require("@game/ReplicatedStorage/Shared/PrestigeShop")
const Types = require("@game/ReplicatedStorage/Shared/Types")
const Upgrades = require("@game/ReplicatedStorage/Shared/Upgrades")

local Boosts = {}

function Boosts.hasPass(player: Player, key: string): boolean
	return player:GetAttribute(`Pass_{key}`) == true
end

function Boosts.potionActive(profile: Types.Profile, boost: string): boolean
	return (profile.boosts[boost] or 0) > os.time()
end

function Boosts.serverLuckActive(): boolean
	local untilTime = ReplicatedStorage:GetAttribute("ServerLuckUntil")
	return typeof(untilTime) == "number" and untilTime > os.time()
end

-- Multiplies coins from monsters, chests, ore sales, and animals.
function Boosts.coins(player: Player, profile: Types.Profile): number
	local multiplier = PrestigeShop.multiplier(profile.prestigeShop, "Coins")
	if Boosts.hasPass(player, "VIP") then
		multiplier *= 1.25
	end
	if Boosts.hasPass(player, "DoubleCoins") then
		multiplier *= 2
	end
	if Boosts.potionActive(profile, "Coins") then
		multiplier *= 2
	end
	return multiplier
end

-- Multiplies Power from training.
function Boosts.power(player: Player, profile: Types.Profile): number
	local multiplier = 1
	if Boosts.hasPass(player, "VIP") then
		multiplier *= 1.25
	end
	if Boosts.potionActive(profile, "Power") then
		multiplier *= 2
	end
	return multiplier
end

-- Everything that feeds a forge roll's luck (Balance.forgeLuck). `charge` says whether a Lucky
-- Forge charge is being spent on this roll.
function Boosts.luckSources(
	player: Player,
	profile: Types.Profile,
	charge: boolean
): Balance.LuckSources
	return {
		upgrade = Upgrades.value("Luck", profile.upgrades.Luck or 0),
		prestige = Balance.prestigeLuck(profile.prestige),
		extraLuck = Boosts.hasPass(player, "ExtraLuck"),
		superLuck = Boosts.hasPass(player, "SuperLuck"),
		potion = Boosts.potionActive(profile, "Luck"),
		server = Boosts.serverLuckActive(),
		charge = charge,
		forgeLuckLevel = PrestigeShop.level(profile.prestigeShop, "ForgeLuck"),
	}
end

function Boosts.walkSpeed(player: Player): number
	return if Boosts.hasPass(player, "SpeedBoost") then 1.5 else 1
end

-- The ore magnet's radius with Auto Collect, or nil without it.
function Boosts.collectRadius(player: Player): number?
	return if Boosts.hasPass(player, "AutoCollect") then 1000 else nil
end

function Boosts.petStorage(player: Player): number
	local storage = Balance.MAX_PETS
	if Boosts.hasPass(player, "PetStorage30") then
		storage += 30
	end
	if Boosts.hasPass(player, "PetStorage60") then
		storage += 60
	end
	return storage
end

function Boosts.bossLoot(player: Player): number
	return if Boosts.hasPass(player, "DoubleBossLoot") then 2 else 1
end

function Boosts.keepsOres(player: Player): boolean
	return Boosts.hasPass(player, "KeepOres")
end

return Boosts
