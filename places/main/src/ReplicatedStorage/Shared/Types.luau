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
}

-- A forge the server has rolled but the player hasn't finished hammering yet.
export type PendingForge = {
	token: string,
	gunId: string,
	rarity: number,
	basePower: number,
	train: number,
	oreIds: { string },
	startedAt: number,
}

-- The saved player profile. Every field is plain JSON so the DataStore can hold it.
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
}

return {}
