--!strict

-- The prestige shop, opened at the violet stall in the lobby's south-west corner. Locked until the
-- first prestige; after that, each card spends prestige tokens on its next level.

const Format = require("@game/ReplicatedStorage/Shared/Format")
const Net = require("@game/ReplicatedStorage/Shared/Net")
const PrestigeShop = require("@game/ReplicatedStorage/Shared/PrestigeShop")
const ClientState = require("../ClientState")
const Kit = require("../UI/Kit")
const Menus = require("../Menus")

local PrestigeShopMenu = {}

const VIOLET = Color3.fromRGB(150, 90, 230)
const VIOLET_DARK = Color3.fromRGB(95, 55, 160)

type Card = { def: PrestigeShop.ItemDef, level: TextLabel, effect: TextLabel, buy: TextButton }

local cards: { Card } = {}
local tokensLabel: TextLabel
local lockNote: TextLabel
local list: ScrollingFrame
local built = false

-- What the card's effect line says at a level.
local function effectAt(def: PrestigeShop.ItemDef, level: number): string
	if def.once then
		return if level >= 1 then "Owned" else "Not owned"
	end
	if level == 0 then
		return "×1"
	end
	return `×{Format.abbreviate(2 ^ level)}`
end

local function refresh()
	local profile = ClientState.profile
	if not profile or not built then
		return
	end
	const locked = profile.prestige < 1
	lockNote.Visible = locked
	list.Visible = not locked
	tokensLabel.Text = `⭐ {Format.commas(profile.prestigeTokens)} token{if profile.prestigeTokens
			== 1
		then ""
		else "s"}`
	for _, card in cards do
		local level = PrestigeShop.level(profile.prestigeShop, card.def.id)
		local cost = PrestigeShop.cost(card.def, level)
		card.level.Text = if card.def.once then "" else `Lv {level}`
		if not cost then
			card.effect.Text = effectAt(card.def, level)
			Kit.setButtonText(card.buy, "OWNED")
			Kit.setButtonColor(card.buy, Kit.Colors.Gold, Kit.Colors.GoldDark)
			continue
		end
		card.effect.Text = if card.def.once
			then card.def.detail
			else `{effectAt(card.def, level)}  >>>  {effectAt(card.def, level + 1)}`
		Kit.setButtonText(card.buy, `⭐ {Format.commas(cost)}`)
		if profile.prestigeTokens >= cost then
			Kit.setButtonColor(card.buy, Kit.Colors.Green, Kit.Colors.GreenDark)
		else
			Kit.setButtonColor(card.buy, Kit.Colors.Grey, Kit.Colors.GreyDark)
		end
	end
end

local function build(content: Frame)
	built = true
	tokensLabel = Kit.text({
		Text = "",
		Size = UDim2.fromScale(0.5, 0.08),
		Position = UDim2.fromScale(1, 0),
		AnchorPoint = Vector2.new(1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Color3.fromRGB(255, 215, 80),
		Stroke = 3,
		Parent = content,
	})
	Kit.text({
		Text = "Each prestige gives a token. 2x items stack: every level doubles again.",
		Size = UDim2.fromScale(0.5, 0.08),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(200, 190, 235),
		Stroke = 1.5,
		Gradient = false,
		Parent = content,
	})
	lockNote = Kit.text({
		Text = "🔒 Prestige once to open the Prestige Shop.\nPrestige unlocks at 15 rebirths.",
		Size = UDim2.fromScale(0.8, 0.3),
		Position = UDim2.fromScale(0.1, 0.35),
		Stroke = 3,
		Parent = content,
	})
	list = Kit.new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 0.9),
		Position = UDim2.fromScale(0, 0.1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = content,
	}) :: ScrollingFrame
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
	for index, def in PrestigeShop.ITEMS do
		local card = Kit.new("Frame", {
			Size = UDim2.new(1, 0, 0, 100),
			BackgroundColor3 = Kit.Colors.Card,
			LayoutOrder = index,
			Parent = list,
		})
		Kit.corner(14).Parent = card
		Kit.stroke(3, Kit.Colors.Ink, Enum.ApplyStrokeMode.Border).Parent = card
		Kit.gradient(VIOLET:Lerp(Kit.Colors.Card, 0.7), Kit.Colors.Card).Parent = card
		local icon = Kit.iconTile(def.glyph, VIOLET, UDim2.fromOffset(76, 76), card)
		icon.Position = UDim2.fromOffset(12, 12)
		Kit.text({
			Text = def.name,
			Size = UDim2.new(0.42, 0, 0, 34),
			Position = UDim2.fromOffset(102, 8),
			TextXAlignment = Enum.TextXAlignment.Left,
			Stroke = 3,
			Parent = card,
		})
		local effect = Kit.text({
			Text = "",
			Size = UDim2.new(0.42, 0, 0, 24),
			Position = UDim2.fromOffset(102, 44),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(130, 255, 120),
			Stroke = 2.5,
			Parent = card,
		})
		if not def.once then
			Kit.text({
				Text = def.detail,
				Size = UDim2.new(0.42, 0, 0, 22),
				Position = UDim2.fromOffset(102, 70),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Color3.fromRGB(200, 205, 225),
				Stroke = 1.5,
				Gradient = false,
				Parent = card,
			})
		end
		local level = Kit.text({
			Text = "",
			Size = UDim2.new(0.26, 0, 0, 28),
			Position = UDim2.new(1, -16, 0, 6),
			AnchorPoint = Vector2.new(1, 0),
			Stroke = 2.5,
			Parent = card,
		})
		local buy = Kit.button({
			name = "Buy",
			color = Kit.Colors.Green,
			dark = Kit.Colors.GreenDark,
			size = UDim2.new(0.26, 0, 0, 52),
			position = UDim2.new(1, -16, 0, 38),
			anchor = Vector2.new(1, 0),
			text = "",
			parent = card,
			onClick = function()
				Net.event("BuyPrestige"):FireServer(def.id)
			end,
		})
		table.insert(cards, { def = def, level = level, effect = effect, buy = buy })
	end
	refresh()
end

function PrestigeShopMenu:Init()
	Menus.register({
		name = "PrestigeShop",
		title = "⭐ Prestige Shop",
		color = VIOLET_DARK,
		size = Vector2.new(0.56, 0.7),
		build = build,
		onOpen = refresh,
	})
end

function PrestigeShopMenu:Start()
	ClientState.ProfileChanged:Connect(function()
		if Menus.isOpen("PrestigeShop") then
			refresh()
		end
	end)
end

return PrestigeShopMenu
