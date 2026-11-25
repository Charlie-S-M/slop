--!strict

--[[
	The forge: pick up to five ores from your bag, see the rarity odds and power range, and forge a
	new gun. The reveal plays a charge-up, a flash, and the gun spinning in on a rarity-colored
	burst.
]]

const TweenService = game:GetService("TweenService")

const Balance = require("@game/ReplicatedStorage/Shared/Balance")
const Format = require("@game/ReplicatedStorage/Shared/Format")
const Net = require("@game/ReplicatedStorage/Shared/Net")
const Ores = require("@game/ReplicatedStorage/Shared/Ores")
const Rarity = require("@game/ReplicatedStorage/Shared/Rarity")
const Upgrades = require("@game/ReplicatedStorage/Shared/Upgrades")
const ClientState = require("../ClientState")
const Kit = require("../UI/Kit")
const Menus = require("../Menus")
const Preview = require("../UI/Preview")
const Cutscene = require("../Cutscene/ForgeCutscene")
const EvolveView = require("./EvolveView")
const Timing = require("../Cutscene/TimingGame")
const Players = game:GetService("Players")

local Forge = {}

local selected: { string } = {}
local oreGrid: ScrollingFrame
local slotFrames: { Frame } = {}
local oddsRows: { { frame: Frame, fill: Frame, label: TextLabel } } = {}
local powerLabel: TextLabel
local forgeButton: TextButton
local built = false
local tab = "Forge"
local showTab: ((string) -> ())? = nil
local forging = false
local activeToken: string? = nil
local beganAt = 0
local strikes: { number } = {}

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

local function doForge()
	if forging or #selected == 0 then
		return
	end
	local request: { [string]: number } = {}
	for _, id in selected do
		request[id] = (request[id] or 0) + 1
	end
	Net.event("Forge"):FireServer(request)
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

	-- Everything above is the Forge tab; the Evolve tab sits beside it.
	local forgeView = Kit.new(
		"Frame",
		{ Name = "ForgeView", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }
	)
	for _, child in content:GetChildren() do
		child.Parent = forgeView
	end
	forgeView.Parent = content
	local evolveView = EvolveView.build(content)
	local tabs: { [string]: TextButton } = {}
	local function setTab(name: string)
		tab = name
		forgeView.Visible = name == "Forge"
		evolveView.Visible = name == "Evolve"
		for tabName, button in tabs do
			if tabName == name then
				Kit.setButtonColor(button, Kit.Colors.Orange, Kit.Colors.OrangeDark)
			else
				Kit.setButtonColor(button, Kit.Colors.GreyDark, Kit.Colors.Ink)
			end
		end
		if name == "Evolve" then
			EvolveView.refresh()
		else
			refreshOres()
		end
	end
	for index, name in { "Forge", "Evolve" } do
		tabs[name] = Kit.button({
			name = `{name}Tab`,
			color = Kit.Colors.GreyDark,
			dark = Kit.Colors.Ink,
			size = UDim2.new(0.15, 0, 0, 40),
			position = UDim2.new(0.5 + (index - 1) * 0.16, 0, 0, -52),
			text = if name == "Forge" then "🔨 Forge" else "✨ Evolve",
			parent = content,
			onClick = function()
				setTab(name)
			end,
		})
	end
	showTab = setTab
	setTab(tab)
end

function Forge:Init()
	Menus.register({
		name = "Forge",
		title = "Forge",
		color = Kit.Colors.Orange,
		size = Vector2.new(0.68, 0.72),
		build = build,
		onOpen = function()
			if built and showTab then
				showTab(tab)
			end
		end,
	})
end

function Forge:Start()
	local function abort()
		local token = activeToken
		activeToken = nil
		forging = false
		Cutscene.abort()
		if token then
			local completed = table.clone(strikes)
			task.delay(
				math.max(0, Balance.FORGE_MIN_SECONDS + 1 - (os.clock() - beganAt)),
				function()
					Net.event("ForgeFinish"):FireServer(token, completed)
				end
			)
		end
	end
	Players.LocalPlayer.CharacterRemoving:Connect(abort)
	local function bindDeath(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 8)
		if humanoid and humanoid:IsA("Humanoid") then
			humanoid.Died:Once(abort)
		end
	end
	Players.LocalPlayer.CharacterAdded:Connect(bindDeath)
	if Players.LocalPlayer.Character then
		task.spawn(bindDeath, Players.LocalPlayer.Character)
	end
	Net.event("ForgeStart").OnClientEvent:Connect(function(start)
		if activeToken then
			return
		end
		selected = {}
		forging = true
		activeToken = start.token
		beganAt = os.clock()
		strikes = {}
		local ok, err = pcall(function()
			Cutscene.play(start, function(index)
				local screen =
					Players.LocalPlayer.PlayerGui:FindFirstChild("ForgeCutscene") :: ScreenGui
				local score = Timing.strike(screen, index, Cutscene.anvilScreenPoint(), function()
					return activeToken == start.token
				end, function(value)
					strikes[index] = value
				end)
				return score
			end)
		end)
		if not ok then
			warn("Forge playback: ", err)
		end
		if activeToken == start.token then
			Net.event("ForgeFinish"):FireServer(start.token, strikes)
		end
	end)
	Net.event("ForgeResult").OnClientEvent:Connect(function(result)
		local reveal = activeToken ~= nil and Cutscene.playing
		activeToken = nil
		forging = false
		if reveal then
			Cutscene.reveal(result)
		end
		if built then
			refreshOres()
		end
	end)
	Net.event("EvolveResult").OnClientEvent:Connect(function(result)
		Cutscene.reveal({ item = result.item, new = false, better = false }, "EVOLVED!")
	end)
	ClientState.ProfileChanged:Connect(function()
		if built and Menus.isOpen("Forge") and not forging then
			if tab == "Evolve" then
				EvolveView.refresh()
			else
				refreshOres()
			end
		end
	end)
end
return Forge
