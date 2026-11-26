--!strict

const JestGlobals = require("@game/ServerScriptService/Tests/Packages/JestGlobals")
const describe = JestGlobals.describe
const expect = JestGlobals.expect
const it = JestGlobals.it

const Products = require("@game/ReplicatedStorage/Shared/Products")

-- The experience the products were created in.
const UNIVERSE = 10779068698

describe("products", function()
	it("has an id in the experience for every product and pass, none shared", function()
		local seen: { [number]: string } = {}
		for _, def in Products.List do
			local id = def.ids[UNIVERSE]
			if not Products.PENDING_PASSES[def.key] then
				expect(typeof(id)).toBe("number")
			end
			if id then
				expect(seen[id]).toBe(nil)
				seen[id] = def.key
			end
		end
	end)

	it("finds a product by its kind and id", function()
		local vip = Products.get("VIP")
		assert(vip, "no VIP")
		expect(vip.kind).toBe("pass")
		expect(vip.ids[UNIVERSE]).toBe(2098626200)
	end)
end)
