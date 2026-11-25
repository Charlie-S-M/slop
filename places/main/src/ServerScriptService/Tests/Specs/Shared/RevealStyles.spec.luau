--!strict

const JestGlobals = require("@game/ServerScriptService/Tests/Packages/JestGlobals")
const describe = JestGlobals.describe
const expect = JestGlobals.expect
const it = JestGlobals.it

const RevealStyles = require("@game/ReplicatedStorage/Shared/RevealStyles")

describe("reveal impact frames", function()
	it("skip everything below Legendary", function()
		for tier = 1, 4 do
			expect(RevealStyles.forRarity(tier)).toBeNil()
		end
	end)

	it("give each top tier its own sequence", function()
		local kinds = {}
		for tier = 5, 8 do
			local style = RevealStyles.forRarity(tier)
			assert(style, `no style for tier {tier}`)
			table.insert(kinds, style.kind)
			expect(style.seconds >= 0.6 and style.seconds <= 2.5).toBe(true)
		end
		expect(table.concat(kinds, ",")).toBe("Ember,Implode,Prism,Radiant")
	end)

	it("leave a halo behind only for Godly and Eternal", function()
		expect((RevealStyles.forRarity(5) :: any).halo).toBe(false)
		expect((RevealStyles.forRarity(6) :: any).halo).toBe(false)
		expect((RevealStyles.forRarity(7) :: any).halo).toBe(true)
		expect((RevealStyles.forRarity(8) :: any).halo).toBe(true)
	end)
end)
