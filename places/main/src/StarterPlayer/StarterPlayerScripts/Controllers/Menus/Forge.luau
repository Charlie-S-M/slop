--!strict

--[[
	The forge: pick up to five ores from your bag, see the rarity odds and power range, and forge a
	new gun. The reveal plays a charge-up, a flash, and the gun spinning in on a rarity-colored
	burst.
]]

const TweenService = game:GetService("TweenService")

const Balance = require("@game/ReplicatedStorage/Shared/Balance")
const Format = require("@game/ReplicatedStorage/Shared/Format")
const Guns = require("@game/ReplicatedStorage/Shared/Guns")
const Net = require("@game/ReplicatedStorage/Shared/Net")
const Ores = require("@game/ReplicatedStorage/Shared/Ores")
const Rarity = require("@game/ReplicatedStorage/Shared/Rarity")
const Upgrades = require("@game/ReplicatedStorage/Shared/Upgrades")
const ClientState = require("../ClientState")
const Effects = require("../Effects")
const Kit = require("../UI/Kit")
const Menus = require("../Menus")
const Preview = require("../UI/Preview")

local Forge = {}

local selected: { string } = {}
local oreGrid: ScrollingFrame
local slotFrames: { Frame } = {}
local oddsRows: { { frame: Frame, fill: Frame, label: TextLabel } } = {}
local powerLabel: TextLabel
local forgeButton: TextButton
local overlay: Frame
local overlayViewport: ViewportFrame
local overlayTitle: TextLabel
local overlaySub: TextLabel
local overlayGlow: Frame
local overlayRays: Frame
local overlayButtons: Frame
local equipNewButton: TextButton
local built = false
local forging = false
local pendingResult: any = nil
local lastResultUid: string? = nil

local function selectedCount(id: string): number
	local count = 0
	for _, value in selected do
		if value == id then
			count += 1
		end
	end
	return count
end

local function selectedDefs(): { Ores.OreDef }
	local list = {}
	for _, id in selected do
		local ore = Ores.get(id)
		if ore then
			table.insert(list, ore)
		end
	end
	return list
end

local function refreshOdds()
	local profile = ClientState.profile
	local luck = Upgrades.value("Luck", if profile then profile.upgrades.Luck or 0 else 0)
	local odds = Balance.forgeOdds(selectedDefs(), luck)
	local bestTier = 1
	for tier, row in oddsRows do
		local chance = odds.chances[tier] or 0
		row.frame.Visible = chance > 0.0005 or #selected == 0 and tier <= 2
		TweenService
			:Create(row.fill, Kit.FAST, { Size = UDim2.fromScale(math.clamp(chance, 0, 1), 1) })
			:Play()
		row.label.Text = `{Rarity.get(tier).name}  {Format.percent(chance)}`
		if chance > (odds.chances[bestTier] or 0) then
			bestTier = tier
		end
	end
	if #selected == 0 then
		powerLabel.Text = "Add ores to see the power range"
		Kit.setButtonColor(forgeButton, Kit.Colors.Grey, Kit.Colors.GreyDark)
		return
	end
	-- The range runs from the weakest likely roll to the best rarity still on the table.
	local lowTier = Rarity.Count
	local topTier = 1
	for tier = 1, Rarity.Count do
		if (odds.chances[tier] or 0) > 0.0005 then
			lowTier = math.min(lowTier, tier)
			topTier = tier
		end
	end
	local low = Balance.forgePowerRange(odds.basePower, lowTier)
	local _, high = Balance.forgePowerRange(odds.basePower, topTier)
	powerLabel.Text = `⚡ Power {Format.abbreviate(low)} – {Format.abbreviate(high)}`
	Kit.setButtonColor(forgeButton, Kit.Colors.Orange, Kit.Colors.OrangeDark)
end

local function refreshSlots()
	for index, slot in slotFrames do
		local id = selected[index]
		local viewport = slot:FindFirstChild("Viewport") :: ViewportFrame
		local plus = slot:FindFirstChild("Plus") :: TextLabel
		if id then
			Preview.ore(viewport, id, 1.2)
			plus.Visible = false
			local ore = Ores.get(id)
			local stroke = slot:FindFirstChildOfClass("UIStroke")
			if stroke and ore then
				stroke.Color = Rarity.get(ore.rarity).color
			end
		else
			viewport:ClearAllChildren()
			plus.Visible = true
			local stroke = slot:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = Kit.Colors.Ink
			end
		end
	end
	refreshOdds()
end

local function refreshOres()
	local profile = ClientState.profile
	if not profile then
		return
	end
	-- Drop selections the bag can no longer cover.
	local index = 1
	while index <= #selected do
		local id = selected[index]
		if selectedCount(id) > (profile.bag[id] or 0) then
			table.remove(selected, index)
		else
			index += 1
		end
	end
	for _, child in oreGrid:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	local any = false
	for order, ore in Ores.List do
		local owned = profile.bag[ore.id] or 0
		if owned <= 0 then
			continue
		end
		any = true
		local available = owned - selectedCount(ore.id)
		local rarity = Rarity.get(ore.rarity)
		local button = Kit.new("TextButton", {
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = Kit.Colors.Card,
			LayoutOrder = -order,
			Parent = oreGrid,
		})
		Kit.corner(10).Parent = button
		Kit.stroke(3, rarity.color, Enum.ApplyStrokeMode.Border).Parent = button
		Kit.gradient(rarity.color:Lerp(Kit.Colors.Card, 0.5), Kit.Colors.Card).Parent = button
		local viewport = Preview.viewport({
			Size = UDim2.fromScale(0.8, 0.6),
			Position = UDim2.fromScale(0.1, 0.03),
			Parent = button,
		})
		Preview.ore(viewport, ore.id)
		Kit.text({
			Text = `x{available}`,
			Size = UDim2.fromScale(0.5, 0.22),
			Position = UDim2.fromScale(0.48, 0.02),
			TextXAlignment = Enum.TextXAlignment.Right,
			Stroke = 2,
			Parent = button,
		})
		Kit.text({
			Text = ore.name,
			Size = UDim2.fromScale(0.94, 0.2),
			Position = UDim2.fromScale(0.03, 0.66),
			TextColor3 = rarity.color:Lerp(Color3.new(1, 1, 1), 0.3),
			Stroke = 2,
			Parent = button,
		})
		Kit.text({
			Text = rarity.name,
			Size = UDim2.fromScale(0.8, 0.13),
			Position = UDim2.fromScale(0.1, 0.85),
			Stroke = 1.5,
			Parent = button,
		})
		if available <= 0 then
			button.BackgroundTransparency = 0.6
		end
		button.Activated:Connect(function()
			if available > 0 and #selected < Balance.MAX_FORGE_ORES then
				table.insert(selected, ore.id)
				Kit.sound(Kit.Sounds.Pop, 0.35, 1.2)
				refreshOres()
				refreshSlots()
			else
				Kit.sound(Kit.Sounds.Error, 0.2)
			end
		end)
	end
	if not any then
		Kit.text({
			Name = "Empty",
			Text = "No ores yet! Defeat enemies in the Gauntlet to collect them.",
			Size = UDim2.new(1, 0, 0, 60),
			Stroke = 2,
			Parent = oreGrid,
		})
	else
		local empty = oreGrid:FindFirstChild("Empty")
		if empty then
			empty:Destroy()
		end
	end
	refreshSlots()
end

-- Fills the slots with the best ores in the bag, strongest first.
local function autoFill()
	local profile = ClientState.profile
	if not profile then
		return
	end
	selected = {}
	for index = #Ores.List, 1, -1 do
		local ore = Ores.List[index]
		local owned = profile.bag[ore.id] or 0
		for _ = 1, owned do
			if #selected >= Balance.MAX_FORGE_ORES then
				break
			end
			table.insert(selected, ore.id)
		end
	end
	refreshOres()
end

local function showResult(result: any)
	local item = result.item
	local def = Guns.get(item.id)
	if not def then
		return
	end
	local rarity = Rarity.get(def.rarity)
	lastResultUid = item.uid
	Preview.gun(overlayViewport, def.id, 1.4)
	overlayViewport.Visible = true
	overlayTitle.Text = def.name
	overlayTitle.TextColor3 = rarity.color:Lerp(Color3.new(1, 1, 1), 0.25)
	overlaySub.Text = `{rarity.name} {def.kind} · ⚡ {Format.abbreviate(item.power)} Power`
		.. (if result.new then "  ·  NEW!" else "")
	overlayGlow.BackgroundColor3 = rarity.color
	overlayGlow.BackgroundTransparency = 0.25
	TweenService:Create(overlayGlow, TweenInfo.new(1.2), { BackgroundTransparency = 0.75 }):Play()
	-- A sunburst of rarity-colored rays turns slowly behind the new gun.
	overlayRays.Visible = true
	for _, ray in overlayRays:GetChildren() do
		if ray:IsA("Frame") then
			ray.BackgroundColor3 = rarity.glow
			ray.BackgroundTransparency = if def.rarity >= 4 then 0.35 else 0.6
		end
	end
	task.spawn(function()
		local started = os.clock()
		while overlay.Visible and overlayRays.Visible do
			overlayRays.Rotation = (os.clock() - started) * 20
			task.wait()
		end
	end)
	if def.rarity >= 5 then
		Effects.confetti({ rarity.color, rarity.glow, Color3.new(1, 1, 1) }, 70)
	end
	overlayButtons.Visible = true
	equipNewButton.Visible = true
	Kit.setButtonText(equipNewButton, if result.better then "Equip (Stronger!)" else "Equip")
	Kit.pop(overlayViewport, 1.4)
	Kit.sound(Kit.Sounds.Ding, 0.5, 1 + def.rarity * 0.04)
	if def.rarity >= 4 then
		Kit.sound(Kit.Sounds.Boom, 0.3, 1.2)
	end
end

local function playForging()
	forging = true
	overlay.Visible = true
	overlayViewport.Visible = false
	overlayButtons.Visible = false
	overlayTitle.Text = "Forging..."
	overlayTitle.TextColor3 = Color3.fromRGB(255, 180, 60)
	overlaySub.Text = "The ores melt into something new"
	overlayGlow.BackgroundColor3 = Color3.fromRGB(255, 130, 30)
	overlayGlow.BackgroundTransparency = 0.6
	overlayRays.Visible = false
	Kit.sound(Kit.Sounds.Charge, 0.5)
	Kit.sound(Kit.Sounds.Riser, 0.35)
	-- The glow pulses faster and faster as the forge heats up.
	local started = os.clock()
	while os.clock() - started < Balance.FORGE_SECONDS do
		local t = (os.clock() - started) / Balance.FORGE_SECONDS
		overlayGlow.BackgroundTransparency = 0.55 - math.abs(math.sin(t * t * 30)) * 0.35
		overlayTitle.Rotation = math.sin(os.clock() * 40) * t * 4
		task.wait()
	end
	overlayTitle.Rotation = 0
	forging = false
	-- The server usually answers long before the animation ends.
	local waited = 0
	while not pendingResult and waited < 3 do
		waited += task.wait()
	end
	if pendingResult then
		showResult(pendingResult)
		pendingResult = nil
	else
		overlay.Visible = false
	end
end

local function doForge()
	if forging or #selected == 0 then
		return
	end
	local request: { [string]: number } = {}
	for _, id in selected do
		request[id] = (request[id] or 0) + 1
	end
	pendingResult = nil
	Net.event("Forge"):FireServer(request)
	selected = {}
	task.spawn(playForging)
end

local function build(content: Frame)
	built = true
	Kit.text({
		Text = "Your Ores",
		Size = UDim2.fromScale(0.3, 0.07),
		TextXAlignment = Enum.TextXAlignment.Left,
		Stroke = 2.5,
		Parent = content,
	})
	oreGrid = Kit.new("ScrollingFrame", {
		Size = UDim2.fromScale(0.5, 0.9),
		Position = UDim2.fromScale(0, 0.09),
		BackgroundColor3 = Kit.Colors.Ink,
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = content,
	})
	Kit.corner(12).Parent = oreGrid
	Kit.padding(10).Parent = oreGrid
	Kit.new("UIGridLayout", {
		CellSize = UDim2.new(0.3, 0, 0, 130),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = oreGrid,
	})

	local right = Kit.new("Frame", {
		Size = UDim2.fromScale(0.47, 1),
		Position = UDim2.fromScale(0.53, 0),
		BackgroundTransparency = 1,
		Parent = content,
	})
	Kit.text({
		Text = "Forge Slots",
		Size = UDim2.fromScale(0.6, 0.07),
		TextXAlignment = Enum.TextXAlignment.Left,
		Stroke = 2.5,
		Parent = right,
	})
	local slots = Kit.new("Frame", {
		Size = UDim2.fromScale(1, 0.17),
		Position = UDim2.fromScale(0, 0.08),
		BackgroundTransparency = 1,
		Parent = right,
	})
	Kit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0.025, 0),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = slots,
	})
	for index = 1, Balance.MAX_FORGE_ORES do
		local slot = Kit.new("TextButton", {
			Text = "",
			AutoButtonColor = false,
			Size = UDim2.fromScale(0.18, 1),
			BackgroundColor3 = Kit.Colors.Card,
			LayoutOrder = index,
			Parent = slots,
		})
		Kit.aspect(1).Parent = slot
		Kit.corner(10).Parent = slot
		Kit.stroke(3, Kit.Colors.Ink, Enum.ApplyStrokeMode.Border).Parent = slot
		Kit.text({
			Name = "Plus",
			Text = "+",
			Size = UDim2.fromScale(0.6, 0.6),
			Position = UDim2.fromScale(0.2, 0.2),
			TextColor3 = Kit.Colors.Grey,
			Stroke = 2,
			Parent = slot,
		})
		Preview.viewport({ Name = "Viewport", Parent = slot })
		slot.Activated:Connect(function()
			if selected[index] then
				table.remove(selected, index)
				Kit.sound(Kit.Sounds.Click, 0.3)
				refreshOres()
			end
		end)
		table.insert(slotFrames, slot :: any)
	end

	Kit.button({
		name = "Auto",
		color = Kit.Colors.Blue,
		dark = Kit.Colors.BlueDark,
		size = UDim2.fromScale(0.36, 0.08),
		position = UDim2.fromScale(0.1, 0.27),
		text = "Auto Fill",
		parent = right,
		onClick = autoFill,
	})
	Kit.button({
		name = "Clear",
		color = Kit.Colors.GreyDark,
		dark = Kit.Colors.Ink,
		size = UDim2.fromScale(0.36, 0.08),
		position = UDim2.fromScale(0.54, 0.27),
		text = "Clear",
		parent = right,
		onClick = function()
			selected = {}
			refreshOres()
		end,
	})

	local oddsBox = Kit.new("Frame", {
		Size = UDim2.fromScale(1, 0.4),
		Position = UDim2.fromScale(0, 0.38),
		BackgroundColor3 = Kit.Colors.Ink,
		BackgroundTransparency = 0.5,
		Parent = right,
	})
	Kit.corner(12).Parent = oddsBox
	Kit.padding(8).Parent = oddsBox
	Kit.new(
		"UIListLayout",
		{ Padding = UDim.new(0.02, 0), SortOrder = Enum.SortOrder.LayoutOrder, Parent = oddsBox }
	)
	for tier = 1, Rarity.Count do
		local rarity = Rarity.get(tier)
		local row = Kit.new("Frame", {
			Size = UDim2.fromScale(1, 0.12),
			BackgroundColor3 = Kit.Colors.Card,
			LayoutOrder = tier,
			Parent = oddsBox,
		})
		Kit.cornerScale(0.5).Parent = row
		local fill = Kit.new("Frame", {
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = rarity.color,
			BorderSizePixel = 0,
			Parent = row,
		})
		Kit.cornerScale(0.5).Parent = fill
		local label = Kit.text({
			Text = rarity.name,
			Size = UDim2.fromScale(0.94, 0.9),
			Position = UDim2.fromScale(0.03, 0.05),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 3,
			Stroke = 2,
			Parent = row,
		})
		table.insert(oddsRows, { frame = row, fill = fill, label = label })
	end
	powerLabel = Kit.text({
		Text = "",
		Size = UDim2.fromScale(1, 0.06),
		Position = UDim2.fromScale(0, 0.79),
		TextColor3 = Color3.fromRGB(255, 220, 100),
		Stroke = 2.5,
		Parent = right,
	})
	forgeButton = Kit.button({
		name = "Forge",
		color = Kit.Colors.Orange,
		dark = Kit.Colors.OrangeDark,
		size = UDim2.fromScale(0.8, 0.11),
		position = UDim2.fromScale(0.1, 0.87),
		text = "🔨 FORGE",
		parent = right,
		onClick = doForge,
	})

	-- The forging and reveal overlay covers the whole window.
	overlay = Kit.new("Frame", {
		Name = "Overlay",
		Size = UDim2.new(1, 20, 1, 20),
		Position = UDim2.fromOffset(-10, -10),
		BackgroundColor3 = Kit.Colors.Ink,
		BackgroundTransparency = 0.08,
		Visible = false,
		ZIndex = 20,
		Parent = content,
	})
	Kit.corner(16).Parent = overlay
	overlayGlow = Kit.new("Frame", {
		Size = UDim2.fromScale(0.6, 0.6),
		Position = UDim2.fromScale(0.5, 0.42),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(255, 130, 30),
		BackgroundTransparency = 0.6,
		ZIndex = 21,
		Parent = overlay,
	})
	Kit.cornerScale(0.5).Parent = overlayGlow
	Kit.aspect(1).Parent = overlayGlow
	-- Twelve thin bars through the center make the sunburst.
	overlayRays = Kit.new("Frame", {
		Name = "Rays",
		Size = UDim2.fromScale(0.9, 0.9),
		Position = UDim2.fromScale(0.5, 0.42),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 21,
		Parent = overlay,
	})
	Kit.aspect(1).Parent = overlayRays
	for index = 0, 11 do
		local ray = Kit.new("Frame", {
			Size = UDim2.fromScale(0.07, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = index * 15,
			BorderSizePixel = 0,
			ZIndex = 21,
			Parent = overlayRays,
		})
		Kit.new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Rotation = 90,
			Parent = ray,
		})
	end
	overlayViewport = Preview.viewport({
		Size = UDim2.fromScale(0.7, 0.55),
		Position = UDim2.fromScale(0.5, 0.42),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 22,
		Parent = overlay,
	})
	overlayTitle = Kit.text({
		Text = "",
		Size = UDim2.fromScale(0.8, 0.1),
		Position = UDim2.fromScale(0.1, 0.03),
		ZIndex = 23,
		Stroke = 4,
		Parent = overlay,
	})
	overlaySub = Kit.text({
		Text = "",
		Size = UDim2.fromScale(0.8, 0.06),
		Position = UDim2.fromScale(0.1, 0.72),
		ZIndex = 23,
		Stroke = 2.5,
		Parent = overlay,
	})
	overlayButtons = Kit.new("Frame", {
		Size = UDim2.fromScale(0.7, 0.12),
		Position = UDim2.fromScale(0.15, 0.82),
		BackgroundTransparency = 1,
		ZIndex = 23,
		Parent = overlay,
	})
	equipNewButton = Kit.button({
		name = "EquipNew",
		color = Kit.Colors.Green,
		dark = Kit.Colors.GreenDark,
		size = UDim2.fromScale(0.48, 1),
		text = "Equip",
		parent = overlayButtons,
		onClick = function()
			if lastResultUid then
				Net.event("Equip"):FireServer(lastResultUid)
			end
			overlay.Visible = false
		end,
	})
	Kit.button({
		name = "Continue",
		color = Kit.Colors.Blue,
		dark = Kit.Colors.BlueDark,
		size = UDim2.fromScale(0.48, 1),
		position = UDim2.fromScale(0.52, 0),
		text = "Continue",
		parent = overlayButtons,
		onClick = function()
			overlay.Visible = false
		end,
	})
	for _, descendant in overlayButtons:GetDescendants() do
		if descendant:IsA("GuiObject") then
			descendant.ZIndex += 23
		end
	end
	refreshOres()
end

function Forge:Init()
	Menus.register({
		name = "Forge",
		title = "Forge",
		color = Kit.Colors.Orange,
		size = Vector2.new(0.68, 0.72),
		build = build,
		onOpen = function()
			if built then
				overlay.Visible = forging
				refreshOres()
			end
		end,
	})
end

function Forge:Start()
	Net.event("ForgeResult").OnClientEvent:Connect(function(result)
		pendingResult = result
	end)
	ClientState.ProfileChanged:Connect(function()
		if built and Menus.isOpen("Forge") and not forging and not overlay.Visible then
			refreshOres()
		end
	end)
end

return Forge
