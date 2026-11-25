--!strict

const JestGlobals = require("@game/ServerScriptService/Tests/Packages/JestGlobals")
const describe = JestGlobals.describe
const expect = JestGlobals.expect
const it = JestGlobals.it

const Biomes = require("@game/ReplicatedStorage/Shared/Biomes")
const Ores = require("@game/ReplicatedStorage/Shared/Ores")

describe("Glassfall Foundry", function()
	it("fills stages 61 to 70 and moves the loop to stage 71", function()
		expect(Biomes.forStage(61).index).toBe(7)
		expect(Biomes.forStage(70).index).toBe(7)
		expect(Biomes.forStage(71).index).toBe(1)
		expect(Biomes.ascension(70)).toBe(0)
		expect(Biomes.ascension(71)).toBe(1)
	end)

	it("is guarded by the Glassheart Warden", function()
		expect(Biomes.List[7].boss.id).toBe("GlassheartWarden")
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
