--!strict

const JestGlobals = require("@game/ServerScriptService/Tests/Packages/JestGlobals")
const describe = JestGlobals.describe
const expect = JestGlobals.expect
const it = JestGlobals.it

const Upgrades = require("@game/ReplicatedStorage/Shared/Upgrades")

local function def(id: string): Upgrades.UpgradeDef
	local found = Upgrades.get(id)
	assert(found, `no upgrade {id}`)
	return found
end

describe("raised upgrade caps", function()
	it("quadruple Ore Bag, Training, Toughness, and Coin Boost, and triple the rest", function()
		expect(def("BagSize").maxLevel).toBe(160)
		expect(def("Training").maxLevel).toBe(160)
		expect(def("Toughness").maxLevel).toBe(160)
		expect(def("CoinBoost").maxLevel).toBe(120)
		expect(def("Luck").maxLevel).toBe(75)
		expect(def("WalkSpeed").maxLevel).toBe(36)
		expect(def("Magnet").maxLevel).toBe(30)
	end)

	it("leave every level up to the old cap exactly as it was", function()
		expect(Upgrades.value("BagSize", 40)).toBe(6 + 2 * 40)
		expect(Upgrades.value("Luck", 25)).toBeCloseTo(0.03 * 25, 6)
		expect(Upgrades.cost(def("Training"), 39)).toBe(math.floor(150 * 1.38 ^ 39))
	end)

	it("give part of the effect past the old cap", function()
		local atCap = Upgrades.value("Training", 40)
		local beyond = Upgrades.value("Training", 41)
		expect(beyond - atCap).toBeCloseTo(0.15 * def("Training").overflow, 6)
		expect(Upgrades.value("WalkSpeed", 36) <= 72).toBe(true)
	end)

	it("cost less per level past the old cap than before it", function()
		local training = def("Training")
		local growthBefore = Upgrades.cost(training, 39) / Upgrades.cost(training, 38)
		local growthAfter = Upgrades.cost(training, 41) / Upgrades.cost(training, 40)
		expect(growthAfter < growthBefore).toBe(true)
		expect(Upgrades.cost(training, 159) < math.huge).toBe(true)
	end)

	it("describe the effect a level actually gives", function()
		expect(Upgrades.describe(def("BagSize"), 40)).toBe("86 ores")
		expect(Upgrades.describe(def("BagSize"), 42)).toBe("88 ores")
	end)
end)
