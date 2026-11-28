--!strict

const JestGlobals = require("@game/ServerScriptService/Tests/Packages/JestGlobals")
const describe = JestGlobals.describe
const expect = JestGlobals.expect
const it = JestGlobals.it

const Balance = require("@game/ReplicatedStorage/Shared/Balance")

describe("the Infinite Tower", function()
	it("unlocks at 1B Power", function()
		expect(Balance.TOWER_UNLOCK_POWER).toBe(1e9)
		expect(Balance.towerUnlocked(999_999_999)).toBe(false)
		expect(Balance.towerUnlocked(1e9)).toBe(true)
	end)

	it("plays floor N as stage 70 + N", function()
		expect(Balance.towerStage(1)).toBe(71)
		expect(Balance.towerFloor(Balance.towerStage(37))).toBe(37)
	end)

	it("resumes from the last checkpoint passed", function()
		expect(Balance.towerStartFloor(0)).toBe(1)
		expect(Balance.towerStartFloor(9)).toBe(1)
		expect(Balance.towerStartFloor(10)).toBe(11)
		expect(Balance.towerStartFloor(27)).toBe(21)
	end)

	it("adds 10% per ten floors cleared, for good", function()
		expect(Balance.towerBonus(0)).toBe(1)
		expect(Balance.towerBonus(9)).toBe(1)
		expect(Balance.towerBonus(10)).toBeCloseTo(1.1, 6)
		expect(Balance.towerBonus(35)).toBeCloseTo(1.3, 6)
	end)
end)
