--!strict

const JestGlobals = require("@game/ServerScriptService/Tests/Packages/JestGlobals")
const describe = JestGlobals.describe
const expect = JestGlobals.expect
const it = JestGlobals.it

const Balance = require("@game/ReplicatedStorage/Shared/Balance")
const Biomes = require("@game/ReplicatedStorage/Shared/Biomes")
const GunBuilder = require("@game/ReplicatedStorage/Shared/GunBuilder")
const GunStats = require("@game/ReplicatedStorage/Shared/GunStats")
const Guns = require("@game/ReplicatedStorage/Shared/Guns")
const Ores = require("@game/ReplicatedStorage/Shared/Ores")

describe("evolutions", function()
	it("evolves Solar Flare into Solar Crown", function()
		local evolved = Guns.evolutionOf("SolarFlare")
		expect(evolved and evolved.id).toBe("SolarCrown")
		expect(evolved and evolved.evolvesFrom).toBe("SolarFlare")
	end)

	it("gives every Legendary+ forge gun an evolution and nothing below", function()
		for rarity = 1, 8 do
			for _, def in Guns.pool(rarity) do
				expect(Guns.evolutionOf(def.id) ~= nil).toBe(rarity >= 5)
			end
		end
	end)

	it("evolved guns do not evolve again and never come out of the forge", function()
		local evolvedCount = 0
		for _, def in Guns.List do
			if def.evolvesFrom then
				evolvedCount += 1
				expect(Guns.evolutionOf(def.id)).toBeNil()
				expect(table.find(Guns.pool(def.rarity), def)).toBeNil()
			end
		end
		expect(evolvedCount).toBe(7)
	end)

	it("charges coins worth stage-70 kills, only from Legendary up", function()
		expect(Balance.evolveCost(4)).toBeNil()
		expect(Balance.evolveCost(5)).toBe(Balance.enemyCoins(70) * 10)
		expect(Balance.evolveCost(7)).toBe(Balance.enemyCoins(70) * 100)
	end)

	it("evolving keeps uid, grade, lock", function()
		local item = {
			uid = "g7",
			id = "SolarFlare",
			power = 100,
			speed = 1,
			train = 50,
			grade = "A",
			locked = true,
		}
		local evolved = GunStats.evolve(item :: any, "SolarCrown")
		expect(evolved.uid).toBe("g7")
		expect(evolved.id).toBe("SolarCrown")
		expect(evolved.grade).toBe("A")
		expect(evolved.locked).toBe(true)
		expect(evolved.power).toBe(300)
		expect(evolved.train).toBe(100)
		expect(math.abs(evolved.speed - 1.1) < 1e-9).toBe(true)
	end)

	it("builds an evolved gun without a template", function()
		local def = Guns.get("SolarCrown")
		assert(def, "missing SolarCrown")
		local model = GunBuilder.build(def)
		expect(model:FindFirstChild("Handle") ~= nil).toBe(true)
	end)
end)

describe("Glassfall Foundry", function()
	it("fills stages 61 to 70", function()
		expect(Biomes.forStage(61).index).toBe(7)
		expect(Biomes.forStage(70).index).toBe(7)
		expect(Biomes.ascension(70)).toBe(0)
	end)

	it("is guarded by the Glassheart Warden", function()
		expect(Biomes.List[7].boss.id).toBe("GlassheartWarden")
	end)

	it("guarantees a Glassheart on the first Warden kill and sometimes after", function()
		expect(Balance.glassheartDrop(true, 0.99)).toBe(1)
		expect(Balance.glassheartDrop(false, 0.1)).toBe(1)
		expect(Balance.glassheartDrop(false, 0.2)).toBe(0)
	end)

	it("drops five Godly ores", function()
		local pool = Ores.forBiome(7)
		expect(#pool).toBe(5)
		for position, ore in pool do
			expect(ore.rarity).toBe(7)
			expect(ore.index).toBe(30 + position)
		end
	end)
end)

describe("daily reward ores", function()
	it("come from the best biome reached, the Foundry included", function()
		expect(Biomes.bestReached(0)).toBe(1)
		expect(Biomes.bestReached(55)).toBe(6)
		expect(Biomes.bestReached(65)).toBe(7)
	end)

	it("stay on the last biome through Ascensions", function()
		expect(Biomes.bestReached(250)).toBe(Biomes.Count)
	end)
end)
