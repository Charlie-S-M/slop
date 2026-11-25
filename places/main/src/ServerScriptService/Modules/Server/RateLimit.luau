--!strict

-- Per-player, per-remote token buckets. Every remote handler asks here first.

const Players = game:GetService("Players")

type Bucket = { tokens: number, last: number }

local RateLimit = {}

local buckets: { [Player]: { [string]: Bucket } } = {}

--[[
	Returns true and spends a token when the player may act. Tokens refill at ratePerSecond up to
	burst, so short bursts pass and sustained spam does not.
]]
function RateLimit.allow(player: Player, key: string, ratePerSecond: number, burst: number): boolean
	local now = os.clock()
	local playerBuckets = buckets[player]
	if not playerBuckets then
		playerBuckets = {}
		buckets[player] = playerBuckets
	end
	local bucket = playerBuckets[key]
	if not bucket then
		bucket = { tokens = burst, last = now }
		playerBuckets[key] = bucket
	end
	bucket.tokens = math.min(burst, bucket.tokens + (now - bucket.last) * ratePerSecond)
	bucket.last = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

function RateLimit:Start()
	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)
end

return RateLimit
