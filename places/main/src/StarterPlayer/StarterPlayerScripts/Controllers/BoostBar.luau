--!strict

--[[
	A row of small icons at the top right, one per boost the player has right now: luck passes,
	potions running, Server Luck, Lucky Forge charges, and the other passes. Hovering an icon (or
	tapping it on a touch screen) shows what it does and how long it has left.
]]

const GuiService = game:GetService("GuiService")
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const UserInputService = game:GetService("UserInputService")

const Format = require("@game/ReplicatedStorage/Shared/Format")
const Products = require("@game/ReplicatedStorage/Shared/Products")
const ClientState = require("./ClientState")
const Hud = require("./Hud")
const Kit = require("./UI/Kit")

local BoostBar = {}

type Boost = { key: string, glyph: string, color: Color3, title: string, detail: string }

-- What each pass shows. Passes not listed here don't get an icon.
const PASSES: { [string]: { glyph: string, detail: string } } = {
	ExtraLuck = { glyph = "🍀", detail = "+25% forge luck" },
	SuperLuck = { glyph = "🌟", detail = "+60% forge luck" },
	VIP = { glyph = "👑", detail = "+25% Power and coins" },
	DoubleCoins = { glyph = "💰", detail = "2× coins from monsters and chests" },
	SpeedBoost = { glyph = "👟", detail = "Walk 50% faster" },
	AutoCollect = { glyph = "🧲", detail = "Ores fly to you" },
	KeepOres = { glyph = "🎒", detail = "Keep your ores when you fall" },
	DoubleBossLoot = { glyph = "👹", detail = "2× boss chest coins" },
}
-- Potions by the boost they run, with what each does.
const POTIONS: { [string]: { glyph: string, title: string, detail: string, color: Color3 } } = {
	Luck = {
		glyph = "🧪",
		title = "Luck Potion",
		detail = "+30% forge luck",
		color = Color3.fromRGB(80, 205, 95),
	},
	Power = {
		glyph = "💪",
		title = "Power Potion",
		detail = "2× training Power",
		color = Color3.fromRGB(240, 85, 70),
	},
	Coins = {
		glyph = "🪙",
		title = "Coin Potion",
		detail = "2× coins",
		color = Color3.fromRGB(255, 196, 60),
	},
}

local bar: Frame
local tooltip: Frame
local tipTitle: TextLabel
local tipDetail: TextLabel
local shown = ""
-- The icon a tap pinned the tip to, on touch screens.
local pinned: string? = nil
-- The icon the mouse last entered; cleared when the icons are rebuilt.
local entered: string? = nil

-- Every boost active right now, in a steady order.
local function activeBoosts(): { Boost }
	local list: { Boost } = {}
	local now = os.time()
	local profile = ClientState.profile
	local serverLuck = ReplicatedStorage:GetAttribute("ServerLuckUntil")
	if typeof(serverLuck) == "number" and serverLuck > now then
		table.insert(list, {
			key = "ServerLuck",
			glyph = "🍀",
			color = Color3.fromRGB(80, 205, 95),
			title = "Server Luck",
			detail = `2× forge luck for everyone · {Format.duration(serverLuck - now)} left`,
		})
	end
	if profile then
		for _, boost in { "Luck", "Power", "Coins" } do
			local ends = profile.boosts[boost] or 0
			local potion = POTIONS[boost]
			if ends > now then
				table.insert(list, {
					key = `Potion{boost}`,
					glyph = potion.glyph,
					color = potion.color,
					title = potion.title,
					detail = `{potion.detail} · {Format.duration(ends - now)} left`,
				})
			end
		end
		if profile.luckyForges > 0 then
			table.insert(list, {
				key = "LuckyForge",
				glyph = "🔨",
				color = Color3.fromRGB(255, 196, 60),
				title = "Lucky Forge",
				detail = `3× luck on your next {profile.luckyForges} forge{if profile.luckyForges
						== 1
					then ""
					else "s"}`,
			})
		end
	end
	for _, def in Products.List do
		local pass = PASSES[def.key]
		if pass and Players.LocalPlayer:GetAttribute(`Pass_{def.key}`) == true then
			table.insert(list, {
				key = def.key,
				glyph = pass.glyph,
				color = def.color,
				title = def.name,
				detail = pass.detail,
			})
		end
	end
	return list
end

local function showTip(boost: Boost?, icon: GuiObject?)
	if not boost or not icon then
		tooltip.Visible = false
		return
	end
	tipTitle.Text = boost.title
	tipDetail.Text = boost.detail
	-- Hangs under the icon, lined up with its right edge. Measured from the bar's own top-right
	-- anchor, so the screen's top inset can't throw it off.
	local fromRight = (bar.AbsolutePosition.X + bar.AbsoluteSize.X)
		- (icon.AbsolutePosition.X + icon.AbsoluteSize.X)
	tooltip.Position = UDim2.new(1, -14 - fromRight, 0, 14 + bar.AbsoluteSize.Y + 6)
	tooltip.Visible = true
end

local function render()
	local list = activeBoosts()
	local keys = {}
	for _, boost in list do
		table.insert(keys, boost.key)
	end
	local signature = table.concat(keys, ",")
	if signature ~= shown then
		shown = signature
		entered = nil
		for _, child in bar:GetChildren() do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
		for order, boost in list do
			local icon = Kit.new("TextButton", {
				Name = boost.key,
				Text = "",
				AutoButtonColor = false,
				BackgroundColor3 = Color3.fromRGB(22, 26, 34),
				BackgroundTransparency = 0.12,
				Size = UDim2.fromOffset(40, 40),
				LayoutOrder = order,
				Parent = bar,
			})
			Kit.corner(10).Parent = icon
			Kit.new("UIStroke", {
				Color = boost.color,
				Thickness = 2,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Parent = icon,
			})
			Kit.text({
				Text = boost.glyph,
				Size = UDim2.fromScale(0.75, 0.75),
				Position = UDim2.fromScale(0.125, 0.125),
				Stroke = 0,
				Gradient = false,
				FontFace = Kit.FONT_BODY,
				Parent = icon,
			})
			icon.MouseEnter:Connect(function()
				entered = boost.key
			end)
			icon.MouseLeave:Connect(function()
				if entered == boost.key then
					entered = nil
				end
			end)
			-- Touch screens have no hover, so a tap pins the tip instead.
			icon.Activated:Connect(function()
				pinned = if pinned == boost.key then nil else boost.key
			end)
		end
	end
	-- What's under the mouse, checked each update: the icons are rebuilt when boosts change, and
	-- a rebuilt icon never hears the mouse arrive.
	local hovered = pinned or entered
	local mouse = UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
	for _, icon in bar:GetChildren() do
		if icon:IsA("TextButton") then
			local corner, size = icon.AbsolutePosition, icon.AbsoluteSize
			if
				mouse.X >= corner.X
				and mouse.X <= corner.X + size.X
				and mouse.Y >= corner.Y
				and mouse.Y <= corner.Y + size.Y
			then
				hovered = icon.Name
			end
		end
	end
	local current: Boost? = nil
	for _, boost in list do
		if boost.key == hovered then
			current = boost
		end
	end
	showTip(current, if current then bar:FindFirstChild(current.key) :: GuiObject? else nil)
end

function BoostBar:Start()
	bar = Kit.new("Frame", {
		Name = "BoostBar",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 14),
		Size = UDim2.fromOffset(400, 40),
		BackgroundTransparency = 1,
		Parent = Hud.screen(),
	})
	Kit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = bar,
	})
	tooltip = Kit.new("Frame", {
		Name = "Tip",
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(240, 58),
		BackgroundColor3 = Color3.fromRGB(22, 26, 34),
		BackgroundTransparency = 0.05,
		Visible = false,
		ZIndex = 20,
		Parent = bar.Parent,
	})
	Kit.corner(10).Parent = tooltip
	Kit.new("UIStroke", {
		Color = Color3.fromRGB(70, 150, 220),
		Thickness = 2,
		Transparency = 0.35,
		Parent = tooltip,
	})
	tipTitle = Kit.text({
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromScale(0.05, 0.08),
		Size = UDim2.fromScale(0.9, 0.42),
		Stroke = 2,
		ZIndex = 21,
		Parent = tooltip,
	})
	tipDetail = Kit.text({
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(190, 205, 225),
		Position = UDim2.fromScale(0.05, 0.52),
		Size = UDim2.fromScale(0.9, 0.38),
		Stroke = 1.5,
		Gradient = false,
		ZIndex = 21,
		Parent = tooltip,
	})
	task.spawn(function()
		while true do
			render()
			task.wait(0.1)
		end
	end)
end

return BoostBar
