--!strict

export type OreStyle = "Rock" | "Metal" | "Crystal" | "Gem" | "Core"

export type OreDef = {
	id: string,
	name: string,
	-- Position in the full list; later ores are worth more.
	index: number,
	rarity: number,
	-- The biome whose enemies drop it.
	biome: number,
	color: Color3,
	style: OreStyle,
	-- Forge strength and the base for its sell price.
	value: number,
}

-- Id, display name, rarity tier, color, and style.
type Entry = { any }

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- Five ores per biome, from most to least common. Rarity climbs a step or two each biome.
const ENTRIES: { Entry } = {
	-- 1 Brickwood Meadow
	{ "Pebble", "Pebble", 1, rgb(150, 150, 155), "Rock" },
	{ "Copper", "Copper", 1, rgb(214, 120, 70), "Metal" },
	{ "Iron", "Iron", 1, rgb(160, 120, 110), "Metal" },
	{ "Bronze", "Bronze", 2, rgb(205, 140, 60), "Metal" },
	{ "Jade", "Jade", 2, rgb(70, 200, 120), "Crystal" },
	-- 2 Gloop Swamp
	{ "Mossite", "Mossite", 2, rgb(110, 160, 60), "Rock" },
	{ "BogIron", "Bog Iron", 2, rgb(90, 110, 80), "Metal" },
	{ "Emerald", "Emerald", 3, rgb(40, 220, 110), "Gem" },
	{ "Toxite", "Toxite", 3, rgb(170, 255, 40), "Crystal" },
	{ "Cobalt", "Cobalt", 3, rgb(40, 90, 230), "Metal" },
	-- 3 Sunscorch Dunes
	{ "Sandglass", "Sandglass", 3, rgb(240, 210, 140), "Crystal" },
	{ "Topaz", "Topaz", 3, rgb(255, 170, 40), "Gem" },
	{ "Amber", "Amber", 4, rgb(255, 130, 20), "Gem" },
	{ "Sapphire", "Sapphire", 4, rgb(40, 110, 255), "Gem" },
	{ "PharaohGold", "Pharaoh Gold", 4, rgb(255, 210, 50), "Metal" },
	-- 4 Frostbite Peaks
	{ "Frostite", "Frostite", 4, rgb(170, 230, 255), "Crystal" },
	{ "Glacium", "Glacium", 4, rgb(110, 200, 255), "Crystal" },
	{ "Aurorite", "Aurorite", 5, rgb(120, 255, 200), "Gem" },
	{ "Moonstone", "Moonstone", 5, rgb(220, 220, 255), "Gem" },
	{ "Starshard", "Starshard", 5, rgb(255, 250, 170), "Core" },
	-- 5 Magma Forgeworks
	{ "Magmite", "Magmite", 5, rgb(255, 90, 30), "Rock" },
	{ "Obsidian", "Obsidian", 5, rgb(50, 30, 70), "Crystal" },
	{ "Infernium", "Infernium", 6, rgb(255, 60, 20), "Core" },
	{ "Dragonheart", "Dragonheart", 6, rgb(220, 20, 60), "Gem" },
	{ "Sunforged", "Sunforged", 6, rgb(255, 200, 60), "Core" },
	-- 6 Void Rift
	{ "Voidglass", "Voidglass", 6, rgb(90, 40, 160), "Crystal" },
	{ "Nebulite", "Nebulite", 6, rgb(200, 80, 255), "Gem" },
	{ "Quasarite", "Quasarite", 7, rgb(80, 240, 230), "Core" },
	{ "EclipseCore", "Eclipse Core", 7, rgb(255, 120, 250), "Core" },
	{ "Singularity", "Singularity", 7, rgb(255, 255, 255), "Core" },
	-- 7 Glassfall Foundry
	{ "Kilnglass", "Kilnglass", 7, rgb(255, 160, 70), "Crystal" },
	{ "Cullet", "Cullet", 7, rgb(140, 230, 240), "Crystal" },
	{ "Prismite", "Prismite", 7, rgb(200, 150, 255), "Gem" },
	{ "AnnealedEmber", "Annealed Ember", 7, rgb(255, 100, 60), "Core" },
	{ "Glasscore", "Glasscore", 7, rgb(220, 250, 255), "Core" },
}

const PER_BIOME = 5

const LIST: { OreDef } = {}
const BY_ID: { [string]: OreDef } = {}
const BY_BIOME: { [number]: { OreDef } } = {}

for index, entry in ENTRIES do
	local biome = math.ceil(index / PER_BIOME)
	local def: OreDef = {
		id = entry[1],
		name = entry[2],
		index = index,
		rarity = entry[3],
		biome = biome,
		color = entry[4],
		style = entry[5],
		-- About 5x per biome, so most of a forged gun's jump comes from rarity, not raw ore value.
		value = math.floor(2 * 1.4 ^ (index - 1) + 0.5),
	}
	table.insert(LIST, def)
	BY_ID[def.id] = def
	local pool = BY_BIOME[biome]
	if not pool then
		pool = {}
		BY_BIOME[biome] = pool
	end
	table.insert(pool, def)
end

local Ores = {}

Ores.List = LIST
Ores.PER_BIOME = PER_BIOME
-- Drop weights for a normal enemy, from the biome's first (commonest) ore to its last.
Ores.NORMAL_WEIGHTS = { 52, 27, 13, 6, 2 }
-- Bosses lean toward the biome's best ores.
Ores.BOSS_WEIGHTS = { 8, 17, 30, 28, 17 }
-- Coins for selling one ore, as a multiple of its value.
Ores.SELL_MULTIPLIER = 2

function Ores.get(id: string): OreDef?
	return BY_ID[id]
end

function Ores.forBiome(biome: number): { OreDef }
	return BY_BIOME[biome] or {}
end

return Ores
