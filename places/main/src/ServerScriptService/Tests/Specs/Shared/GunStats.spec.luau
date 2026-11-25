--!strict

const JestGlobals = require("@game/ServerScriptService/Tests/Packages/JestGlobals")
const describe = JestGlobals.describe
const expect = JestGlobals.expect
const it = JestGlobals.it

const GunStats = require("@game/ReplicatedStorage/Shared/GunStats")
const Ores = require("@game/ReplicatedStorage/Shared/Ores")

local function oresOf(id: string, count: number): { Ores.OreDef }
	local ore = Ores.get(id)
	assert(ore, `missing ore {id}`)
	local list = {}
	for _ = 1, count do
		table.insert(list, ore)
	end
	return list
end

describe("GunStats.strikeAccuracy", function()
	it("scores each window", function()
		expect(GunStats.strikeAccuracy(0.05)).toBe(1)
		expect(GunStats.strikeAccuracy(0.15)).toBe(0.75)
		expect(GunStats.strikeAccuracy(0.3)).toBe(0.45)
		expect(GunStats.strikeAccuracy(0.5)).toBe(0)
	end)
end)

describe("GunStats.gradeFor", function()
	it("grades the average of four strikes", function()
		expect(GunStats.gradeFor({ 1, 1, 1, 1 })).toBe("S")
		expect(GunStats.gradeFor({ 1, 0.75, 0.75, 0.75 })).toBe("A")
		expect(GunStats.gradeFor({ 0.45, 0.45, 0.45, 0.45 })).toBe("C")
		expect(GunStats.gradeFor({ 0, 0, 0, 0 })).toBe("D")
	end)

	it("treats bad accuracies as misses", function()
		expect(GunStats.gradeFor({ 0 / 0, -3, math.huge, "x" :: any })).toBe("D")
		expect(GunStats.gradeFor({})).toBe("D")
		expect(GunStats.gradeFor({ 1, 1, 1, 1, 1, 1 })).toBe("S")
	end)
end)

describe("GunStats.oreTrainingFactor", function()
	it("gives Common ores today's rate and rarer ores more", function()
		expect(GunStats.oreTrainingFactor(oresOf("Pebble", 4))).toBe(1)
		expect(math.abs(GunStats.oreTrainingFactor(oresOf("Singularity", 4)) - 1.25 ^ 6) < 1e-9).toBe(
			true
		)
	end)
end)

describe("GunStats.finalize", function()
	it("applies the grade to power and speed", function()
		local power, speed = GunStats.finalize(100, "S", 1)
		expect(power).toBe(130)
		expect(speed).toBe(1.15)
		power, speed = GunStats.finalize(100, "D", 1)
		expect(power).toBe(70)
		expect(speed).toBe(0.85)
	end)
end)

describe("GunStats.migrateGun", function()
	it("migrates an old gun without slowing its training", function()
		local item = GunStats.migrateGun({ uid = "g5", id = "RookieRifle", power = 40 })
		expect(item.speed).toBe(1)
		expect(item.grade).toBe("B")
		expect(item.train >= 40).toBe(true)
	end)

	it("keeps the starter pistol at exactly +1", function()
		local item = GunStats.migrateGun({ uid = "g1", id = "PopPistol", power = 1 })
		expect(item.train).toBe(1)
	end)
end)
