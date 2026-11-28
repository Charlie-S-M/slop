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
	-- Biome 8: Aurora Reach. Auroracore also unlocks the Eternal tier.
	{ "Frostglass", "Frostglass", 7, rgb(200, 230, 255), "Crystal" },
	{ "Rimesteel", "Rimesteel", 7, rgb(150, 170, 200), "Metal" },
	{ "Polarite", "Polarite", 7, rgb(120, 200, 255), "Gem" },
	{ "Borealite", "Borealite", 7, rgb(170, 110, 255), "Gem" },
	{ "Auroracore", "Auroracore", 7, rgb(120, 255, 190), "Core" },
	-- Past stage 80, one region of five biomes per new tier. Each biome's last ore is a Core: the
	-- key that lets the forge reach its region's tier (Balance.TIER_KEYS).
	-- 9 Skyharbor Isles
	{ "Cloudite", "Cloudite", 8, rgb(235, 245, 255), "Rock" },
	{ "Zephyrite", "Zephyrite", 8, rgb(170, 230, 255), "Crystal" },
	{ "Galestone", "Galestone", 8, rgb(140, 200, 230), "Rock" },
	{ "Skysilver", "Skysilver", 8, rgb(210, 225, 245), "Metal" },
	{ "Halocore", "Halocore", 8, rgb(255, 245, 180), "Core" },
	-- 10 Thunderspire
	{ "Stormglass", "Stormglass", 8, rgb(110, 120, 170), "Crystal" },
	{ "Voltite", "Voltite", 8, rgb(255, 240, 80), "Gem" },
	{ "Thunderite", "Thunderite", 8, rgb(150, 160, 255), "Rock" },
	{ "Arcsteel", "Arcsteel", 8, rgb(120, 220, 255), "Metal" },
	{ "Tempestcore", "Tempestcore", 8, rgb(200, 240, 255), "Core" },
	-- 11 Crystal Canopy
	{ "Leafglass", "Leafglass", 8, rgb(120, 230, 140), "Crystal" },
	{ "Bloomite", "Bloomite", 8, rgb(255, 150, 210), "Gem" },
	{ "Barkiron", "Barkiron", 8, rgb(140, 100, 70), "Metal" },
	{ "Verdantine", "Verdantine", 8, rgb(60, 220, 120), "Gem" },
	{ "Canopycore", "Canopycore", 8, rgb(190, 255, 170), "Core" },
	-- 12 Sunken Temple
	{ "Tidepearl", "Tidepearl", 8, rgb(230, 245, 250), "Gem" },
	{ "Coralite", "Coralite", 8, rgb(255, 120, 110), "Rock" },
	{ "Abyssalite", "Abyssalite", 8, rgb(30, 60, 120), "Crystal" },
	{ "Leviathine", "Leviathine", 8, rgb(40, 170, 180), "Metal" },
	{ "Tidecore", "Tidecore", 8, rgb(110, 255, 240), "Core" },
	-- 13 Starlight Sanctum
	{ "Lumenite", "Lumenite", 8, rgb(255, 250, 220), "Crystal" },
	{ "Seraphine", "Seraphine", 8, rgb(255, 220, 150), "Gem" },
	{ "Haloglass", "Haloglass", 8, rgb(240, 250, 255), "Crystal" },
	{ "Divinium", "Divinium", 8, rgb(255, 230, 110), "Metal" },
	{ "Sanctumcore", "Sanctumcore", 8, rgb(255, 255, 255), "Core" },
	-- 14 Moonbase Ruins
	{ "Regolith", "Regolith", 9, rgb(170, 170, 175), "Rock" },
	{ "Lunarite", "Lunarite", 9, rgb(220, 220, 240), "Crystal" },
	{ "Cratersteel", "Cratersteel", 9, rgb(120, 125, 140), "Metal" },
	{ "Selenite", "Selenite", 9, rgb(240, 240, 255), "Gem" },
	{ "Mooncore", "Mooncore", 9, rgb(200, 210, 255), "Core" },
	-- 15 Comet Belt
	{ "Cometice", "Comet Ice", 9, rgb(180, 230, 255), "Crystal" },
	{ "Stardust", "Stardust", 9, rgb(255, 240, 200), "Rock" },
	{ "Meteorite", "Meteorite", 9, rgb(110, 80, 70), "Metal" },
	{ "Orbitium", "Orbitium", 9, rgb(140, 180, 255), "Gem" },
	{ "Cometcore", "Cometcore", 9, rgb(120, 220, 255), "Core" },
	-- 16 Nebula Gardens
	{ "Nebulaglass", "Nebulaglass", 9, rgb(200, 120, 255), "Crystal" },
	{ "Gasglow", "Gasglow", 9, rgb(255, 140, 200), "Gem" },
	{ "Pulsarite", "Pulsarite", 9, rgb(120, 255, 230), "Crystal" },
	{ "Starbloom", "Starbloom", 9, rgb(255, 210, 255), "Gem" },
	{ "Nebulacore", "Nebulacore", 9, rgb(230, 150, 255), "Core" },
	-- 17 Pulsar Forge
	{ "Neutronite", "Neutronite", 9, rgb(200, 200, 230), "Metal" },
	{ "Pulsarsteel", "Pulsarsteel", 9, rgb(90, 130, 255), "Metal" },
	{ "Magnetar", "Magnetar", 9, rgb(255, 90, 160), "Gem" },
	{ "Gammaite", "Gammaite", 9, rgb(140, 255, 120), "Crystal" },
	{ "Pulsarcore", "Pulsarcore", 9, rgb(150, 200, 255), "Core" },
	-- 18 Event Horizon
	{ "Darkmatter", "Dark Matter", 9, rgb(30, 20, 50), "Rock" },
	{ "Gravitite", "Gravitite", 9, rgb(80, 60, 140), "Metal" },
	{ "Horizonite", "Horizonite", 9, rgb(255, 160, 80), "Crystal" },
	{ "Hawkingite", "Hawkingite", 9, rgb(255, 220, 180), "Gem" },
	{ "Horizoncore", "Horizoncore", 9, rgb(255, 255, 255), "Core" },
	-- 19 Shattered Realm
	{ "Shardstone", "Shardstone", 10, rgb(200, 190, 220), "Rock" },
	{ "Fracturite", "Fracturite", 10, rgb(255, 120, 255), "Crystal" },
	{ "Riftsteel", "Riftsteel", 10, rgb(120, 90, 180), "Metal" },
	{ "Paradoxite", "Paradoxite", 10, rgb(120, 255, 220), "Gem" },
	{ "Shattercore", "Shattercore", 10, rgb(255, 200, 255), "Core" },
	-- 20 Clockwork Chasm
	{ "Cogsteel", "Cogsteel", 10, rgb(150, 140, 120), "Metal" },
	{ "Brassite", "Brassite", 10, rgb(220, 170, 70), "Metal" },
	{ "Chronite", "Chronite", 10, rgb(120, 230, 210), "Crystal" },
	{ "Tickglass", "Tickglass", 10, rgb(255, 240, 200), "Crystal" },
	{ "Chronocore", "Chronocore", 10, rgb(255, 220, 120), "Core" },
	-- 21 Dreamscape
	{ "Dreamglass", "Dreamglass", 10, rgb(255, 190, 240), "Crystal" },
	{ "Lucidite", "Lucidite", 10, rgb(190, 160, 255), "Gem" },
	{ "Mirageite", "Mirageite", 10, rgb(255, 230, 170), "Crystal" },
	{ "Somnite", "Somnite", 10, rgb(110, 100, 200), "Rock" },
	{ "Dreamcore", "Dreamcore", 10, rgb(255, 160, 255), "Core" },
	-- 22 Bone Wastes
	{ "Bonechalk", "Bonechalk", 10, rgb(235, 225, 205), "Rock" },
	{ "Marrowite", "Marrowite", 10, rgb(200, 90, 90), "Gem" },
	{ "Gravesteel", "Gravesteel", 10, rgb(90, 95, 100), "Metal" },
	{ "Wraithglass", "Wraithglass", 10, rgb(150, 255, 200), "Crystal" },
	{ "Bonecore", "Bonecore", 10, rgb(255, 250, 230), "Core" },
	-- 23 Inferno Throne
	{ "Hellstone", "Hellstone", 10, rgb(140, 30, 20), "Rock" },
	{ "Brimstone", "Brimstone", 10, rgb(255, 200, 40), "Crystal" },
	{ "Demonite", "Demonite", 10, rgb(200, 20, 50), "Metal" },
	{ "Abyssflame", "Abyssflame", 10, rgb(255, 90, 20), "Gem" },
	{ "Infernocore", "Infernocore", 10, rgb(255, 140, 60), "Core" },
	-- 24 Primordial Chaos
	{ "Chaosite", "Chaosite", 11, rgb(255, 60, 120), "Crystal" },
	{ "Entropite", "Entropite", 11, rgb(60, 40, 60), "Rock" },
	{ "Primalite", "Primalite", 11, rgb(255, 170, 60), "Gem" },
	{ "Genesisite", "Genesisite", 11, rgb(170, 255, 140), "Gem" },
	{ "Chaoscore", "Chaoscore", 11, rgb(255, 100, 200), "Core" },
	-- 25 Omega Gate
	{ "Omegite", "Omegite", 11, rgb(255, 60, 80), "Metal" },
	{ "Alphaite", "Alphaite", 11, rgb(255, 255, 255), "Crystal" },
	{ "Finalium", "Finalium", 11, rgb(40, 20, 30), "Metal" },
	{ "Apexite", "Apexite", 11, rgb(255, 220, 120), "Gem" },
	{ "Omegacore", "Omegacore", 11, rgb(255, 80, 100), "Core" },
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
