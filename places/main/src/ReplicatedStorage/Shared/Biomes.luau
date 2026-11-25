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
