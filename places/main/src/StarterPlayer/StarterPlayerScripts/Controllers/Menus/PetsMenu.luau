--!strict

--[[
	The Pets menu. Eggs on the left: each shows its price, its odds, and a Hatch button, or the stage
	that unlocks it. Owned pets on the right: picking one shows its bonus and exactly what equipping
	it changes ("Training ×1.20 → ×1.40"), with Equip, Lock, and Release. A hatch pops a card with
	the new pet.
]]

const Balance = require("@game/ReplicatedStorage/Shared/Balance")
const Format = require("@game/ReplicatedStorage/Shared/Format")
const Net = require("@game/ReplicatedStorage/Shared/Net")
const PetStats = require("@game/ReplicatedStorage/Shared/PetStats")
const Pets = require("@game/ReplicatedStorage/Shared/Pets")
const Rarity = require("@game/ReplicatedStorage/Shared/Rarity")
const ClientState = require("../ClientState")
const Effects = require("../Effects")
const Kit = require("../UI/Kit")
const Menus = require("../Menus")
const Preview = require("../UI/Preview")

local PetsMenu = {}

const KIND_LABEL: { [string]: string } = {
	Ores = "⛏️ Ore drops",
	Training = "🎯 Training",
	Damage = "💥 Damage",
}

local built = false
local eggCards: { { egg: Pets.EggDef, price: TextLabel, button: TextButton } } = {}
local list: ScrollingFrame
local equippedLabel: TextLabel
local detail: Frame
local detailViewport: Frame
local detailName: TextLabel
local detailStats: TextLabel
local equipButton: TextButton
local lockButton: TextButton
local releaseButton: TextButton
local selectedUid: string? = nil
local selecting = false
local marked: { [string]: boolean } = {}
local releaseMany: TextButton
local hatchCard: Frame?
local hatchCount = 0
local content: Frame

local function owned(uid: string?): PetStats.OwnedPet?
	local profile = ClientState.profile
	if not profile or not uid then
		return nil
	end
	for _, pet in profile.pets do
		if pet.uid == uid then
			return pet
		end
	end
	return nil
end

-- How a multiplier reads for its kind. Ore drops show the capped drop chance the server uses.
local function effect(kind: string, multiplier: number): string
	if kind == "Ores" then
		return Format.percent(Balance.oreDropChance(multiplier))
	end
	return `×{string.format("%.2f", multiplier)}`
end

local function refreshDetail()
	local profile = ClientState.profile
	local pet = owned(selectedUid)
	local def = pet and Pets.get(pet.id)
	detail.Visible = not selecting and profile ~= nil and pet ~= nil and def ~= nil
	if selecting or not profile or not pet or not def then
		return
	end
	local rarity = Rarity.get(def.rarity)
	Preview.pet(detailViewport, def.id, 0.8)
	detailName.Text = def.name
	detailName.TextColor3 = rarity.color
	local equipped = table.find(profile.equippedPets, pet.uid) ~= nil
	local now = PetStats.multiplier(profile.pets, profile.equippedPets, def.kind)
	local change: string
	if equipped then
		local without = table.clone(profile.equippedPets)
		table.remove(without, table.find(without, pet.uid) :: number)
		local after = PetStats.multiplier(profile.pets, without, def.kind)
		change =
			`Unequip: {KIND_LABEL[def.kind]} {effect(def.kind, now)} → {effect(def.kind, after)}`
	elseif #profile.equippedPets >= Balance.PET_SLOTS then
		change = `All {Balance.PET_SLOTS} pet slots are full`
	else
		local with = table.clone(profile.equippedPets)
		table.insert(with, pet.uid)
		local after = PetStats.multiplier(profile.pets, with, def.kind)
		change =
			`Equip: {KIND_LABEL[def.kind]} {effect(def.kind, now)} → {effect(def.kind, after)}`
	end
	detailStats.Text =
		`{rarity.name} pet\n{KIND_LABEL[def.kind]} +{Format.percent(def.bonus)}\n{change}`
	Kit.setButtonText(equipButton, if equipped then "Unequip" else "Equip")
	Kit.setButtonText(lockButton, if pet.locked then "🔒 Locked" else "🔓 Lock")
	local canRelease = not pet.locked and not equipped
	Kit.setButtonText(releaseButton, if canRelease then "Release" else "Can't release")
	if canRelease then
		Kit.setButtonColor(releaseButton, Kit.Colors.Red, Kit.Colors.RedDark)
	else
		Kit.setButtonColor(releaseButton, Kit.Colors.Grey, Kit.Colors.GreyDark)
	end
end

local function refreshEggs()
	local profile = ClientState.profile
	if not built or not profile then
		return
	end
	for _, card in eggCards do
		local unlocked = profile.bestStage + 1 >= card.egg.unlockStage
		local price = Pets.price(card.egg)
		if unlocked then
			card.price.Text = `💰 {Format.abbreviate(price)}`
			Kit.setButtonText(card.button, "Hatch")
			if profile.coins >= price then
				Kit.setButtonColor(card.button, Kit.Colors.Green, Kit.Colors.GreenDark)
			else
				Kit.setButtonColor(card.button, Kit.Colors.Grey, Kit.Colors.GreyDark)
			end
		else
			card.price.Text = `🔒 Reach stage {card.egg.unlockStage}`
			Kit.setButtonText(card.button, "Locked")
			Kit.setButtonColor(card.button, Kit.Colors.Grey, Kit.Colors.GreyDark)
		end
	end
	equippedLabel.Text = if selecting
		then "Select unlocked pets to release"
		else `Following you: {#profile.equippedPets}/{Balance.PET_SLOTS}  ·  Owned: {#profile.pets}/{Balance.MAX_PETS}`
end

-- What the grid shows; it is only rebuilt when this changes.
local lastGrid = ""

local function refresh()
	local profile = ClientState.profile
	if not built or not profile then
		return
	end
	refreshEggs()
	local count = 0
	for uid in marked do
		local pet = owned(uid)
		if not pet or pet.locked or table.find(profile.equippedPets, uid) then
			marked[uid] = nil
		else
			count += 1
		end
	end
	Kit.setButtonText(
		releaseMany,
		if not selecting then "Select pets" elseif count == 0 then "Cancel" else "Release " .. count
	)
	local parts =
		{ tostring(selecting), selectedUid or "", table.concat(profile.equippedPets, ",") }
	for _, pet in profile.pets do
		table.insert(parts, `{pet.uid}:{pet.id}:{if pet.locked then 1 else 0}`)
	end
	local signature = table.concat(parts, "|")
	if signature == lastGrid then
		refreshDetail()
		return
	end
	lastGrid = signature

	for _, child in list:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	local sorted = table.clone(profile.pets)
	table.sort(sorted, function(a, b)
		local da, db = Pets.get(a.id), Pets.get(b.id)
		return (if da then da.rarity else 0) > (if db then db.rarity else 0)
	end)
	for order, pet in sorted do
		local def = Pets.get(pet.id)
		if def then
			local rarity = Rarity.get(def.rarity)
			local selected = if selecting then marked[pet.uid] == true else pet.uid == selectedUid
			local button = Kit.new("TextButton", {
				Text = "",
				AutoButtonColor = false,
				BackgroundColor3 = Kit.Colors.Card,
				LayoutOrder = order,
				Parent = list,
			})
			Kit.corner(12).Parent = button
			Kit.stroke(
				if selected then 4 else 3,
				if selected then Kit.Colors.White else rarity.color,
				Enum.ApplyStrokeMode.Border
			).Parent =
				button
			local viewport = Preview.viewport({
				Size = UDim2.fromScale(0.9, 0.62),
				Position = UDim2.fromScale(0.05, 0.03),
				Parent = button,
			})
			Preview.pet(viewport, def.id)
			local mark = if table.find(profile.equippedPets, pet.uid) then "  ✓" else ""
			Kit.text({
				Text = `{def.name}{mark}\n+{Format.percent(def.bonus)}`,
				Size = UDim2.fromScale(0.94, 0.33),
				Position = UDim2.fromScale(0.03, 0.65),
				TextColor3 = rarity.color,
				Stroke = 2,
				Parent = button,
			})
			button.Activated:Connect(function()
				Kit.sound(Kit.Sounds.Click, 0.3)
				if selecting then
					if pet.locked or table.find(profile.equippedPets, pet.uid) then
						return
					end
					if marked[pet.uid] then
						marked[pet.uid] = nil
					else
						marked[pet.uid] = true
					end
					lastGrid = ""
				else
					selectedUid = pet.uid
				end
				refresh()
			end)
		end
	end
	if selectedUid and not owned(selectedUid) then
		selectedUid = nil
	end
	refreshDetail()
end

-- A card that pops over the menu with the pet that just hatched.
local function showHatch(pet: PetStats.OwnedPet, count: number)
	local def = Pets.get(pet.id)
	if not def or not built then
		return
	end
	local rarity = Rarity.get(def.rarity)
	if hatchCard then
		hatchCard:Destroy()
	end
	hatchCount += count
	local card = Kit.new("Frame", {
		Size = UDim2.fromScale(0.4, 0.62),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Kit.Colors.Ink,
		ZIndex = 20,
		Parent = content,
	})
	hatchCard = card
	Kit.corner(16).Parent = card
	Kit.stroke(5, rarity.color, Enum.ApplyStrokeMode.Border).Parent = card
	local viewport = Preview.viewport({
		Size = UDim2.fromScale(0.9, 0.55),
		Position = UDim2.fromScale(0.05, 0.03),
		ZIndex = 21,
		Parent = card,
	})
	Preview.pet(viewport, def.id, 1.2)
	Kit.text({
		Text = `{def.name}  NEW!`,
		Size = UDim2.fromScale(0.9, 0.12),
		Position = UDim2.fromScale(0.05, 0.58),
		TextColor3 = rarity.color,
		Stroke = 3,
		ZIndex = 21,
		Parent = card,
	})
	Kit.text({
		Text = `{rarity.name} · {KIND_LABEL[def.kind]} +{Format.percent(def.bonus)}`,
		Size = UDim2.fromScale(0.9, 0.08),
		Position = UDim2.fromScale(0.05, 0.71),
		Stroke = 2,
		ZIndex = 21,
		Parent = card,
	})
	Kit.button({
		name = "Nice",
		color = Kit.Colors.Blue,
		dark = Kit.Colors.BlueDark,
		size = UDim2.fromScale(0.6, 0.13),
		position = UDim2.fromScale(0.2, 0.83),
		text = if hatchCount == 1 then "Okay" else "Okay (" .. hatchCount .. " hatched)",
		parent = card,
		onClick = function()
			hatchCard = nil
			hatchCount = 0
			card:Destroy()
		end,
	})
	Kit.pop(card, 0.6)
	Kit.sound(Kit.Sounds.Ding, 0.5, 1 + def.rarity * 0.05)
	if def.rarity >= 5 then
		Kit.sound(Kit.Sounds.Boom, 0.35, 1.1)
		Effects.confetti({ rarity.color, rarity.glow, Color3.new(1, 1, 1) }, 80 + def.rarity * 20)
	end
	selectedUid = pet.uid
end

local function build(frame: Frame)
	built = true
	content = frame
	local eggs = Kit.new("Frame", {
		Size = UDim2.fromScale(0.27, 1),
		BackgroundTransparency = 1,
		Parent = frame,
	})
	Kit.new("UIListLayout", {
		Padding = UDim.new(0.02, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = eggs,
	})
	for order, egg in Pets.EGGS do
		local card = Kit.new("Frame", {
			Size = UDim2.fromScale(1, 0.32),
			BackgroundColor3 = Kit.Colors.Card,
			LayoutOrder = order,
			Parent = eggs,
		})
		Kit.corner(12).Parent = card
		Kit.stroke(3, egg.color, Enum.ApplyStrokeMode.Border).Parent = card
		local egg3d = Kit.new("Frame", {
			Size = UDim2.fromScale(0.26, 0.5),
			Position = UDim2.fromScale(0.04, 0.08),
			BackgroundColor3 = egg.color,
			Parent = card,
		})
		Kit.new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = egg3d })
		Kit.aspect(0.8).Parent = egg3d
		Kit.text({
			Text = egg.name,
			Size = UDim2.fromScale(0.64, 0.24),
			Position = UDim2.fromScale(0.33, 0.05),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = egg.color,
			Stroke = 2.5,
			Parent = card,
		})
		local odds = {}
		for _, entry in egg.pets do
			local def = Pets.get(entry.petId)
			if def then
				table.insert(odds, `{Rarity.get(def.rarity).name} {entry.weight}%`)
			end
		end
		Kit.text({
			Text = table.concat(odds, " · "),
			Size = UDim2.fromScale(0.64, 0.2),
			Position = UDim2.fromScale(0.33, 0.3),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			Stroke = 1.5,
			Parent = card,
		})
		local price = Kit.text({
			Text = "",
			Size = UDim2.fromScale(0.92, 0.18),
			Position = UDim2.fromScale(0.04, 0.55),
			TextColor3 = Color3.fromRGB(255, 220, 100),
			Stroke = 2,
			Parent = card,
		})
		local button = Kit.button({
			name = "Hatch",
			color = Kit.Colors.Green,
			dark = Kit.Colors.GreenDark,
			size = UDim2.fromScale(0.47, 0.22),
			position = UDim2.fromScale(0.05, 0.75),
			text = "Hatch",
			parent = card,
			onClick = function()
				Net.event("HatchEgg"):FireServer(egg.id)
			end,
		})
		Kit.button({
			name = "HatchThree",
			color = Kit.Colors.Blue,
			dark = Kit.Colors.BlueDark,
			size = UDim2.fromScale(0.4, 0.22),
			position = UDim2.fromScale(0.55, 0.75),
			text = "Hatch ×3",
			parent = card,
			onClick = function()
				Net.event("HatchEgg"):FireServer(egg.id, 3)
			end,
		})
		table.insert(eggCards, { egg = egg, price = price, button = button })
	end

	local right = Kit.new("Frame", {
		Size = UDim2.fromScale(0.71, 1),
		Position = UDim2.fromScale(0.29, 0),
		BackgroundTransparency = 1,
		Parent = frame,
	})
	equippedLabel = Kit.text({
		Text = "",
		Size = UDim2.fromScale(0.6, 0.07),
		TextXAlignment = Enum.TextXAlignment.Left,
		Stroke = 2.5,
		Parent = right,
	})
	for i, kind in { "Damage", "Training", "Ores" } do
		Kit.button({
			name = "Best" .. kind,
			color = Kit.Colors.Blue,
			dark = Kit.Colors.BlueDark,
			size = UDim2.fromScale(0.24, 0.075),
			position = UDim2.fromScale((i - 1) * 0.25, 0.085),
			text = "Best " .. kind,
			parent = right,
			onClick = function()
				Net.event("EquipBestPets"):FireServer(kind)
			end,
		})
	end
	releaseMany = Kit.button({
		name = "SelectPets",
		color = Kit.Colors.Red,
		dark = Kit.Colors.RedDark,
		size = UDim2.fromScale(0.24, 0.075),
		position = UDim2.fromScale(0.75, 0.085),
		text = "Select pets",
		parent = right,
		onClick = function()
			if selecting then
				local ids = {}
				for uid in marked do
					table.insert(ids, uid)
				end
				if #ids > 0 then
					Net.event("ReleasePet"):FireServer(ids)
				end
				table.clear(marked)
			end
			selecting = not selecting
			refresh()
		end,
	})
	list = Kit.new("ScrollingFrame", {
		Size = UDim2.fromScale(0.58, 0.82),
		Position = UDim2.fromScale(0, 0.18),
		BackgroundColor3 = Kit.Colors.Ink,
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = right,
	})
	Kit.corner(12).Parent = list
	Kit.padding(10).Parent = list
	Kit.new("UIGridLayout", {
		CellSize = UDim2.new(0.31, 0, 0, 130),
		CellPadding = UDim2.fromOffset(10, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = list,
	})
	detail = Kit.new("Frame", {
		Size = UDim2.fromScale(0.4, 0.82),
		Position = UDim2.fromScale(0.6, 0.18),
		BackgroundColor3 = Kit.Colors.Ink,
		BackgroundTransparency = 0.5,
		Visible = false,
		Parent = right,
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
		TextWrapped = true,
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
			if not profile or not selectedUid then
				return
			end
			if table.find(profile.equippedPets, selectedUid) then
				Net.event("UnequipPet"):FireServer(selectedUid)
			else
				Net.event("EquipPet"):FireServer(selectedUid)
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
				Net.event("LockPet"):FireServer(selectedUid)
			end
		end,
	})
	releaseButton = Kit.button({
		name = "Release",
		color = Kit.Colors.Red,
		dark = Kit.Colors.RedDark,
		size = UDim2.fromScale(0.43, 0.075),
		position = UDim2.fromScale(0.52, 0.9),
		text = "Release",
		parent = detail,
		onClick = function()
			if selectedUid then
				Net.event("ReleasePet"):FireServer(selectedUid)
			end
		end,
	})
	refresh()
end

function PetsMenu:Init()
	Menus.register({
		name = "Pets",
		title = "Pets",
		color = Color3.fromRGB(255, 140, 190),
		size = Vector2.new(0.72, 0.72),
		build = build,
		onOpen = refresh,
	})
end

function PetsMenu:Start()
	ClientState.ProfileChanged:Connect(function()
		if built and Menus.isOpen("Pets") then
			refresh()
		end
	end)
	ClientState.StatsChanged:Connect(function()
		if built and Menus.isOpen("Pets") then
			refreshEggs()
		end
	end)
	Net.event("Hatched").OnClientEvent:Connect(function(data)
		if typeof(data) == "table" and typeof(data.pet) == "table" then
			showHatch(data.pet, data.count or 1)
		end
	end)
end

return PetsMenu
