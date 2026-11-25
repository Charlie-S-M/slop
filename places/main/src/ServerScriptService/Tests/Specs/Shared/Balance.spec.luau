--!strict

const JestGlobals = require("@game/ServerScriptService/Tests/Packages/JestGlobals")
const describe = JestGlobals.describe
const expect = JestGlobals.expect
const it = JestGlobals.it

const Balance = require("@game/ReplicatedStorage/Shared/Balance")
const Ores = require("@game/ReplicatedStorage/Shared/Ores")
const Rarity = require("@game/ReplicatedStorage/Shared/Rarity")

local function sum(list: { number }): number
	local total = 0
	for _, value in list do
		total += value
	end
	return total
end

local function oresOf(id: string, count: number): { Ores.OreDef }
	local ore = Ores.get(id)
	assert(ore, `missing ore {id}`)
	local list = {}
	for _ = 1, count do
		table.insert(list, ore)
	end
	return list
end

describe("Balance.forgeOdds", function()
	it("returns chances that add up to one", function()
		local odds = Balance.forgeOdds(oresOf("Emerald", 3), 0)
		expect(math.abs(sum(odds.chances) - 1) < 1e-9).toBe(true)
	end)

	it("never rolls more than one rarity above the best ore", function()
		local odds = Balance.forgeOdds(oresOf("Pebble", 5), 10)
		for tier = 3, Rarity.Count do
			expect(odds.chances[tier]).toBe(0)
		end
	end)

	it("rewards adding more ores of the same kind", function()
		local one = Balance.forgeOdds(oresOf("Bronze", 1), 0)
		local five = Balance.forgeOdds(oresOf("Bronze", 5), 0)
		expect(five.chances[3] > one.chances[3]).toBe(true)
	end)

	it("adds up the ores' values as the base power", function()
		local ore = Ores.get("Iron")
		assert(ore, "missing Iron")
		local odds = Balance.forgeOdds(oresOf("Iron", 4), 0)
		expect(odds.basePower).toBe(ore.value * 4)
	end)
end)

describe("Balance.pickRarity", function()
	it("maps a roll onto the cumulative chances", function()
		local odds = { chances = { 0.5, 0.5, 0, 0, 0, 0, 0 }, basePower = 1, oreCount = 1 }
		expect(Balance.pickRarity(odds, 0.1)).toBe(1)
		expect(Balance.pickRarity(odds, 0.9)).toBe(2)
	end)
end)

describe("stage scaling", function()
	it("makes every stage tougher and bigger than the one before", function()
		for stage = 1, 120 do
			expect(Balance.enemyHealth(stage + 1) > Balance.enemyHealth(stage)).toBe(true)
			expect(Balance.enemyDamage(stage + 1) > Balance.enemyDamage(stage)).toBe(true)
			expect(Balance.enemyScale(stage + 1, false) >= Balance.enemyScale(stage, false)).toBe(
				true
			)
		end
	end)

	it("puts a boss on every fifth stage", function()
		expect(Balance.isBossStage(5)).toBe(true)
		expect(Balance.isBossStage(6)).toBe(false)
	end)

	it("offers a checkpoint at the start of each biome reached", function()
		local list = Balance.checkpoints(25)
		expect(list[1]).toBe(1)
		expect(list[2]).toBe(11)
		expect(list[3]).toBe(21)
		expect(#list).toBe(3)
	end)
end)
