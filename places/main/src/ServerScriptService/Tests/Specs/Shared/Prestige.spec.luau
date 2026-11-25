--!strict

const JestGlobals = require("@game/ServerScriptService/Tests/Packages/JestGlobals")
const describe = JestGlobals.describe
const expect = JestGlobals.expect
const it = JestGlobals.it

const Balance = require("@game/ReplicatedStorage/Shared/Balance")

describe("prestige", function()
	it("opens at rebirth 15", function()
		expect(Balance.canPrestige(14)).toBe(false)
		expect(Balance.canPrestige(15)).toBe(true)
	end)

	it("gives nothing before the first prestige", function()
		expect(Balance.prestigeDamage(0)).toBe(1)
		expect(Balance.prestigeLuck(0)).toBe(0)
		expect(Balance.prestigeOres(0)).toBe(1)
	end)

	it("stacks 1.5x damage, +10% forge luck, and +25% ore drops each time", function()
		expect(Balance.prestigeDamage(1)).toBeCloseTo(1.5, 6)
		expect(Balance.prestigeDamage(2)).toBeCloseTo(2, 6)
		-- Forge Luck shows its effect doubled, so +10% on the card is 0.05 luck.
		expect(Balance.prestigeLuck(1)).toBeCloseTo(0.05, 6)
		expect(Balance.prestigeOres(2)).toBeCloseTo(1.5, 6)
	end)
end)
