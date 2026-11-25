--!strict

const JestGlobals = require("@game/ServerScriptService/Tests/Packages/JestGlobals")
const describe = JestGlobals.describe
const expect = JestGlobals.expect
const it = JestGlobals.it

const Balance = require("@game/ReplicatedStorage/Shared/Balance")
const Guns = require("@game/ReplicatedStorage/Shared/Guns")
const Ores = require("@game/ReplicatedStorage/Shared/Ores")
const Rarity = require("@game/ReplicatedStorage/Shared/Rarity")

local function ores(ids: { string }): { Ores.OreDef }
	local list = {}
	for _, id in ids do
		local ore = Ores.get(id)
		assert(ore, `unknown ore {id}`)
		table.insert(list, ore)
	end
	return list
end

describe("the Eternal tier", function()
	it("is the eighth rarity", function()
		expect(Rarity.Count).toBe(8)
		expect(Rarity.get(8).name).toBe("Eternal")
	end)

	it("can't be forged without Glasscore, even with top luck", function()
		local mix = ores({ "Kilnglass", "Cullet", "Prismite", "AnnealedEmber", "AnnealedEmber" })
		expect(Balance.forgeOdds(mix, 5).chances[8]).toBe(0)
	end)

	it("can be forged with a Glasscore in the mix", function()
		local mix = ores({ "Prismite", "Prismite", "Prismite", "Prismite", "Glasscore" })
		expect(Balance.forgeOdds(mix, 0).chances[8] > 0).toBe(true)
	end)

	it("leaves odds for low ores as they were", function()
		local odds = Balance.forgeOdds(ores({ "Pebble", "Pebble", "Copper" }), 0)
		expect(string.format("%.4f", odds.chances[1])).toBe("0.8477")
		expect(string.format("%.4f", odds.chances[2])).toBe("0.1523")
		expect(odds.chances[3]).toBe(0)
	end)

	it("has a damage tier for every rarity", function()
		for tier = 1, Rarity.Count do
			expect(Balance.GUN_DAMAGE_TIERS[tier] ~= nil).toBe(true)
		end
		expect(Balance.GUN_DAMAGE_TIERS[8] > Balance.GUN_DAMAGE_TIERS[7]).toBe(true)
	end)

	it("has two guns that don't evolve", function()
		expect(#Guns.pool(8)).toBe(2)
		expect(Guns.evolutionOf("Dawnbringer")).toBe(nil)
		expect(Guns.evolutionOf("EverlightCannon")).toBe(nil)
	end)
end)
