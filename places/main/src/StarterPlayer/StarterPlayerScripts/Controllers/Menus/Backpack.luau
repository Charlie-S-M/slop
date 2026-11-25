--!strict

-- The backpack: every gun you own (equip, lock, sell) and the ores in your bag (sell).

const Balance = require("@game/ReplicatedStorage/Shared/Balance")
const Format = require("@game/ReplicatedStorage/Shared/Format")
const Guns = require("@game/ReplicatedStorage/Shared/Guns")
const PetStats = require("@game/ReplicatedStorage/Shared/PetStats")
const Net = require("@game/ReplicatedStorage/Shared/Net")
const Ores = require("@game/ReplicatedStorage/Shared/Ores")
const Rarity = require("@game/ReplicatedStorage/Shared/Rarity")
const Types = require("@game/ReplicatedStorage/Shared/Types")
const ClientState = require("../ClientState")
const Kit = require("../UI/Kit")
const Menus = require("../Menus")
const Preview = require("../UI/Preview")
const ArmorView = require("./ArmorView")
const PartsView = require("./PartsView")

local Backpack = {}

local tab = "Guns"
local selectedUid: string? = nil
local gunsGrid: ScrollingFrame
local oresGrid: ScrollingFrame
local detail: Frame
local detailViewport: ViewportFrame
local detailName: TextLabel
local detailRarity: TextLabel
local detailStats: TextLabel
local equipButton: TextButton
local lockButton: TextButton
local sellButton: TextButton
local oresFooter: Frame
local armorView: Frame
local partsView: Frame
local sellAllButton: TextButton
local tabButtons: { [string]: TextButton } = {}
local built = false

local function gunDamage(item: Types.GunItem, def: Guns.GunDef): number
	local profile = ClientState.profile
	if not profile then
		return 0
	end
	return Balance.shotDamage(
		profile.power,
		item.power,
		def.kind,
		profile.rebirths,
		profile.level,
		def.id
	) * PetStats.multiplier(profile.pets, profile.equippedPets, "Damage")
end

local function card(parent: Instance, rarityTier: number, order: number): TextButton
	local rarity = Rarity.get(rarityTier)
	local button = Kit.new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Kit.Colors.Card,
		LayoutOrder = order,
		Parent = parent,
	})
	Kit.corner(12).Parent = button
	local stroke = Kit.stroke(3, rarity.color, Enum.ApplyStrokeMode.Border)
	stroke.Name = "RarityStroke"
	stroke.Parent = button
	Kit.gradient(rarity.color:Lerp(Kit.Colors.Card, 0.55), Kit.Colors.Card).Parent = button
	button.MouseButton1Down:Connect(function()
		Kit.pop(button, 0.92)
	end)
	return button
end

local function refreshDetail()
	local profile = ClientState.profile
	if not profile then
		return
	end
	local item: Types.GunItem? = nil
	for _, gun in profile.guns do
		if gun.uid == selectedUid then
			item = gun
		end
	end
	if not item then
		local equipped = ClientState.equipped()
		item = equipped
		selectedUid = if equipped then equipped.uid else nil
	end
	if not item then
		return
	end
	local def = Guns.get(item.id)
	if not def then
		return
	end
	local rarity = Rarity.get(def.rarity)
	local stats = Guns.kindStats(def.kind)
	Preview.gun(detailViewport, def.id, 0.8)
	detailName.Text = def.name
	detailRarity.Text = `{rarity.name} {def.kind}`
	detailRarity.TextColor3 = rarity.color:Lerp(Color3.new(1, 1, 1), 0.2)
	detailStats.Text = table.concat({
		`Grade {item.grade}   •   Speed {string.format("%.2f", item.speed)}×`,
		`⚡ Gun Power: {Format.abbreviate(item.power)}`,
		`💥 Damage: {Format.abbreviate(gunDamage(item, def))}`,
		`🔥 Fire rate: {string.format("%.1f", stats.fireRate * item.speed)}/s`,
		`📦 Magazine: {stats.magazine}`,
		`🎯 Training: +{Format.abbreviate(
			Balance.trainingGain(item.train, def.kind, 1, profile.upgrades.Training or 0)
		)}/shot`,
	}, "\n")
	local isEquipped = item.uid == profile.equipped
	Kit.setButtonText(equipButton, if isEquipped then "Equipped" else "Equip")
	if isEquipped then
		Kit.setButtonColor(equipButton, Kit.Colors.Grey, Kit.Colors.GreyDark)
	else
		Kit.setButtonColor(equipButton, Kit.Colors.Green, Kit.Colors.GreenDark)
	end
	Kit.setButtonText(lockButton, if item.locked then "🔒 Locked" else "🔓 Lock")
	local price = Balance.gunSellPrice(item.power, def.rarity)
	Kit.setButtonText(sellButton, `Sell 💰{Format.abbreviate(price)}`)
	local canSell = not item.locked and not isEquipped
	if canSell then
		Kit.setButtonColor(sellButton, Kit.Colors.Red, Kit.Colors.RedDark)
	else
		Kit.setButtonColor(sellButton, Kit.Colors.Grey, Kit.Colors.GreyDark)
	end
end

local function refreshGuns()
	local profile = ClientState.profile
	if not profile then
		return
	end
	for _, child in gunsGrid:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	-- Strongest first: rarity, then power.
	local sorted = table.clone(profile.guns)
	table.sort(sorted, function(a, b)
		local da = Guns.get(a.id)
		local db = Guns.get(b.id)
		local ra = if da then da.rarity else 0
		local rb = if db then db.rarity else 0
		if a.uid == profile.equipped then
			return true
		elseif b.uid == profile.equipped then
			return false
		end
		if ra ~= rb then
			return ra > rb
		end
		return a.power > b.power
	end)
	for index, item in sorted do
		local def = Guns.get(item.id)
		if not def then
			continue
		end
		local button = card(gunsGrid, def.rarity, index)
		local viewport = Preview.viewport({
			Size = UDim2.fromScale(0.92, 0.62),
			Position = UDim2.fromScale(0.04, 0.04),
			Parent = button,
		})
		Preview.gun(viewport, def.id)
		Kit.text({
			Text = def.name,
			Size = UDim2.fromScale(0.92, 0.17),
			Position = UDim2.fromScale(0.04, 0.64),
			TextColor3 = Rarity.get(def.rarity).color:Lerp(Color3.new(1, 1, 1), 0.3),
			Stroke = 2,
			Parent = button,
		})
		Kit.text({
			Text = `⚡ {Format.abbreviate(item.power)}`,
			Size = UDim2.fromScale(0.9, 0.16),
			Position = UDim2.fromScale(0.05, 0.81),
			TextColor3 = Color3.fromRGB(255, 220, 100),
			Stroke = 2,
			Parent = button,
		})
		if item.uid == profile.equipped then
			local tag = Kit.new("Frame", {
				Size = UDim2.fromScale(0.6, 0.16),
				Position = UDim2.fromScale(0.5, -0.04),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundColor3 = Kit.Colors.Green,
				ZIndex = 4,
				Parent = button,
			})
			Kit.cornerScale(0.5).Parent = tag
			Kit.stroke(2, Kit.Colors.Ink, Enum.ApplyStrokeMode.Border).Parent = tag
			Kit.text({
				Text = "EQUIPPED",
				Size = UDim2.fromScale(0.9, 0.8),
				Position = UDim2.fromScale(0.05, 0.1),
				ZIndex = 5,
				Stroke = 1.5,
				Parent = tag,
			})
		end
		if item.locked then
			Kit.text({
				Text = "🔒",
				Size = UDim2.fromScale(0.22, 0.2),
				Position = UDim2.fromScale(0.76, 0.02),
				Stroke = 0,
				Gradient = false,
				FontFace = Kit.FONT_BODY,
				Parent = button,
			})
		end
		if item.uid == selectedUid then
			local stroke = button:FindFirstChild("RarityStroke") :: UIStroke?
			if stroke then
				stroke.Thickness = 5
				stroke.Color = Color3.new(1, 1, 1)
			end
		end
		button.Activated:Connect(function()
			selectedUid = item.uid
			Kit.sound(Kit.Sounds.Click, 0.3)
			refreshGuns()
			refreshDetail()
		end)
	end
	refreshDetail()
end

local function refreshOres()
	local profile = ClientState.profile
	if not profile then
		return
	end
	for _, child in oresGrid:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	local total = 0
	local count = 0
	for index, ore in Ores.List do
		local amount = profile.bag[ore.id] or 0
		if amount <= 0 then
			continue
		end
		count += amount
		local price = Balance.oreSellPrice(ore, profile.upgrades.CoinBoost or 0)
		total += price * amount
		local button = card(oresGrid, ore.rarity, -index)
		local viewport = Preview.viewport({
			Size = UDim2.fromScale(0.8, 0.55),
			Position = UDim2.fromScale(0.1, 0.04),
			Parent = button,
		})
		Preview.ore(viewport, ore.id)
		Kit.text({
			Text = `x{amount}`,
			Size = UDim2.fromScale(0.4, 0.2),
			Position = UDim2.fromScale(0.58, 0.02),
			TextXAlignment = Enum.TextXAlignment.Right,
			Stroke = 2,
			Parent = button,
		})
		Kit.text({
			Text = ore.name,
			Size = UDim2.fromScale(0.92, 0.18),
			Position = UDim2.fromScale(0.04, 0.6),
			TextColor3 = Rarity.get(ore.rarity).color:Lerp(Color3.new(1, 1, 1), 0.3),
			Stroke = 2,
			Parent = button,
		})
		Kit.text({
			Text = `💰 {Format.abbreviate(price)}`,
			Size = UDim2.fromScale(0.9, 0.16),
			Position = UDim2.fromScale(0.05, 0.8),
			TextColor3 = Color3.fromRGB(255, 215, 80),
			Stroke = 2,
			Parent = button,
		})
		button.Activated:Connect(function()
			Net.event("SellOres"):FireServer(ore.id)
		end)
	end
	Kit.setButtonText(
		sellAllButton,
		if count > 0 then `Sell All ({count}) 💰{Format.abbreviate(total)}` else "Bag is empty"
	)
end

local function setTab(name: string)
	tab = name
	gunsGrid.Visible = name == "Guns"
	detail.Visible = name == "Guns"
	oresGrid.Visible = name == "Ores"
	oresFooter.Visible = name == "Ores"
	armorView.Visible = name == "Armor"
	partsView.Visible = name == "Parts"
	for tabName, button in tabButtons do
		if tabName == name then
			Kit.setButtonColor(button, Kit.Colors.Orange, Kit.Colors.OrangeDark)
		else
			Kit.setButtonColor(button, Kit.Colors.GreyDark, Kit.Colors.Ink)
		end
	end
	if name == "Guns" then
		refreshGuns()
	elseif name == "Armor" then
		ArmorView.refresh()
	elseif name == "Parts" then
		PartsView.refresh()
	else
		refreshOres()
	end
end

local function grid(parent: Instance, size: UDim2, position: UDim2, cell: UDim2): ScrollingFrame
	local scroll = Kit.new("ScrollingFrame", {
		Size = size,
		Position = position,
		BackgroundColor3 = Kit.Colors.Ink,
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Kit.Colors.White,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = parent,
	})
	Kit.corner(12).Parent = scroll
	Kit.padding(10).Parent = scroll
	Kit.new("UIGridLayout", {
		CellSize = cell,
		CellPadding = UDim2.fromOffset(10, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = scroll,
	})
	return scroll
end

local function build(content: Frame)
	built = true
	for index, name in { "Guns", "Ores", "Armor", "Parts" } do
		tabButtons[name] = Kit.button({
			name = name,
			color = Kit.Colors.GreyDark,
			dark = Kit.Colors.Ink,
			size = UDim2.fromScale(0.16, 0.1),
			position = UDim2.fromScale((index - 1) * 0.17, 0),
			text = if name == "Guns"
				then "🔫 Guns"
				elseif name == "Ores" then "💎 Ores"
				elseif name == "Armor" then "🛡️ Armor"
				else "⚙️ Parts",
			parent = content,
			onClick = function()
				setTab(name)
			end,
		})
	end

	gunsGrid = grid(
		content,
		UDim2.fromScale(0.6, 0.86),
		UDim2.fromScale(0, 0.13),
		UDim2.new(0.31, 0, 0, 150)
	)
	oresGrid = grid(
		content,
		UDim2.fromScale(1, 0.72),
		UDim2.fromScale(0, 0.13),
		UDim2.new(0.18, 0, 0, 140)
	)

	detail = Kit.new("Frame", {
		Name = "Detail",
		Size = UDim2.fromScale(0.38, 0.86),
		Position = UDim2.fromScale(0.62, 0.13),
		BackgroundColor3 = Kit.Colors.Ink,
		BackgroundTransparency = 0.5,
		Parent = content,
	})
	Kit.corner(14).Parent = detail
	detailViewport = Preview.viewport({
		Size = UDim2.fromScale(0.94, 0.34),
		Position = UDim2.fromScale(0.03, 0.02),
		Parent = detail,
	})
	detailName = Kit.text({
		Text = "",
		Size = UDim2.fromScale(0.92, 0.09),
		Position = UDim2.fromScale(0.04, 0.36),
		Stroke = 3,
		Parent = detail,
	})
	detailRarity = Kit.text({
		Text = "",
		Size = UDim2.fromScale(0.8, 0.06),
		Position = UDim2.fromScale(0.1, 0.45),
		Stroke = 2,
		Parent = detail,
	})
	detailStats = Kit.text({
		Text = "",
		Size = UDim2.fromScale(0.9, 0.27),
		Position = UDim2.fromScale(0.05, 0.52),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Stroke = 2,
		Parent = detail,
	})
	equipButton = Kit.button({
		name = "Equip",
		color = Kit.Colors.Green,
		dark = Kit.Colors.GreenDark,
		size = UDim2.fromScale(0.9, 0.08),
		position = UDim2.fromScale(0.05, 0.8),
		text = "Equip",
		parent = detail,
		onClick = function()
			if selectedUid then
				Net.event("Equip"):FireServer(selectedUid)
			end
		end,
	})
	lockButton = Kit.button({
		name = "Lock",
		color = Kit.Colors.Blue,
		dark = Kit.Colors.BlueDark,
		size = UDim2.fromScale(0.43, 0.075),
		position = UDim2.fromScale(0.05, 0.9),
		text = "🔓 Lock",
		parent = detail,
		onClick = function()
			if selectedUid then
				Net.event("ToggleLock"):FireServer(selectedUid)
			end
		end,
	})
	sellButton = Kit.button({
		name = "Sell",
		color = Kit.Colors.Red,
		dark = Kit.Colors.RedDark,
		size = UDim2.fromScale(0.43, 0.075),
		position = UDim2.fromScale(0.52, 0.9),
		text = "Sell",
		parent = detail,
		onClick = function()
			if selectedUid then
				Net.event("SellGun"):FireServer(selectedUid)
				selectedUid = nil
			end
		end,
	})

	oresFooter = Kit.new("Frame", {
		Size = UDim2.fromScale(1, 0.12),
		Position = UDim2.fromScale(0, 0.88),
		BackgroundTransparency = 1,
		Parent = content,
	})
	sellAllButton = Kit.button({
		name = "SellAll",
		color = Kit.Colors.Gold,
		dark = Kit.Colors.GoldDark,
		size = UDim2.fromScale(0.5, 0.9),
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		text = "Sell All",
		parent = oresFooter,
		onClick = function()
			Net.event("SellOres"):FireServer("*")
		end,
	})
	Kit.text({
		Text = "Tip: tap an ore to sell that kind",
		Size = UDim2.fromScale(0.22, 0.5),
		Position = UDim2.fromScale(0, 0.25),
		TextXAlignment = Enum.TextXAlignment.Left,
		Stroke = 1.5,
		Parent = oresFooter,
	})
	armorView = ArmorView.build(content)
	partsView = PartsView.build(content)
	setTab(tab)
end

-- Opens the backpack straight to a tab.
function Backpack.openTab(name: string)
	tab = name
	Menus.open("Backpack")
	if built then
		setTab(name)
	end
end

function Backpack:Init()
	Menus.register({
		name = "Backpack",
		title = "Backpack",
		color = Kit.Colors.Orange,
		size = Vector2.new(0.66, 0.7),
		build = build,
		onOpen = function()
			if built then
				setTab(tab)
			end
		end,
	})
end

function Backpack:Start()
	ClientState.ProfileChanged:Connect(function()
		if built and Menus.isOpen("Backpack") then
			if tab == "Guns" then
				refreshGuns()
			elseif tab == "Armor" then
				ArmorView.refresh()
			elseif tab == "Parts" then
				PartsView.refresh()
			else
				refreshOres()
			end
		end
	end)
end

return Backpack
