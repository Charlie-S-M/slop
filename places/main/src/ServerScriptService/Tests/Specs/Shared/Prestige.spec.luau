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

	it("doubles damage and ore drops with each prestige", function()
		expect(Balance.prestigeDamage(1)).toBe(2)
		expect(Balance.prestigeDamage(2)).toBe(4)
		expect(Balance.prestigeDamage(3)).toBe(8)
		expect(Balance.prestigeOres(2)).toBe(4)
	end)

	it("adds forge luck that doubles too: +25%, +75%, +175%", function()
		-- Forge Luck shows its effect doubled, so +25% on the card is 0.125 luck.
		expect(Balance.prestigeLuck(1)).toBeCloseTo(0.125, 6)
		expect(Balance.prestigeLuck(2)).toBeCloseTo(0.375, 6)
		expect(Balance.prestigeLuck(3)).toBeCloseTo(0.875, 6)
	end)
end)
