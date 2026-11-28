--!strict

export type EnemyShape = "Humanoid" | "Blob" | "Brute" | "Floater" | "Critter"
export type Behavior = "Melee" | "Ranged" | "Fast" | "Tank" | "Splitter"

export type EnemyDef = {
	id: string,
	name: string,
	shape: EnemyShape,
	behavior: Behavior,
	-- Main body color, clothing or shell color, and a highlight color for eyes and trim.
	skin: Color3,
	cloth: Color3,
	accent: Color3,
	hpMultiplier: number,
	-- Studs per second at size 1; larger enemies stride a little faster.
	speed: number,
	-- Optional headwear: "Crown", "Horns", "Helmet", "Wrap", "Cap", or "Spikes".
	hat: string?,
}

export type BiomeDef = {
	index: number,
	name: string,
	floor: Color3,
	floorAccent: Color3,
	wall: Color3,
	wallAccent: Color3,
	trim: Color3,
	-- Color for the stage banner text and the arena's glow strips.
	glow: Color3,
	fogColor: Color3,
	ambient: Color3,
	enemies: { EnemyDef },
	boss: EnemyDef,
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function enemy(
	id: string,
	name: string,
	shape: EnemyShape,
	behavior: Behavior,
	skin: Color3,
	cloth: Color3,
	accent: Color3,
	hpMultiplier: number,
	speed: number,
	hat: string?
): EnemyDef
	return {
		id = id,
		name = name,
		shape = shape,
		behavior = behavior,
		skin = skin,
		cloth = cloth,
		accent = accent,
		hpMultiplier = hpMultiplier,
		speed = speed,
		hat = hat,
	}
end

const LIST: { BiomeDef } = {
	{
		index = 1,
		name = "Brickwood Meadow",
		floor = rgb(110, 200, 90),
		floorAccent = rgb(150, 225, 110),
		wall = rgb(214, 128, 70),
		wallAccent = rgb(70, 130, 230),
		trim = rgb(245, 235, 210),
		glow = rgb(255, 230, 90),
		fogColor = rgb(190, 230, 255),
		ambient = rgb(140, 140, 150),
		enemies = {
			enemy(
				"Shambler",
				"Shambler",
				"Humanoid",
				"Melee",
				rgb(120, 190, 90),
				rgb(90, 70, 160),
				rgb(255, 60, 60),
				1,
				10
			),
			enemy(
				"ChomperSlime",
				"Chomper Slime",
				"Blob",
				"Splitter",
				rgb(90, 220, 90),
				rgb(60, 170, 60),
				rgb(255, 255, 255),
				0.8,
				9
			),
			enemy(
				"PebbleGolem",
				"Pebble Golem",
				"Brute",
				"Tank",
				rgb(150, 150, 160),
				rgb(110, 110, 120),
				rgb(90, 220, 255),
				2.2,
				6
			),
		},
		boss = enemy(
			"SirShambles",
			"Sir Shambles",
			"Humanoid",
			"Melee",
			rgb(110, 180, 80),
			rgb(200, 40, 50),
			rgb(255, 220, 60),
			1,
			8,
			"Crown"
		),
	},
	{
		index = 2,
		name = "Gloop Swamp",
		floor = rgb(80, 120, 60),
		floorAccent = rgb(110, 150, 70),
		wall = rgb(120, 85, 55),
		wallAccent = rgb(70, 160, 110),
		trim = rgb(200, 220, 150),
		glow = rgb(160, 255, 90),
		fogColor = rgb(170, 210, 170),
		ambient = rgb(120, 150, 120),
		enemies = {
			enemy(
				"BogFrog",
				"Bog Frog",
				"Critter",
				"Fast",
				rgb(100, 200, 70),
				rgb(240, 230, 140),
				rgb(255, 255, 255),
				0.6,
				15
			),
			enemy(
				"SwampGhoul",
				"Swamp Ghoul",
				"Humanoid",
				"Ranged",
				rgb(90, 150, 110),
				rgb(60, 80, 50),
				rgb(200, 255, 80),
				0.9,
				8,
				"Cap"
			),
			enemy(
				"MushBrute",
				"Mush Brute",
				"Brute",
				"Tank",
				rgb(240, 220, 190),
				rgb(220, 50, 60),
				rgb(255, 255, 255),
				2.4,
				6,
				"Cap"
			),
		},
		boss = enemy(
			"KingGloopus",
			"King Gloopus",
			"Blob",
			"Splitter",
			rgb(120, 230, 80),
			rgb(60, 170, 40),
			rgb(255, 220, 60),
			1,
			7,
			"Crown"
		),
	},
	{
		index = 3,
		name = "Sunscorch Dunes",
		floor = rgb(240, 210, 140),
		floorAccent = rgb(250, 225, 165),
		wall = rgb(215, 170, 100),
		wallAccent = rgb(60, 150, 200),
		trim = rgb(255, 230, 120),
		glow = rgb(255, 200, 60),
		fogColor = rgb(255, 225, 180),
		ambient = rgb(170, 150, 120),
		enemies = {
			enemy(
				"WrappedOne",
				"Wrapped One",
				"Humanoid",
				"Melee",
				rgb(235, 225, 195),
				rgb(200, 185, 150),
				rgb(60, 220, 255),
				1,
				9,
				"Wrap"
			),
			enemy(
				"ScarabScuttler",
				"Scarab Scuttler",
				"Critter",
				"Fast",
				rgb(40, 110, 140),
				rgb(255, 200, 40),
				rgb(255, 80, 40),
				0.6,
				16
			),
			enemy(
				"SandSentinel",
				"Sand Sentinel",
				"Brute",
				"Tank",
				rgb(210, 165, 95),
				rgb(60, 150, 200),
				rgb(255, 230, 120),
				2.4,
				5.5,
				"Helmet"
			),
		},
		boss = enemy(
			"PharaohRex",
			"Pharaoh Rex",
			"Humanoid",
			"Ranged",
			rgb(240, 230, 200),
			rgb(40, 90, 200),
			rgb(255, 210, 50),
			1,
			7,
			"Crown"
		),
	},
	{
		index = 4,
		name = "Frostbite Peaks",
		floor = rgb(235, 245, 255),
		floorAccent = rgb(200, 230, 255),
		wall = rgb(140, 200, 245),
		wallAccent = rgb(255, 255, 255),
		trim = rgb(90, 140, 220),
		glow = rgb(140, 230, 255),
		fogColor = rgb(215, 235, 255),
		ambient = rgb(150, 170, 200),
		enemies = {
			enemy(
				"SnowScrapper",
				"Snow Scrapper",
				"Humanoid",
				"Melee",
				rgb(250, 250, 255),
				rgb(220, 60, 60),
				rgb(40, 40, 50),
				1,
				9,
				"Cap"
			),
			enemy(
				"PenguinBandit",
				"Penguin Bandit",
				"Critter",
				"Fast",
				rgb(40, 45, 60),
				rgb(255, 255, 255),
				rgb(255, 170, 30),
				0.6,
				17
			),
			enemy(
				"FrostBrute",
				"Frost Brute",
				"Brute",
				"Tank",
				rgb(220, 240, 255),
				rgb(120, 180, 230),
				rgb(40, 120, 255),
				2.5,
				6,
				"Horns"
			),
		},
		boss = enemy(
			"BigBrr",
			"Big Brr the Yeti",
			"Brute",
			"Ranged",
			rgb(245, 250, 255),
			rgb(150, 200, 240),
			rgb(40, 150, 255),
			1,
			6,
			"Horns"
		),
	},
	{
		index = 5,
		name = "Magma Forgeworks",
		floor = rgb(70, 55, 55),
		floorAccent = rgb(255, 110, 30),
		wall = rgb(90, 70, 70),
		wallAccent = rgb(255, 120, 30),
		trim = rgb(255, 190, 60),
		glow = rgb(255, 120, 40),
		fogColor = rgb(255, 170, 120),
		ambient = rgb(160, 110, 90),
		enemies = {
			enemy(
				"EmberImp",
				"Ember Imp",
				"Critter",
				"Fast",
				rgb(255, 100, 40),
				rgb(80, 30, 20),
				rgb(255, 240, 120),
				0.6,
				17,
				"Horns"
			),
			enemy(
				"CinderKnight",
				"Cinder Knight",
				"Humanoid",
				"Ranged",
				rgb(60, 50, 55),
				rgb(255, 110, 30),
				rgb(255, 230, 90),
				1,
				8,
				"Helmet"
			),
			enemy(
				"MagmaGolem",
				"Magma Golem",
				"Brute",
				"Tank",
				rgb(55, 40, 40),
				rgb(255, 90, 20),
				rgb(255, 220, 80),
				2.6,
				5.5,
				"Spikes"
			),
		},
		boss = enemy(
			"OverlordScorch",
			"Overlord Scorch",
			"Humanoid",
			"Ranged",
			rgb(50, 35, 35),
			rgb(255, 80, 20),
			rgb(255, 230, 90),
			1,
			7,
			"Horns"
		),
	},
	{
		index = 6,
		name = "Void Rift",
		floor = rgb(40, 30, 70),
		floorAccent = rgb(160, 80, 255),
		wall = rgb(55, 40, 95),
		wallAccent = rgb(80, 240, 230),
		trim = rgb(255, 120, 250),
		glow = rgb(200, 120, 255),
		fogColor = rgb(150, 110, 220),
		ambient = rgb(120, 100, 170),
		enemies = {
			enemy(
				"RiftWisp",
				"Rift Wisp",
				"Floater",
				"Ranged",
				rgb(180, 120, 255),
				rgb(80, 240, 230),
				rgb(255, 255, 255),
				0.8,
				9
			),
			enemy(
				"NullKnight",
				"Null Knight",
				"Humanoid",
				"Melee",
				rgb(30, 25, 45),
				rgb(150, 70, 255),
				rgb(80, 240, 230),
				1.1,
				10,
				"Helmet"
			),
			enemy(
				"GloomTitan",
				"Gloom Titan",
				"Brute",
				"Tank",
				rgb(40, 30, 70),
				rgb(255, 120, 250),
				rgb(80, 240, 230),
				2.6,
				5.5,
				"Spikes"
			),
		},
		boss = enemy(
			"TheUnmaker",
			"The Unmaker",
			"Floater",
			"Ranged",
			rgb(20, 15, 35),
			rgb(255, 120, 250),
			rgb(80, 240, 230),
			1,
			6,
			"Crown"
		),
	},
	{
		-- A glassworks of glowing kilns and crystal cullet, past the Void Rift.
		index = 7,
		name = "Glassfall Foundry",
		floor = rgb(48, 64, 74),
		floorAccent = rgb(120, 220, 230),
		wall = rgb(70, 150, 165),
		wallAccent = rgb(255, 170, 70),
		trim = rgb(210, 245, 250),
		glow = rgb(255, 175, 80),
		fogColor = rgb(150, 205, 215),
		ambient = rgb(120, 150, 160),
		enemies = {
			enemy(
				"KilnHound",
				"Kiln Hound",
				"Critter",
				"Fast",
				rgb(255, 140, 60),
				rgb(70, 60, 60),
				rgb(255, 230, 140),
				0.6,
				17,
				"Spikes"
			),
			enemy(
				"PaneKnight",
				"Pane Knight",
				"Humanoid",
				"Melee",
				rgb(150, 220, 230),
				rgb(60, 110, 130),
				rgb(255, 180, 80),
				1.1,
				10,
				"Helmet"
			),
			enemy(
				"CulletGolem",
				"Cullet Golem",
				"Brute",
				"Tank",
				rgb(120, 200, 215),
				rgb(255, 150, 60),
				rgb(255, 240, 180),
				2.6,
				5.5,
				"Spikes"
			),
		},
		boss = enemy(
			"GlassheartWarden",
			"Glassheart Warden",
			"Brute",
			"Ranged",
			rgb(170, 235, 245),
			rgb(255, 140, 50),
			rgb(255, 90, 140),
			1,
			6,
			"Crown"
		),
	},
	{
		-- A frozen ridge under the northern lights, past the Glassfall Foundry.
		index = 8,
		name = "Aurora Reach",
		floor = rgb(225, 238, 250),
		floorAccent = rgb(150, 255, 200),
		wall = rgb(120, 170, 220),
		wallAccent = rgb(170, 110, 255),
		trim = rgb(245, 250, 255),
		glow = rgb(120, 255, 190),
		fogColor = rgb(180, 210, 255),
		ambient = rgb(140, 150, 185),
		enemies = {
			enemy(
				"FrostLynx",
				"Frost Lynx",
				"Critter",
				"Fast",
				rgb(230, 240, 255),
				rgb(120, 160, 220),
				rgb(120, 255, 200),
				0.65,
				18,
				"Spikes"
			),
			enemy(
				"RimeArcher",
				"Rime Archer",
				"Humanoid",
				"Ranged",
				rgb(190, 220, 255),
				rgb(80, 90, 160),
				rgb(170, 110, 255),
				1.1,
				10,
				"Helmet"
			),
			enemy(
				"GlacierOx",
				"Glacier Ox",
				"Brute",
				"Tank",
				rgb(170, 205, 235),
				rgb(70, 90, 130),
				rgb(150, 255, 210),
				2.8,
				5.5,
				"Spikes"
			),
		},
		boss = enemy(
			"AuroraSentinel",
			"Aurora Sentinel",
			"Humanoid",
			"Ranged",
			rgb(220, 240, 255),
			rgb(120, 90, 220),
			rgb(120, 255, 190),
			1,
			8,
			"Crown"
		),
	},
}

-- Health and speed by behavior, for the biomes past stage 80, which only list their enemies.
const BEHAVIOR_STATS: { [Behavior]: { hp: number, speed: number } } = {
	Melee = { hp = 1, speed = 10 },
	Fast = { hp = 0.65, speed = 18 },
	Ranged = { hp = 1.1, speed = 10 },
	Tank = { hp = 2.8, speed = 5.5 },
	Splitter = { hp = 1.2, speed = 9 },
}

type Roster = { id: string, name: string, shape: EnemyShape, behavior: Behavior, hat: string? }

local function r(
	id: string,
	name: string,
	shape: EnemyShape,
	behavior: Behavior,
	hat: string?
): Roster
	return { id = id, name = name, shape = shape, behavior = behavior, hat = hat }
end

--[[
	A biome past stage 80 from three colors: `base` for the floor and walls, `accent` for trim and
	the enemies' cloth, and `glow` for banners, glow strips, and eyes. Enemies take their health and
	speed from their behavior; the boss is a crowned Humanoid.
]]
local function generated(
	index: number,
	name: string,
	base: Color3,
	accent: Color3,
	glow: Color3,
	roster: { Roster },
	bossId: string,
	bossName: string
): BiomeDef
	local enemies = {}
	for order, entry in roster do
		local stats = BEHAVIOR_STATS[entry.behavior]
		table.insert(
			enemies,
			enemy(
				entry.id,
				entry.name,
				entry.shape,
				entry.behavior,
				base:Lerp(Color3.new(1, 1, 1), 0.25 + 0.15 * order),
				accent,
				glow,
				stats.hp,
				stats.speed,
				entry.hat
			)
		)
	end
	return {
		index = index,
		name = name,
		floor = base:Lerp(Color3.new(1, 1, 1), 0.55),
		floorAccent = glow:Lerp(Color3.new(1, 1, 1), 0.3),
		wall = base,
		wallAccent = accent,
		trim = base:Lerp(Color3.new(1, 1, 1), 0.8),
		glow = glow,
		fogColor = base:Lerp(Color3.new(1, 1, 1), 0.4),
		ambient = base:Lerp(Color3.new(0.5, 0.5, 0.5), 0.6),
		enemies = enemies,
		boss = enemy(
			bossId,
			bossName,
			"Humanoid",
			"Ranged",
			base:Lerp(glow, 0.5),
			accent,
			glow,
			1,
			8,
			"Crown"
		),
	}
end

-- Stages 81 to 250: the Celestial region (biomes 9 to 13), the Cosmic region (14 to 18), the
-- Omega region (19 to 23), and the finale (24 and 25).
for _, biome in
	{
		generated(
			9,
			"Skyharbor Isles",
			rgb(120, 180, 230),
			rgb(255, 255, 255),
			rgb(255, 240, 170),
			{
				r("GustSprite", "Gust Sprite", "Floater", "Fast"),
				r("CloudKnight", "Cloud Knight", "Humanoid", "Melee", "Helmet"),
				r("SkyRam", "Sky Ram", "Brute", "Tank", "Horns"),
			},
			"TempestRoc",
			"Tempest Roc"
		),
		generated(10, "Thunderspire", rgb(70, 75, 120), rgb(255, 230, 60), rgb(150, 220, 255), {
			r("SparkImp", "Spark Imp", "Critter", "Fast", "Spikes"),
			r("StormCaller", "Storm Caller", "Humanoid", "Ranged", "Wrap"),
			r("VoltGolem", "Volt Golem", "Brute", "Tank"),
		}, "ThunderKing", "Thunder King"),
		generated(11, "Crystal Canopy", rgb(60, 150, 90), rgb(255, 150, 210), rgb(190, 255, 170), {
			r("ThornSprout", "Thorn Sprout", "Blob", "Splitter"),
			r("LeafRanger", "Leaf Ranger", "Humanoid", "Ranged", "Cap"),
			r("BarkBeast", "Bark Beast", "Brute", "Tank", "Horns"),
		}, "CanopyWarden", "Canopy Warden"),
		generated(12, "Sunken Temple", rgb(40, 110, 140), rgb(255, 120, 110), rgb(110, 255, 240), {
			r("ReefCrab", "Reef Crab", "Critter", "Fast", "Spikes"),
			r("TideMage", "Tide Mage", "Humanoid", "Ranged", "Wrap"),
			r("DeepGuardian", "Deep Guardian", "Brute", "Tank", "Helmet"),
		}, "Leviathan", "Leviathan"),
		generated(
			13,
			"Starlight Sanctum",
			rgb(200, 190, 240),
			rgb(255, 220, 120),
			rgb(255, 255, 255),
			{
				r("Wisp", "Wisp", "Floater", "Fast"),
				r("Seraph", "Seraph", "Humanoid", "Ranged", "Crown"),
				r("HaloGolem", "Halo Golem", "Brute", "Tank"),
			},
			"ArchSeraph",
			"Arch Seraph"
		),
		generated(
			14,
			"Moonbase Ruins",
			rgb(120, 125, 140),
			rgb(200, 210, 255),
			rgb(150, 255, 230),
			{
				r("RoverBot", "Rover Bot", "Critter", "Fast", "Cap"),
				r("LunarTrooper", "Lunar Trooper", "Humanoid", "Ranged", "Helmet"),
				r("CraterHulk", "Crater Hulk", "Brute", "Tank"),
			},
			"MoonTyrant",
			"Moon Tyrant"
		),
		generated(15, "Comet Belt", rgb(40, 60, 110), rgb(255, 240, 200), rgb(120, 220, 255), {
			r("Stardrop", "Stardrop", "Blob", "Splitter"),
			r("CometRider", "Comet Rider", "Humanoid", "Melee", "Helmet"),
			r("RockShell", "Rock Shell", "Brute", "Tank", "Spikes"),
		}, "CometWyrm", "Comet Wyrm"),
		generated(
			16,
			"Nebula Gardens",
			rgb(110, 60, 160),
			rgb(255, 140, 200),
			rgb(230, 150, 255),
			{
				r("GasJelly", "Gas Jelly", "Floater", "Ranged"),
				r("StarGardener", "Star Gardener", "Humanoid", "Melee", "Cap"),
				r("BloomBrute", "Bloom Brute", "Brute", "Tank", "Horns"),
			},
			"NebulaQueen",
			"Nebula Queen"
		),
		generated(17, "Pulsar Forge", rgb(50, 60, 110), rgb(90, 130, 255), rgb(140, 255, 120), {
			r("PulseDrone", "Pulse Drone", "Floater", "Fast"),
			r("Forgeborn", "Forgeborn", "Humanoid", "Melee", "Helmet"),
			r("NeutronOgre", "Neutron Ogre", "Brute", "Tank", "Horns"),
		}, "PulsarSmith", "Pulsar Smith"),
		generated(18, "Event Horizon", rgb(25, 20, 45), rgb(255, 160, 80), rgb(255, 255, 255), {
			r("VoidMite", "Void Mite", "Critter", "Fast", "Spikes"),
			r("GravityMonk", "Gravity Monk", "Humanoid", "Ranged", "Wrap"),
			r("SingularityBeast", "Singularity Beast", "Blob", "Splitter"),
		}, "HorizonEater", "Horizon Eater"),
		generated(
			19,
			"Shattered Realm",
			rgb(120, 90, 160),
			rgb(120, 255, 220),
			rgb(255, 200, 255),
			{
				r("ShardImp", "Shard Imp", "Critter", "Fast", "Spikes"),
				r("RiftBlade", "Rift Blade", "Humanoid", "Melee", "Helmet"),
				r("FractureGolem", "Fracture Golem", "Brute", "Tank"),
			},
			"ParadoxLord",
			"Paradox Lord"
		),
		generated(
			20,
			"Clockwork Chasm",
			rgb(130, 100, 60),
			rgb(220, 170, 70),
			rgb(120, 230, 210),
			{
				r("CogBug", "Cog Bug", "Critter", "Fast", "Cap"),
				r("Gearwright", "Gearwright", "Humanoid", "Ranged", "Helmet"),
				r("BrassColossus", "Brass Colossus", "Brute", "Tank", "Horns"),
			},
			"Chronarch",
			"Chronarch"
		),
		generated(21, "Dreamscape", rgb(200, 150, 230), rgb(110, 100, 200), rgb(255, 230, 170), {
			r("Daydream", "Daydream", "Floater", "Fast"),
			r("Sleepwalker", "Sleepwalker", "Humanoid", "Melee", "Wrap"),
			r("NightmareBlob", "Nightmare Blob", "Blob", "Splitter"),
		}, "DreamWeaver", "Dream Weaver"),
		generated(22, "Bone Wastes", rgb(180, 170, 150), rgb(200, 90, 90), rgb(150, 255, 200), {
			r("BoneRat", "Bone Rat", "Critter", "Fast", "Spikes"),
			r("Gravecaller", "Gravecaller", "Humanoid", "Ranged", "Horns"),
			r("MarrowTitan", "Marrow Titan", "Brute", "Tank", "Helmet"),
		}, "BoneEmperor", "Bone Emperor"),
		generated(23, "Inferno Throne", rgb(120, 25, 20), rgb(255, 200, 40), rgb(255, 120, 40), {
			r("Hellhound", "Hellhound", "Critter", "Fast", "Horns"),
			r("Pyromancer", "Pyromancer", "Humanoid", "Ranged", "Wrap"),
			r("DemonBrute", "Demon Brute", "Brute", "Tank", "Horns"),
		}, "InfernoTyrant", "Inferno Tyrant"),
		generated(24, "Primordial Chaos", rgb(90, 30, 70), rgb(255, 170, 60), rgb(255, 100, 200), {
			r("ChaosSpawn", "Chaos Spawn", "Blob", "Splitter"),
			r("EntropyKnight", "Entropy Knight", "Humanoid", "Melee", "Helmet"),
			r("PrimalBehemoth", "Primal Behemoth", "Brute", "Tank", "Horns"),
		}, "ChaosPrime", "Chaos Prime"),
		generated(25, "Omega Gate", rgb(30, 15, 25), rgb(255, 60, 80), rgb(255, 255, 255), {
			r("OmegaWisp", "Omega Wisp", "Floater", "Fast"),
			r("GateWarden", "Gate Warden", "Humanoid", "Ranged", "Crown"),
			r("Finalborn", "Finalborn", "Brute", "Tank", "Spikes"),
		}, "TheOmega", "The Omega"),
	}
do
	table.insert(LIST, biome)
end

local Biomes = {}

Biomes.List = LIST
Biomes.Count = #LIST
Biomes.STAGES_PER_BIOME = 10

-- The biome a stage belongs to. Past the last biome the cycle restarts as an Ascension.
function Biomes.forStage(stage: number): BiomeDef
	local index = math.floor((stage - 1) / Biomes.STAGES_PER_BIOME) % #LIST + 1
	return LIST[index]
end

-- How many times the player has looped all biomes by this stage (0 on the first pass).
function Biomes.ascension(stage: number): number
	return math.floor((stage - 1) / (Biomes.STAGES_PER_BIOME * #LIST))
end

-- The furthest biome a player with this best stage has reached. Ascensions stay on the last one.
function Biomes.bestReached(bestStage: number): number
	return math.clamp(math.floor(bestStage / Biomes.STAGES_PER_BIOME) + 1, 1, #LIST)
end

return Biomes
