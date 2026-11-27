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
Balance.DAY_SECONDS = 300
Balance.NIGHT_SECONDS = 360
Balance.LUCK_BONUS = { ExtraLuck = 0.25, SuperLuck = 0.6, Potion = 0.3, Server = 0.5, Charge = 1 }

-- The flat damage every shot starts with, so a new player can clear stage 1 before training.
-- Past Eternal each tier hits 3x harder: a real upgrade that still leaves stages to grind.
Balance.GUN_DAMAGE_TIERS = { 1, 2, 3, 10, 25, 100, 500, 2000, 6000, 18000, 54000 }
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
-- Ores are scarce on purpose: a third of what they once were, so ore pets and prestige (which
-- multiply the chance) are what speed forging up.
Balance.ORE_DROP_CHANCE = 0.15
Balance.BOSS_ORE_DROPS = 2
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

-- The material each boss drops: one on the first kill ever, then at GLASSHEART_REPEAT_CHANCE.
Balance.BOSS_MATERIALS = {
	GlassheartWarden = "Glassheart",
	AuroraSentinel = "AuroraShard",
} :: { [string]: string }

-- How each material reads on screen.
Balance.MATERIAL_NAMES = {
	Glassheart = "Glassheart",
	AuroraShard = "Aurora Shard",
} :: { [string]: string }

function Balance.bossMaterialDrop(firstKill: boolean, roll: number): number
	return Balance.glassheartDrop(firstKill, roll)
end

-- Tempering: one Aurora Shard plus coins makes an armor piece block TEMPER_MULTIPLIER times as much, once.
Balance.TEMPER_MULTIPLIER = 1.25
Balance.TEMPER_KILLS = { 2, 4, 8, 15, 30, 60, 120, 240 }

function Balance.temperCost(rarity: number): number
	return Balance.enemyCoins(80)
		* Balance.TEMPER_KILLS[math.clamp(rarity, 1, #Balance.TEMPER_KILLS)]
end

-- Evolving: the coin cost is worth this many stage-70 kills, by rarity, so it keeps pace with the
-- income of players who can reach the catalyst.
Balance.EVOLVE_KILLS = { [5] = 10, [6] = 30, [7] = 100, [8] = 300 }
Balance.EVOLVE_MULTIPLIERS = { power = 3, train = 2, speed = 1.1 }

-- The boss material an evolution takes: Legendary to Godly use the Foundry's Glassheart, and Eternal
-- guns the next region's Aurora Shard.
function Balance.evolveMaterial(rarity: number): string
	return if rarity >= 8 then "AuroraShard" else "Glassheart"
end

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
Balance.STAGE_BREAK_SECONDS = 8

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

-- Prestige: at PRESTIGE_REBIRTHS rebirths a player can wipe their progress (Economy.luau lists what
-- resets) for permanent bonuses that double with each prestige: damage and ore drops x2, x4, x8...,
-- and forge luck +25%, +75%, +175%...
Balance.PRESTIGE_REBIRTHS = 15

function Balance.canPrestige(rebirths: number): boolean
	return rebirths >= Balance.PRESTIGE_REBIRTHS
end

function Balance.prestigeDamage(prestige: number): number
	return 2 ^ prestige
end

-- Forge luck units; the Forge Luck card shows them doubled, so 0.125 reads as +25%.
function Balance.prestigeLuck(prestige: number): number
	return 0.125 * (2 ^ prestige - 1)
end

function Balance.prestigeOres(prestige: number): number
	return 2 ^ prestige
end

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

-- What a gun's focus does to its hits: Damage guns hit 25% harder and Training guns 15% softer.
-- FireRate guns are tuned so their damage per second matches their tier's Damage gun.
Balance.FOCUS_DAMAGE = 1.25
Balance.FOCUS_TRAINING_DAMAGE = 0.85
-- Training guns give this much more Power per shot when training.
Balance.FOCUS_TRAINING = 2.5

local function kindDps(kind: Guns.GunKind): number
	local stats = Guns.kindStats(kind)
	return stats.damageScale * stats.pellets * stats.fireRate
end

function Balance.focusTuning(def: Guns.GunDef): number
	if def.focus == "Damage" then
		return Balance.FOCUS_DAMAGE
	elseif def.focus == "Training" then
		return Balance.FOCUS_TRAINING_DAMAGE
	elseif def.focus == "FireRate" then
		for _, other in Guns.pool(def.rarity) do
			if other.focus == "Damage" then
				return Balance.FOCUS_DAMAGE * kindDps(other.kind) / kindDps(def.kind)
			end
		end
	end
	return 1
end

-- How much a gun's focus multiplies the Training Power it's forged with.
function Balance.focusTraining(gunId: string): number
	local def = Guns.get(gunId)
	return if def and def.focus == "Training" then Balance.FOCUS_TRAINING else 1
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
	local tuning = (if gunId then Balance.GUN_DAMAGE_TUNING[gunId] or 1 else 1)
		* (if def then Balance.focusTuning(def) else 1)
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

function Balance.maxHealth(
	level: number,
	rebirths: number,
	toughnessLevel: number,
	bestStage: number?
): number
	local toughness = Upgrades.value("Toughness", toughnessLevel) - 1
	local stageHealth = Balance.enemyDamage(math.max(bestStage or 1, 1))
		* math.min(toughness * 0.5, 5)
	return math.floor(
		stageHealth
			+ 100
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
-- Past stage 80 there is a new tier only every 50 stages, so gun power climbs about 7x a biome
-- (ores plus the tier bumps) instead of 10x. Health climbs 57x a biome there instead of 150x,
-- keeping the same share for training and rebirths to cover: steady, and a little challenging.
Balance.GROWTH_SHIFT_STAGE = 80

local function shifted(stage: number, before: number, after: number): number
	local shift = Balance.GROWTH_SHIFT_STAGE
	if stage <= shift then
		return before ^ (stage - 1)
	end
	return before ^ (shift - 1) * after ^ (stage - shift)
end

function Balance.enemyHealth(stage: number): number
	return 30 * shifted(stage, 1.65, 1.5)
end

-- Enemy hits grow slower than health so deep stages stay survivable with Toughness and levels.
function Balance.enemyDamage(stage: number): number
	return 8 * shifted(stage, 1.15, 1.11)
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
	return math.floor(4 * shifted(stage, 1.32, 1.28))
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

-- Boss chests: most give coins (CHEST_COIN_KILLS worth of kills); CHEST_PART_CHANCE give an
-- attachment whose rarity is rolled on the reel. Part Luck reshapes the reel, never the chance.
Balance.CHEST_PART_CHANCE = 0.05
Balance.CHEST_COIN_KILLS = 8
Balance.REEL_WEIGHTS = { 50, 25, 15, 5, 3.9, 1, 0.1 }

-- The reel's chance for each rarity at a Part Luck value, summing to 1.
function Balance.reelWeights(luck: number): { number }
	local weights = {}
	local total = 0
	for tier, weight in Balance.REEL_WEIGHTS do
		local boosted = weight * (if tier >= 3 then 1 + luck * (tier - 2) else 1)
		weights[tier] = boosted
		total += boosted
	end
	for tier, weight in weights do
		weights[tier] = weight / total
	end
	return weights
end

-- The rarity the reel lands on for a roll in [0, 1).
function Balance.reelRarity(roll: number, luck: number): number
	local running = 0
	local weights = Balance.reelWeights(luck)
	for tier, weight in weights do
		running += weight
		if roll < running then
			return tier
		end
	end
	return #weights
end

-- The Infinite Tower: unlocks at 1B Power. Floor N plays as stage TOWER_STAGE_OFFSET + N, and every
-- TOWER_CHECKPOINT floors cleared is a checkpoint that adds TOWER_BONUS_STEP to training and coins.
Balance.TOWER_UNLOCK_POWER = 1e9
Balance.TOWER_STAGE_OFFSET = 70
Balance.TOWER_CHECKPOINT = 10
Balance.TOWER_BONUS_STEP = 0.1

function Balance.towerUnlocked(power: number): boolean
	return power >= Balance.TOWER_UNLOCK_POWER
end

function Balance.towerStage(floor: number): number
	return Balance.TOWER_STAGE_OFFSET + floor
end

function Balance.towerFloor(stage: number): number
	return stage - Balance.TOWER_STAGE_OFFSET
end

-- The floor a Tower run starts on: the one after the last checkpoint passed.
function Balance.towerStartFloor(best: number): number
	return math.floor(best / Balance.TOWER_CHECKPOINT) * Balance.TOWER_CHECKPOINT + 1
end

-- The permanent multiplier on training Power and kill coins from Tower checkpoints.
function Balance.towerBonus(best: number): number
	return 1 + Balance.TOWER_BONUS_STEP * math.floor(best / Balance.TOWER_CHECKPOINT)
end

-- Pets: how many can be equipped and owned, and the cap on ore drop chance with pet bonuses.
Balance.PET_SLOTS = 3
Balance.MAX_PETS = 50
Balance.MAX_ORE_DROP_CHANCE = 0.95

-- The chance a regular enemy drops an ore, raised by Ores pets up to the cap.
function Balance.oreDropChance(petMultiplier: number): number
	return math.min(Balance.ORE_DROP_CHANCE * petMultiplier, Balance.MAX_ORE_DROP_CHANCE)
end

-- The forge reaches the Eternal tier only when the mix has one of these ores, so Godly ores alone
-- can't roll it.
Balance.ETERNAL_TIER = 8
Balance.ETERNAL_ORES = { Glasscore = true, Auroracore = true } :: { [string]: boolean }

-- Key ores for each tier from Eternal up: the Cores of the region that tier belongs to.
Balance.TIER_KEYS = {
	[8] = Balance.ETERNAL_ORES,
	[9] = {
		Halocore = true,
		Tempestcore = true,
		Canopycore = true,
		Tidecore = true,
		Sanctumcore = true,
	},
	[10] = {
		Mooncore = true,
		Cometcore = true,
		Nebulacore = true,
		Pulsarcore = true,
		Horizoncore = true,
	},
	[11] = {
		Shattercore = true,
		Chronocore = true,
		Dreamcore = true,
		Bonecore = true,
		Infernocore = true,
		Chaoscore = true,
		Omegacore = true,
	},
} :: { [number]: { [string]: boolean } }

-- True when a mix can reach `tier`: one of its ores is already that rare, or is the tier's key.
function Balance.unlocksTier(ores: { OreDef }, tier: number): boolean
	local keys = Balance.TIER_KEYS[tier]
	for _, ore in ores do
		if ore.rarity >= tier or (keys and keys[ore.id]) then
			return true
		end
	end
	return keys == nil
end

function Balance.forgeOdds(ores: { OreDef }, luck: number): ForgeOdds
	local count = #ores
	local chances = table.create(Rarity.Count, 0)
	if count == 0 then
		chances[1] = 1
		return { chances = chances, basePower = 0, oreCount = 0 }
	end

	local rankSum = 0
	local raritySum = 0
	local best = 1
	local basePower = 0
	for _, ore in ores do
		rankSum += ore.index
		raritySum += ore.rarity
		best = math.max(best, ore.rarity)
		basePower += ore.value
	end
	local center = raritySum / count - 0.4 + 0.12 * (count - 1) + luck
	local ceiling = math.min(best + 1, Rarity.Count)
	-- From Eternal up, each tier needs an ore already at that tier or one of its key ores.
	while ceiling >= Balance.ETERNAL_TIER and not Balance.unlocksTier(ores, ceiling) do
		ceiling -= 1
	end

	-- Reserve a separate Eternal draw. Compare the rest in log space so even extreme luck
	-- values leave a normalized distribution among the eligible tiers.
	local eternal = Balance.ETERNAL_TIER
	local strength = rankSum / (Balance.MAX_FORGE_ORES * #Ores.List)
	local eternalChance = if ceiling >= eternal then 0.05 * math.clamp(strength, 0, 1) ^ 5 else 0
	local peak = math.clamp(math.round(center), 1, ceiling)
	if peak == eternal then
		peak = if ceiling > eternal and center > eternal then eternal + 1 else eternal - 1
	end
	local total = 0
	for tier = 1, ceiling do
		if tier == eternal then
			continue
		end
		local relative = (tier - peak) * (tier + peak - 2 * center)
		local weight = math.exp(-relative / (2 * FORGE_SPREAD * FORGE_SPREAD))
		chances[tier] = weight
		total += weight
	end
	for tier = 1, Rarity.Count do
		chances[tier] = if tier == eternal
			then eternalChance
			else chances[tier] / total * (1 - eternalChance)
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

-- Armor sells for part of what its ores were worth, so forging and selling armor never makes coins
-- the ores alone wouldn't.
function Balance.armorSellPrice(worth: number): number
	return math.max(1, math.floor(worth * 0.6))
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

Balance.TOWER_WAVE_SECONDS = 23
Balance.CRYSTAL_HITS = 40

-- Players without the Auto Perfect pass are shown it after every this many forges.
Balance.FORGES_PER_RECOMMENDATION = 5

function Balance.recommendsAutoPerfect(forges: number, owned: boolean): boolean
	return not owned and forges > 0 and forges % Balance.FORGES_PER_RECOMMENDATION == 0
end

return Balance
