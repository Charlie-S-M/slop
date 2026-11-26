--!strict

const JestGlobals = require("@game/ServerScriptService/Tests/Packages/JestGlobals")
const describe = JestGlobals.describe
const expect = JestGlobals.expect
const it = JestGlobals.it

const Armor = require("@game/ReplicatedStorage/Shared/Armor")
const ArmorStats = require("@game/ReplicatedStorage/Shared/ArmorStats")
const Balance = require("@game/ReplicatedStorage/Shared/Balance")
const Types = require("@game/ReplicatedStorage/Shared/Types")

local function piece(id: string, defense: number): Types.ArmorItem
	return { uid = id, id = id, defense = defense, grade = "B" }
end

describe("the armor catalog", function()
	it("has one piece per slot for every rarity", function()
		expect(#Armor.List).toBe(33)
		expect(Armor.forSlot("Chestplate", 5).id).toBe("SunforgedChestplate")
		expect(Armor.forSlot("Helmet", 8).name).toBe("Dawnlight Helmet")
		expect(Armor.get("ScrapBoots") and (Armor.get("ScrapBoots") :: any).slot).toBe("Boots")
	end)
end)

describe("a finished armor forge", function()
	it("becomes an unlocked piece with its rolled defense", function()
		local def = Armor.forSlot("Boots", 3)
		local item = ArmorStats.makeItem("u7", def, "A", 1)
		expect(item.uid).toBe("u7")
		expect(item.id).toBe("SteelguardBoots")
		expect(item.grade).toBe("A")
		expect(item.locked).toBe(false)
		expect(item.defense).toBeCloseTo(0.2 * 0.19 * 1.05, 4)
	end)
end)

describe("armor defense", function()
	it("comes from slot share, rarity, grade, and roll", function()
		local def = Armor.forSlot("Chestplate", 5)
		expect(ArmorStats.roll(def, "B", 1)).toBeCloseTo(0.5 * 0.34, 6)
		expect(ArmorStats.roll(def, "S", 1)).toBeCloseTo(0.5 * 0.34 * 1.15, 6)
	end)

	it("adds up the equipped pieces only", function()
		local armor = {
			piece("SunforgedChestplate", 0.17),
			piece("SunforgedHelmet", 0.1),
			piece("ScrapBoots", 0.02),
		}
		local blocked = ArmorStats.blocked(
			armor,
			{ Chestplate = "SunforgedChestplate", Helmet = "SunforgedHelmet" }
		)
		expect(blocked).toBeCloseTo(0.27, 6)
	end)

	it("keeps the best possible set at or under the cap", function()
		local armor = {}
		local equipped = {}
		for _, slot: Types.ArmorSlot in Armor.SLOTS do
			local def = Armor.forSlot(slot, 8)
			table.insert(armor, piece(def.id, ArmorStats.roll(def, "S", Balance.ARMOR_ROLL_MAX)))
			equipped[slot] = def.id
		end
		expect(ArmorStats.blocked(armor, equipped) <= Balance.ARMOR_MAX_BLOCK).toBe(true)
	end)

	it("never blocks more than the cap", function()
		local armor = { piece("DawnlightChestplate", 0.5), piece("DawnlightHelmet", 0.4) }
		local equipped = { Chestplate = "DawnlightChestplate", Helmet = "DawnlightHelmet" }
		expect(ArmorStats.blocked(armor, equipped)).toBe(Balance.ARMOR_MAX_BLOCK)
	end)

	it("never sells for more than the ores it was forged from", function()
		for _, worth in { 10, 1000, 1e9 } do
			local price = Balance.armorSellPrice(worth)
			expect(price < worth).toBe(true)
			expect(price > 0).toBe(true)
		end
		expect(Balance.armorSellPrice(0)).toBe(1)
	end)

	it("ignores equipped uids it can't find and pieces in the wrong slot", function()
		local armor = { piece("SunforgedHelmet", 0.1) }
		expect(ArmorStats.blocked(armor, { Chestplate = "SunforgedHelmet", Boots = "missing" })).toBe(
			0
		)
	end)
end)
