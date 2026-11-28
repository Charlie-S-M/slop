--!strict

const JestGlobals = require("@game/ServerScriptService/Tests/Packages/JestGlobals")
const describe = JestGlobals.describe
const expect = JestGlobals.expect
const it = JestGlobals.it

const Balance = require("@game/ReplicatedStorage/Shared/Balance")
const PetStats = require("@game/ReplicatedStorage/Shared/PetStats")
const Pets = require("@game/ReplicatedStorage/Shared/Pets")

describe("the pet catalog", function()
	it("has three eggs with one pet per rarity", function()
		expect(#Pets.EGGS).toBe(3)
		expect(#Pets.List).toBe(12)
		for _, egg in Pets.EGGS do
			local total = 0
			for _, entry in egg.pets do
				total += entry.weight
				expect(Pets.get(entry.petId) ~= nil).toBe(true)
			end
			expect(total).toBe(100)
		end
	end)

	it("hatches by weight", function()
		local meadow = Pets.egg("MeadowEgg")
		assert(meadow, "no Meadow Egg")
		expect(Pets.roll(meadow, 0).rarity).toBe(1)
		expect(Pets.roll(meadow, 0.95).rarity).toBe(3)
		expect(Pets.roll(meadow, 0.999).rarity).toBe(4)
	end)

	it("locks eggs until their stage and prices them from it", function()
		local ember = Pets.egg("EmberEgg")
		assert(ember, "no Ember Egg")
		expect(ember.unlockStage).toBe(31)
		expect(Pets.price(ember)).toBe(Balance.enemyCoins(31) * 400)
	end)
end)

describe("pet bonuses", function()
	local function pet(uid: string, id: string): PetStats.OwnedPet
		return { uid = uid, id = id }
	end

	it("follow rarity", function()
		local def = Pets.get(Pets.EGGS[1].pets[1].petId)
		assert(def, "no pet")
		expect(def.bonus).toBe(0.05)
	end)

	it("add up per kind across equipped pets only", function()
		local training = {}
		for _, def in Pets.List do
			if def.kind == "Training" then
				table.insert(training, def)
			end
		end
		local a, b = training[1], training[2]
		local owned = { pet("u1", a.id), pet("u2", b.id), pet("u3", a.id) }
		local multiplier = PetStats.multiplier(owned, { "u1", "u2" }, "Training")
		expect(multiplier).toBeCloseTo(1 + a.bonus + b.bonus, 6)
		expect(PetStats.multiplier(owned, { "u1", "u2" }, "Damage")).toBe(1)
	end)

	it("never counts more than the slot limit or unknown uids", function()
		local def = Pets.List[1]
		local owned = {}
		local equipped = {}
		for index = 1, Balance.PET_SLOTS + 2 do
			table.insert(owned, pet(`u{index}`, def.id))
			table.insert(equipped, `u{index}`)
		end
		table.insert(equipped, "missing")
		expect(PetStats.multiplier(owned, equipped, def.kind)).toBeCloseTo(
			1 + def.bonus * Balance.PET_SLOTS,
			6
		)
	end)
end)

describe("ore drop chance with pets", function()
	it("scales with the Ores multiplier and stops at the cap", function()
		expect(Balance.oreDropChance(1)).toBe(Balance.ORE_DROP_CHANCE)
		expect(Balance.oreDropChance(1.5)).toBeCloseTo(Balance.ORE_DROP_CHANCE * 1.5, 6)
		expect(Balance.oreDropChance(10)).toBe(Balance.MAX_ORE_DROP_CHANCE)
	end)
end)

describe("equip best", function()
	it("maximizes the selected bonus across unique pets and keeps equipped ties", function()
		local owned = {}
		for i, def in Pets.List do
			table.insert(owned, { uid = tostring(i), id = def.id })
		end
		for _, kind: Pets.PetKind in { "Damage", "Training", "Ores" } :: { Pets.PetKind } do
			local chosen = PetStats.best(owned, {}, kind)
			local bonuses = {}
			for _, def in Pets.List do
				if def.kind == kind then
					table.insert(bonuses, def.bonus)
				end
			end
			table.sort(bonuses, function(a, b)
				return a > b
			end)
			local expected = 1
			for i = 1, math.min(#bonuses, Balance.PET_SLOTS) do
				expected += bonuses[i]
			end
			expect(PetStats.multiplier(owned, chosen, kind)).toBeCloseTo(expected, 6)
			expect(#chosen).toBe(Balance.PET_SLOTS)
		end
		local same = { { uid = "a", id = Pets.List[1].id }, { uid = "z", id = Pets.List[1].id } }
		expect(PetStats.best(same, { "z" }, Pets.List[1].kind)[1]).toBe("z")
	end)
end)
