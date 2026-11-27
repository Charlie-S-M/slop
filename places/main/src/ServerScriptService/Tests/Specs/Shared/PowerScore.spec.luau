--!strict

const JestGlobals = require("@game/ServerScriptService/Tests/Packages/JestGlobals")
const describe = JestGlobals.describe
const expect = JestGlobals.expect
const it = JestGlobals.it

const PowerScore = require("@game/ReplicatedStorage/Shared/PowerScore")

describe("all-time Power score", function()
	it("is a whole number a data store can sort, even for huge Power", function()
		for _, power in { 0, 1, 250, 1e18, 1e33, 1e120 } do
			local score = PowerScore.encode(power)
			expect(score).toBe(math.floor(score))
			expect(score).toBeGreaterThanOrEqual(0)
			expect(score).toBeLessThan(2 ^ 53)
		end
	end)

	it("keeps stronger players ahead", function()
		expect(PowerScore.encode(1001)).toBeGreaterThan(PowerScore.encode(1000))
		expect(PowerScore.encode(1.01e33)).toBeGreaterThan(PowerScore.encode(1e33))
	end)

	it("reads back as the same Power", function()
		for _, power in { 0, 5, 1234, 7.5e21, 1e33 } do
			expect(PowerScore.decode(PowerScore.encode(power)) / math.max(power, 1)).toBeCloseTo(
				if power == 0 then 0 else 1,
				6
			)
		end
	end)

	it("treats a bad number as no Power", function()
		expect(PowerScore.encode(-5)).toBe(0)
		expect(PowerScore.encode(0 / 0)).toBe(0)
		expect(PowerScore.encode(math.huge)).toBe(0)
	end)
end)
