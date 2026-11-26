--!strict

const JestGlobals = require("@game/ServerScriptService/Tests/Packages/JestGlobals")
const describe = JestGlobals.describe
const expect = JestGlobals.expect
const it = JestGlobals.it

const Wheel = require("@game/ReplicatedStorage/Shared/Wheel")

describe("lucky wheel", function()
	it("has eight prizes whose chances add up to 100%", function()
		expect(#Wheel.PRIZES).toBe(8)
		local total = 0
		for _, prize in Wheel.PRIZES do
			total += prize.weight
		end
		expect(total).toBeCloseTo(100, 6)
	end)

	it("gives the exclusive 0.5% of the time", function()
		expect(Wheel.PRIZES[Wheel.EXCLUSIVE].weight).toBeCloseTo(0.5, 6)
	end)

	it("maps a roll across the prizes in order", function()
		expect(Wheel.pick(0, 0)).toBe(1)
		expect(Wheel.pick(0.9999, 0)).toBe(#Wheel.PRIZES)
	end)

	it("guarantees the exclusive on the last spin of the pity count", function()
		expect(Wheel.pick(0, Wheel.PITY - 1)).toBe(Wheel.EXCLUSIVE)
		expect(Wheel.pick(0, Wheel.PITY - 2)).never.toBe(Wheel.EXCLUSIVE)
	end)

	it("has a free spin once a day", function()
		expect(Wheel.freeReady(0, 100000)).toBe(true)
		expect(Wheel.freeReady(100000, 100000 + 3600)).toBe(false)
		expect(Wheel.freeReady(100000, 100000 + Wheel.FREE_COOLDOWN)).toBe(true)
	end)
end)
