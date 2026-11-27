--!strict

--[[
	The lobby's farm animals: where each one walks, from server time, so every client and the server
	agree on where an animal is. A shot animal is knocked off the map and comes back RESPAWN_SECONDS
	later at the spot it was shot, walking its loop from there.

	The server keeps each animal's state in ReplicatedStorage attributes: "AnimalDown<i>" is the
	server time it comes back, and "AnimalShift<i>" the offset (x, z) its loop is walked from.
]]

export type Route = {
	species: string,
	origin: Vector2,
	size: number,
	pace: number,
	phase: number,
}

const ROUTES: { Route } = {
	{ species = "Cow", origin = Vector2.new(30, 80), size = 8.5, pace = 3.1, phase = 3 },
	{ species = "Cow", origin = Vector2.new(42, 92), size = 7, pace = 2.7, phase = 13 },
	{ species = "Pig", origin = Vector2.new(-32, 84), size = 6.3, pace = 3.4, phase = 7 },
	{ species = "Pig", origin = Vector2.new(-42, 67), size = 5.5, pace = 3, phase = 21 },
	{ species = "Chicken", origin = Vector2.new(22, 99), size = 4.7, pace = 4.3, phase = 2 },
	{ species = "Chicken", origin = Vector2.new(34, 104), size = 4.2, pace = 4.6, phase = 18 },
}

const TRAIL = { Vector2.new(-5, -2), Vector2.new(6, -5), Vector2.new(9, 3), Vector2.new(-3, 5) }

local FarmRoutes = {}

FarmRoutes.ROUTES = ROUTES
FarmRoutes.RESPAWN_SECONDS = 10
FarmRoutes.COINS = 1
FarmRoutes.HEIGHT = 2

-- Where an animal walks at server time `now`, before any shift: its spot, bob, and facing.
function FarmRoutes.walk(route: Route, now: number): (Vector2, number, boolean)
	local t = now + route.phase
	local index = math.floor(t / 6) % #TRAIL + 1
	local a, b = TRAIL[index], TRAIL[index % #TRAIL + 1]
	local distance = (b - a).Magnitude
	local progress = math.min((t % 6) * route.pace / distance, 1)
	local bob = if progress < 1 then math.abs(math.sin(t * route.pace * 2)) * 0.34 else 0
	return route.origin + a:Lerp(b, progress), bob, b.X < a.X
end

-- The animal's ground position at `now`, with its shift applied.
function FarmRoutes.position(route: Route, now: number, shift: Vector2?): Vector3
	local spot, bob = FarmRoutes.walk(route, now)
	local at = spot + (shift or Vector2.zero)
	return Vector3.new(at.X, FarmRoutes.HEIGHT, at.Y - bob)
end

-- How far a shift may move a loop from its origin, so animals shot again and again stay on the farm.
const MAX_SHIFT = 12

-- The shift that makes an animal coming back at `respawnAt` start from `spot`.
function FarmRoutes.shiftFor(route: Route, respawnAt: number, spot: Vector2): Vector2
	local walked = FarmRoutes.walk(route, respawnAt)
	local shift = spot - walked
	if shift.Magnitude > MAX_SHIFT then
		shift = shift.Unit * MAX_SHIFT
	end
	return shift
end

return FarmRoutes
