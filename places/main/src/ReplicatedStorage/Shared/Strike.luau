--!strict

-- Whether a mob's swing reaches a player, judged along the whole stretch the player covered since
-- the last check, so running past doesn't slip between two checks. Heights are ignored.

-- A longer stretch than this is a teleport, and only where the player landed counts.
const MAX_SWEEP = 20

local Strike = {}

function Strike.reaches(mob: Vector3, from: Vector3, to: Vector3, range: number): boolean
	const flat = Vector3.new(1, 0, 1)
	const finish = to * flat
	local start = from * flat
	if (finish - start).Magnitude > MAX_SWEEP then
		start = finish
	end
	const path = finish - start
	const length = path:Dot(path)
	const along = if length > 0
		then math.clamp((mob * flat - start):Dot(path) / length, 0, 1)
		else 0
	return (mob * flat - (start + path * along)).Magnitude <= range
end

return Strike
