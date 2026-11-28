--!strict

const JestGlobals = require("@game/ServerScriptService/Tests/Packages/JestGlobals")
const describe = JestGlobals.describe
const expect = JestGlobals.expect
const it = JestGlobals.it

const Rarity = require("@game/ReplicatedStorage/Shared/Rarity")
const ShotStyles = require("@game/ReplicatedStorage/Shared/ShotStyles")

describe("shot styles", function()
	it("keeps the basic look below Legendary", function()
		for tier = 1, 4 do
			expect(ShotStyles.forRarity(tier).name).toBe("Basic")
		end
	end)

	it("gives each top tier its own style", function()
		expect(ShotStyles.forRarity(5).name).toBe("Legendary")
		expect(ShotStyles.forRarity(6).name).toBe("Mythic")
		expect(ShotStyles.forRarity(7).name).toBe("Godly")
		expect(ShotStyles.forRarity(8).name).toBe("Eternal")
	end)

	it("caps the extra parts a shot makes", function()
		for tier = 1, Rarity.Count do
			expect(ShotStyles.forRarity(tier).extraParts <= 6).toBe(true)
		end
	end)

	it("clamps tiers out of range", function()
		expect(ShotStyles.forRarity(0).name).toBe("Basic")
		expect(ShotStyles.forRarity(99).name).toBe("Eternal")
	end)
end)
