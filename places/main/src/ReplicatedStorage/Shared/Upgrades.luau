--!strict

export type UpgradeId =
	"BagSize"
	| "Luck"
	| "Training"
	| "WalkSpeed"
	| "Toughness"
	| "CoinBoost"
	| "Magnet"
	| "PartLuck"

export type UpgradeDef = {
	id: UpgradeId,
	name: string,
	description: string,
	-- Icon key the client maps to an image or emoji badge.
	icon: string,
	color: Color3,
	maxLevel: number,
	-- The old cap. Past it, each level gives `overflow` of a normal level's effect and costs less
	-- extra per level, so the raised caps stay reachable without breaking the game.
	softCap: number,
	overflow: number,
	baseCost: number,
	costGrowth: number,
	-- The upgrade's effect at a level, as the number the game uses.
	effect: (level: number) -> number,
	-- How the effect reads on the card, such as "+12 ores" or "+24%".
	describe: (level: number) -> string,
}

local function percent(value: number): string
	return `+{math.floor(value * 100 + 0.5)}%`
end

const LIST: { UpgradeDef } = {
	{
		id = "BagSize",
		name = "Ore Bag",
		description = "Carry more ores each run",
		icon = "Bag",
		color = Color3.fromRGB(255, 150, 50),
		maxLevel = 160,
		softCap = 40,
		overflow = 0.5,
		baseCost = 40,
		costGrowth = 1.3,
		effect = function(level)
			return 6 + 2 * level
		end,
		describe = function(level)
			return `{6 + 2 * level} ores`
		end,
	},
	{
		id = "Luck",
		name = "Forge Luck",
		description = "Better rarity odds at the forge",
		icon = "Clover",
		color = Color3.fromRGB(80, 220, 110),
		maxLevel = 75,
		softCap = 25,
		overflow = 0.35,
		baseCost = 500,
		costGrowth = 1.50,
		effect = function(level)
			return 0.03 * level
		end,
		describe = function(level)
			return percent(0.06 * level)
		end,
	},
	{
		id = "Training",
		name = "Training Boost",
		description = "More power from training targets",
		icon = "Star",
		color = Color3.fromRGB(70, 160, 255),
		maxLevel = 160,
		softCap = 40,
		overflow = 0.5,
		baseCost = 300,
		costGrowth = 1.43,
		effect = function(level)
			return 1 + 0.15 * level
		end,
		describe = function(level)
			return percent(0.15 * level)
		end,
	},
	{
		id = "WalkSpeed",
		name = "Swift Boots",
		description = "Run faster through stages",
		icon = "Boot",
		color = Color3.fromRGB(80, 230, 230),
		maxLevel = 36,
		softCap = 12,
		overflow = 0.3,
		baseCost = 100,
		costGrowth = 1.6,
		effect = function(level)
			return 22 + 2.5 * level
		end,
		describe = function(level)
			return `{math.floor(22 + 2.5 * level + 0.5)} speed`
		end,
	},
	{
		id = "Toughness",
		name = "Toughness",
		description = "More health for deep stages",
		icon = "Heart",
		color = Color3.fromRGB(255, 70, 90),
		maxLevel = 1000,
		softCap = 40,
		overflow = 0.5,
		baseCost = 120,
		costGrowth = 1.36,
		effect = function(level)
			return 1 + 0.18 * level
		end,
		describe = function(level)
			return percent(0.18 * level)
		end,
	},
	{
		id = "CoinBoost",
		name = "Coin Boost",
		description = "More coins from enemies and sales",
		icon = "Coin",
		color = Color3.fromRGB(255, 210, 50),
		maxLevel = 120,
		softCap = 30,
		overflow = 0.5,
		baseCost = 400,
		costGrowth = 1.45,
		effect = function(level)
			return 1 + 0.12 * level
		end,
		describe = function(level)
			return percent(0.12 * level)
		end,
	},
	{
		id = "Magnet",
		name = "Ore Magnet",
		description = "Pick up ores from farther away",
		icon = "Magnet",
		color = Color3.fromRGB(200, 90, 255),
		maxLevel = 30,
		softCap = 10,
		overflow = 0.4,
		baseCost = 600,
		costGrowth = 1.75,
		effect = function(level)
			return 9 + 4 * level
		end,
		describe = function(level)
			return `{math.floor(9 + 4 * level + 0.5)} studs`
		end,
	},
	{
		id = "PartLuck",
		name = "Part Luck",
		description = "Rarer attachments from boss chests",
		icon = "Gear",
		color = Color3.fromRGB(90, 200, 255),
		maxLevel = 20,
		softCap = 20,
		overflow = 1,
		baseCost = 2000,
		costGrowth = 1.6,
		effect = function(level)
			return 0.1 * level
		end,
		describe = function(level)
			return percent(0.1 * level)
		end,
	},
}

const BY_ID: { [string]: UpgradeDef } = {}
for _, def in LIST do
	BY_ID[def.id] = def
end

local Upgrades = {}

Upgrades.List = LIST

function Upgrades.get(id: string): UpgradeDef?
	return BY_ID[id]
end

-- Past the soft cap the price grows by 40% of the usual step, so the extra levels stay in reach.
function Upgrades.cost(def: UpgradeDef, currentLevel: number): number
	local below = math.min(currentLevel, def.softCap)
	local above = math.max(0, currentLevel - def.softCap)
	local taper = 1 + (def.costGrowth - 1) * 0.4
	return math.floor(def.baseCost * def.costGrowth ^ below * taper ^ above)
end

-- The price of the next `count` levels from `currentLevel`, stopping at the cap, and how many
-- levels that is.
function Upgrades.bulkCost(def: UpgradeDef, currentLevel: number, count: number): (number, number)
	local total = 0
	local levels = 0
	for level = currentLevel, math.min(currentLevel + count, def.maxLevel) - 1 do
		total += Upgrades.cost(def, level)
		levels += 1
	end
	return total, levels
end

-- The level an upgrade's formula sees: full levels up to the soft cap, then `overflow` each.
local function effectiveLevel(def: UpgradeDef, level: number): number
	local clamped = math.clamp(level, 0, def.maxLevel)
	return math.min(clamped, def.softCap) + math.max(0, clamped - def.softCap) * def.overflow
end

-- How an upgrade reads at a level, as the card shows it.
function Upgrades.describe(def: UpgradeDef, level: number): string
	return def.describe(effectiveLevel(def, level))
end

-- The effect of an upgrade at a level, clamped to its range.
function Upgrades.value(id: UpgradeId, level: number): number
	local def = BY_ID[id]
	return def.effect(effectiveLevel(def, level))
end

return Upgrades
