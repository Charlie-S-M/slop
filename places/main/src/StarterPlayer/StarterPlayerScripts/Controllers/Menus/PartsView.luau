--!strict

--[[
	The Backpack's Parts tab. The equipped gun's five attachment slots sit on top; tapping a filled
	slot takes the part off. Below, every owned part with its count. Picking one previews what it
	does to the equipped gun ("Starforge Power 1K → 1.07K") with an Equip button.
]]

const Attachments = require("@game/ReplicatedStorage/Shared/Attachments")
const Format = require("@game/ReplicatedStorage/Shared/Format")
const GunStats = require("@game/ReplicatedStorage/Shared/GunStats")
const Guns = require("@game/ReplicatedStorage/Shared/Guns")
const Net = require("@game/ReplicatedStorage/Shared/Net")
const Rarity = require("@game/ReplicatedStorage/Shared/Rarity")
const Types = require("@game/ReplicatedStorage/Shared/Types")
const ClientState = require("../ClientState")
const Kit = require("../UI/Kit")

local PartsView = {}

const STAT_NAME = { power = "Power", speed = "Speed", train = "Training" }

local root: Frame
local slotLabels: { [string]: TextLabel } = {}
local gunLabel: TextLabel
local list: ScrollingFrame
local emptyLabel: TextLabel
local previewLabel: TextLabel
local equipButton: TextButton
local selectedId: string? = nil

local function equippedGun(): Types.GunItem?
	local profile = ClientState.profile
	if not profile then
		return nil
	end
	for _, item in profile.guns do
		if item.uid == profile.equipped then
			return item
		end
	end
	return profile.guns[1]
end

local function statText(item: Types.GunItem, stat: string): string
	local value = (item :: any)[stat] :: number
	return if stat == "speed" then Format.multiplier(value) else Format.abbreviate(value)
end

local function refreshPreview()
	local gun = equippedGun()
	local def = if selectedId then Attachments.get(selectedId) else nil
	if not gun or not def then
		previewLabel.Text = "Pick a part to see what it does to your gun"
		equipButton.Visible = false
		return
	end
	local gunDef = Guns.get(gun.id)
	local parts = table.clone(gun.parts or {})
	parts[def.slot] = def.id
	local before = GunStats.effective(gun)
	local withPart = table.clone(gun)
	withPart.parts = parts
	local after = GunStats.effective(withPart)
	previewLabel.Text = `{def.name}: +{Format.percent(def.bonus)} {STAT_NAME[def.stat]}\n{if gunDef
		then gunDef.name
		else "Gun"} {STAT_NAME[def.stat]} {statText(before, def.stat)} → {statText(after, def.stat)}`
	equipButton.Visible = true
end

function PartsView.refresh()
	local profile = ClientState.profile
	if not root or not profile then
		return
	end
	local gun = equippedGun()
	local gunDef = gun and Guns.get(gun.id)
	gunLabel.Text =
		`On your {if gunDef then gunDef.name else "gun"} (tap a slot to take a part off)`
	for slot, label in slotLabels do
		local id = gun and gun.parts and gun.parts[slot]
		local def = id and Attachments.get(id)
		if def then
			label.Text = `{slot}\n{def.name}`
			label.TextColor3 = Rarity.get(def.rarity).color
		else
			label.Text = `{slot}\nempty`
			label.TextColor3 = Kit.Colors.Grey
		end
	end

	for _, child in list:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	local owned = {}
	for id, count in profile.attachments do
		local def = Attachments.get(id)
		if def and count > 0 then
			table.insert(owned, { def = def, count = count })
		end
	end
	table.sort(owned, function(a, b)
		return a.def.rarity > b.def.rarity
	end)
	for order, entry in owned do
		local rarity = Rarity.get(entry.def.rarity)
		local button = Kit.new("TextButton", {
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = Kit.Colors.Card,
			LayoutOrder = order,
			Parent = list,
		})
		Kit.corner(12).Parent = button
		Kit.stroke(
			if entry.def.id == selectedId then 4 else 3,
			if entry.def.id == selectedId then Kit.Colors.White else rarity.color,
			Enum.ApplyStrokeMode.Border
		).Parent =
			button
		Kit.text({
			Text = `{entry.def.name}  ×{entry.count}\n+{Format.percent(entry.def.bonus)} {STAT_NAME[entry.def.stat]}`,
			Size = UDim2.fromScale(0.92, 0.8),
			Position = UDim2.fromScale(0.04, 0.1),
			TextColor3 = rarity.color,
			TextWrapped = true,
			Stroke = 2,
			Parent = button,
		})
		button.Activated:Connect(function()
			Kit.sound(Kit.Sounds.Click, 0.3)
			selectedId = entry.def.id
			PartsView.refresh()
		end)
	end
	emptyLabel.Visible = #owned == 0
	if selectedId and not profile.attachments[selectedId] then
		selectedId = nil
	end
	refreshPreview()
end

function PartsView.build(parent: Instance): Frame
	root = Kit.new("Frame", {
		Name = "PartsView",
		Size = UDim2.fromScale(1, 0.86),
		Position = UDim2.fromScale(0, 0.13),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = parent,
	})
	gunLabel = Kit.text({
		Text = "",
		Size = UDim2.fromScale(1, 0.06),
		TextXAlignment = Enum.TextXAlignment.Left,
		Stroke = 2,
		Parent = root,
	})
	for index, slot in Attachments.SLOTS do
		local button = Kit.new("TextButton", {
			Text = "",
			AutoButtonColor = false,
			Size = UDim2.fromScale(0.185, 0.16),
			Position = UDim2.fromScale((index - 1) * 0.204, 0.07),
			BackgroundColor3 = Kit.Colors.Card,
			Parent = root,
		})
		Kit.corner(12).Parent = button
		Kit.stroke(3, Kit.Colors.Ink, Enum.ApplyStrokeMode.Border).Parent = button
		slotLabels[slot] = Kit.text({
			Text = slot,
			Size = UDim2.fromScale(0.92, 0.84),
			Position = UDim2.fromScale(0.04, 0.08),
			TextWrapped = true,
			Stroke = 2,
			Parent = button,
		})
		button.Activated:Connect(function()
			Net.event("UnequipPart"):FireServer(slot)
		end)
	end
	list = Kit.new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 0.52),
		Position = UDim2.fromScale(0, 0.26),
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
		CellSize = UDim2.new(0.235, 0, 0, 74),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = list,
	})
	emptyLabel = Kit.text({
		Text = "No parts yet! Beat bosses for chests.",
		Size = UDim2.fromScale(0.9, 0.1),
		Position = UDim2.fromScale(0.05, 0.45),
		Stroke = 2,
		Parent = root,
	})
	previewLabel = Kit.text({
		Text = "",
		Size = UDim2.fromScale(0.68, 0.18),
		Position = UDim2.fromScale(0, 0.81),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Stroke = 2,
		Parent = root,
	})
	equipButton = Kit.button({
		name = "EquipPart",
		color = Kit.Colors.Green,
		dark = Kit.Colors.GreenDark,
		size = UDim2.fromScale(0.28, 0.12),
		position = UDim2.fromScale(0.71, 0.84),
		text = "Equip on gun",
		parent = root,
		onClick = function()
			if selectedId then
				Net.event("EquipPart"):FireServer(selectedId)
			end
		end,
	})
	equipButton.Visible = false
	return root
end

return PartsView
