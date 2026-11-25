--!strict

--[[
	Every progression number in one place. The server's results are the ones that count; the
	client runs the same functions only to preview odds, costs, and suggestions in the UI.
]]

const Biomes = require("./Biomes")
const Guns = require("./Guns")
const Ores = require("./Ores")
const Rarity = require("./Rarity")
const Types = require("./Types")
const Upgrades = require("./Upgrades")

type OreDef = Ores.OreDef

export type TrainingZone = {
	multiplier: number,
	rebirthsNeeded: number,
}

export type ForgeOdds = {
	-- Chance of each rarity tier, indexed 1..Rarity.Count; they sum to 1.
	chances: { number },
	-- The sum of the ores' values, before rarity and the random roll.
	basePower: number,
	oreCount: number,
}

local Balance = {}

-- The flat damage every shot starts with, so a new player can clear stage 1 before training.
Balance.GUN_DAMAGE_TIERS = { 1, 2, 3, 10, 25, 100, 500, 2000 }
Balance.GUN_DAMAGE_TUNING = {
	BrickBlaster = 1.08,
	ScrapScatter = 1.04,
	RangerRifle = 1.04,
	Boomstick = 1.08,
	HawkEye = 1.08,
	Dragonbreath = 1.04,
	VoidLance = 1.08,
	TitanHowitzer = 1.04,
	GildedHandcannon = 1.08,
}
-- Evolved guns keep their base gun's tuning.
Balance.GUN_DAMAGE_TUNING.TitanColossus = Balance.GUN_DAMAGE_TUNING.TitanHowitzer
Balance.GUN_DAMAGE_TUNING.GildedSovereign = Balance.GUN_DAMAGE_TUNING.GildedHandcannon
Balance.BASE_DAMAGE = 10
Balance.MAX_FORGE_ORES = 5
Balance.MAX_GUNS = 60
Balance.BOSS_EVERY = 5
Balance.CHECKPOINT_EVERY = 10
Balance.ORE_DROP_CHANCE = 0.45
Balance.BOSS_ORE_DROPS = 4
Balance.FORGE_SECONDS = 2.6

-- The forging timing game. Each strike's ring shrinks over RING_SECONDS; a click's error is how
-- far from the ring's end it lands, as a share of RING_SECONDS.
Balance.STRIKES = 4
Balance.RING_SECONDS = 1.1
Balance.STRIKE_WINDOWS = {
	{ within = 0.08, accuracy = 1, label = "PERFECT" },
	{ within = 0.18, accuracy = 0.75, label = "GREAT" },
	{ within = 0.32, accuracy = 0.45, label = "GOOD" },
}
-- The lowest average accuracy each grade needs, best grade first.
const GRADE_THRESHOLDS: { { grade: Types.Grade, minimum: number } } = {
	{ grade = "S", minimum = 0.9 },
	{ grade = "A", minimum = 0.7 },
	{ grade = "B", minimum = 0.5 },
	{ grade = "C", minimum = 0.3 },
	{ grade = "D", minimum = -math.huge },
}
Balance.GRADE_THRESHOLDS = GRADE_THRESHOLDS
Balance.GRADE_MULTIPLIERS = {
	S = { power = 1.3, speed = 1.15 },
	A = { power = 1.15, speed = 1.07 },
	B = { power = 1, speed = 1 },
	C = { power = 0.85, speed = 0.93 },
	D = { power = 0.7, speed = 0.85 },
}
Balance.SPEED_ROLL_MIN = 0.97
Balance.SPEED_ROLL_MAX = 1.03
-- Training Power climbs this much per rarity tier of the ores used, from 1 for Common ores.
Balance.ORE_TRAINING_GROWTH = 1.25
-- A finish faster than this can't have played the cutscene; one slower than the timeout is filled in.
-- The Glassheart catalyst: the Glassfall Foundry boss's first kill always drops one, later kills
-- sometimes do.
Balance.GLASSHEART_BOSS = "GlassheartWarden"
Balance.GLASSHEART_REPEAT_CHANCE = 0.15

function Balance.glassheartDrop(firstKill: boolean, roll: number): number
	if firstKill or roll < Balance.GLASSHEART_REPEAT_CHANCE then
		return 1
	end
	return 0
end

-- Evolving: the coin cost is worth this many stage-70 kills, by rarity, so it keeps pace with the
-- income of players who can reach the catalyst.
Balance.EVOLVE_KILLS = { [5] = 10, [6] = 30, [7] = 100 }
Balance.EVOLVE_MULTIPLIERS = { power = 3, train = 2, speed = 1.1 }

-- Coins to evolve a gun of this rarity, or nil when the rarity can't evolve.
function Balance.evolveCost(rarity: number): number?
	local kills = Balance.EVOLVE_KILLS[rarity]
	if not kills then
		return nil
	end
	return Balance.enemyCoins(70) * kills
end

Balance.FORGE_MIN_SECONDS = 3
Balance.FORGE_TIMEOUT_SECONDS = 60
Balance.DAILY_COOLDOWN = 20 * 60 * 60
Balance.STAGE_BREAK_SECONDS = 3

Balance.TRAINING_ZONES = {
	{ multiplier = 1, rebirthsNeeded = 0 },
	{ multiplier = 2, rebirthsNeeded = 1 },
	{ multiplier = 4, rebirthsNeeded = 2 },
	{ multiplier = 8, rebirthsNeeded = 3 },
	{ multiplier = 16, rebirthsNeeded = 5 },
	{ multiplier = 32, rebirthsNeeded = 7 },
	{ multiplier = 64, rebirthsNeeded = 10 },
	{ multiplier = 128, rebirthsNeeded = 14 },
} :: { TrainingZone }

------------------------------------------------------------------------------------------------
-- Player stats
------------------------------------------------------------------------------------------------

function Balance.rebirthDamageMultiplier(rebirths: number): number
	return 1 + 0.5 * rebirths
end

function Balance.levelDamageMultiplier(level: number): number
	return 1 + 0.02 * (level - 1)
end

-- Damage of one pellet before the gun kind's share is applied.
function Balance.baseShotDamage(
	power: number,
	gunPower: number,
	rebirths: number,
	level: number
): number
	return (Balance.BASE_DAMAGE + gunPower + power)
		* Balance.rebirthDamageMultiplier(rebirths)
		* Balance.levelDamageMultiplier(level)
end

function Balance.pelletDamage(
	power: number,
	gunPower: number,
	kind: Guns.GunKind,
	rebirths: number,
	level: number,
	gunId: string?
): number
	local def = if gunId then Guns.get(gunId) else nil
	local tierScale = if def then Balance.GUN_DAMAGE_TIERS[def.rarity] else 1
	local tuning = if gunId then Balance.GUN_DAMAGE_TUNING[gunId] or 1 else 1
	return tierScale
		* tuning
		* Balance.baseShotDamage(power, gunPower, rebirths, level)
		* Guns.kindStats(kind).damageScale
end

-- Damage a full trigger pull deals when every pellet lands, the number the HUD shows.
function Balance.shotDamage(
	power: number,
	gunPower: number,
	kind: Guns.GunKind,
	rebirths: number,
	level: number,
	gunId: string?
): number
	local stats = Guns.kindStats(kind)
	return Balance.pelletDamage(power, gunPower, kind, rebirths, level, gunId) * stats.pellets
end

--[[
	Power one training shot adds, from the gun's Training Power. Each kind earns about the same per
	second at equal Training Power; a gun's Speed is what makes it train faster.
]]
function Balance.trainingGain(
	train: number,
	kind: Guns.GunKind,
	zoneMultiplier: number,
	trainingLevel: number
): number
	local stats = Guns.kindStats(kind)
	local perShot = train * stats.damageScale * stats.pellets
	return perShot * zoneMultiplier * Upgrades.value("Training", trainingLevel)
end

function Balance.maxHealth(level: number, rebirths: number, toughnessLevel: number): number
	return math.floor(
		100
			* (1 + 0.06 * (level - 1))
			* (1 + 0.25 * rebirths)
			* Upgrades.value("Toughness", toughnessLevel)
	)
end

function Balance.xpToNext(level: number): number
	return math.floor(12 * 1.11 ^ (level - 1))
end

function Balance.rebirthCost(rebirths: number): number
	return 5000 * 10 ^ rebirths
end

-- The best training zone a player with this many rebirths may use.
function Balance.bestZone(rebirths: number): number
	local best = 1
	for index, zone in Balance.TRAINING_ZONES do
		if rebirths >= zone.rebirthsNeeded then
			best = index
		end
	end
	return best
end

------------------------------------------------------------------------------------------------
-- Stages and enemies
------------------------------------------------------------------------------------------------

function Balance.isBossStage(stage: number): boolean
	return stage % Balance.BOSS_EVERY == 0
end

-- Health climbs about 150x per biome. Gun power climbs about 10x per biome from better ores and
-- rarities, and training zones plus rebirths cover the rest, so every biome asks for a rebirth or
-- two and some time on the pads.
function Balance.enemyHealth(stage: number): number
	return 30 * 1.65 ^ (stage - 1)
end

-- Enemy hits grow slower than health so deep stages stay survivable with Toughness and levels.
function Balance.enemyDamage(stage: number): number
	return 8 * 1.15 ^ (stage - 1)
end

function Balance.bossHealthMultiplier(): number
	return 14
end

-- Enemies grow with every stage. Normal enemies stop at 10x so they still fit the arena; bosses
-- keep growing to 24x.
function Balance.enemyScale(stage: number, isBoss: boolean): number
	local scale = 1 + 0.075 * (stage - 1)
	if isBoss then
		return math.min(scale * 2.3, 24)
	end
	return math.min(scale, 10)
end

function Balance.enemyCount(stage: number): number
	if Balance.isBossStage(stage) then
		return 3
	end
	return math.min(3 + math.floor((stage - 1) / 3), 8)
end

function Balance.enemyCoins(stage: number): number
	return math.floor(4 * 1.32 ^ (stage - 1))
end

function Balance.enemyXp(stage: number): number
	return math.floor(4 * 1.24 ^ (stage - 1))
end

-- The per-shot damage the stage banner recommends: enough to drop a normal enemy in three hits.
function Balance.suggestedDamage(stage: number): number
	return Balance.enemyHealth(stage) / 3
end

------------------------------------------------------------------------------------------------
-- Forge
------------------------------------------------------------------------------------------------

const FORGE_SPREAD = 0.62

--[[
	Rarity chances for forging these ores. The odds center a little below the ores' average rarity,
	and every extra ore and every point of luck pushes the center up, so more ores are always worth
	adding. A forge can rise at most one rarity above its best ore.
]]
-- Armor. A piece blocks slot share x rarity defense x grade multiplier x roll of each hit; the
-- equipped pieces add up, capped so armor never makes a player untouchable.
Balance.ARMOR_SLOT_SHARE = { Helmet = 0.3, Chestplate = 0.5, Boots = 0.2 } :: { [string]: number }
Balance.ARMOR_RARITY_DEFENSE = { 0.08, 0.13, 0.19, 0.26, 0.34, 0.42, 0.5, 0.58 }
Balance.ARMOR_GRADE_MULTIPLIER =
	{ S = 1.15, A = 1.05, B = 1, C = 0.95, D = 0.9 } :: { [string]: number }
Balance.ARMOR_ROLL_MIN = 0.9
Balance.ARMOR_ROLL_MAX = 1.1
Balance.ARMOR_MAX_BLOCK = 0.75
Balance.MAX_ARMOR = 60

-- The forge reaches the Eternal tier only when the mix has one of these ores, so Godly ores alone
-- can't roll it.
Balance.ETERNAL_TIER = 8
Balance.ETERNAL_ORES = { Glasscore = true } :: { [string]: boolean }

function Balance.forgeOdds(ores: { OreDef }, luck: number): ForgeOdds
	local count = #ores
	local chances = table.create(Rarity.Count, 0)
	if count == 0 then
		chances[1] = 1
		return { chances = chances, basePower = 0, oreCount = 0 }
	end

	local raritySum = 0
	local best = 1
	local basePower = 0
	for _, ore in ores do
		raritySum += ore.rarity
		best = math.max(best, ore.rarity)
		basePower += ore.value
	end
	local center = raritySum / count - 0.4 + 0.12 * (count - 1) + luck
	local ceiling = math.min(best + 1, Rarity.Count)
	if ceiling >= Balance.ETERNAL_TIER then
		local hasKey = false
		for _, ore in ores do
			if Balance.ETERNAL_ORES[ore.id] then
				hasKey = true
				break
			end
		end
		if not hasKey then
			ceiling = Balance.ETERNAL_TIER - 1
		end
	end

	local total = 0
	for tier = 1, ceiling do
		local distance = tier - center
		local weight = math.exp(-(distance * distance) / (2 * FORGE_SPREAD * FORGE_SPREAD))
		chances[tier] = weight
		total += weight
	end
	for tier = 1, Rarity.Count do
		chances[tier] = if total > 0 then chances[tier] / total else 0
	end
	return { chances = chances, basePower = basePower, oreCount = count }
end

Balance.FORGE_ROLL_MIN = 0.85
Balance.FORGE_ROLL_MAX = 1.2

function Balance.forgePowerRange(basePower: number, rarity: number): (number, number)
	local multiplier = Rarity.get(rarity).powerMultiplier
	return math.max(1, math.floor(basePower * multiplier * Balance.FORGE_ROLL_MIN)),
		math.max(1, math.floor(basePower * multiplier * Balance.FORGE_ROLL_MAX))
end

-- Picks a rarity from forge odds with a roll in [0, 1).
function Balance.pickRarity(odds: ForgeOdds, roll: number): number
	local running = 0
	for tier, chance in odds.chances do
		running += chance
		if roll < running then
			return tier
		end
	end
	for tier = Rarity.Count, 1, -1 do
		if odds.chances[tier] > 0 then
			return tier
		end
	end
	return 1
end

-- An ore sells for about as much as a kill in the middle of its biome, more for the rarer ones, so
-- selling stays worthwhile however deep the player goes.
function Balance.oreSellPrice(ore: OreDef, coinBoostLevel: number): number
	local positionInBiome = (ore.index - 1) % Ores.PER_BIOME + 1
	local midStage = (ore.biome - 1) * Biomes.STAGES_PER_BIOME + 5
	local base = Balance.enemyCoins(midStage)
		* (0.4 + 0.3 * (positionInBiome - 1))
		* Ores.SELL_MULTIPLIER
	return math.max(1, math.floor(base * Upgrades.value("CoinBoost", coinBoostLevel)))
end

function Balance.gunSellPrice(power: number, rarity: number): number
	return math.floor(math.max(5, power * 0.6 * rarity))
end

-- Stages a player can start a run from: stage 1 and the first stage of every biome they've reached.
function Balance.checkpoints(bestStage: number): { number }
	local list = { 1 }
	local stage = Balance.CHECKPOINT_EVERY + 1
	while stage <= bestStage + 1 do
		table.insert(list, stage)
		stage += Balance.CHECKPOINT_EVERY
	end
	return list
end

-- The biome a stage uses, re-exported so UI code needs one require.
Balance.biomeForStage = Biomes.forStage

return Balance
