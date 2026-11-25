--!strict

--[[
	The Backpack's Armor tab. Three slot cards show what's worn and how much of each hit the set
	blocks; below them, every owned piece. Picking a piece shows its block, how it compares with the
	piece worn in its slot, and Equip, Lock, and Sell.
]]

const Armor = require("@game/ReplicatedStorage/Shared/Armor")
const ArmorStats = require("@game/ReplicatedStorage/Shared/ArmorStats")
const Balance = require("@game/ReplicatedStorage/Shared/Balance")
const Format = require("@game/ReplicatedStorage/Shared/Format")
const Net = require("@game/ReplicatedStorage/Shared/Net")
const Rarity = require("@game/ReplicatedStorage/Shared/Rarity")
const Types = require("@game/ReplicatedStorage/Shared/Types")
const ClientState = require("../ClientState")
const Kit = require("../UI/Kit")
const Preview = require("../UI/Preview")

local ArmorView = {}

local root: Frame
local slotCards: { [string]: { button: TextButton, viewport: ViewportFrame, label: TextLabel } } =
	{}
local totalLabel: TextLabel
local list: ScrollingFrame
local emptyLabel: TextLabel
local detail: Frame
local detailViewport: ViewportFrame
local detailName: TextLabel
local detailStats: TextLabel
local equipButton: TextButton
local lockButton: TextButton
local sellButton: TextButton
local selectedUid: string? = nil

local function findItem(uid: string?): Types.ArmorItem?
	local profile = ClientState.profile
	if not profile or not uid then
		return nil
	end
	for _, item in profile.armor do
		if item.uid == uid then
			return item
		end
	end
	return nil
end

local function isWorn(profile: Types.Profile, uid: string): boolean
	for _, worn in profile.equippedArmor do
		if worn == uid then
			return true
		end
	end
	return false
end

local function refreshDetail()
	local profile = ClientState.profile
	local item = findItem(selectedUid)
	local def = item and Armor.get(item.id)
	detail.Visible = profile ~= nil and item ~= nil and def ~= nil
	if not profile or not item or not def then
		return
	end
	local rarity = Rarity.get(def.rarity)
	Preview.armor(detailViewport, def.id, 0.6)
	detailName.Text = def.name
	detailName.TextColor3 = rarity.color
	local worn = ArmorStats.equippedIn(profile.armor, profile.equippedArmor, def.slot)
	local wearing = worn ~= nil and worn.uid == item.uid
	local compare = if wearing
		then "Worn now"
		elseif worn then `{if item.defense >= worn.defense then "+" else "−"}{Format.percent(
			math.abs(item.defense - worn.defense)
		)} vs worn`
		else `+{Format.percent(item.defense)} (slot empty)`
	detailStats.Text =
		`{rarity.name} {def.slot}  ·  Grade {item.grade}\n🛡️ Blocks {Format.percent(
			item.defense
		)} of each hit\n{compare}`
	Kit.setButtonText(equipButton, if wearing then "Unequip" else "Equip")
	Kit.setButtonText(lockButton, if item.locked then "🔒 Locked" else "🔓 Lock")
	local price = Balance.armorSellPrice(item.defense, def.rarity)
	local canSell = not item.locked and not wearing
	Kit.setButtonText(
		sellButton,
		if canSell then `Sell 💰{Format.abbreviate(price)}` else "Can't sell"
	)
	if canSell then
		Kit.setButtonColor(sellButton, Kit.Colors.Red, Kit.Colors.RedDark)
	else
		Kit.setButtonColor(sellButton, Kit.Colors.Grey, Kit.Colors.GreyDark)
	end
end

function ArmorView.refresh()
	local profile = ClientState.profile
	if not root or not profile then
		return
	end
	-- The worn set.
	for _, slot: Types.ArmorSlot in Armor.SLOTS do
		local card = slotCards[slot]
		local worn = ArmorStats.equippedIn(profile.armor, profile.equippedArmor, slot)
		local def = worn and Armor.get(worn.id)
		if worn and def then
			Preview.armor(card.viewport, def.id)
			card.label.Text = `{slot}\n{Format.percent(worn.defense)}`
			card.label.TextColor3 = Rarity.get(def.rarity).color
		else
			card.viewport:ClearAllChildren()
			card.label.Text = `{slot}\nempty`
			card.label.TextColor3 = Kit.Colors.Grey
		end
	end
	totalLabel.Text = `🛡️ Your set blocks {Format.percent(
		ArmorStats.blocked(profile.armor, profile.equippedArmor)
	)} of each hit`

	-- Every owned piece, best first.
	for _, child in list:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	local pieces = table.clone(profile.armor)
	table.sort(pieces, function(a, b)
		return a.defense > b.defense
	end)
	for order, item in pieces do
		local def = Armor.get(item.id)
		if def then
			local rarity = Rarity.get(def.rarity)
			local button = Kit.new("TextButton", {
				Text = "",
				AutoButtonColor = false,
				BackgroundColor3 = Kit.Colors.Card,
				LayoutOrder = order,
				Parent = list,
			})
			Kit.corner(12).Parent = button
			Kit.stroke(
				if item.uid == selectedUid then 4 else 3,
				if item.uid == selectedUid then Kit.Colors.White else rarity.color,
				Enum.ApplyStrokeMode.Border
			).Parent =
				button
			local viewport = Preview.viewport({
				Size = UDim2.fromScale(0.9, 0.6),
				Position = UDim2.fromScale(0.05, 0.03),
				Parent = button,
			})
			Preview.armor(viewport, def.id)
			Kit.text({
				Text = `{def.name}\n{Format.percent(item.defense)}{if isWorn(profile, item.uid)
					then "  ✓"
					else ""}`,
				Size = UDim2.fromScale(0.94, 0.34),
				Position = UDim2.fromScale(0.03, 0.64),
				TextColor3 = rarity.color,
				Stroke = 2,
				Parent = button,
			})
			button.Activated:Connect(function()
				Kit.sound(Kit.Sounds.Click, 0.3)
				selectedUid = item.uid
				ArmorView.refresh()
			end)
		end
	end
	emptyLabel.Visible = #pieces == 0
	if selectedUid and not findItem(selectedUid) then
		selectedUid = nil
	end
	refreshDetail()
end

function ArmorView.build(parent: Instance): Frame
	root = Kit.new("Frame", {
		Name = "ArmorView",
		Size = UDim2.fromScale(1, 0.86),
		Position = UDim2.fromScale(0, 0.13),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = parent,
	})
	local left = Kit.new("Frame", {
		Size = UDim2.fromScale(0.6, 1),
		BackgroundTransparency = 1,
		Parent = root,
	})
	for index, slot in Armor.SLOTS do
		local button = Kit.new("TextButton", {
			Text = "",
			AutoButtonColor = false,
			Size = UDim2.fromScale(0.31, 0.24),
			Position = UDim2.fromScale((index - 1) * 0.345, 0),
			BackgroundColor3 = Kit.Colors.Card,
			Parent = left,
		})
		Kit.corner(12).Parent = button
		Kit.stroke(3, Kit.Colors.Ink, Enum.ApplyStrokeMode.Border).Parent = button
		local viewport = Preview.viewport({
			Size = UDim2.fromScale(0.5, 0.9),
			Position = UDim2.fromScale(0.02, 0.05),
			Parent = button,
		})
		local label = Kit.text({
			Text = slot,
			Size = UDim2.fromScale(0.46, 0.8),
			Position = UDim2.fromScale(0.52, 0.1),
			Stroke = 2,
			Parent = button,
		})
		button.Activated:Connect(function()
			local profile = ClientState.profile
			local uid = profile and profile.equippedArmor[slot]
			if uid then
				selectedUid = uid
				ArmorView.refresh()
			end
		end)
		slotCards[slot] = { button = button :: TextButton, viewport = viewport, label = label }
	end
	totalLabel = Kit.text({
		Text = "",
		Size = UDim2.fromScale(1, 0.07),
		Position = UDim2.fromScale(0, 0.25),
		TextColor3 = Color3.fromRGB(150, 210, 255),
		Stroke = 2.5,
		Parent = left,
	})
	list = Kit.new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 0.66),
		Position = UDim2.fromScale(0, 0.34),
		BackgroundColor3 = Kit.Colors.Ink,
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = left,
	})
	Kit.corner(12).Parent = list
	Kit.padding(10).Parent = list
	Kit.new("UIGridLayout", {
		CellSize = UDim2.new(0.31, 0, 0, 140),
		CellPadding = UDim2.fromOffset(10, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = list,
	})
	emptyLabel = Kit.text({
		Text = "No armor yet! Forge some at the forge.",
		Size = UDim2.fromScale(0.9, 0.12),
		Position = UDim2.fromScale(0.05, 0.6),
		Stroke = 2,
		Parent = left,
	})

	detail = Kit.new("Frame", {
		Size = UDim2.fromScale(0.38, 1),
		Position = UDim2.fromScale(0.62, 0),
		BackgroundColor3 = Kit.Colors.Ink,
		BackgroundTransparency = 0.5,
		Parent = root,
	})
	Kit.corner(14).Parent = detail
	detailViewport = Preview.viewport({
		Size = UDim2.fromScale(0.94, 0.36),
		Position = UDim2.fromScale(0.03, 0.02),
		Parent = detail,
	})
	detailName = Kit.text({
		Text = "",
		Size = UDim2.fromScale(0.92, 0.09),
		Position = UDim2.fromScale(0.04, 0.38),
		Stroke = 3,
		Parent = detail,
	})
	detailStats = Kit.text({
		Text = "",
		Size = UDim2.fromScale(0.9, 0.3),
		Position = UDim2.fromScale(0.05, 0.48),
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
			local profile = ClientState.profile
			local item = findItem(selectedUid)
			local def = item and Armor.get(item.id)
			if not profile or not item or not def then
				return
			end
			if profile.equippedArmor[def.slot] == item.uid then
				Net.event("UnequipArmor"):FireServer(def.slot)
			else
				Net.event("EquipArmor"):FireServer(item.uid)
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
				Net.event("LockArmor"):FireServer(selectedUid)
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
				Net.event("SellArmor"):FireServer(selectedUid)
			end
		end,
	})
	detail.Visible = false
	return root
end

return ArmorView
