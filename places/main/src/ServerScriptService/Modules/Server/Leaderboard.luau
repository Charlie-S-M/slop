--!strict

-- Fills the lobby leaderboard with the strongest players in the server, and keeps the player list
-- stats (Power and Stage) current. The board's "Entries" attribute carries the same list as JSON
-- for the Leaderboard menu, which opens from the board's prompt.

const HttpService = game:GetService("HttpService")
const Players = game:GetService("Players")

const Format = require("@game/ReplicatedStorage/Shared/Format")
const PlayerData = require("./PlayerData")

const REFRESH_SECONDS = 4
const ROWS = 8

local Leaderboard = {}

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

local function refresh()
	local entries = {}
	for _, player in Players:GetPlayers() do
		local profile = PlayerData.get(player)
		if profile then
			table.insert(
				entries,
				{ name = player.DisplayName, power = profile.power, rebirths = profile.rebirths }
			)
			-- The player list shows display copies; the profile stays the source of truth.
			local power, stage = ensureStats(player)
			power.Value = Format.abbreviate(profile.power)
			stage.Value = profile.bestStage
		end
	end
	table.sort(entries, function(a, b)
		if a.rebirths ~= b.rebirths then
			return a.rebirths > b.rebirths
		end
		return a.power > b.power
	end)
	local found = board()
	if not found then
		return
	end
	local top = {}
	for row = 1, math.min(ROWS, #entries) do
		top[row] = entries[row]
	end
	found:SetAttribute("Entries", HttpService:JSONEncode(top))
	local gui = found:FindFirstChild("Gui")
	if not gui then
		return
	end
	for row = 1, ROWS do
		local label = gui:FindFirstChild(`Row{row}`) :: TextLabel?
		if label then
			local entry = entries[row]
			label.Text = if entry
				then `{row}. {entry.name}   ⚡ {Format.abbreviate(entry.power)}   🔄 {entry.rebirths}`
				else ""
		end
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
end

return Leaderboard
