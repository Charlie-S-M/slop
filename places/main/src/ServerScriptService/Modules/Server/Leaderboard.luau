--!strict

--[[
	The lobby leaderboard, opened from the board's prompt. Its boards are:
	- Power: the strongest players in this server, by rebirths and then Power.
	- PowerAll: the most Power anyone has ever held, in any server.
	- Robux Spent, Playtime, and Forged: all-time boards kept in ordered data stores. When those
	  can't be reached (a Studio place without API access), they show the players in the server.

	The board part's "Entries" attribute carries every board as JSON for the Leaderboard menu.
	This module also keeps the player list stats (Power and Stage) current.
]]

const DataStoreService = game:GetService("DataStoreService")
const HttpService = game:GetService("HttpService")
const Players = game:GetService("Players")
const RunService = game:GetService("RunService")

const Format = require("@game/ReplicatedStorage/Shared/Format")
const PowerScore = require("@game/ReplicatedStorage/Shared/PowerScore")
const Types = require("@game/ReplicatedStorage/Shared/Types")
const PlayerData = require("./PlayerData")

const REFRESH_SECONDS = 4
-- The first all-time read comes soon after the server starts, then once a minute.
const FIRST_GLOBAL_SECONDS = 8
const GLOBAL_SECONDS = 60
const ROWS = 10

type Entry = { name: string, value: number, rebirths: number? }
type GlobalBoard = {
	key: string,
	read: (Types.Profile) -> number,
	-- Keeps each player's highest value instead of their latest.
	best: boolean?,
}

-- The all-time boards, by the name the menu shows them under.
const GLOBAL_BOARDS: { [string]: GlobalBoard } = {
	PowerAll = {
		key = "Power",
		read = function(profile)
			return PowerScore.encode(profile.power)
		end,
		-- A rebirth empties Power, but not the record.
		best = true,
	},
	Robux = {
		key = "RobuxSpent",
		read = function(profile)
			return profile.robuxSpent
		end,
	},
	Playtime = {
		key = "Playtime",
		read = function(profile)
			return profile.playSeconds
		end,
	},
	Forged = {
		key = "Forged",
		read = function(profile)
			return profile.forges
		end,
	},
}

local Leaderboard = {}

-- The last all-time lists read from the stores; nil until a read works.
local globalLists: { [string]: { Entry } } = {}
local names: { [number]: string } = {}

local function board(): Instance?
	local lobby = workspace:FindFirstChild("Lobby")
	local decor = lobby and lobby:FindFirstChild("Decor")
	return decor and decor:FindFirstChild("Leaderboard")
end

local function ensureStats(player: Player): (StringValue, IntValue)
	local folder: Instance
	local existing = player:FindFirstChild("leaderstats")
	if existing then
		folder = existing
	else
		local created = Instance.new("Folder")
		created.Name = "leaderstats"
		created.Parent = player
		folder = created
	end
	local power = folder:FindFirstChild("Power") :: StringValue?
	if not power then
		local value = Instance.new("StringValue")
		value.Name = "Power"
		value.Parent = folder
		power = value
	end
	local stage = folder:FindFirstChild("Stage") :: IntValue?
	if not stage then
		local value = Instance.new("IntValue")
		value.Name = "Stage"
		value.Parent = folder
		stage = value
	end
	return power :: StringValue, stage :: IntValue
end

local function nameOf(userId: number): string
	local cached = names[userId]
	if cached then
		return cached
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local found = if ok and typeof(name) == "string" then name else `Player {userId}`
	names[userId] = found
	return found
end

-- Writes everyone's all-time stats, then reads back each board's top rows.
local function syncGlobal()
	for label, spec in GLOBAL_BOARDS do
		local ok, store = pcall(function()
			return DataStoreService:GetOrderedDataStore(`Board_{spec.key}`)
		end)
		if not ok or not store then
			continue
		end
		for _, player in Players:GetPlayers() do
			local profile = PlayerData.get(player)
			if profile then
				names[player.UserId] = player.DisplayName
				const value = math.floor(spec.read(profile))
				const key = tostring(player.UserId)
				if not spec.best then
					pcall(function()
						store:SetAsync(key, value)
					end)
				elseif not RunService:IsStudio() then
					-- Studio test profiles stay off the all-time Power record, which never falls.
					pcall(function()
						store:UpdateAsync(key, function(old)
							return if typeof(old) == "number" then math.max(old, value) else value
						end)
					end)
				end
			end
		end
		local read, pages = pcall(function()
			return store:GetSortedAsync(false, ROWS)
		end)
		if read and pages then
			local list: { Entry } = {}
			for _, row in (pages :: DataStorePages):GetCurrentPage() do
				local userId = tonumber(row.key)
				if userId and typeof(row.value) == "number" then
					table.insert(list, { name = nameOf(userId), value = row.value })
				end
			end
			globalLists[label] = list
		end
	end
end

-- A board from the players in this server, for when the all-time list can't be read.
local function serverList(read: (Types.Profile) -> number): { Entry }
	local list: { Entry } = {}
	for _, player in Players:GetPlayers() do
		local profile = PlayerData.get(player)
		if profile then
			table.insert(list, { name = player.DisplayName, value = read(profile) })
		end
	end
	table.sort(list, function(a, b)
		return a.value > b.value
	end)
	while #list > ROWS do
		table.remove(list)
	end
	return list
end

-- The all-time Power record as shown: the stored scores, with anyone here who has since passed
-- theirs (or isn't stored yet) counted at what they hold now.
local function decodedRecord(stored: { Entry }, here: { Entry }): { Entry }
	const scores: { [string]: number } = {}
	for _, entries in { stored, here } do
		for _, entry in entries do
			scores[entry.name] = math.max(entry.value, scores[entry.name] or 0)
		end
	end
	const list: { Entry } = {}
	for name, score in scores do
		table.insert(list, { name = name, value = PowerScore.decode(score) })
	end
	table.sort(list, function(a, b)
		return a.value > b.value
	end)
	while #list > ROWS do
		table.remove(list)
	end
	return list
end

local function refresh()
	local power: { Entry } = {}
	for _, player in Players:GetPlayers() do
		local profile = PlayerData.get(player)
		if profile then
			table.insert(
				power,
				{ name = player.DisplayName, value = profile.power, rebirths = profile.rebirths }
			)
			-- The player list shows display copies; the profile stays the source of truth.
			local shownPower, stage = ensureStats(player)
			shownPower.Value = Format.abbreviate(profile.power)
			stage.Value = profile.bestStage
		end
	end
	table.sort(power, function(a, b)
		if a.rebirths ~= b.rebirths then
			return (a.rebirths or 0) > (b.rebirths or 0)
		end
		return a.value > b.value
	end)
	while #power > ROWS do
		table.remove(power)
	end
	local boards: { [string]: { Entry } } = { Power = power }
	for label, spec in GLOBAL_BOARDS do
		local list = globalLists[label] or serverList(spec.read)
		if label == "PowerAll" then
			list = decodedRecord(list, serverList(spec.read))
		end
		boards[label] = list
	end
	local found = board()
	if found then
		found:SetAttribute("Entries", HttpService:JSONEncode(boards))
	end
end

function Leaderboard:Start()
	-- A lobby baked before the board became a station gets the same setup the builder gives it:
	-- a prompt station, and parts players walk through.
	const found = board()
	if found and found:IsA("BasePart") and found.Parent then
		found:SetAttribute("Station", "Leaderboard")
		for _, part in found.Parent:GetChildren() do
			if
				part:IsA("BasePart")
				and (
					part.Name == "Leaderboard"
					or part.Name == "BoardFrame"
					or part.Name == "BoardLeg"
				)
			then
				part.CanCollide = false
			end
		end
	end
	task.spawn(function()
		while true do
			refresh()
			task.wait(REFRESH_SECONDS)
		end
	end)
	task.spawn(function()
		task.wait(FIRST_GLOBAL_SECONDS)
		while true do
			syncGlobal()
			task.wait(GLOBAL_SECONDS)
		end
	end)
end

return Leaderboard
