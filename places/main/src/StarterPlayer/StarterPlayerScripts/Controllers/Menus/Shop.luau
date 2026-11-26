--!strict

--[[
	The Robux shop, opened at the shop stall south of the forge. Section tabs on the left jump to
	each section of one long scrolling page: Featured (the starter pack and limited guns), Server
	Luck, Passes, Power, Coins, Eggs, and Potions. Potions you own are used from their cards.

	Standing near the stall rains cash and dollar signs down the screen, fading as they fall.
]]

const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const TweenService = game:GetService("TweenService")

const Format = require("@game/ReplicatedStorage/Shared/Format")
const Net = require("@game/ReplicatedStorage/Shared/Net")
const Products = require("@game/ReplicatedStorage/Shared/Products")
const ClientState = require("../ClientState")
const Kit = require("../UI/Kit")
const Purchases = require("../UI/Purchases")
const Menus = require("../Menus")

local ShopMenu = {}

const PAGE_COLOR = Color3.fromRGB(70, 40, 120)
const STALL = Vector3.new(88, 0, 48)
const RAIN_RANGE = 34
const RAIN_GLYPHS = { "$", "💵", "💰", "$", "🪙" }

type Card = { def: Products.ProductDef, button: TextButton, note: TextLabel? }

local built = false
local page: ScrollingFrame
local sections: { [string]: Frame } = {}
local cards: { Card } = {}

local function ownsPass(key: string): boolean
	return Players.LocalPlayer:GetAttribute(`Pass_{key}`) == true
end

local function refresh()
	local profile = ClientState.profile
	if not built or not profile then
		return
	end
	local now = os.time()
	for _, card in cards do
		local def = card.def
		local potion = Products.POTIONS[def.key]
		if def.kind == "pass" and ownsPass(def.key) then
			Kit.setButtonColor(card.button, Kit.Colors.Grey, Kit.Colors.GreyDark)
			Kit.setButtonText(card.button, "✓ Owned")
		elseif def.key == "StarterPack" and profile.starterPackBought then
			Kit.setButtonColor(card.button, Kit.Colors.Grey, Kit.Colors.GreyDark)
			Kit.setButtonText(card.button, "✓ Bought")
		else
			Kit.setButtonColor(card.button, Kit.Colors.Green, Kit.Colors.GreenDark)
			Kit.setButtonText(card.button, `R$ {Format.commas(def.price)}`)
		end
		local note = card.note
		if note then
			if potion then
				local owned = profile.potions[def.key] or 0
				local ends = profile.boosts[potion] or 0
				note.Text = if ends > now
					then `Active {Format.duration(ends - now)} · Own {owned}`
					else `You own {owned}`
			elseif def.key == "ServerLuck" then
				local ends = ReplicatedStorage:GetAttribute("ServerLuckUntil")
				note.Text = if typeof(ends) == "number" and ends > now
					then `Active: {Format.duration(ends - now)}`
					else "Not active"
			elseif def.key == "LuckyForge" then
				note.Text = `Charges: {profile.luckyForges}`
			elseif def.key == "NovaReaper" or def.key == "DragonheartCannon" then
				local left = Products.LIMITED_ENDS - now
				note.Text = if left > 0
					then `LIMITED · Ends in {Format.duration(left)}`
					else "Sold out"
			end
		end
	end
end

local function sectionFrame(order: number, label: string, glyph: string, columns: number): Frame
	Kit.text({
		Name = `{label}Header`,
		Text = `{glyph}  {label}  {glyph}`,
		Size = UDim2.new(1, 0, 0, 44),
		LayoutOrder = order * 2 - 1,
		Stroke = 3,
		Parent = page,
	})
	local grid = Kit.new("Frame", {
		Name = label,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(0.96, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order * 2,
		Parent = page,
	})
	Kit.new("UIGridLayout", {
		CellSize = UDim2.new(1 / columns - 0.02, 0, 0, if columns == 1 then 150 else 190),
		CellPadding = UDim2.new(0.02, 0, 0, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = grid,
	})
	return grid
end

local function productCard(def: Products.ProductDef, order: number, parent: Frame, wide: boolean)
	local card = Kit.new("Frame", {
		Name = def.key,
		BackgroundColor3 = def.color,
		LayoutOrder = order,
		Parent = parent,
	})
	Kit.corner(16).Parent = card
	Kit.stroke(3, Kit.Colors.Ink, Enum.ApplyStrokeMode.Border).Parent = card
	Kit.gradient(def.color:Lerp(Color3.new(1, 1, 1), 0.25), def.color:Lerp(Color3.new(), 0.3)).Parent =
		card
	Kit.text({
		Text = def.glyph,
		Size = if wide then UDim2.fromScale(0.22, 0.8) else UDim2.fromScale(0.5, 0.36),
		Position = if wide then UDim2.fromScale(0.02, 0.1) else UDim2.fromScale(0.25, 0.04),
		Stroke = 0,
		Gradient = false,
		FontFace = Kit.FONT_BODY,
		Parent = card,
	})
	Kit.text({
		Text = def.name,
		Size = if wide then UDim2.fromScale(0.5, 0.28) else UDim2.fromScale(0.94, 0.16),
		Position = if wide then UDim2.fromScale(0.26, 0.08) else UDim2.fromScale(0.03, 0.4),
		TextXAlignment = if wide then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
		Stroke = 3,
		Parent = card,
	})
	Kit.text({
		Text = def.description,
		Size = if wide then UDim2.fromScale(0.5, 0.22) else UDim2.fromScale(0.94, 0.14),
		Position = if wide then UDim2.fromScale(0.26, 0.4) else UDim2.fromScale(0.03, 0.56),
		TextXAlignment = if wide then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
		TextColor3 = Color3.fromRGB(245, 240, 255),
		Stroke = 1.5,
		Gradient = false,
		Parent = card,
	})
	local note: TextLabel? = nil
	if
		Products.POTIONS[def.key]
		or def.key == "ServerLuck"
		or def.key == "LuckyForge"
		or def.key == "NovaReaper"
		or def.key == "DragonheartCannon"
	then
		note = Kit.text({
			Text = "",
			Size = if wide then UDim2.fromScale(0.5, 0.18) else UDim2.fromScale(0.94, 0.1),
			Position = if wide then UDim2.fromScale(0.26, 0.66) else UDim2.fromScale(0.03, 0.7),
			TextXAlignment = if wide then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
			TextColor3 = Color3.fromRGB(255, 230, 120),
			Stroke = 2,
			Parent = card,
		})
	end
	local button = Kit.button({
		name = "Buy",
		color = Kit.Colors.Green,
		dark = Kit.Colors.GreenDark,
		size = if wide then UDim2.fromScale(0.2, 0.42) else UDim2.fromScale(0.62, 0.16),
		position = if wide then UDim2.fromScale(0.77, 0.29) else UDim2.fromScale(0.04, 0.82),
		text = `R$ {def.price}`,
		parent = card,
		onClick = function()
			if def.kind == "pass" and ownsPass(def.key) then
				return
			end
			Purchases.prompt(def.key)
		end,
	})
	if Products.POTIONS[def.key] then
		-- Potions you own are used from here.
		Kit.button({
			name = "Use",
			color = Kit.Colors.Blue,
			dark = Kit.Colors.BlueDark,
			size = UDim2.fromScale(0.28, 0.16),
			position = UDim2.fromScale(0.68, 0.82),
			text = "Use",
			parent = card,
			onClick = function()
				Net.event("UsePotion"):FireServer(def.key)
			end,
		})
	end
	table.insert(cards, { def = def, button = button, note = note })
end

local function build(content: Frame)
	built = true
	local tabs = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(0.2, 1),
		Parent = content,
	})
	Kit.new("UIListLayout", {
		Padding = UDim.new(0.012, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = tabs,
	})
	page = Kit.new("ScrollingFrame", {
		BackgroundColor3 = PAGE_COLOR,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0.78, 1),
		Position = UDim2.fromScale(0.22, 0),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 8,
		Parent = content,
	}) :: ScrollingFrame
	Kit.corner(18).Parent = page
	Kit.stroke(3, Color3.fromRGB(120, 170, 255), Enum.ApplyStrokeMode.Border).Parent = page
	Kit.new("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = page,
	})
	Kit.new("UIPadding", {
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 16),
		Parent = page,
	})
	for order, section in Products.SECTIONS do
		local wide = section.key == "Featured"
		local grid = sectionFrame(order, section.label, section.glyph, if wide then 1 else 3)
		sections[section.key] = grid
		local index = 0
		for _, def in Products.List do
			if def.section == section.key then
				index += 1
				productCard(def, index, grid, wide)
			end
		end
		Kit.button({
			name = section.key,
			color = section.color,
			dark = section.color:Lerp(Color3.new(), 0.35),
			size = UDim2.fromScale(1, 0.125),
			text = `{section.glyph} {section.label}`,
			parent = tabs,
			onClick = function()
				-- Scroll so the section's header sits at the top of the page.
				local header = page:FindFirstChild(`{section.label}Header`) :: GuiObject?
				if header then
					local target = header.AbsolutePosition.Y
						- page.AbsolutePosition.Y
						+ page.CanvasPosition.Y
						- 6
					TweenService
						:Create(page, Kit.SMOOTH, { CanvasPosition = Vector2.new(0, target) })
						:Play()
				end
			end,
		}).LayoutOrder =
			order
	end
	refresh()
	task.spawn(function()
		while content.Parent do
			if Menus.isOpen("Shop") then
				refresh()
			end
			task.wait(1)
		end
	end)
end

-- Cash and dollar signs drifting down the screen while the player stands near the stall.
local function rainCash(screen: ScreenGui)
	local glyph = Kit.text({
		Text = RAIN_GLYPHS[math.random(#RAIN_GLYPHS)],
		Size = UDim2.fromOffset(46, 46),
		Position = UDim2.fromScale(math.random(), -0.06),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextColor3 = Color3.fromRGB(110, 235, 110),
		Rotation = math.random(-25, 25),
		Stroke = 2.5,
		StrokeColor = Color3.fromRGB(20, 80, 30),
		Gradient = false,
		FontFace = Kit.FONT_BODY,
		Parent = screen,
	})
	local fall =
		TweenInfo.new(2.4 + math.random() * 1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
	TweenService:Create(glyph, fall, {
		Position = UDim2.fromScale(glyph.Position.X.Scale + (math.random() - 0.5) * 0.12, 0.75),
		Rotation = glyph.Rotation + math.random(-90, 90),
		TextTransparency = 1,
	}):Play()
	local stroke = glyph:FindFirstChildOfClass("UIStroke")
	if stroke then
		TweenService:Create(stroke, fall, { Transparency = 1 }):Play()
	end
	task.delay(fall.Time, function()
		glyph:Destroy()
	end)
end

function ShopMenu:Init()
	Menus.register({
		name = "Shop",
		title = "🛒 Shop",
		color = Kit.Colors.Gold,
		size = Vector2.new(0.74, 0.8),
		build = build,
		onOpen = refresh,
	})
end

function ShopMenu:Start()
	ClientState.ProfileChanged:Connect(function()
		if Menus.isOpen("Shop") then
			refresh()
		end
	end)
	local screen = Kit.new("ScreenGui", {
		Name = "ShopRain",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 2,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	}) :: ScreenGui
	task.spawn(function()
		while true do
			task.wait(0.18)
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if
				root
				and root:IsA("BasePart")
				and not Menus.isOpen()
				and (Vector3.new(root.Position.X, 0, root.Position.Z) - STALL).Magnitude
					< RAIN_RANGE
			then
				rainCash(screen)
			end
		end
	end)
end

return ShopMenu
