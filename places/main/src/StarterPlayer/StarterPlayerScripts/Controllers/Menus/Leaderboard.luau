--!strict

-- Top Shooters, opened from the lobby leaderboard's prompt: four boards behind tabs (Power in
-- this server; Robux spent, playtime, and items forged all-time). The server keeps every board as
-- JSON in the board part's "Entries" attribute.

const HttpService = game:GetService("HttpService")

const Format = require("@game/ReplicatedStorage/Shared/Format")
const Kit = require("../UI/Kit")
const Menus = require("../Menus")

local LeaderboardMenu = {}

const ROWS = 10
const PLACE_COLORS = {
	Color3.fromRGB(255, 215, 70),
	Color3.fromRGB(220, 225, 235),
	Color3.fromRGB(230, 160, 100),
}

type Entry = { name: string, value: number, rebirths: number? }
type Row = { frame: Frame, name: TextLabel, stats: TextLabel }
type Tab = { key: string, label: string, color: Color3, show: (Entry) -> string }

const TABS: { Tab } = {
	{
		key = "Power",
		label = "⚡ Power",
		color = Kit.Colors.Gold,
		show = function(entry)
			return `⚡ {Format.abbreviate(entry.value)}   🔄 {Format.abbreviate(
				entry.rebirths or 0
			)}`
		end,
	},
	{
		key = "Robux",
		label = "💸 Robux Spent",
		color = Kit.Colors.Green,
		show = function(entry)
			return `R$ {Format.commas(entry.value)}`
		end,
	},
	{
		key = "Playtime",
		label = "⏱️ Playtime",
		color = Kit.Colors.Blue,
		show = function(entry)
			return Format.duration(entry.value)
		end,
	},
	{
		key = "Forged",
		label = "🔨 Forged",
		color = Kit.Colors.Orange,
		show = function(entry)
			return `{Format.commas(entry.value)} forged`
		end,
	},
}

local rows: { Row } = {}
local tabButtons: { [string]: TextButton } = {}
local empty: TextLabel
local note: TextLabel
local current = "Power"
local built = false

local function board(): Instance?
	local lobby = workspace:FindFirstChild("Lobby")
	local decor = lobby and lobby:FindFirstChild("Decor")
	return decor and decor:FindFirstChild("Leaderboard")
end

local function boards(): { [string]: { Entry } }
	local found = board()
	local raw = found and found:GetAttribute("Entries")
	if typeof(raw) ~= "string" then
		return {}
	end
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	return if ok and typeof(decoded) == "table" then decoded :: { [string]: { Entry } } else {}
end

local function refresh()
	if not built then
		return
	end
	local tab = TABS[1]
	for _, candidate in TABS do
		if candidate.key == current then
			tab = candidate
		end
		local button = tabButtons[candidate.key]
		if candidate.key == current then
			Kit.setButtonColor(button, candidate.color, candidate.color:Lerp(Color3.new(), 0.35))
		else
			Kit.setButtonColor(button, Kit.Colors.Grey, Kit.Colors.GreyDark)
		end
	end
	local list = boards()[current] or {}
	for index, row in rows do
		local entry = list[index]
		row.frame.Visible = entry ~= nil
		if entry then
			row.name.Text = entry.name
			row.stats.Text = tab.show(entry)
		end
	end
	empty.Visible = #list == 0
	note.Text = if current == "Power" then "Players in this server" else "All-time, every server"
end

local function build(content: Frame)
	built = true
	for index, tab in TABS do
		tabButtons[tab.key] = Kit.button({
			name = tab.key,
			color = Kit.Colors.Grey,
			dark = Kit.Colors.GreyDark,
			size = UDim2.fromScale(0.23, 0.085),
			position = UDim2.fromScale(0.02 + (index - 1) * 0.245, 0.005),
			text = tab.label,
			parent = content,
			onClick = function()
				current = tab.key
				refresh()
			end,
		})
	end
	note = Kit.text({
		Text = "",
		Size = UDim2.fromScale(0.6, 0.04),
		Position = UDim2.fromScale(0.2, 0.1),
		TextColor3 = Color3.fromRGB(190, 205, 225),
		Stroke = 1.5,
		Gradient = false,
		Parent = content,
	})
	for index = 1, ROWS do
		local frame = Kit.new("Frame", {
			Name = `Row{index}`,
			BackgroundColor3 = Kit.Colors.Card,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.03, 0.15 + (index - 1) * 0.085),
			Size = UDim2.fromScale(0.94, 0.075),
			Parent = content,
		})
		Kit.corner(10).Parent = frame
		Kit.stroke(2, Kit.Colors.Ink, Enum.ApplyStrokeMode.Border).Parent = frame
		local color = PLACE_COLORS[index] or Kit.Colors.White
		Kit.text({
			Text = `#{index}`,
			TextColor3 = color,
			Position = UDim2.fromScale(0.02, 0.12),
			Size = UDim2.fromScale(0.1, 0.76),
			Parent = frame,
		})
		local name = Kit.text({
			Text = "",
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromScale(0.14, 0.15),
			Size = UDim2.fromScale(0.46, 0.7),
			Parent = frame,
		})
		local stats = Kit.text({
			Text = "",
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.fromScale(0.58, 0.18),
			Size = UDim2.fromScale(0.39, 0.64),
			Stroke = 2,
			Parent = frame,
		})
		table.insert(rows, { frame = frame, name = name, stats = stats })
	end
	empty = Kit.text({
		Text = "No one's on this board yet!",
		Position = UDim2.fromScale(0.1, 0.45),
		Size = UDim2.fromScale(0.8, 0.1),
		Parent = content,
	})
	refresh()
end

function LeaderboardMenu:Init()
	Menus.register({
		name = "Leaderboard",
		title = "🏆 Top Shooters",
		color = Kit.Colors.Gold,
		size = Vector2.new(0.5, 0.72),
		build = build,
		onOpen = refresh,
	})
end

function LeaderboardMenu:Start()
	task.spawn(function()
		local found = board()
		while not found do
			task.wait(1)
			found = board()
		end
		-- The loop above leaves it set; the type checker cannot see that through the loop.
		(found :: Instance):GetAttributeChangedSignal("Entries"):Connect(function()
			if Menus.isOpen("Leaderboard") then
				refresh()
			end
		end)
	end)
end

return LeaderboardMenu
