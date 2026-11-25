--!strict

-- Top Shooters: the server's strongest players, opened from the lobby leaderboard's prompt. The
-- server keeps the list as JSON in the board's "Entries" attribute.

const HttpService = game:GetService("HttpService")

const Format = require("@game/ReplicatedStorage/Shared/Format")
const Kit = require("../UI/Kit")
const Menus = require("../Menus")

local LeaderboardMenu = {}

const ROWS = 8
const PLACE_COLORS = {
	Color3.fromRGB(255, 215, 70),
	Color3.fromRGB(220, 225, 235),
	Color3.fromRGB(230, 160, 100),
}

type Entry = { name: string, power: number, rebirths: number }
type Row = { frame: Frame, place: TextLabel, name: TextLabel, stats: TextLabel }

local rows: { Row } = {}
local empty: TextLabel
local built = false

local function board(): Instance?
	local lobby = workspace:FindFirstChild("Lobby")
	local decor = lobby and lobby:FindFirstChild("Decor")
	return decor and decor:FindFirstChild("Leaderboard")
end

local function entries(): { Entry }
	local found = board()
	local raw = found and found:GetAttribute("Entries")
	if typeof(raw) ~= "string" then
		return {}
	end
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	return if ok and typeof(decoded) == "table" then decoded :: { Entry } else {}
end

local function refresh()
	if not built then
		return
	end
	local list = entries()
	for index, row in rows do
		local entry = list[index]
		row.frame.Visible = entry ~= nil
		if entry then
			row.name.Text = entry.name
			row.stats.Text =
				`⚡ {Format.abbreviate(entry.power)}   🔄 {Format.abbreviate(entry.rebirths)}`
		end
	end
	empty.Visible = #list == 0
end

local function build(content: Frame)
	built = true
	for index = 1, ROWS do
		local frame = Kit.new("Frame", {
			Name = `Row{index}`,
			BackgroundColor3 = Kit.Colors.Card,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.03, 0.02 + (index - 1) * 0.12),
			Size = UDim2.fromScale(0.94, 0.105),
			Parent = content,
		})
		Kit.corner(10).Parent = frame
		Kit.stroke(2, Kit.Colors.Ink, Enum.ApplyStrokeMode.Border).Parent = frame
		local color = PLACE_COLORS[index] or Kit.Colors.White
		local place = Kit.text({
			Text = `#{index}`,
			TextColor3 = color,
			Position = UDim2.fromScale(0.02, 0.12),
			Size = UDim2.fromScale(0.12, 0.76),
			Parent = frame,
		})
		local name = Kit.text({
			Text = "",
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromScale(0.16, 0.15),
			Size = UDim2.fromScale(0.44, 0.7),
			Parent = frame,
		})
		local stats = Kit.text({
			Text = "",
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.fromScale(0.6, 0.18),
			Size = UDim2.fromScale(0.37, 0.64),
			Stroke = 2,
			Parent = frame,
		})
		table.insert(rows, { frame = frame, place = place, name = name, stats = stats })
	end
	empty = Kit.text({
		Text = "No one's on the board yet!",
		Position = UDim2.fromScale(0.1, 0.42),
		Size = UDim2.fromScale(0.8, 0.12),
		Parent = content,
	})
	refresh()
end

function LeaderboardMenu:Init()
	Menus.register({
		name = "Leaderboard",
		title = "🏆 Top Shooters",
		color = Kit.Colors.Gold,
		size = Vector2.new(0.42, 0.62),
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
