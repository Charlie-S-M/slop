--!strict

--[[
	The Lucky Wheel's prizes and odds. One free spin a day; more spins are sold in packs. Every spin
	without the exclusive counts toward a pity limit, and the spin that reaches it lands on the
	exclusive gun.
]]

export type Prize = {
	key: string,
	label: string,
	glyph: string,
	-- Chance in percent; the list adds up to 100.
	weight: number,
}

local Wheel = {}

-- In wheel order, clockwise from the top.
Wheel.PRIZES = {
	{ key = "Coins", label = "Coins", glyph = "💰", weight = 40.5 },
	{ key = "LuckPotion", label = "Luck Potion", glyph = "🧪", weight = 14 },
	{ key = "LuckyForge", label = "Lucky Forge", glyph = "🔨", weight = 10 },
	{ key = "Power", label = "Power", glyph = "⚡", weight = 17 },
	{ key = "CoinPotion", label = "2 Coin Potions", glyph = "🪙", weight = 10 },
	{ key = "PowerPotion", label = "2 Power Potions", glyph = "💪", weight = 5 },
	{ key = "Eggs", label = "3 Eggs", glyph = "🥚", weight = 3 },
	{ key = "Exclusive", label = "Jackpot Blaster", glyph = "🎰", weight = 0.5 },
} :: { Prize }

Wheel.EXCLUSIVE = 8
Wheel.EXCLUSIVE_GUN = "JackpotBlaster"
-- The 100th spin since the last exclusive is always the exclusive.
Wheel.PITY = 100
Wheel.FREE_COOLDOWN = 24 * 3600
-- Spin packs by product key.
Wheel.PACKS = { WheelSpin1 = 1, WheelSpin3 = 3, WheelSpin10 = 10 }

-- The prize for a roll in [0, 1), given the spins since the last exclusive.
function Wheel.pick(roll: number, pity: number): number
	if pity >= Wheel.PITY - 1 then
		return Wheel.EXCLUSIVE
	end
	local point = roll * 100
	for index, prize in Wheel.PRIZES do
		point -= prize.weight
		if point < 0 then
			return index
		end
	end
	return #Wheel.PRIZES
end

function Wheel.freeReady(lastFree: number, now: number): boolean
	return now - lastFree >= Wheel.FREE_COOLDOWN
end

return Wheel
