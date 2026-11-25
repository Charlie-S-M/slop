--!strict

const JestGlobals = require("@game/ServerScriptService/Tests/Packages/JestGlobals")
const describe = JestGlobals.describe
const expect = JestGlobals.expect
const it = JestGlobals.it

const Armor = require("@game/ReplicatedStorage/Shared/Armor")
const Guns = require("@game/ReplicatedStorage/Shared/Guns")
const Pets = require("@game/ReplicatedStorage/Shared/Pets")
const PixelSprites = require("@game/ReplicatedStorage/Shared/PixelSprites")

describe("pixel sprites", function()
	it("are all 16 by 16 and use only known colors", function()
		for name, rows in PixelSprites.SPRITES do
			expect(#rows).toBe(16)
			for _, row in rows do
				expect(#row).toBe(16)
				expect(string.find(row, "[^%.kbatw]")).toBeNil()
			end
			expect(name ~= "").toBe(true)
		end
	end)

	it("have a sprite for every gun kind, armor slot, and pet style", function()
		for _, def in Guns.List do
			expect(PixelSprites.SPRITES[PixelSprites.forGun(def.kind)]).toBeDefined()
		end
		for _, slot in Armor.SLOTS do
			expect(PixelSprites.SPRITES[PixelSprites.forArmor(slot)]).toBeDefined()
		end
		for _, def in Pets.List do
			expect(PixelSprites.SPRITES[PixelSprites.forPet(def.style)]).toBeDefined()
		end
	end)

	it("merge each row into runs of one color", function()
		local runs = PixelSprites.runs({
			"..kkbb..........",
			table.unpack(table.create(15, "................")),
		})
		expect(#runs).toBe(2)
		expect(runs[1].x).toBe(2)
		expect(runs[1].width).toBe(2)
		expect(runs[1].key).toBe("k")
		expect(runs[2].key).toBe("b")
	end)
end)
