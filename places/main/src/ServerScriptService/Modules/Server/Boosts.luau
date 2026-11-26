--!strict

--[[
	What purchases change in play: game passes (recorded as "Pass_<key>" player attributes by
	Shop.luau), potions running (profile.boosts, by the os.time they end), and Server Luck (the
	"ServerLuckUntil" attribute on ReplicatedStorage, so every client can show it). Gameplay code
	asks here instead of reading passes itself.
]]

const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Balance = require("@game/ReplicatedStorage/Shared/Balance")
const Types = require("@game/ReplicatedStorage/Shared/Types")

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

-- Multiplies coins from monsters and chests.
function Boosts.coins(player: Player, profile: Types.Profile): number
	local multiplier = 1
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

-- Forge luck added on top of the Forge Luck upgrade.
function Boosts.luck(player: Player, profile: Types.Profile): number
	local bonus = 0
	if Boosts.hasPass(player, "ExtraLuck") then
		bonus += 0.25
	end
	if Boosts.hasPass(player, "SuperLuck") then
		bonus += 0.6
	end
	if Boosts.potionActive(profile, "Luck") then
		bonus += 0.3
	end
	if Boosts.serverLuckActive() then
		bonus += 0.5
	end
	return bonus
end

-- Extra luck for a Lucky Forge, used up one forge at a time.
Boosts.LUCKY_FORGE_LUCK = 1

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
