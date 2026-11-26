--!strict

-- The grade the forge's timing game gave a gun, best first.
export type Grade = "S" | "A" | "B" | "C" | "D"

--[[
	One forged gun the player owns. The id names its catalog entry. Power is damage, speed
	multiplies the gun kind's fire rate, and train is the power each training shot adds.
]]
export type GunItem = {
	uid: string,
	id: string,
	power: number,
	speed: number,
	train: number,
	grade: Grade,
	locked: boolean?,
	-- Attachment ids on this gun, by slot.
	parts: { [string]: string }?,
}

export type PetItem = { uid: string, id: string, locked: boolean? }

export type ArmorSlot = "Helmet" | "Chestplate" | "Boots"

-- One forged armor piece the player owns. `defense` is the share of each hit it blocks.
export type ArmorItem = {
	uid: string,
	id: string,
	defense: number,
	grade: Grade,
	locked: boolean?,
	-- What the ores it was forged from would have sold for; its own sell price comes from this.
	worth: number?,
	-- Set once an Aurora Shard has tempered the piece; it can't be tempered again.
	tempered: boolean?,
}

-- A forge the server has rolled but the player hasn't finished hammering yet.
export type PendingForge = {
	token: string,
	-- The catalog id being forged: a gun, or an armor piece when `slot` is set.
	gunId: string,
	slot: ArmorSlot?,
	rarity: number,
	basePower: number,
	train: number,
	oreIds: { string },
	startedAt: number,
}

-- The saved player profile. Every field is plain JSON so the DataStore can hold it.
-- One quest: what to do, how far along it is, and its reward in stars.
export type Quest = {
	kind: string,
	target: number,
	progress: number,
	stars: number,
	hard: boolean,
	claimed: boolean,
	-- Each daily quest can be swapped for another once.
	swapped: boolean,
}

-- The Quests menu's state: today's dailies, the longer challenges, stars toward the next rank,
-- and the daily chest, which opens after three dailies are claimed.
export type QuestBook = {
	-- The UTC day the dailies were dealt for.
	day: number,
	daily: { Quest },
	challenge: { Quest },
	stars: number,
	chestPips: number,
	chestOpened: boolean,
}

-- What the Settings menu saves. Volumes run from 0 to 1.
export type Settings = {
	-- Turn auto mode on when a stage starts, and off on the way back to the lobby.
	autoMode: boolean,
	-- Skip the wait between stages and waves as soon as it starts.
	autoSkip: boolean,
	sfx: number,
	music: number,
}

export type Profile = {
	version: number,
	power: number,
	coins: number,
	rebirths: number,
	level: number,
	xp: number,
	guns: { GunItem },
	equipped: string,
	nextUid: number,
	-- Ores carried, by ore id. Dying in a stage empties it.
	bag: { [string]: number },
	oreIndex: { [string]: boolean },
	gunIndex: { [string]: boolean },
	upgrades: { [string]: number },
	-- The deepest stage the player has cleared.
	bestStage: number,
	lastDaily: number,
	dailyStreak: number,
	kills: number,
	forges: number,
	playSeconds: number,
	-- Saved so a crash between starting and finishing a forge can't lose the ores.
	pendingForge: PendingForge?,
	-- Catalysts and other non-ore materials by id. Unlike the bag, these survive dying.
	materials: { [string]: number },
	-- Bosses this player has ever defeated, by enemy id, for first-kill rewards.
	bossesDefeated: { [string]: boolean },
	-- Forged armor pieces, and the uid worn in each slot.
	armor: { ArmorItem },
	equippedArmor: { [string]: string },
	-- Hatched pets, and the uids following the player (at most Balance.PET_SLOTS).
	pets: { PetItem },
	equippedPets: { string },
	-- The highest Infinite Tower floor cleared.
	towerBest: number,
	-- How many times the player has prestiged.
	prestige: number,
	-- Attachments not on a gun, by part id.
	attachments: { [string]: number },
	-- Robux the player has spent in this game, for the leaderboard.
	robuxSpent: number,
	-- The Settings menu's choices, and the codes this player has redeemed.
	settings: Settings,
	redeemedCodes: { [string]: boolean },
	quests: QuestBook,
	-- Potions waiting to be used, by product key, and the boosts running, by boost name -> the
	-- os.time they end.
	potions: { [string]: number },
	boosts: { [string]: number },
	-- Forges left that roll with Lucky Forge luck.
	luckyForges: number,
	starterPackBought: boolean,
	-- The last purchase receipts granted, newest last, so a retried receipt never grants twice.
	receipts: { string },
}

-- The stats that change many times a second, sent on their own so the full state stays quiet.
export type Stats = {
	power: number,
	coins: number,
	level: number,
	xp: number,
	rebirths: number,
}

export type RunInfo = {
	active: boolean,
	stage: number,
	biome: number,
	enemiesLeft: number,
	enemiesTotal: number,
	isBoss: boolean,
	suggested: number,
	bossName: string?,
	-- Set in the Infinite Tower, where stages are shown as floors.
	tower: boolean?,
	floor: number?,
	-- Seconds until the next stage or Tower wave, and the full wait, for the countdown bar.
	nextIn: number?,
	nextTotal: number?,
}

return {}
