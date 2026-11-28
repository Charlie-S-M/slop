--!strict

const JestGlobals = require("@game/ServerScriptService/Tests/Packages/JestGlobals")
const describe = JestGlobals.describe
const expect = JestGlobals.expect
const it = JestGlobals.it

const Balance = require("@game/ReplicatedStorage/Shared/Balance")
const Guns = require("@game/ReplicatedStorage/Shared/Guns")

-- Damage a second for one point of Power, as the HUD would count it.
local function dps(def: Guns.GunDef): number
	local stats = Guns.kindStats(def.kind)
	return Balance.pelletDamage(1, 0, def.kind, 0, 1, def.id) * stats.pellets * stats.fireRate
end

describe("gun focus", function()
	it(
		"gives every tier from Legendary up one Damage, one Training, and one FireRate gun",
		function()
			for tier = 5, 11 do
				local seen: { [string]: number } = {}
				for _, def in Guns.pool(tier) do
					local focus = def.focus or "none"
					seen[focus] = (seen[focus] or 0) + 1
				end
				expect(seen.Damage).toBe(1)
				expect(seen.Training).toBe(1)
				expect(seen.FireRate).toBe(1)
			end
		end
	)

	it("matches a FireRate gun's damage per second to its tier's Damage gun", function()
		for tier = 5, 11 do
			local damage, fast
			for _, def in Guns.pool(tier) do
				if def.focus == "Damage" then
					damage = def
				elseif def.focus == "FireRate" then
					fast = def
				end
			end
			assert(damage and fast, `tier {tier} is missing a focus`)
			-- Per-gun tuning nudges stay small, so the two land within a few percent.
			expect(math.abs(dps(fast) / dps(damage) - 1) < 0.1).toBe(true)
			local stats = Guns.kindStats
			expect(stats(fast.kind).fireRate > stats(damage.kind).fireRate).toBe(true)
		end
	end)

	it("trains Training guns faster and leaves the rest alone", function()
		expect(Balance.focusTraining("GildedHandcannon")).toBe(Balance.FOCUS_TRAINING)
		expect(Balance.focusTraining("TitanHowitzer")).toBe(1)
		expect(Balance.focusTraining("PopPistol")).toBe(1)
	end)
end)
