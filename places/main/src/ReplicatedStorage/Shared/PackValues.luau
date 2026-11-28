--!strict

--[[
	How much Power and coins the shop's packs give. A fixed amount is useless late and too much
	early, so each pack is worth a set stretch of the player's own play: Power from training on the
	best pad they've unlocked with the gun they hold, coins from fighting at their best stage. Bigger
	packs are a better deal per Robux, but even the largest is a day's play, never a skip.

	The server grants these amounts and the shop shows them, so both use this one module.
]]

const Balance = require("./Balance")
const GunStats = require("./GunStats")
const Guns = require("./Guns")
const PetStats = require("./PetStats")
const Types = require("./Types")
const Upgrades = require("./Upgrades")

local PackValues = {}

-- Minutes of play each pack is worth.
PackValues.POWER_MINUTES = { Power1 = 10, Power2 = 45, Power3 = 150, Power4 = 480 }
PackValues.COIN_MINUTES = { Coins1 = 10, Coins2 = 45, Coins3 = 150, Coins4 = 480 }
-- About how many monsters a player clears a minute at their best stage.
PackValues.KILLS_PER_MINUTE = 20

local function equippedGun(profile: Types.Profile): Types.GunItem?
	for _, item in profile.guns do
		if item.uid == profile.equipped then
			return GunStats.effective(item)
		end
	end
	return nil
end

-- Power a minute of training gives right now: best unlocked pad, equipped gun, pets, Tower bonus.
function PackValues.powerPerMinute(profile: Types.Profile): number
	local item = equippedGun(profile)
	local def = item and Guns.get(item.id)
	if not item or not def then
		return 0
	end
	local zone = 1
	for _, entry in Balance.TRAINING_ZONES do
		if profile.rebirths >= entry.rebirthsNeeded then
			zone = math.max(zone, entry.multiplier)
		end
	end
	local perShot = Balance.trainingGain(item.train, def.kind, zone, profile.upgrades.Training or 0)
		* PetStats.multiplier(profile.pets, profile.equippedPets, "Training")
		* Balance.towerBonus(profile.towerBest)
	return perShot * GunStats.fireRate(def.kind, item.speed) * 60
end

-- Coins a minute of fighting gives right now, at the best stage reached.
function PackValues.coinsPerMinute(profile: Types.Profile): number
	return Balance.enemyCoins(math.max(profile.bestStage, 1))
		* PackValues.KILLS_PER_MINUTE
		* Upgrades.value("CoinBoost", profile.upgrades.CoinBoost or 0)
		* Balance.towerBonus(profile.towerBest)
end

-- What a Power or coin pack gives this player now, and which of the two it is; nil for others.
function PackValues.amount(profile: Types.Profile, key: string): (number?, "Power" | "Coins" | nil)
	local powerMinutes = PackValues.POWER_MINUTES[key]
	if powerMinutes then
		return math.max(100, math.floor(PackValues.powerPerMinute(profile) * powerMinutes)), "Power"
	end
	local coinMinutes = PackValues.COIN_MINUTES[key]
	if coinMinutes then
		return math.max(100, math.floor(PackValues.coinsPerMinute(profile) * coinMinutes)), "Coins"
	end
	return nil, nil
end

return PackValues
