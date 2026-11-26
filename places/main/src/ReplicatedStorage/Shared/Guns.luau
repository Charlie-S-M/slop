--!strict

export type GunKind =
	"Pistol"
	| "SMG"
	| "Rifle"
	| "Shotgun"
	| "Burst"
	| "Sniper"
	| "Minigun"
	| "Launcher"

export type KindStats = {
	-- Shots per second while the trigger is held.
	fireRate: number,
	-- Damage per pellet, as a share of the player's damage stat.
	damageScale: number,
	pellets: number,
	magazine: number,
	reloadTime: number,
	-- Cone half-angle in degrees.
	spread: number,
	-- Studs; 0 means no splash.
	splashRadius: number,
	-- Rounds per trigger pull; burst guns fire several in a quick row.
	burst: number,
	automatic: boolean,
	-- Camera kick in degrees per shot.
	recoil: number,
}

export type GunDef = {
	id: string,
	name: string,
	rarity: number,
	kind: GunKind,
	body: Color3,
	accent: Color3,
	trim: Color3,
	-- Set on evolved guns: the id of the gun that evolves into this one.
	evolvesFrom: string?,
	-- Legendary and up: what the gun is best at (Damage, Training, or FireRate).
	focus: string?,
}

const KINDS: { [GunKind]: KindStats } = {
	Pistol = {
		fireRate = 4,
		damageScale = 1,
		pellets = 1,
		magazine = 12,
		reloadTime = 1.1,
		spread = 0.6,
		splashRadius = 0,
		burst = 1,
		automatic = true,
		recoil = 1.2,
	},
	SMG = {
		fireRate = 10,
		damageScale = 0.45,
		pellets = 1,
		magazine = 32,
		reloadTime = 1.4,
		spread = 2.4,
		splashRadius = 0,
		burst = 1,
		automatic = true,
		recoil = 0.6,
	},
	Rifle = {
		fireRate = 7,
		damageScale = 0.7,
		pellets = 1,
		magazine = 30,
		reloadTime = 1.5,
		spread = 1.2,
		splashRadius = 0,
		burst = 1,
		automatic = true,
		recoil = 0.8,
	},
	Shotgun = {
		fireRate = 1.3,
		damageScale = 0.55,
		pellets = 7,
		magazine = 6,
		reloadTime = 1.7,
		spread = 6,
		splashRadius = 0,
		burst = 1,
		automatic = true,
		recoil = 4,
	},
	Burst = {
		fireRate = 6.6,
		damageScale = 0.64,
		pellets = 1,
		magazine = 18,
		reloadTime = 1.5,
		spread = 0.4,
		splashRadius = 0,
		burst = 3,
		automatic = true,
		recoil = 1,
	},
	Sniper = {
		fireRate = 0.8,
		damageScale = 6.5,
		pellets = 1,
		magazine = 5,
		reloadTime = 2.2,
		spread = 0,
		splashRadius = 0,
		burst = 1,
		automatic = true,
		recoil = 6,
	},
	Minigun = {
		fireRate = 18,
		damageScale = 0.32,
		pellets = 1,
		magazine = 120,
		reloadTime = 3,
		spread = 3.5,
		splashRadius = 0,
		burst = 1,
		automatic = true,
		recoil = 0.35,
	},
	Launcher = {
		fireRate = 0.75,
		damageScale = 5.5,
		pellets = 1,
		magazine = 4,
		reloadTime = 2.4,
		spread = 0,
		splashRadius = 14,
		burst = 1,
		automatic = true,
		recoil = 5,
	},
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function gun(
	id: string,
	name: string,
	rarity: number,
	kind: GunKind,
	body: Color3,
	accent: Color3,
	trim: Color3
): GunDef
	return {
		id = id,
		name = name,
		rarity = rarity,
		kind = kind,
		body = body,
		accent = accent,
		trim = trim,
	}
end

-- Every gun that can be forged, grouped by rarity. The forge picks evenly among the guns of the
-- rarity it rolls.
const LIST: { GunDef } = {
	-- Common
	gun(
		"PopPistol",
		"Pop Pistol",
		1,
		"Pistol",
		rgb(70, 190, 255),
		rgb(255, 210, 60),
		rgb(60, 70, 90)
	),
	gun(
		"BrickBlaster",
		"Brick Blaster",
		1,
		"Pistol",
		rgb(230, 80, 60),
		rgb(255, 255, 255),
		rgb(70, 70, 80)
	),
	gun(
		"TinSpitter",
		"Tin Spitter",
		1,
		"SMG",
		rgb(170, 175, 185),
		rgb(255, 140, 40),
		rgb(60, 60, 70)
	),
	gun(
		"ScrapScatter",
		"Scrap Scatter",
		1,
		"Shotgun",
		rgb(150, 100, 60),
		rgb(200, 200, 205),
		rgb(70, 50, 40)
	),
	gun(
		"RookieRifle",
		"Rookie Rifle",
		1,
		"Rifle",
		rgb(110, 150, 80),
		rgb(230, 210, 140),
		rgb(60, 60, 50)
	),
	-- Uncommon
	gun("BuzzSMG", "Buzz SMG", 2, "SMG", rgb(255, 200, 30), rgb(40, 40, 45), rgb(90, 90, 100)),
	gun(
		"RangerRifle",
		"Ranger Rifle",
		2,
		"Rifle",
		rgb(60, 120, 70),
		rgb(255, 240, 200),
		rgb(50, 55, 50)
	),
	gun(
		"Boomstick",
		"Boomstick",
		2,
		"Shotgun",
		rgb(180, 60, 50),
		rgb(255, 200, 80),
		rgb(60, 40, 35)
	),
	gun(
		"TwinPea",
		"Twin Peashooter",
		2,
		"Pistol",
		rgb(120, 220, 90),
		rgb(40, 120, 40),
		rgb(50, 70, 50)
	),
	gun(
		"TrackerDMR",
		"Tracker DMR",
		2,
		"Burst",
		rgb(90, 110, 140),
		rgb(120, 255, 160),
		rgb(45, 50, 60)
	),
	gun(
		"SlingCannon",
		"Sling Cannon",
		2,
		"Launcher",
		rgb(130, 90, 60),
		rgb(110, 230, 90),
		rgb(60, 45, 35)
	),
	-- Rare
	gun(
		"CoralCarbine",
		"Coral Carbine",
		3,
		"Rifle",
		rgb(255, 120, 110),
		rgb(90, 230, 255),
		rgb(60, 60, 80)
	),
	gun(
		"FrostRepeater",
		"Frost Repeater",
		3,
		"SMG",
		rgb(200, 240, 255),
		rgb(60, 160, 255),
		rgb(70, 90, 120)
	),
	gun(
		"ThunderPump",
		"Thunder Pump",
		3,
		"Shotgun",
		rgb(60, 70, 120),
		rgb(255, 235, 60),
		rgb(40, 40, 60)
	),
	gun("HawkEye", "Hawk-Eye", 3, "Sniper", rgb(120, 90, 60), rgb(80, 200, 255), rgb(50, 40, 30)),
	gun("Riveter", "Riveter", 3, "Pistol", rgb(255, 150, 40), rgb(60, 60, 70), rgb(120, 120, 130)),
	gun("TriTap", "Tri-Tap", 3, "Burst", rgb(40, 140, 230), rgb(255, 255, 255), rgb(30, 50, 80)),
	-- Epic
	gun(
		"NebulaNeedler",
		"Nebula Needler",
		4,
		"SMG",
		rgb(110, 50, 200),
		rgb(255, 120, 240),
		rgb(40, 25, 70)
	),
	gun(
		"PrismBurst",
		"Prism Burst",
		4,
		"Burst",
		rgb(240, 240, 255),
		rgb(170, 90, 255),
		rgb(90, 80, 140)
	),
	gun(
		"Dragonbreath",
		"Dragonbreath",
		4,
		"Shotgun",
		rgb(170, 30, 40),
		rgb(255, 150, 30),
		rgb(50, 20, 20)
	),
	gun(
		"Stormcaller",
		"Stormcaller",
		4,
		"Rifle",
		rgb(40, 50, 90),
		rgb(120, 220, 255),
		rgb(25, 30, 55)
	),
	gun(
		"VoidLance",
		"Void Lance",
		4,
		"Sniper",
		rgb(30, 20, 50),
		rgb(200, 90, 255),
		rgb(70, 50, 110)
	),
	gun("Cyclone", "Cyclone", 4, "Minigun", rgb(80, 200, 200), rgb(255, 255, 255), rgb(40, 70, 80)),
	-- Legendary
	gun(
		"SolarFlare",
		"Solar Flare",
		5,
		"Rifle",
		rgb(255, 190, 40),
		rgb(255, 90, 30),
		rgb(120, 60, 20)
	),
	gun(
		"TitanHowitzer",
		"Titan Howitzer",
		5,
		"Launcher",
		rgb(70, 75, 85),
		rgb(255, 200, 40),
		rgb(35, 35, 40)
	),
	gun(
		"PhoenixRepeater",
		"Phoenix Repeater",
		5,
		"SMG",
		rgb(255, 110, 40),
		rgb(255, 230, 90),
		rgb(110, 30, 20)
	),
	gun(
		"Leviathan",
		"Leviathan",
		5,
		"Sniper",
		rgb(20, 70, 110),
		rgb(60, 255, 220),
		rgb(15, 35, 55)
	),
	gun(
		"Thunderdome",
		"Thunderdome",
		5,
		"Minigun",
		rgb(250, 220, 80),
		rgb(60, 120, 255),
		rgb(70, 60, 30)
	),
	gun(
		"GildedHandcannon",
		"Gilded Handcannon",
		5,
		"Pistol",
		rgb(255, 210, 80),
		rgb(255, 255, 255),
		rgb(140, 90, 30)
	),
	-- Mythic
	gun(
		"CosmicAnnihilator",
		"Cosmic Annihilator",
		6,
		"Minigun",
		rgb(30, 15, 60),
		rgb(255, 80, 200),
		rgb(90, 60, 200)
	),
	gun(
		"GalaxyBreaker",
		"Galaxy Breaker",
		6,
		"Sniper",
		rgb(20, 20, 40),
		rgb(90, 200, 255),
		rgb(200, 160, 255)
	),
	gun(
		"OmegaPewCannon",
		"Omega Pew Cannon",
		6,
		"Launcher",
		rgb(200, 30, 60),
		rgb(255, 220, 100),
		rgb(60, 10, 25)
	),
	gun(
		"InfernoStorm",
		"Inferno Storm",
		6,
		"Shotgun",
		rgb(60, 20, 10),
		rgb(255, 120, 20),
		rgb(255, 60, 30)
	),
	gun(
		"EclipseRifle",
		"Eclipse Rifle",
		6,
		"Rifle",
		rgb(15, 15, 20),
		rgb(255, 70, 90),
		rgb(255, 200, 120)
	),
	-- Celestial
	gun(
		"Starforge",
		"Starforge",
		7,
		"Minigun",
		rgb(250, 250, 255),
		rgb(80, 240, 230),
		rgb(255, 120, 250)
	),
	gun(
		"AuroraLance",
		"Aurora Lance",
		7,
		"Sniper",
		rgb(30, 40, 80),
		rgb(120, 255, 200),
		rgb(255, 140, 255)
	),
	gun(
		"Infinipew",
		"Infinipew",
		7,
		"Launcher",
		rgb(255, 255, 255),
		rgb(255, 120, 250),
		rgb(80, 240, 230)
	),
	gun(
		"HaloBurst",
		"Halo Burst",
		7,
		"Burst",
		rgb(255, 245, 200),
		rgb(255, 200, 60),
		rgb(120, 200, 255)
	),
	-- Eternal: forged only from a mix with a Glasscore.
	gun(
		"Dawnbringer",
		"Dawnbringer",
		8,
		"Rifle",
		rgb(255, 250, 240),
		rgb(255, 214, 120),
		rgb(170, 210, 255)
	),
	gun(
		"EverlightCannon",
		"Everlight Cannon",
		8,
		"Launcher",
		rgb(245, 240, 255),
		rgb(170, 210, 255),
		rgb(255, 236, 190)
	),
}

table.insert(
	LIST,
	gun(
		"PrismCarbine",
		"Prism Carbine",
		3,
		"Rifle",
		rgb(60, 72, 85),
		rgb(25, 229, 255),
		rgb(234, 221, 192)
	)
)
-- Past Eternal: two guns for each of the Celestial, Cosmic, and Omega tiers.
for _, def in
	{
		gun(
			"HaloRepeater",
			"Halo Repeater",
			9,
			"SMG",
			rgb(235, 245, 255),
			rgb(150, 230, 255),
			rgb(255, 230, 140)
		),
		gun(
			"SeraphLance",
			"Seraph Lance",
			9,
			"Sniper",
			rgb(250, 245, 230),
			rgb(255, 250, 200),
			rgb(120, 200, 255)
		),
		gun(
			"NebulaStorm",
			"Nebula Storm",
			10,
			"Minigun",
			rgb(40, 30, 100),
			rgb(230, 120, 255),
			rgb(90, 110, 255)
		),
		gun(
			"QuasarCannon",
			"Quasar Cannon",
			10,
			"Launcher",
			rgb(20, 20, 60),
			rgb(120, 240, 255),
			rgb(255, 200, 255)
		),
		gun(
			"OmegaRifle",
			"Omega Rifle",
			11,
			"Rifle",
			rgb(25, 15, 20),
			rgb(255, 60, 80),
			rgb(255, 255, 255)
		),
		gun(
			"Worldbreaker",
			"Worldbreaker",
			11,
			"Shotgun",
			rgb(60, 10, 20),
			rgb(255, 120, 60),
			rgb(255, 230, 230)
		),
		-- Filling every tier from Legendary up to three guns, one per focus (FOCUS below).
		gun(
			"BloodmoonCannon",
			"Bloodmoon Cannon",
			6,
			"Launcher",
			rgb(90, 15, 30),
			rgb(255, 70, 90),
			rgb(255, 170, 90)
		),
		gun(
			"Riftcaller",
			"Riftcaller",
			6,
			"Rifle",
			rgb(60, 25, 80),
			rgb(255, 120, 200),
			rgb(255, 180, 90)
		),
		gun(
			"Godsplitter",
			"Godsplitter",
			7,
			"Sniper",
			rgb(30, 40, 60),
			rgb(70, 240, 230),
			rgb(255, 130, 250)
		),
		gun(
			"HalcyonRifle",
			"Halcyon Rifle",
			7,
			"Rifle",
			rgb(225, 245, 250),
			rgb(70, 240, 230),
			rgb(255, 200, 250)
		),
		gun(
			"EternityGatling",
			"Eternity Gatling",
			8,
			"Minigun",
			rgb(250, 240, 220),
			rgb(170, 210, 255),
			rgb(255, 230, 170)
		),
		gun(
			"StarsongRifle",
			"Starsong Rifle",
			9,
			"Rifle",
			rgb(240, 248, 255),
			rgb(150, 230, 255),
			rgb(255, 245, 180)
		),
		gun(
			"OrbitRifle",
			"Orbit Rifle",
			10,
			"Rifle",
			rgb(30, 30, 80),
			rgb(90, 110, 255),
			rgb(230, 120, 255)
		),
		gun(
			"OmegaGatling",
			"Omega Gatling",
			11,
			"Minigun",
			rgb(20, 10, 15),
			rgb(255, 60, 80),
			rgb(255, 255, 255)
		),
	}
do
	table.insert(LIST, def)
end

--[[
	What each Legendary-and-up gun is best at. Damage guns hit hardest; Training guns train much
	faster but hit softer; FireRate guns shoot fast with lighter shots that add up to the same
	damage per second as their tier's Damage gun. Balance.focusTuning and focusTraining apply it.
]]
export type Focus = "Damage" | "Training" | "FireRate"
const FOCUS: { [string]: Focus } = {
	TitanHowitzer = "Damage",
	GildedHandcannon = "Training",
	SolarFlare = "FireRate",
	BloodmoonCannon = "Damage",
	Riftcaller = "Training",
	CosmicAnnihilator = "FireRate",
	Godsplitter = "Damage",
	HalcyonRifle = "Training",
	Starforge = "FireRate",
	EverlightCannon = "Damage",
	Dawnbringer = "Training",
	EternityGatling = "FireRate",
	SeraphLance = "Damage",
	StarsongRifle = "Training",
	HaloRepeater = "FireRate",
	QuasarCannon = "Damage",
	OrbitRifle = "Training",
	NebulaStorm = "FireRate",
	Worldbreaker = "Damage",
	OmegaRifle = "Training",
	OmegaGatling = "FireRate",
}
local collectionIds = {
	"PopPistol",
	"BrickBlaster",
	"TinSpitter",
	"ScrapScatter",
	"RookieRifle",
	"BuzzSMG",
	"RangerRifle",
	"Boomstick",
	"TrackerDMR",
	"PrismCarbine",
	"FrostRepeater",
	"HawkEye",
	"PrismBurst",
	"Dragonbreath",
	"VoidLance",
	"SolarFlare",
	"TitanHowitzer",
	"GildedHandcannon",
	"CosmicAnnihilator",
	"Starforge",
	"Dawnbringer",
	"EverlightCannon",
	"HaloRepeater",
	"SeraphLance",
	"NebulaStorm",
	"QuasarCannon",
	"OmegaRifle",
	"Worldbreaker",
	"BloodmoonCannon",
	"Riftcaller",
	"Godsplitter",
	"HalcyonRifle",
	"EternityGatling",
	"StarsongRifle",
	"OrbitRifle",
	"OmegaGatling",
}
--[[
	Evolved guns: one per Legendary-and-up forge gun. Each keeps its base gun's kind and rarity, is
	never rolled by the forge, and sits right after its base gun in the list the Index shows.
]]
local function evolved(
	base: string,
	id: string,
	name: string,
	body: Color3,
	accent: Color3,
	trim: Color3
): GunDef
	local from = nil
	for _, def in LIST do
		if def.id == base then
			from = def
		end
	end
	assert(from, `evolution base {base} is not in the catalog`)
	local def = gun(id, name, from.rarity, from.kind, body, accent, trim)
	def.evolvesFrom = base
	return def
end

const EVOLUTIONS: { GunDef } = {
	-- The focus guns added to Mythic, Godly, and Eternal.
	evolved(
		"BloodmoonCannon",
		"CrimsonEclipse",
		"Crimson Eclipse",
		rgb(60, 5, 20),
		rgb(255, 40, 70),
		rgb(255, 210, 120)
	),
	evolved(
		"Riftcaller",
		"RiftSovereign",
		"Rift Sovereign",
		rgb(40, 15, 60),
		rgb(255, 90, 220),
		rgb(255, 220, 120)
	),
	evolved(
		"Godsplitter",
		"Heavensplitter",
		"Heavensplitter",
		rgb(15, 25, 45),
		rgb(120, 255, 240),
		rgb(255, 160, 255)
	),
	evolved(
		"HalcyonRifle",
		"HalcyonAscendant",
		"Halcyon Ascendant",
		rgb(240, 255, 255),
		rgb(120, 255, 230),
		rgb(255, 220, 255)
	),
	evolved(
		"EternityGatling",
		"InfinityGatling",
		"Infinity Gatling",
		rgb(255, 250, 235),
		rgb(150, 200, 255),
		rgb(255, 240, 190)
	),
	evolved(
		"Dawnbringer",
		"SolsticeParagon",
		"Solstice Paragon",
		rgb(255, 247, 196),
		rgb(255, 126, 68),
		rgb(117, 229, 255)
	),
	evolved(
		"EverlightCannon",
		"EventideNova",
		"Eventide Nova",
		rgb(74, 58, 124),
		rgb(255, 174, 237),
		rgb(127, 242, 248)
	),
	evolved(
		"SolarFlare",
		"SolarCrown",
		"Solar Crown",
		rgb(255, 215, 90),
		rgb(255, 120, 40),
		rgb(255, 250, 220)
	),
	evolved(
		"TitanHowitzer",
		"TitanColossus",
		"Titan Colossus",
		rgb(60, 66, 80),
		rgb(255, 210, 60),
		rgb(255, 120, 40)
	),
	evolved(
		"GildedHandcannon",
		"GildedSovereign",
		"Gilded Sovereign",
		rgb(255, 225, 120),
		rgb(255, 255, 255),
		rgb(170, 100, 255)
	),
	evolved(
		"CosmicAnnihilator",
		"CosmicOblivion",
		"Cosmic Oblivion",
		rgb(20, 10, 45),
		rgb(255, 90, 220),
		rgb(120, 220, 255)
	),
	evolved(
		"Starforge",
		"StarforgeAscendant",
		"Starforge Ascendant",
		rgb(255, 255, 255),
		rgb(120, 250, 240),
		rgb(255, 200, 80)
	),
}

const BY_ID: { [string]: GunDef } = {}
const BY_RARITY: { [number]: { GunDef } } = {}
const EVOLUTION_OF: { [string]: GunDef } = {}
for _, def in LIST do
	BY_ID[def.id] = def
end
for id, focus in FOCUS do
	local def = BY_ID[id]
	if def then
		def.focus = focus
	end
end
for _, def in EVOLUTIONS do
	BY_ID[def.id] = def
	EVOLUTION_OF[def.evolvesFrom :: string] = def
end
-- An evolved gun keeps its base gun's focus.
for _, def in EVOLUTIONS do
	def.focus = FOCUS[def.evolvesFrom :: string]
end
local collection: { GunDef } = {}
for _, id in collectionIds do
	local def = assert(BY_ID[id], `collection gun {id} is not in the catalog`)
	table.insert(collection, def)
	local pool = BY_RARITY[def.rarity]
	if not pool then
		pool = {}
		BY_RARITY[def.rarity] = pool
	end
	table.insert(pool, def)
	-- The evolution shows next to its base gun but never joins the forge's pools.
	local evolution = EVOLUTION_OF[id]
	if evolution then
		table.insert(collection, evolution)
	end
end

-- Limited guns sold in the shop. They show in the Index but never join the forge's pools.
const LIMITED: { GunDef } = {
	gun(
		"NovaReaper",
		"Nova Reaper",
		8,
		"Rifle",
		rgb(40, 30, 80),
		rgb(150, 110, 255),
		rgb(120, 240, 255)
	),
	gun(
		"DragonheartCannon",
		"Dragonheart Cannon",
		8,
		"Launcher",
		rgb(120, 24, 30),
		rgb(255, 120, 40),
		rgb(255, 210, 90)
	),
	-- The Lucky Wheel's exclusive.
	gun(
		"JackpotBlaster",
		"Jackpot Blaster",
		8,
		"Minigun",
		rgb(250, 200, 40),
		rgb(255, 80, 160),
		rgb(255, 255, 255)
	),
}
for _, def in LIMITED do
	BY_ID[def.id] = def
	table.insert(collection, def)
end

local Guns = {}

Guns.List = collection
Guns.LIMITED = LIMITED
Guns.Kinds = KINDS
Guns.STARTER_ID = "PopPistol"
-- The starter gun gives exactly +1 power per shot, the number the game is named for.
Guns.STARTER_POWER = 1

function Guns.get(id: string): GunDef?
	return BY_ID[id]
end

function Guns.kindStats(kind: GunKind): KindStats
	return KINDS[kind]
end

-- The gun this one evolves into, or nil when it can't evolve (below Legendary, or already evolved).
function Guns.evolutionOf(id: string): GunDef?
	return EVOLUTION_OF[id]
end

function Guns.pool(rarity: number): { GunDef }
	return BY_RARITY[rarity] or {}
end

return Guns
