--!strict

const JestGlobals = require("@game/ServerScriptService/Tests/Packages/JestGlobals")
const describe = JestGlobals.describe
const expect = JestGlobals.expect
const it = JestGlobals.it

const Balance = require("@game/ReplicatedStorage/Shared/Balance")
const Biomes = require("@game/ReplicatedStorage/Shared/Biomes")
const Ores = require("@game/ReplicatedStorage/Shared/Ores")
const Rarity = require("@game/ReplicatedStorage/Shared/Rarity")

local function ore(id: string): Ores.OreDef
	local found = Ores.get(id)
	assert(found, `no ore {id}`)
	return found
end

describe("stages to 250", function()
	it("has 25 biomes, the last being the Omega Gate at stage 250", function()
		expect(Biomes.Count).toBe(25)
		expect(Biomes.forStage(250).name).toBe("Omega Gate")
		expect(Biomes.ascension(250)).toBe(0)
		expect(Biomes.ascension(251)).toBe(1)
		for _, biome in Biomes.List do
			expect(#biome.enemies).toBe(3)
		end
	end)

	it("has five ores per biome, with a Core last", function()
		expect(#Ores.List).toBe(125)
		for biome = 9, 25 do
			local ores = Ores.forBiome(biome)
			expect(#ores).toBe(5)
			expect(ores[5].style).toBe("Core")
		end
	end)

	it("adds Celestial, Cosmic, and Omega, one per 50 stages", function()
		expect(Rarity.Count).toBe(11)
		expect(Rarity.get(9).name).toBe("Celestial")
		expect(Rarity.get(10).name).toBe("Cosmic")
		expect(Rarity.get(11).name).toBe("Omega")
		expect(Ores.forBiome(9)[1].rarity).toBe(8)
		expect(Ores.forBiome(14)[1].rarity).toBe(9)
		expect(Ores.forBiome(19)[1].rarity).toBe(10)
		expect(Ores.forBiome(25)[1].rarity).toBe(11)
		for tier = 9, 11 do
			expect(Balance.GUN_DAMAGE_TIERS[tier] > Balance.GUN_DAMAGE_TIERS[tier - 1]).toBe(true)
			expect(Rarity.get(tier).powerMultiplier > Rarity.get(tier - 1).powerMultiplier).toBe(
				true
			)
		end
	end)

	it("needs a region's Core to forge its tier", function()
		local plain = Balance.forgeOdds({ ore("Cloudite"), ore("Cloudite") }, 3)
		expect(plain.chances[9]).toBe(0)
		local keyed = Balance.forgeOdds({ ore("Cloudite"), ore("Halocore") }, 3)
		expect(keyed.chances[9] > 0).toBe(true)
		expect(keyed.chances[10]).toBe(0)
		local cosmic = Balance.forgeOdds({ ore("Regolith"), ore("Mooncore") }, 3)
		expect(cosmic.chances[10] > 0).toBe(true)
	end)

	it("keeps stages 1 to 80 as they were and grows more gently past them", function()
		expect(Balance.enemyHealth(80)).toBeCloseTo(30 * 1.65 ^ 79, 0)
		local before = Balance.enemyHealth(80) / Balance.enemyHealth(79)
		local after = Balance.enemyHealth(82) / Balance.enemyHealth(81)
		expect(after < before).toBe(true)
		expect(Balance.enemyHealth(250) < math.huge).toBe(true)
		expect(Balance.enemyCoins(250) > Balance.enemyCoins(249)).toBe(true)
	end)
end)
