--!strict
const Jest = require("@game/ServerScriptService/Tests/Packages/JestGlobals")
const Balance = require("@game/ReplicatedStorage/Shared/Balance")
const Upgrades = require("@game/ReplicatedStorage/Shared/Upgrades")
Jest.describe("Ruby Exchange economy", function()
	Jest.it("charges for every prepaid day after the two lifetime posts", function()
		for posts = 0, 2 do
			for tier = 1, 11 do
				for days = 1, 7 do
					const fee = Balance.listingFee(posts, tier, days)
					Jest.expect(fee)
						.toBe(if posts < 2 then 0 else math.max(1, tier - 4) * 10 * days)
					Jest.expect(Balance.listingRefund(fee)).toBe(fee / 2)
				end
			end
		end
	end)
	Jest.it("requires the prestige unlock and doubles the drop chance", function()
		Jest.expect(Balance.rubyChance(0, 10)).toBe(0)
		Jest.expect(Balance.rubyChance(1, 0)).toBe(0.0001)
		Jest.expect(Balance.rubyChance(2, 0)).toBe(0.0002)
		Jest.expect(Balance.rubyChance(50, 10)).toBe(1)
	end)
	Jest.it("prices the cash path against stage 200 and 250 payouts", function()
		const def = assert(Upgrades.get("RubyChance"))
		const cost = Upgrades.bulkCost(def, 0, def.maxLevel)
		Jest.expect(math.abs(cost / (Balance.enemyCoins(250) * 8) - 1) < 0.00001).toBe(true)
		Jest.expect(Upgrades.cost(def, 0)).toBe(Balance.enemyCoins(200) * 8)
	end)
	Jest.it("resets expired contracts and caps progress at their goal", function()
		local p = { rubyQuests = { day = -1 } } :: any
		Balance.rubyQuestProgress(p, "bosses", 999)
		Jest.expect(p.rubyQuests.bosses).toBe(Balance.RUBY_QUEST_GOALS.bosses)
		Jest.expect(p.rubyQuests.forges).toBe(0)
	end)
end)
