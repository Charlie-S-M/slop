--!strict

-- One forged gun the player owns. The id names its catalog entry; power was rolled at the forge.
export type GunItem = {
	uid: string,
	id: string,
	power: number,
	locked: boolean?,
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
