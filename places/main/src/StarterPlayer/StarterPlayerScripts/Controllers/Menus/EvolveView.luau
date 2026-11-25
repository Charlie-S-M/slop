--!strict

--[[
	The Forge menu's Evolve tab. Lists the player's guns that can evolve; picking one shows the gun
	before and after, the stat changes, and the cost (one Glassheart plus coins). The Evolve button
	explains what's missing when the player can't afford it.
]]

const Balance = require("@game/ReplicatedStorage/Shared/Balance")
const Format = require("@game/ReplicatedStorage/Shared/Format")
const GunStats = require("@game/ReplicatedStorage/Shared/GunStats")
const Guns = require("@game/ReplicatedStorage/Shared/Guns")
const Net = require("@game/ReplicatedStorage/Shared/Net")
const Rarity = require("@game/ReplicatedStorage/Shared/Rarity")
const Types = require("@game/ReplicatedStorage/Shared/Types")
const ClientState = require("../ClientState")
const Kit = require("../UI/Kit")
const Preview = require("../UI/Preview")

local EvolveView = {}

local root: Frame
local list: ScrollingFrame
local emptyLabel: TextLabel
local detail: Frame
local beforeViewport: Frame
local afterViewport: Frame
local titleLabel: TextLabel
local statsLabel: TextLabel
local costLabel: TextLabel
local catalystLabel: TextLabel
local evolveButton: TextButton
local selectedUid: string? = nil

local function evolvable(): { Types.GunItem }
	local profile = ClientState.profile
	local found = {}
	if profile then
		for _, item in profile.guns do
			if Guns.evolutionOf(item.id) then
				table.insert(found, item)
			end
		end
	end
	return found
end

local function refreshDetail()
	local profile = ClientState.profile
	local glasshearts = if profile then profile.materials.Glassheart or 0 else 0
	catalystLabel.Text = `💎 Glasshearts: {glasshearts}`
	local item: Types.GunItem? = nil
	for _, candidate in evolvable() do
		if candidate.uid == selectedUid then
			item = candidate
		end
	end
	detail.Visible = item ~= nil
	if not item or not profile then
		return
	end
	local def = Guns.get(item.id)
	local evolution = Guns.evolutionOf(item.id)
	local cost = def and Balance.evolveCost(def.rarity)
	if not def or not evolution or not cost then
		return
	end
	local after = GunStats.evolve(item, evolution.id)
	Preview.gun(beforeViewport, def.id, 0.8)
	Preview.gun(afterViewport, evolution.id, 0.8)
	titleLabel.Text = `{def.name}  >>>  {evolution.name}`
	titleLabel.TextColor3 = Rarity.get(def.rarity).color:Lerp(Color3.new(1, 1, 1), 0.3)
	statsLabel.Text = table.concat({
		`💥 Power  {Format.abbreviate(item.power)} >>> {Format.abbreviate(after.power)}`,
		`⚡ Speed  {string.format("%.1f", GunStats.fireRate(def.kind, item.speed))}/s >>> {string.format(
			"%.1f",
			GunStats.fireRate(def.kind, after.speed)
		)}/s`,
		`🎯 Training  +{Format.abbreviate(item.train)} >>> +{Format.abbreviate(after.train)}`,
		`Grade {item.grade} stays`,
	}, "\n")
	costLabel.Text = `Cost: 💎 1 Glassheart + 💰 {Format.abbreviate(cost)}`
	local reason = nil
	if glasshearts < 1 then
		reason = "Need a Glassheart (Foundry boss)"
	elseif profile.coins < cost then
		reason = `Need {Format.abbreviate(cost - profile.coins)} more coins`
	end
	if reason then
		Kit.setButtonColor(evolveButton, Kit.Colors.Grey, Kit.Colors.GreyDark)
		Kit.setButtonText(evolveButton, reason)
	else
		Kit.setButtonColor(evolveButton, Kit.Colors.Pink, Kit.Colors.PinkDark)
		Kit.setButtonText(evolveButton, "✨ EVOLVE")
	end
end

function EvolveView.refresh()
	if not root then
		return
	end
	for _, child in list:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	local items = evolvable()
	emptyLabel.Visible = #items == 0
	if selectedUid == nil and items[1] then
		selectedUid = items[1].uid
	end
	for order, item in items do
		local def = Guns.get(item.id)
		if not def then
			continue
		end
		local rarity = Rarity.get(def.rarity)
		local card = Kit.new("TextButton", {
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = Kit.Colors.Card,
			LayoutOrder = order,
			Parent = list,
		})
		Kit.corner(12).Parent = card
		Kit.stroke(
			if item.uid == selectedUid then 5 else 3,
			if item.uid == selectedUid then Color3.new(1, 1, 1) else rarity.color,
			Enum.ApplyStrokeMode.Border
		).Parent =
			card
		Kit.gradient(rarity.color:Lerp(Kit.Colors.Card, 0.5), Kit.Colors.Card).Parent = card
		local viewport = Preview.viewport({
			Size = UDim2.fromScale(0.92, 0.6),
			Position = UDim2.fromScale(0.04, 0.04),
			Parent = card,
		})
		Preview.gun(viewport, def.id)
		Kit.text({
			Text = def.name,
			Size = UDim2.fromScale(0.92, 0.18),
			Position = UDim2.fromScale(0.04, 0.64),
			TextColor3 = rarity.color:Lerp(Color3.new(1, 1, 1), 0.3),
			Stroke = 2,
			Parent = card,
		})
		Kit.text({
			Text = `⚡ {Format.abbreviate(item.power)}  ·  {item.grade}`,
			Size = UDim2.fromScale(0.9, 0.15),
			Position = UDim2.fromScale(0.05, 0.82),
			TextColor3 = Color3.fromRGB(255, 220, 100),
			Stroke = 2,
			Parent = card,
		})
		card.Activated:Connect(function()
			selectedUid = item.uid
			Kit.sound(Kit.Sounds.Click, 0.3)
			EvolveView.refresh()
		end)
	end
	refreshDetail()
end

function EvolveView.build(parent: Frame): Frame
	root = Kit.new("Frame", {
		Name = "EvolveView",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = parent,
	})
	Kit.text({
		Text = "Evolvable Guns",
		Size = UDim2.fromScale(0.4, 0.07),
		TextXAlignment = Enum.TextXAlignment.Left,
		Stroke = 2.5,
		Parent = root,
	})
	list = Kit.new("ScrollingFrame", {
		Size = UDim2.fromScale(0.42, 0.9),
		Position = UDim2.fromScale(0, 0.09),
		BackgroundColor3 = Kit.Colors.Ink,
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = root,
	})
	Kit.corner(12).Parent = list
	Kit.padding(10).Parent = list
	Kit.new("UIGridLayout", {
		CellSize = UDim2.new(0.47, 0, 0, 140),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = list,
	})
	emptyLabel = Kit.text({
		Text = "Legendary, Mythic, Godly, and Eternal guns can evolve. Forge one, then bring a Glassheart from the Glassfall Foundry boss!",
		Size = UDim2.new(0.42, -20, 0, 90),
		Position = UDim2.new(0, 10, 0.12, 0),
		Stroke = 2,
		Visible = false,
		Parent = root,
	})

	local right = Kit.new("Frame", {
		Size = UDim2.fromScale(0.55, 1),
		Position = UDim2.fromScale(0.45, 0),
		BackgroundTransparency = 1,
		Parent = root,
	})
	catalystLabel = Kit.text({
		Text = "",
		Size = UDim2.fromScale(1, 0.07),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Color3.fromRGB(255, 160, 210),
		Stroke = 2.5,
		Parent = right,
	})
	detail = Kit.new("Frame", {
		Size = UDim2.fromScale(1, 0.9),
		Position = UDim2.fromScale(0, 0.09),
		BackgroundTransparency = 1,
		Parent = right,
	})
	titleLabel =
		Kit.text({ Text = "", Size = UDim2.fromScale(1, 0.09), Stroke = 3, Parent = detail })
	beforeViewport = Preview.viewport({
		Size = UDim2.fromScale(0.44, 0.33),
		Position = UDim2.fromScale(0, 0.1),
		Parent = detail,
	})
	Kit.text({
		Text = ">>>",
		Size = UDim2.fromScale(0.12, 0.15),
		Position = UDim2.fromScale(0.44, 0.19),
		Stroke = 3,
		Parent = detail,
	})
	afterViewport = Preview.viewport({
		Size = UDim2.fromScale(0.44, 0.33),
		Position = UDim2.fromScale(0.56, 0.1),
		Parent = detail,
	})
	statsLabel = Kit.text({
		Text = "",
		Size = UDim2.fromScale(1, 0.28),
		Position = UDim2.fromScale(0, 0.45),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Stroke = 2,
		Parent = detail,
	})
	costLabel = Kit.text({
		Text = "",
		Size = UDim2.fromScale(1, 0.07),
		Position = UDim2.fromScale(0, 0.75),
		TextColor3 = Color3.fromRGB(255, 220, 100),
		Stroke = 2.5,
		Parent = detail,
	})
	evolveButton = Kit.button({
		name = "Evolve",
		color = Kit.Colors.Pink,
		dark = Kit.Colors.PinkDark,
		size = UDim2.fromScale(0.8, 0.12),
		position = UDim2.fromScale(0.1, 0.85),
		text = "✨ EVOLVE",
		parent = detail,
		onClick = function()
			if selectedUid then
				Net.event("Evolve"):FireServer(selectedUid)
			end
		end,
	})
	return root
end

return EvolveView
