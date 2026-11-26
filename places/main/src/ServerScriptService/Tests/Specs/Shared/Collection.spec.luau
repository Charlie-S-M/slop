--!strict
local Jest = require("@game/ServerScriptService/Tests/Packages/JestGlobals")
local Balance = require("@game/ReplicatedStorage/Shared/Balance")
local Guns = require("@game/ReplicatedStorage/Shared/Guns")
local Ores = require("@game/ReplicatedStorage/Shared/Ores")
Jest.it(
	"indexes twenty-eight forgeable guns, seven evolutions, and the limited shop and wheel guns",
	function()
		Jest.expect(#Guns.List).toBe(35 + #Guns.LIMITED)
		Jest.expect(#Guns.LIMITED).toBe(3)
		for tier, expected in { 5, 4, 3, 3, 3, 1, 1, 2, 2, 2, 2 } do
			Jest.expect(#Guns.pool(tier)).toBe(expected)
		end
		Jest.expect(Guns.get("Infinipew") ~= nil).toBe(true)
	end
)
Jest.it("scales existing shot damage once, including spread pellets", function()
	local tiers = { 1, 2, 3, 10, 25, 100, 500, 2000, 6000, 18000, 54000 }
	for _, def in Guns.List do
		local baseline = Balance.shotDamage(7, 13, def.kind, 2, 3)
		local actual = Balance.shotDamage(7, 13, def.kind, 2, 3, def.id)
		local expected = tiers[def.rarity] * (Balance.GUN_DAMAGE_TUNING[def.id] or 1)
		Jest.expect(math.abs(actual / baseline - expected) < 1e-7).toBe(true)
	end
end)
Jest.it("requires high-tier ore to roll Godly and rewards the top ore", function()
	local function chance(id: string): number
		return Balance.forgeOdds({ assert(Ores.get(id)) }, 0).chances[7]
	end
	Jest.expect(chance("Pebble")).toBe(0)
	Jest.expect(chance("Infernium") > 0).toBe(true)
	Jest.expect(chance("Singularity") > chance("Infernium")).toBe(true)
end)
