--!strict

const JestGlobals = require("@game/ServerScriptService/Tests/Packages/JestGlobals")
const describe = JestGlobals.describe
const expect = JestGlobals.expect
const it = JestGlobals.it

const Strike = require("@game/ReplicatedStorage/Shared/Strike")

const mob = Vector3.new(0, 0, 0)

describe("mob strikes", function()
	it("reaches a player standing within range", function()
		const spot = Vector3.new(5, 3, 0)
		expect(Strike.reaches(mob, spot, spot, 6)).toBe(true)
	end)

	it("misses a player standing out of range", function()
		const spot = Vector3.new(7, 0, 0)
		expect(Strike.reaches(mob, spot, spot, 6)).toBe(false)
	end)

	it("reaches a player who ran past between two checks", function()
		expect(Strike.reaches(mob, Vector3.new(-9, 0, 4), Vector3.new(9, 0, 4), 6)).toBe(true)
	end)

	it("ignores height", function()
		const spot = Vector3.new(2, 40, 0)
		expect(Strike.reaches(mob, spot, spot, 6)).toBe(true)
	end)

	it("does not sweep the path of a teleport", function()
		expect(Strike.reaches(mob, Vector3.new(-80, 0, 0), Vector3.new(80, 0, 0), 6)).toBe(false)
	end)
end)
