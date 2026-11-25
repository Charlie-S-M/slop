--!strict

const JestGlobals = require("@game/ServerScriptService/Tests/Packages/JestGlobals")
const describe = JestGlobals.describe
const expect = JestGlobals.expect
const it = JestGlobals.it

const Attachments = require("@game/ReplicatedStorage/Shared/Attachments")
const Balance = require("@game/ReplicatedStorage/Shared/Balance")
const GunStats = require("@game/ReplicatedStorage/Shared/GunStats")
const Types = require("@game/ReplicatedStorage/Shared/Types")

local function gun(parts: { [string]: string }?): Types.GunItem
	return {
		uid = "g1",
		id = "SolarFlare",
		power = 1000,
		speed = 1,
		train = 10,
		grade = "A",
		parts = parts,
	}
end

describe("the attachment catalog", function()
	it("has a part for every slot and rarity", function()
		expect(#Attachments.SLOTS).toBe(5)
		expect(#Attachments.List).toBe(35)
		local def = Attachments.forSlot("Barrel", 5)
		expect(def.name).toBe("Gilded Barrel")
		expect(def.stat).toBe("power")
	end)
end)

describe("the chest reel", function()
	it("uses the listed odds at base luck", function()
		local weights = Balance.reelWeights(0)
		local expected = { 50, 25, 15, 5, 3.9, 1, 0.1 }
		for tier, weight in expected do
			expect(weights[tier] * 100).toBeCloseTo(weight, 4)
		end
	end)

	it("moves odds toward rarer parts with luck, keeping the total", function()
		local base = Balance.reelWeights(0)
		local lucky = Balance.reelWeights(0.5)
		local total = 0
		for _, weight in lucky do
			total += weight
		end
		expect(total).toBeCloseTo(1, 6)
		expect(lucky[7] > base[7]).toBe(true)
		expect(lucky[1] < base[1]).toBe(true)
	end)

	it("maps rolls onto rarities", function()
		expect(Balance.reelRarity(0, 0)).toBe(1)
		expect(Balance.reelRarity(0.6, 0)).toBe(2)
		expect(Balance.reelRarity(0.9995, 0)).toBe(7)
	end)

	it("only gives a part 5% of the time, whatever the luck", function()
		expect(Balance.CHEST_PART_CHANCE).toBe(0.05)
	end)
end)

describe("equipped parts", function()
	it("raise the gun's stats by their bonus", function()
		local barrel = Attachments.forSlot("Barrel", 3)
		local grip = Attachments.forSlot("Grip", 3)
		local key = Attachments.forSlot("Keychain", 3)
		local effective =
			GunStats.effective(gun({ Barrel = barrel.id, Grip = grip.id, Keychain = key.id }))
		expect(effective.power).toBeCloseTo(1000 * (1 + barrel.bonus), 6)
		expect(effective.speed).toBeCloseTo(1 + grip.bonus, 6)
		expect(effective.train).toBeCloseTo(10 * (1 + key.bonus), 6)
	end)

	it("ignore unknown ids and parts in the wrong slot", function()
		local barrel = Attachments.forSlot("Barrel", 3)
		local effective = GunStats.effective(gun({ Grip = barrel.id, Scope = "Nope" }))
		expect(effective.power).toBe(1000)
		expect(effective.speed).toBe(1)
	end)

	it("carry over when a gun evolves", function()
		local barrel = Attachments.forSlot("Barrel", 2)
		local evolved = GunStats.evolve(gun({ Barrel = barrel.id }), "SolarCrown")
		expect(evolved.parts and evolved.parts.Barrel).toBe(barrel.id)
	end)
end)
