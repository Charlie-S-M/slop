--!strict

-- Ordered data stores only sort whole numbers, and Power grows far past what they hold, so the
-- all-time Power board stores each player's Power on a logarithmic scale and reads it back.

const SCALE = 1e12

local PowerScore = {}

function PowerScore.encode(power: number): number
	-- NaN, infinity, and negatives all count as nothing.
	if power ~= power or power == math.huge or power <= 0 then
		return 0
	end
	return math.floor(math.log10(power + 1) * SCALE + 0.5)
end

function PowerScore.decode(score: number): number
	return 10 ^ (score / SCALE) - 1
end

return PowerScore
