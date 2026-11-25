--!strict

-- Fills the lobby leaderboard with the strongest players in the server, and keeps the player list
-- stats (Power and Stage) current.

const Players = game:GetService("Players")

const Format = require("@game/ReplicatedStorage/Shared/Format")
const PlayerData = require("./PlayerData")

const REFRESH_SECONDS = 4
const ROWS = 8

local Leaderboard = {}

local function boardGui(): Instance?
	local lobby = workspace:FindFirstChild("Lobby")
	local decor = lobby and lobby:FindFirstChild("Decor")
	local board = decor and decor:FindFirstChild("Leaderboard")
	return board and board:FindFirstChild("Gui")
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
	local gui = boardGui()
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
	task.spawn(function()
		while true do
			refresh()
			task.wait(REFRESH_SECONDS)
		end
	end)
end

return Leaderboard
