--!strict

--[[
	Quests: four dailies dealt each UTC day, three longer challenges, and stars that raise a quest
	rank. Claiming three dailies fills the daily chest. Everything here works on a QuestBook, so
	the server owns the state and the client can draw it the same way.
]]

const Balance = require("./Balance")
const Types = require("./Types")

export type Quest = Types.Quest
export type QuestBook = Types.QuestBook

-- How a kind of quest reads and looks, and the targets it's dealt with.
export type KindDef = {
	text: string,
	glyph: string,
	color: Color3,
	daily: { min: number, max: number, stars: number },
	challenge: { min: number, max: number, stars: number },
	-- Hard quests carry a HARD tag and more stars.
	hard: boolean,
}

local Quests = {}

Quests.DAILY_COUNT = 4
Quests.CHALLENGE_COUNT = 3
-- Claimed dailies needed to open the daily chest.
Quests.CHEST_PIPS = 3

Quests.KINDS = {
	Kills = {
		text = "Defeat {n} monsters",
		glyph = "⚔️",
		color = Color3.fromRGB(235, 80, 95),
		daily = { min = 60, max = 150, stars = 1 },
		challenge = { min = 800, max = 2000, stars = 3 },
		hard = false,
	},
	Bosses = {
		text = "Defeat {n} bosses",
		glyph = "👑",
		color = Color3.fromRGB(200, 90, 230),
		daily = { min = 2, max = 5, stars = 1 },
		challenge = { min = 15, max = 30, stars = 3 },
		hard = false,
	},
	Ores = {
		text = "Bring back {n} ore",
		glyph = "💎",
		color = Color3.fromRGB(70, 150, 245),
		daily = { min = 20, max = 45, stars = 1 },
		challenge = { min = 200, max = 400, stars = 3 },
		hard = false,
	},
	Stages = {
		text = "Clear {n} stages",
		glyph = "🚪",
		color = Color3.fromRGB(90, 200, 110),
		daily = { min = 5, max = 12, stars = 1 },
		challenge = { min = 40, max = 80, stars = 3 },
		hard = false,
	},
	Forges = {
		text = "Forge {n} items",
		glyph = "🔨",
		color = Color3.fromRGB(245, 150, 50),
		daily = { min = 2, max = 5, stars = 1 },
		challenge = { min = 20, max = 40, stars = 3 },
		hard = false,
	},
	Hatches = {
		text = "Hatch {n} pets",
		glyph = "🥚",
		color = Color3.fromRGB(250, 130, 190),
		daily = { min = 3, max = 8, stars = 1 },
		challenge = { min = 40, max = 80, stars = 3 },
		hard = false,
	},
	Floors = {
		text = "Climb {n} tower floors",
		glyph = "🗼",
		color = Color3.fromRGB(60, 190, 200),
		daily = { min = 3, max = 6, stars = 2 },
		challenge = { min = 20, max = 40, stars = 4 },
		hard = true,
	},
} :: { [string]: KindDef }

-- Every kind in a fixed order, so the same seed always deals the same quests.
Quests.ORDER = { "Kills", "Bosses", "Ores", "Stages", "Forges", "Hatches", "Floors" }

-- Stars each rank takes to finish, and the ranks' names. Past the list, each rank takes the last.
Quests.RANK_STEPS = { 4, 8, 12, 16, 20, 25, 30, 40 }
Quests.RANK_NAMES =
	{ "Recruit", "Scout", "Hunter", "Squire", "Knight", "Champion", "Hero", "Legend", "Mythic" }

function Quests.emptyBook(): QuestBook
	return { day = 0, daily = {}, challenge = {}, stars = 0, chestPips = 0, chestOpened = false }
end

function Quests.make(kind: string, target: number, stars: number, hard: boolean): Quest
	return {
		kind = kind,
		target = target,
		progress = 0,
		stars = stars,
		hard = hard,
		claimed = false,
		swapped = false,
	}
end

function Quests.done(quest: Quest): boolean
	return quest.progress >= quest.target
end

function Quests.describe(quest: Quest): string
	local def = Quests.KINDS[quest.kind]
	return if def then (def.text:gsub("{n}", tostring(quest.target))) else quest.kind
end

-- Coins for a quest, scaled to how far the player has come.
function Quests.coins(quest: Quest, bestStage: number): number
	return math.floor(Balance.enemyCoins(math.max(bestStage, 1)) * 25 * quest.stars)
end

-- Coins in the daily chest.
function Quests.chestCoins(bestStage: number): number
	return math.floor(Balance.enemyCoins(math.max(bestStage, 1)) * 120)
end

local function kindsFor(towerBest: number, taken: { [string]: boolean }): { string }
	local list = {}
	for _, kind in Quests.ORDER do
		if not taken[kind] and (kind ~= "Floors" or towerBest > 0) then
			table.insert(list, kind)
		end
	end
	return list
end

local function deal(
	scope: "daily" | "challenge",
	towerBest: number,
	taken: { [string]: boolean },
	random: Random
): Quest
	local kinds = kindsFor(towerBest, taken)
	if #kinds == 0 then
		kinds = kindsFor(towerBest, {})
	end
	local kind = kinds[random:NextInteger(1, #kinds)]
	local def = Quests.KINDS[kind]
	local range = if scope == "daily" then def.daily else def.challenge
	local target = random:NextInteger(range.min, range.max)
	-- Big targets round to a tidy number.
	if target >= 100 then
		target = math.floor(target / 10 + 0.5) * 10
	end
	return Quests.make(kind, target, range.stars, def.hard)
end

local function takenBy(list: { Quest }, except: number?): { [string]: boolean }
	local taken: { [string]: boolean } = {}
	for index, quest in list do
		if index ~= except then
			taken[quest.kind] = true
		end
	end
	return taken
end

--[[
	Deals new dailies when the UTC day has changed (and resets the daily chest), and tops the
	challenges up to three. Returns true when anything changed.
]]
function Quests.refresh(book: QuestBook, now: number, towerBest: number, random: Random): boolean
	local changed = false
	local day = now // 86400
	if book.day ~= day then
		book.day = day
		book.daily = {}
		book.chestPips = 0
		book.chestOpened = false
		for _ = 1, Quests.DAILY_COUNT do
			table.insert(book.daily, deal("daily", towerBest, takenBy(book.daily), random))
		end
		changed = true
	end
	while #book.challenge < Quests.CHALLENGE_COUNT do
		table.insert(book.challenge, deal("challenge", towerBest, takenBy(book.challenge), random))
		changed = true
	end
	return changed
end

-- Adds progress to every unclaimed quest of a kind.
function Quests.record(book: QuestBook, kind: string, amount: number)
	for _, list in { book.daily, book.challenge } do
		for _, quest in list do
			if quest.kind == kind and not quest.claimed then
				quest.progress = math.min(quest.target, quest.progress + amount)
			end
		end
	end
end

-- Replaces a daily with a new one of a different kind. Each daily can be swapped once.
function Quests.swap(book: QuestBook, index: number, towerBest: number, random: Random): boolean
	local quest = book.daily[index]
	if not quest or quest.swapped or quest.claimed then
		return false
	end
	local taken = takenBy(book.daily)
	local replacement = deal("daily", towerBest, taken, random)
	replacement.swapped = true
	book.daily[index] = replacement
	return true
end

-- Deals a whole new set of dailies, keeping the day and the chest as they are.
function Quests.reroll(book: QuestBook, towerBest: number, random: Random)
	book.daily = {}
	for _ = 1, Quests.DAILY_COUNT do
		table.insert(book.daily, deal("daily", towerBest, takenBy(book.daily), random))
	end
end

-- True when a finished quest or the daily chest is waiting to be claimed.
function Quests.ready(book: QuestBook): boolean
	if book.chestPips >= Quests.CHEST_PIPS and not book.chestOpened then
		return true
	end
	for _, list in { book.daily, book.challenge } do
		for _, quest in list do
			if Quests.done(quest) and not quest.claimed then
				return true
			end
		end
	end
	return false
end

export type RankInfo = {
	rank: number,
	name: string,
	nextName: string,
	-- Stars into this rank, and the stars it takes to finish it.
	into: number,
	need: number,
}

function Quests.rank(stars: number): RankInfo
	local rank = 1
	local left = stars
	while true do
		local need = Quests.RANK_STEPS[rank] or Quests.RANK_STEPS[#Quests.RANK_STEPS]
		if left < need then
			local names = Quests.RANK_NAMES
			return {
				rank = rank,
				name = names[math.min(rank, #names)],
				nextName = names[math.min(rank + 1, #names)],
				into = left,
				need = need,
			}
		end
		left -= need
		rank += 1
	end
end

return Quests
