--!strict

const JestGlobals = require("@game/ServerScriptService/Tests/Packages/JestGlobals")
const describe = JestGlobals.describe
const expect = JestGlobals.expect
const it = JestGlobals.it

const Balance = require("@game/ReplicatedStorage/Shared/Balance")

describe("the Auto Perfect recommendation", function()
	it("comes up after every fifth forge", function()
		const due = {}
		for forges = 0, 16 do
			if Balance.recommendsAutoPerfect(forges, false) then
				table.insert(due, forges)
			end
		end
		expect(due).toEqual({ 5, 10, 15 })
	end)

	it("never comes up for someone who owns the pass", function()
		expect(Balance.recommendsAutoPerfect(5, true)).toBe(false)
	end)
end)
