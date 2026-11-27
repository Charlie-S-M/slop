--!strict

const JestGlobals = require("@game/ServerScriptService/Tests/Packages/JestGlobals")
const describe = JestGlobals.describe
const expect = JestGlobals.expect
const it = JestGlobals.it

const Balance = require("@game/ReplicatedStorage/Shared/Balance")
const GunStats = require("@game/ReplicatedStorage/Shared/GunStats")
const Guns = require("@game/ReplicatedStorage/Shared/Guns")
const Ores = require("@game/ReplicatedStorage/Shared/Ores")
const PrestigeShop = require("@game/ReplicatedStorage/Shared/PrestigeShop")
const Upgrades = require("@game/ReplicatedStorage/Shared/Upgrades")

local function ores(ids: { string }): { Ores.OreDef }
	local list = {}
	for _, id in ids do
		table.insert(list, (assert(Ores.get(id), `unknown ore {id}`)))
	end
	return list
end

const NO_LUCK: Balance.LuckSources = {
	upgrade = 0,
	prestige = 0,
	extraLuck = false,
	superLuck = false,
	potion = false,
	server = false,
	charge = false,
	forgeLuckLevel = 0,
}

describe("the prestige shop", function()
	it("doubles the effect and the cost every level", function()
		const coins = assert(PrestigeShop.get("Coins"))
		expect(PrestigeShop.cost(coins, 0)).toBe(1)
		expect(PrestigeShop.cost(coins, 1)).toBe(2)
		expect(PrestigeShop.cost(coins, 3)).toBe(8)
		expect(PrestigeShop.multiplier({ Coins = 3 }, "Coins")).toBe(8)
		expect(PrestigeShop.multiplier({}, "Coins")).toBe(1)
	end)

	it("sells each Save item once, at its listed price", function()
		expect(PrestigeShop.cost(assert(PrestigeShop.get("SavePets")), 0)).toBe(3)
		expect(PrestigeShop.cost(assert(PrestigeShop.get("SaveUpgrades")), 0)).toBe(3)
		expect(PrestigeShop.cost(assert(PrestigeShop.get("SaveGuns")), 0)).toBe(10)
		expect(PrestigeShop.cost(assert(PrestigeShop.get("SaveGuns")), 1)).toBeNil()
	end)

	it("gives one token a prestige, doubled by 2x Prestige Coins", function()
		expect(PrestigeShop.tokensPerPrestige({})).toBe(1)
		expect(PrestigeShop.tokensPerPrestige({ Tokens = 2 })).toBe(4)
	end)

	it("turns firing speed past its cap into damage, so each level still doubles", function()
		const levels = { FireRate = 5 }
		expect(PrestigeShop.multiplier(levels, "FireRate")).toBe(PrestigeShop.MAX_FIRE_RATE)
		expect(PrestigeShop.multiplier(levels, "FireRate") * PrestigeShop.fireRateDamage(levels)).toBe(
			32
		)
	end)
end)

describe("Eternal odds", function()
	const glass = ores({ "Kilnglass", "Cullet", "Prismite", "AnnealedEmber", "Glasscore" })

	it("are 1 in 40 with a key ore and no boosts", function()
		const luck, boost = Balance.forgeLuck(NO_LUCK)
		expect(Balance.forgeOdds(glass, luck, boost).chances[8]).toBeCloseTo(1 / 40, 6)
	end)

	it("grow with passes, potions, and 2x Forging Luck", function()
		const sources = table.clone(NO_LUCK)
		sources.superLuck = true
		sources.potion = true
		sources.forgeLuckLevel = 2
		const _, boost = Balance.forgeLuck(sources)
		expect(boost).toBeCloseTo(1.6 * 1.3 * 4, 6)
	end)

	it("stay zero without a key ore", function()
		const mix = ores({ "Kilnglass", "Cullet", "Prismite", "AnnealedEmber", "AnnealedEmber" })
		expect(Balance.forgeOdds(mix, 5, 100).chances[8]).toBe(0)
	end)

	it("never let a region tier come before the tiers under it", function()
		-- Godly ores can't reach Celestial; Skyharbor ores without their Core can't either.
		expect(Balance.forgeOdds(glass, 3, 1).chances[9]).toBe(0)
		const sky = ores({ "Cloudite", "Zephyrite", "Galestone", "Skysilver" })
		expect(Balance.forgeOdds(sky, 3, 1).chances[9]).toBe(0)
	end)
end)

describe("the Index", function()
	it("lists guns from Common to Omega", function()
		for index = 2, #Guns.List do
			expect(Guns.List[index].rarity >= Guns.List[index - 1].rarity).toBe(true)
		end
	end)

	it("keeps each evolution right after its base gun", function()
		for index, def in Guns.List do
			if def.evolvesFrom then
				expect(Guns.List[index - 1].id).toBe(def.evolvesFrom)
			end
		end
	end)
end)

describe("Robux guns", function()
	it("one-shot a normal enemy at the deepest stage ever cleared", function()
		const def = assert(Guns.get("NovaReaper"))
		const floor = Balance.limitedPelletFloor(def.id, def.kind, 120)
		expect(floor * Guns.kindStats(def.kind).pellets).toBeCloseTo(Balance.enemyHealth(120), 3)
	end)

	it("give forged guns no floor", function()
		expect(Balance.limitedPelletFloor("PopPistol", "Pistol", 120)).toBe(0)
	end)
end)

describe("Quick Hands", function()
	it("reloads 2% faster a level, 40% at most", function()
		const kind = "Rifle"
		const base = Guns.kindStats(kind).reloadTime
		expect(GunStats.reloadTime(kind, 0)).toBe(base)
		expect(GunStats.reloadTime(kind, 10)).toBeCloseTo(base * 0.8, 6)
		const def = assert(Upgrades.get("ReloadSpeed"))
		expect(GunStats.reloadTime(kind, def.maxLevel)).toBeCloseTo(base * 0.6, 6)
	end)
end)
