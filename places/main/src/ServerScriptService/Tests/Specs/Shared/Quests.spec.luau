--!strict

const JestGlobals = require("@game/ServerScriptService/Tests/Packages/JestGlobals")
const describe = JestGlobals.describe
const expect = JestGlobals.expect
const it = JestGlobals.it

const Quests = require("@game/ReplicatedStorage/Shared/Quests")

const DAY = 86400

local function fresh(): Quests.QuestBook
	return Quests.emptyBook()
end

describe("quest book", function()
	it("deals four dailies and three challenges", function()
		local book = fresh()
		Quests.refresh(book, 10 * DAY + 5, 0, Random.new(1))
		expect(#book.daily).toBe(Quests.DAILY_COUNT)
		expect(#book.challenge).toBe(Quests.CHALLENGE_COUNT)
		expect(book.day).toBe(10)
	end)

	it("keeps the same dailies within a day and deals new ones the next day", function()
		local book = fresh()
		Quests.refresh(book, 10 * DAY, 0, Random.new(1))
		book.daily[1].progress = 3
		Quests.refresh(book, 10 * DAY + 3600, 0, Random.new(2))
		expect(book.daily[1].progress).toBe(3)
		book.chestOpened = true
		Quests.refresh(book, 11 * DAY, 0, Random.new(3))
		expect(book.day).toBe(11)
		expect(book.daily[1].progress).toBe(0)
		expect(book.chestOpened).toBe(false)
		expect(book.chestPips).toBe(0)
	end)

	it("leaves Tower quests out until the Tower has been climbed", function()
		for seed = 1, 40 do
			local book = fresh()
			Quests.refresh(book, DAY, 0, Random.new(seed))
			for _, quest in book.daily do
				expect(quest.kind).never.toBe("Floors")
			end
		end
	end)
end)

describe("progress", function()
	it("counts toward quests of the same kind and stops at the target", function()
		local book = fresh()
		book.daily = { Quests.make("Kills", 10, 1, false) }
		Quests.record(book, "Kills", 4)
		Quests.record(book, "Ores", 4)
		expect(book.daily[1].progress).toBe(4)
		Quests.record(book, "Kills", 50)
		expect(book.daily[1].progress).toBe(10)
		expect(Quests.done(book.daily[1])).toBe(true)
	end)

	it("skips quests already claimed", function()
		local book = fresh()
		local quest = Quests.make("Kills", 10, 1, false)
		quest.claimed = true
		book.daily = { quest }
		Quests.record(book, "Kills", 4)
		expect(quest.progress).toBe(0)
	end)
end)

describe("ranks", function()
	it("starts at rank 1 and climbs as stars add up", function()
		local first = Quests.rank(0)
		expect(first.rank).toBe(1)
		expect(first.into).toBe(0)
		expect(first.need).toBe(Quests.RANK_STEPS[1])
		local second = Quests.rank(Quests.RANK_STEPS[1] + 2)
		expect(second.rank).toBe(2)
		expect(second.into).toBe(2)
	end)

	it("names each rank and the next one", function()
		local info = Quests.rank(0)
		expect(info.name).toBe(Quests.RANK_NAMES[1])
		expect(info.nextName).toBe(Quests.RANK_NAMES[2])
	end)
end)
