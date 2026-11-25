--!strict

const JestGlobals = require("@game/ServerScriptService/Tests/Packages/JestGlobals")
const describe = JestGlobals.describe
const expect = JestGlobals.expect
const it = JestGlobals.it

const Armor = require("@game/ReplicatedStorage/Shared/Armor")
const ArmorStats = require("@game/ReplicatedStorage/Shared/ArmorStats")
const Balance = require("@game/ReplicatedStorage/Shared/Balance")
const Biomes = require("@game/ReplicatedStorage/Shared/Biomes")
const Ores = require("@game/ReplicatedStorage/Shared/Ores")

describe("Aurora Reach", function()
	it("is the eighth biome, stages 71 to 80", function()
		expect(Biomes.Count).toBe(8)
		expect(Biomes.forStage(71).name).toBe("Aurora Reach")
		expect(Biomes.forStage(80).name).toBe("Aurora Reach")
		expect(Biomes.forStage(81).index).toBe(1)
		expect(Biomes.ascension(81)).toBe(1)
		expect(Biomes.forStage(75).boss.id).toBe("AuroraSentinel")
	end)

	it("has five Godly ores, and Auroracore unlocks Eternal", function()
		local ores = Ores.forBiome(8)
		expect(#ores).toBe(5)
		for _, ore in ores do
			expect(ore.rarity).toBe(7)
		end
		expect(Balance.ETERNAL_ORES.Auroracore).toBe(true)
		local core = Ores.get("Auroracore")
		assert(core, "no Auroracore")
		expect(Balance.forgeOdds({ core, core }, 0).chances[8] > 0).toBe(true)
	end)

	it("has a Sentinel that drops Aurora Shards like the Warden drops Glasshearts", function()
		expect(Balance.BOSS_MATERIALS.AuroraSentinel).toBe("AuroraShard")
		expect(Balance.BOSS_MATERIALS.GlassheartWarden).toBe("Glassheart")
		expect(Balance.bossMaterialDrop(true, 0.99)).toBe(1)
		expect(Balance.bossMaterialDrop(false, 0.5)).toBe(0)
		expect(Balance.bossMaterialDrop(false, 0.05)).toBe(1)
	end)
end)

describe("tempering armor", function()
	it("raises a piece's block by a quarter, once", function()
		local def = Armor.forSlot("Chestplate", 6)
		local item = ArmorStats.makeItem("u1", def, "B", 1)
		local tempered = ArmorStats.temper(item)
		expect(tempered.defense).toBeCloseTo(item.defense * Balance.TEMPER_MULTIPLIER, 4)
		expect(tempered.tempered).toBe(true)
		expect(tempered.uid).toBe("u1")
		expect(ArmorStats.canTemper(tempered)).toBe(false)
		expect(ArmorStats.canTemper(item)).toBe(true)
	end)

	it("costs coins worth stage-80 kills by rarity", function()
		expect(Balance.temperCost(5)).toBe(Balance.enemyCoins(80) * Balance.TEMPER_KILLS[5])
		expect(Balance.temperCost(8) > Balance.temperCost(1)).toBe(true)
	end)
end)

describe("the temper preview", function()
	it("shows the gain the worn set can actually use under the cap", function()
		local chest = ArmorStats.makeItem("c", Armor.forSlot("Chestplate", 1), "B", 1)
		local nearCap =
			{ chest, { uid = "h", id = "DawnlightHelmet", defense = 0.72, grade = "S" } :: any }
		local equipped = { Chestplate = "c", Helmet = "h" }
		local capped = math.min(0.75, 0.72 + chest.defense * Balance.TEMPER_MULTIPLIER)
			- math.min(0.75, 0.72 + chest.defense)
		expect(ArmorStats.temperGain(nearCap, equipped, chest)).toBeCloseTo(capped, 4)
		expect(capped < chest.defense * (Balance.TEMPER_MULTIPLIER - 1)).toBe(true)
		local spare = ArmorStats.makeItem("s", Armor.forSlot("Boots", 1), "B", 1)
		table.insert(nearCap, spare)
		-- A piece that isn't worn shows its own gain.
		expect(ArmorStats.temperGain(nearCap, equipped, spare)).toBeCloseTo(
			spare.defense * (Balance.TEMPER_MULTIPLIER - 1),
			4
		)
	end)

	it("names the Aurora Shard apart from the Starshard ore", function()
		expect(Balance.MATERIAL_NAMES.AuroraShard).toBe("Aurora Shard")
	end)
end)
