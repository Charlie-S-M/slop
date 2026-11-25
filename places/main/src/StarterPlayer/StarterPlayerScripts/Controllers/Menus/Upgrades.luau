--!strict

-- Coin upgrades: a scrolling list of cards, each with its current and next effect and a buy button.

const Format = require("@game/ReplicatedStorage/Shared/Format")
const Net = require("@game/ReplicatedStorage/Shared/Net")
const Upgrades = require("@game/ReplicatedStorage/Shared/Upgrades")
const ClientState = require("../ClientState")
const Kit = require("../UI/Kit")
const Menus = require("../Menus")

local UpgradesMenu = {}

const GLYPHS = {
	Bag = "🎒",
	Clover = "🍀",
	Star = "💥",
	Boot = "👟",
	Heart = "❤️",
	Coin = "💰",
	Magnet = "🧲",
	Gear = "⚙️",
}

type Card = { def: Upgrades.UpgradeDef, level: TextLabel, effect: TextLabel, buy: TextButton }

local cards: { Card } = {}
local coinsLabel: TextLabel
local built = false

local function refresh()
	local profile = ClientState.profile
	if not profile or not built then
		return
	end
	coinsLabel.Text = `💰 {Format.abbreviate(profile.coins)}`
	for _, card in cards do
		local level = profile.upgrades[card.def.id] or 0
		card.level.Text = `Lv {level} / {card.def.maxLevel}`
		if level >= card.def.maxLevel then
			card.effect.Text = `{card.def.describe(level)}  (MAX)`
			Kit.setButtonText(card.buy, "MAX")
			Kit.setButtonColor(card.buy, Kit.Colors.Gold, Kit.Colors.GoldDark)
		else
			card.effect.Text = `{card.def.describe(level)}  >>>  {card.def.describe(level + 1)}`
			local cost = Upgrades.cost(card.def, level)
			Kit.setButtonText(card.buy, `💰 {Format.abbreviate(cost)}`)
			if profile.coins >= cost then
				Kit.setButtonColor(card.buy, Kit.Colors.Green, Kit.Colors.GreenDark)
			else
				Kit.setButtonColor(card.buy, Kit.Colors.Grey, Kit.Colors.GreyDark)
			end
		end
	end
end

local function build(content: Frame)
	built = true
	coinsLabel = Kit.text({
		Text = "",
		Size = UDim2.fromScale(0.4, 0.08),
		Position = UDim2.fromScale(1, 0),
		AnchorPoint = Vector2.new(1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Color3.fromRGB(255, 215, 70),
		Stroke = 3,
		Parent = content,
	})
	local list = Kit.new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 0.9),
		Position = UDim2.fromScale(0, 0.1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = content,
	})
	Kit.new(
		"UIListLayout",
		{ Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list }
	)
	Kit.new("UIPadding", {
		PaddingRight = UDim.new(0, 14),
		PaddingLeft = UDim.new(0, 4),
		PaddingTop = UDim.new(0, 4),
		Parent = list,
	})
	for index, def in Upgrades.List do
		local card = Kit.new("Frame", {
			Size = UDim2.new(1, 0, 0, 108),
			BackgroundColor3 = Kit.Colors.Card,
			LayoutOrder = index,
			Parent = list,
		})
		Kit.corner(14).Parent = card
		Kit.stroke(3, Kit.Colors.Ink, Enum.ApplyStrokeMode.Border).Parent = card
		Kit.gradient(Kit.Colors.PanelLight, Kit.Colors.Card).Parent = card
		local icon =
			Kit.iconTile(GLYPHS[def.icon] or "⭐", def.color, UDim2.fromOffset(84, 84), card)
		icon.Position = UDim2.fromOffset(12, 12)
		Kit.text({
			Text = def.name,
			Size = UDim2.new(0.42, 0, 0, 36),
			Position = UDim2.fromOffset(110, 8),
			TextXAlignment = Enum.TextXAlignment.Left,
			Stroke = 3,
			Parent = card,
		})
		Kit.text({
			Text = def.description,
			Size = UDim2.new(0.42, 0, 0, 24),
			Position = UDim2.fromOffset(110, 44),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(200, 205, 225),
			Stroke = 2,
			Parent = card,
		})
		local effect = Kit.text({
			Text = "",
			Size = UDim2.new(0.42, 0, 0, 30),
			Position = UDim2.fromOffset(110, 70),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(130, 255, 120),
			Stroke = 2.5,
			Parent = card,
		})
		local level = Kit.text({
			Text = "",
			Size = UDim2.new(0.26, 0, 0, 30),
			Position = UDim2.new(1, -16, 0, 8),
			AnchorPoint = Vector2.new(1, 0),
			TextXAlignment = Enum.TextXAlignment.Center,
			Stroke = 2.5,
			Parent = card,
		})
		local buy = Kit.button({
			name = "Buy",
			color = Kit.Colors.Green,
			dark = Kit.Colors.GreenDark,
			size = UDim2.new(0.26, 0, 0, 56),
			position = UDim2.new(1, -16, 0, 42),
			anchor = Vector2.new(1, 0),
			text = "",
			parent = card,
			onClick = function()
				Net.event("BuyUpgrade"):FireServer(def.id)
			end,
		})
		table.insert(cards, { def = def, level = level, effect = effect, buy = buy })
	end
	refresh()
end

function UpgradesMenu:Init()
	Menus.register({
		name = "Upgrades",
		title = "Upgrades",
		color = Kit.Colors.Blue,
		size = Vector2.new(0.56, 0.7),
		build = build,
		onOpen = refresh,
	})
end

function UpgradesMenu:Start()
	ClientState.StatsChanged:Connect(function()
		if Menus.isOpen("Upgrades") then
			refresh()
		end
	end)
end

return UpgradesMenu
