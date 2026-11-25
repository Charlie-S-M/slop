--!strict

--[[
	The rules for a gun's three stats and its grade: scoring timing-game strikes, turning them into a
	grade, applying the grade to Power and Speed, Training Power from the ores used, and filling in
	stats for guns saved before they existed. The server's results count; the client runs the same
	rules to preview and grade strikes.
]]

const Balance = require("./Balance")
const Guns = require("./Guns")
const Ores = require("./Ores")
const Types = require("./Types")

type Grade = Types.Grade

local GunStats = {}

-- Accuracy for one strike, from how far the click landed from the ring's end (share of RING_SECONDS).
function GunStats.strikeAccuracy(errorFraction: number): number
	local distance = math.abs(errorFraction)
	if distance ~= distance then
		return 0
	end
	for _, window in Balance.STRIKE_WINDOWS do
		if distance <= window.within then
			return window.accuracy
		end
	end
	return 0
end

-- The label shown for a strike's accuracy: PERFECT, GREAT, GOOD, or MISS.
function GunStats.strikeLabel(accuracy: number): string
	for _, window in Balance.STRIKE_WINDOWS do
		if accuracy >= window.accuracy then
			return window.label
		end
	end
	return "MISS"
end

--[[
	The grade for a forge's strikes. Only the first STRIKES entries count; anything that isn't a
	finite number is a miss, and every value is clamped to 0..1, so a hostile client can't push past S.
]]
function GunStats.gradeFor(accuracies: { any }): Grade
	local total = 0
	for index = 1, Balance.STRIKES do
		local value = accuracies[index]
		if
			typeof(value) == "number"
			and value == value
			and value > -math.huge
			and value < math.huge
		then
			total += math.clamp(value, 0, 1)
		end
	end
	local average = total / Balance.STRIKES
	for _, threshold in Balance.GRADE_THRESHOLDS do
		if average >= threshold.minimum then
			return threshold.grade :: Grade
		end
	end
	return "D"
end

-- How much rarer ores raise Training Power: 1 for Common ores, growing per tier of their average.
function GunStats.oreTrainingFactor(ores: { Ores.OreDef }): number
	if #ores == 0 then
		return 1
	end
	local total = 0
	for _, ore in ores do
		total += ore.rarity
	end
	return Balance.ORE_TRAINING_GROWTH ^ (total / #ores - 1)
end

-- Final Power and Speed once the grade is known. Power stays a whole number of at least 1.
function GunStats.finalize(basePower: number, grade: Grade, speedRoll: number): (number, number)
	local multipliers = Balance.GRADE_MULTIPLIERS[grade] or Balance.GRADE_MULTIPLIERS.D
	local power = math.max(1, math.floor(basePower * multipliers.power + 0.5))
	return power, multipliers.speed * speedRoll
end

-- Shots per second for a gun kind at a Speed.
function GunStats.fireRate(kind: Guns.GunKind, speed: number): number
	return Guns.kindStats(kind).fireRate * speed
end

--[[
	Fills in Speed, Training Power, and grade for a gun saved before they existed. Training Power
	uses the gun's rarity as the ore tier, so no old gun trains slower than it did. The starter
	pistol keeps exactly +1 per shot.
]]
function GunStats.migrateGun(item: { [string]: any }): Types.GunItem
	local power = if typeof(item.power) == "number" then item.power else 1
	local train = item.train
	if typeof(train) ~= "number" then
		local def = if typeof(item.id) == "string" then Guns.get(item.id) else nil
		local rarity = if def then def.rarity else 1
		train = if item.id == Guns.STARTER_ID
			then power
			else power * Balance.ORE_TRAINING_GROWTH ^ (rarity - 1)
	end
	local grade = item.grade
	if typeof(grade) ~= "string" or Balance.GRADE_MULTIPLIERS[grade] == nil then
		grade = "B"
	end
	return {
		uid = item.uid,
		id = item.id,
		power = power,
		speed = if typeof(item.speed) == "number" then item.speed else 1,
		train = train,
		grade = grade,
		locked = item.locked,
	}
end

return GunStats
