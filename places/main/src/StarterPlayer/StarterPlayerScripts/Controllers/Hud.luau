--!strict

--[[
	The always-on HUD: power up top, the menu grid on the left, currency pills bottom-left, health,
	level, and ammo along the bottom, the auto-fire toggle bottom-right, and the stage panel with a
	Back button while in the Gauntlet.
]]

const Players = game:GetService("Players")
const RunService = game:GetService("RunService")
const TweenService = game:GetService("TweenService")
const UserInputService = game:GetService("UserInputService")

const Balance = require("@game/ReplicatedStorage/Shared/Balance")
const Biomes = require("@game/ReplicatedStorage/Shared/Biomes")
const Format = require("@game/ReplicatedStorage/Shared/Format")
const Net = require("@game/ReplicatedStorage/Shared/Net")
const Quests = require("@game/ReplicatedStorage/Shared/Quests")
const Signal = require("@game/ReplicatedStorage/Shared/Signal")
const ClientState = require("./ClientState")
const Kit = require("./UI/Kit")
const Menus = require("./Menus")

local Hud = {}

-- Fired when the auto-fire toggle changes; the gun controller listens.
Hud.AutoChanged = Signal.new() :: Signal.Signal<boolean>
Hud.autoFire = false

local screen: ScreenGui
local powerLabel: TextLabel
local damageLabel: TextLabel
local coinsLabel: TextLabel
local bagLabel: TextLabel
local rebirthLabel: TextLabel
local levelLabel: TextLabel
local levelFill: Frame
local levelText: TextLabel
local healthFill: Frame
local healthText: TextLabel
local ammoLabel: TextLabel
local autoButton: TextButton
local runPanel: Frame
-- The countdown to the next stage or Tower wave, with a Skip button.
local nextBar: Frame
local nextFill: Frame
local nextLabel: TextLabel
local nextDeadline = 0
local nextTotal = 1
local nextIsWave = false
local stageLabel: TextLabel
local enemiesLabel: TextLabel
local suggestedLabel: TextLabel
local backButton: TextButton
local badges: { [string]: Frame } = {}

type MenuButton = { name: string, glyph: string, color: Color3, key: Enum.KeyCode? }

const MENU_BUTTONS: { MenuButton } = {
	{
		name = "Backpack",
		glyph = "🎒",
		color = Color3.fromRGB(230, 140, 60),
		key = Enum.KeyCode.G,
	},
	{
		name = "Upgrades",
		glyph = "⬆️",
		color = Color3.fromRGB(70, 170, 255),
		key = Enum.KeyCode.U,
	},
	{ name = "Index", glyph = "📖", color = Color3.fromRGB(150, 100, 70), key = Enum.KeyCode.I },
	{ name = "Pets", glyph = "🐾", color = Color3.fromRGB(255, 140, 190), key = Enum.KeyCode.P },
	{ name = "Rebirth", glyph = "🔄", color = Color3.fromRGB(170, 90, 255), key = nil },
	{ name = "Daily", glyph = "🎁", color = Color3.fromRGB(70, 200, 90), key = nil },
	{ name = "Gauntlet", glyph = "⚔️", color = Color3.fromRGB(235, 70, 90), key = nil },
	{ name = "Quests", glyph = "📜", color = Color3.fromRGB(255, 160, 60), key = Enum.KeyCode.Q },
	{ name = "Settings", glyph = "⚙️", color = Color3.fromRGB(150, 160, 185), key = nil },
}

local function pill(parent: Instance, glyph: string, color: Color3, order: number): TextLabel
	local frame = Kit.new("Frame", {
		Name = "Pill",
		Size = UDim2.fromScale(1, 0.3),
		BackgroundColor3 = Kit.Colors.Ink,
		BackgroundTransparency = 0.35,
		LayoutOrder = order,
		Parent = parent,
	})
	Kit.cornerScale(0.5).Parent = frame
	local icon = Kit.iconTile(glyph, color, UDim2.fromScale(0.26, 1.05), frame)
	icon.Position = UDim2.fromScale(-0.04, -0.025)
	Kit.aspect(1).Parent = icon
	return Kit.text({
		Name = "Value",
		Text = "0",
		Size = UDim2.fromScale(0.68, 0.85),
		Position = UDim2.fromScale(0.3, 0.075),
		TextXAlignment = Enum.TextXAlignment.Left,
		Stroke = 3,
		Parent = frame,
	})
end

local function bar(
	parent: Instance,
	name: string,
	color: Color3,
	size: UDim2,
	position: UDim2
): (Frame, Frame, TextLabel)
	local back = Kit.new("Frame", {
		Name = name,
		Size = size,
		Position = position,
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = Kit.Colors.Ink,
		Parent = parent,
	})
	Kit.cornerScale(0.5).Parent = back
	Kit.stroke(3, Kit.Colors.Ink, Enum.ApplyStrokeMode.Border).Parent = back
	local fill = Kit.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0.5, 1),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = back,
	})
	Kit.cornerScale(0.5).Parent = fill
	Kit.gradient(color:Lerp(Color3.new(1, 1, 1), 0.3), color:Lerp(Color3.new(0, 0, 0), 0.15)).Parent =
		fill
	local text = Kit.text({
		Name = "Text",
		Size = UDim2.fromScale(0.96, 0.82),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 3,
		Stroke = 2.5,
		Parent = back,
	})
	return back, fill, text
end

-- The loadout bar's look, shared by the side buttons: a dark glassy panel with a soft blue edge.
const PANEL_COLOR = Color3.fromRGB(22, 26, 34)
const PANEL_EDGE = Color3.fromRGB(70, 150, 220)
const TILE_COLOR = Color3.fromRGB(34, 40, 52)
const TILE_EDGE = Color3.fromRGB(70, 80, 100)
const LABEL_COLOR = Color3.fromRGB(190, 205, 225)

local function buildMenuGrid()
	local panel = Kit.new("Frame", {
		Name = "MenuGrid",
		Size = UDim2.fromScale(0.13, 0.6),
		Position = UDim2.fromScale(0.012, 0.49),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = PANEL_COLOR,
		BackgroundTransparency = 0.12,
		Parent = screen,
	})
	Kit.new(
		"UISizeConstraint",
		{ MaxSize = Vector2.new(200, 470), MinSize = Vector2.new(118, 260), Parent = panel }
	)
	Kit.new("UICorner", { CornerRadius = UDim.new(0, 20), Parent = panel })
	Kit.new("UIStroke", { Color = PANEL_EDGE, Thickness = 2, Transparency = 0.35, Parent = panel })
	Kit.text({
		Text = "MENU",
		Size = UDim2.fromScale(0.6, 0.04),
		Position = UDim2.fromScale(0.08, 0.012),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = LABEL_COLOR,
		Stroke = 0,
		Gradient = false,
		Parent = panel,
	})
	local grid = Kit.new("Frame", {
		Name = "Buttons",
		Size = UDim2.fromScale(0.88, 0.9),
		Position = UDim2.fromScale(0.06, 0.07),
		BackgroundTransparency = 1,
		Parent = panel,
	})
	Kit.new("UIGridLayout", {
		CellSize = UDim2.fromScale(0.47, 0.18),
		CellPadding = UDim2.fromScale(0.06, 0.025),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})
	for index, info in MENU_BUTTONS do
		local holder = Kit.new("Frame", {
			Name = info.name,
			BackgroundTransparency = 1,
			LayoutOrder = index,
			Parent = grid,
		})
		local button = Kit.new("TextButton", {
			Name = "Button",
			Text = "",
			AutoButtonColor = false,
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = TILE_COLOR,
			Parent = holder,
		})
		Kit.new("UICorner", { CornerRadius = UDim.new(0, 12), Parent = button })
		local edge = Kit.new("UIStroke", {
			Color = TILE_EDGE,
			Thickness = 2,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = button,
		})
		local scale = Kit.new("UIScale", { Scale = 1, Parent = button })
		-- The button's own color, as a slim strip along its bottom edge.
		local strip = Kit.new("Frame", {
			Name = "Accent",
			Size = UDim2.fromScale(0.5, 0.05),
			Position = UDim2.fromScale(0.5, 0.95),
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = info.color,
			BorderSizePixel = 0,
			Parent = button,
		})
		Kit.cornerScale(0.5).Parent = strip
		Kit.text({
			Name = "Glyph",
			Text = info.glyph,
			Size = UDim2.fromScale(0.5, 0.46),
			Position = UDim2.fromScale(0.5, 0.1),
			AnchorPoint = Vector2.new(0.5, 0),
			Stroke = 0,
			Gradient = false,
			FontFace = Kit.FONT_BODY,
			Parent = button,
		})
		Kit.text({
			Name = "Name",
			Text = info.name,
			Size = UDim2.fromScale(0.92, 0.24),
			Position = UDim2.fromScale(0.5, 0.86),
			AnchorPoint = Vector2.new(0.5, 1),
			TextColor3 = LABEL_COLOR,
			Stroke = 1.5,
			Gradient = false,
			Parent = button,
		})
		if info.key then
			Kit.text({
				Name = "Key",
				Text = info.key.Name,
				Size = UDim2.fromScale(0.2, 0.18),
				Position = UDim2.fromScale(0.94, 0.06),
				AnchorPoint = Vector2.new(1, 0),
				TextColor3 = Color3.fromRGB(120, 135, 160),
				Stroke = 0,
				Gradient = false,
				Parent = button,
			})
		end
		button.MouseEnter:Connect(function()
			TweenService:Create(edge, Kit.FAST, { Color = info.color }):Play()
			TweenService:Create(scale, Kit.FAST, { Scale = 1.05 }):Play()
		end)
		button.MouseLeave:Connect(function()
			TweenService:Create(edge, Kit.FAST, { Color = TILE_EDGE }):Play()
			TweenService:Create(scale, Kit.FAST, { Scale = 1 }):Play()
		end)
		button.Activated:Connect(function()
			Kit.sound(Kit.Sounds.Click, 0.4)
			Kit.pop(button)
			Menus.toggle(info.name)
		end)
		local badge = Kit.new("Frame", {
			Name = "Badge",
			Size = UDim2.fromScale(0.3, 0.3),
			Position = UDim2.fromScale(0.86, 0.02),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Kit.Colors.Red,
			Visible = false,
			ZIndex = 8,
			Parent = holder,
		})
		Kit.aspect(1).Parent = badge
		Kit.cornerScale(0.5).Parent = badge
		Kit.stroke(2.5, Kit.Colors.White, Enum.ApplyStrokeMode.Border).Parent = badge
		Kit.text({
			Text = "!",
			Size = UDim2.fromScale(0.8, 0.8),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			ZIndex = 9,
			Stroke = 1.5,
			Parent = badge,
		})
		badges[info.name] = badge
	end
end

local function buildTop()
	local top = Kit.new("Frame", {
		Name = "Top",
		Size = UDim2.fromScale(0.36, 0.11),
		Position = UDim2.fromScale(0.5, 0.012),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Parent = screen,
	})
	Kit.new("UISizeConstraint", { MaxSize = Vector2.new(520, 110), Parent = top })
	Kit.text({
		Name = "PowerTitle",
		Text = "⚡ POWER",
		Size = UDim2.fromScale(0.5, 0.3),
		Position = UDim2.fromScale(0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		TextColor3 = Color3.fromRGB(255, 225, 90),
		Stroke = 2.5,
		Parent = top,
	})
	powerLabel = Kit.text({
		Name = "Power",
		Text = "0",
		Size = UDim2.fromScale(1, 0.62),
		Position = UDim2.fromScale(0.5, 0.28),
		AnchorPoint = Vector2.new(0.5, 0),
		Stroke = 4,
		Gradient = false,
		Parent = top,
	})
	Kit.gradient(Color3.fromRGB(255, 240, 120), Color3.fromRGB(255, 150, 40)).Parent = powerLabel
end

local function buildBottom()
	local bottom = Kit.new("Frame", {
		Name = "Bottom",
		Size = UDim2.fromScale(0.4, 0.2),
		Position = UDim2.fromScale(0.5, 0.99),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Parent = screen,
	})
	Kit.new("UISizeConstraint", { MaxSize = Vector2.new(560, 170), Parent = bottom })
	damageLabel = Kit.text({
		Name = "Damage",
		Text = "0 Damage",
		Size = UDim2.fromScale(0.7, 0.2),
		Position = UDim2.fromScale(0.5, 0.02),
		AnchorPoint = Vector2.new(0.5, 0),
		TextColor3 = Color3.fromRGB(255, 205, 90),
		Stroke = 3,
		Parent = bottom,
	})
	local _, hFill, hText = bar(
		bottom,
		"Health",
		Color3.fromRGB(235, 55, 60),
		UDim2.fromScale(0.86, 0.2),
		UDim2.fromScale(0.5, 0.48)
	)
	healthFill = hFill
	healthText = hText
	Kit.text({
		Name = "Heart",
		Text = "❤️",
		Size = UDim2.fromScale(0.09, 0.26),
		Position = UDim2.fromScale(0.04, 0.35),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Stroke = 0,
		Gradient = false,
		FontFace = Kit.FONT_BODY,
		ZIndex = 5,
		Parent = bottom,
	})
	local levelBack, lFill, lText = bar(
		bottom,
		"Level",
		Color3.fromRGB(255, 160, 40),
		UDim2.fromScale(0.86, 0.24),
		UDim2.fromScale(0.5, 0.78)
	)
	levelFill = lFill
	levelText = lText
	lText.TextXAlignment = Enum.TextXAlignment.Right
	levelLabel = Kit.text({
		Name = "LevelNumber",
		Text = "Lv. 1",
		Size = UDim2.fromScale(0.3, 0.9),
		Position = UDim2.fromScale(0.03, 0.05),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
		Stroke = 2.5,
		Parent = levelBack,
	})

	local ammoFrame = Kit.new("Frame", {
		Name = "Ammo",
		Size = UDim2.fromScale(0.2, 0.26),
		Position = UDim2.fromScale(1.02, 0.78),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundTransparency = 1,
		Parent = bottom,
	})
	ammoLabel = Kit.text({
		Name = "Value",
		Text = "12 / 12",
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 225, 120),
		Stroke = 3,
		Parent = ammoFrame,
	})
end

local function buildPills()
	local column = Kit.new("Frame", {
		Name = "Pills",
		Size = UDim2.fromScale(0.15, 0.17),
		Position = UDim2.fromScale(0.012, 0.985),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundTransparency = 1,
		Parent = screen,
	})
	Kit.new("UISizeConstraint", { MaxSize = Vector2.new(230, 150), Parent = column })
	Kit.new("UIListLayout", {
		Padding = UDim.new(0.04, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		Parent = column,
	})
	bagLabel = pill(column, "🎒", Color3.fromRGB(230, 140, 60), 1)
	coinsLabel = pill(column, "💰", Color3.fromRGB(255, 200, 40), 2)
	rebirthLabel = pill(column, "🔄", Color3.fromRGB(170, 90, 255), 3)
end

local function setAuto(on: boolean)
	Hud.autoFire = on
	local face = autoButton:FindFirstChild("Face")
	local label = face and face:FindFirstChild("State") :: TextLabel?
	if label then
		label.Text = if on then "ON" else "OFF"
		label.TextColor3 = if on
			then Color3.fromRGB(140, 255, 120)
			else Color3.fromRGB(255, 140, 140)
	end
	if on then
		Kit.setButtonColor(autoButton, Kit.Colors.Green, Kit.Colors.GreenDark)
	else
		Kit.setButtonColor(autoButton, Kit.Colors.Grey, Kit.Colors.GreyDark)
	end
	Hud.AutoChanged:Fire(on)
end

local function buildRight()
	autoButton = Kit.button({
		name = "Auto",
		color = Kit.Colors.Grey,
		dark = Kit.Colors.GreyDark,
		size = UDim2.fromScale(0.085, 0.1),
		position = UDim2.fromScale(0.985, 0.97),
		anchor = Vector2.new(1, 1),
		radius = 16,
		parent = screen,
		onClick = function()
			setAuto(not Hud.autoFire)
		end,
	})
	Kit.aspect(1.15).Parent = autoButton
	Kit.new("UISizeConstraint", { MaxSize = Vector2.new(120, 104), Parent = autoButton })
	local face = autoButton:FindFirstChild("Face") :: Frame
	Kit.text({
		Name = "Title",
		Text = "AUTO",
		Size = UDim2.fromScale(0.9, 0.42),
		Position = UDim2.fromScale(0.5, 0.1),
		AnchorPoint = Vector2.new(0.5, 0),
		ZIndex = 3,
		Parent = face,
	})
	Kit.text({
		Name = "State",
		Text = "OFF",
		Size = UDim2.fromScale(0.8, 0.36),
		Position = UDim2.fromScale(0.5, 0.55),
		AnchorPoint = Vector2.new(0.5, 0),
		ZIndex = 3,
		Parent = face,
	})

	runPanel = Kit.panel({
		Name = "RunPanel",
		Size = UDim2.fromScale(0.2, 0.2),
		Position = UDim2.fromScale(0.985, 0.2),
		AnchorPoint = Vector2.new(1, 0),
		Visible = false,
		Parent = screen,
	})
	Kit.new("UISizeConstraint", { MaxSize = Vector2.new(300, 190), Parent = runPanel })
	stageLabel = Kit.text({
		Name = "Stage",
		Text = "STAGE 1",
		Size = UDim2.new(1, -20, 0.36, 0),
		Position = UDim2.new(0, 10, 0.04, 0),
		Stroke = 3.5,
		Parent = runPanel,
	})
	enemiesLabel = Kit.text({
		Name = "Enemies",
		Text = "0/0 Enemies",
		Size = UDim2.new(1, -20, 0.25, 0),
		Position = UDim2.new(0, 10, 0.42, 0),
		Stroke = 2.5,
		Parent = runPanel,
	})
	suggestedLabel = Kit.text({
		Name = "Suggested",
		Text = "Suggested ⚡ 0",
		Size = UDim2.new(1, -20, 0.22, 0),
		Position = UDim2.new(0, 10, 0.7, 0),
		Stroke = 2.5,
		Parent = runPanel,
	})

	backButton = Kit.button({
		name = "Back",
		color = Kit.Colors.Red,
		dark = Kit.Colors.RedDark,
		size = UDim2.fromScale(0.09, 0.075),
		position = UDim2.fromScale(0.985, 0.42),
		anchor = Vector2.new(1, 0),
		text = "↩ Back",
		parent = screen,
		onClick = function()
			Net.event("LeaveArena"):FireServer()
		end,
	})
	Kit.new("UISizeConstraint", { MaxSize = Vector2.new(150, 64), Parent = backButton })
	backButton.Visible = false

	nextBar = Kit.panel({
		Name = "NextBar",
		Size = UDim2.fromScale(0.2, 0.09),
		Position = UDim2.fromScale(0.985, 0.52),
		AnchorPoint = Vector2.new(1, 0),
		Visible = false,
		Parent = screen,
	})
	Kit.new("UISizeConstraint", { MaxSize = Vector2.new(300, 86), Parent = nextBar })
	nextLabel = Kit.text({
		Text = "",
		Size = UDim2.new(0.62, -10, 0.45, 0),
		Position = UDim2.new(0, 10, 0.06, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Stroke = 2.5,
		Parent = nextBar,
	})
	local track = Kit.new("Frame", {
		Size = UDim2.new(0.62, -10, 0.26, 0),
		Position = UDim2.new(0, 10, 0.6, 0),
		BackgroundColor3 = Kit.Colors.Ink,
		Parent = nextBar,
	})
	Kit.cornerScale(0.5).Parent = track
	nextFill = Kit.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(110, 200, 255),
		BorderSizePixel = 0,
		Parent = track,
	})
	Kit.cornerScale(0.5).Parent = nextFill
	Kit.button({
		name = "Skip",
		color = Kit.Colors.Orange,
		dark = Kit.Colors.OrangeDark,
		size = UDim2.fromScale(0.32, 0.78),
		position = UDim2.fromScale(0.97, 0.5),
		anchor = Vector2.new(1, 0.5),
		text = "Skip ⏩",
		parent = nextBar,
		onClick = function()
			Kit.sound(Kit.Sounds.Click, 0.4)
			Net.event("SkipWait"):FireServer()
		end,
	})
end

-- Count-up tweens pass through fractions; show whole numbers only.
local function wholeNumber(value: number): string
	return Format.abbreviate(math.floor(value + 0.5))
end

local function refreshStats()
	local profile = ClientState.profile
	if not profile then
		return
	end
	Kit.countTo(powerLabel, profile.power, wholeNumber, 0.25)
	Kit.countTo(coinsLabel, profile.coins, wholeNumber, 0.3)
	rebirthLabel.Text = Format.abbreviate(profile.rebirths)
	bagLabel.Text = `{ClientState.bagCount()} / {ClientState.bagCapacity()}`
	damageLabel.Text = `{Format.abbreviate(ClientState.shotDamage())} Damage`
	levelLabel.Text = `Lv. {profile.level}`
	local needed = Balance.xpToNext(profile.level)
	levelText.Text = `{Format.abbreviate(profile.xp)} / {Format.abbreviate(needed)}`
	TweenService:Create(
		levelFill,
		Kit.FAST,
		{ Size = UDim2.fromScale(math.clamp(profile.xp / needed, 0.04, 1), 1) }
	):Play()

	badges.Rebirth.Visible = profile.power >= Balance.rebirthCost(profile.rebirths)
	badges.Daily.Visible = os.time() - profile.lastDaily >= Balance.DAILY_COOLDOWN
	badges.Quests.Visible = Quests.ready(profile.quests)
end

local wasActive = false
local skippedDeadline = 0

-- The Settings menu's automation: auto mode follows entering and leaving a stage, and the wait
-- between stages or waves is skipped as soon as it starts.
local function automate(run: any, active: boolean)
	local profile = ClientState.profile
	local options = profile and profile.settings
	if not options then
		wasActive = active
		return
	end
	if options.autoMode and active ~= wasActive then
		setAuto(active)
	end
	wasActive = active
	-- Run updates repeat the same countdown, so each countdown is skipped once.
	if options.autoSkip and active and typeof(run.nextIn) == "number" then
		local deadline = os.clock() + run.nextIn
		if math.abs(deadline - skippedDeadline) > 1 then
			skippedDeadline = deadline
			Net.event("SkipWait"):FireServer()
		end
	end
end

local function refreshRun(run: any)
	local active = run.active == true
	automate(run, active)
	runPanel.Visible = active
	backButton.Visible = active
	if active and typeof(run.nextIn) == "number" then
		nextDeadline = os.clock() + run.nextIn
		nextTotal = math.max(1, run.nextTotal or 1)
		nextIsWave = run.tower == true
		nextBar.Visible = true
	else
		nextBar.Visible = false
	end
	if not active then
		return
	end
	local biome = Biomes.List[run.biome or 1]
	stageLabel.Text = if run.tower and run.floor
		then (if run.isBoss then `BOSS FLOOR {run.floor}` else `FLOOR {run.floor}`)
		elseif run.isBoss then `BOSS {run.stage}`
		else `STAGE {run.stage}`
	stageLabel.TextColor3 = if biome
		then biome.glow:Lerp(Color3.new(1, 1, 1), 0.35)
		else Color3.new(1, 1, 1)
	if run.state == "starting" then
		enemiesLabel.Text = "Get ready..."
	elseif run.tower then
		enemiesLabel.Text = "Crystal "
			.. tostring(run.integrity or 100)
			.. "% • "
			.. tostring(run.enemiesLeft or 0)
			.. " foes"
	elseif run.cleared then
		enemiesLabel.Text = "✅ CLEAR!"
	else
		enemiesLabel.Text = `{run.enemiesLeft or 0} / {run.enemiesTotal or 0} Enemies`
	end
	local damage = ClientState.shotDamage()
	local suggested = run.suggested or 0
	suggestedLabel.Text = `Suggested ⚡ {Format.abbreviate(suggested)}`
	suggestedLabel.TextColor3 = if damage >= suggested
		then Color3.fromRGB(130, 255, 120)
		else Color3.fromRGB(255, 120, 110)
end

local function watchHealth(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	local function update()
		local share = if humanoid.MaxHealth > 0 then humanoid.Health / humanoid.MaxHealth else 0
		TweenService
			:Create(healthFill, Kit.FAST, { Size = UDim2.fromScale(math.clamp(share, 0, 1), 1) })
			:Play()
		healthText.Text = `{Format.abbreviate(math.max(0, humanoid.Health))} / {Format.abbreviate(
			humanoid.MaxHealth
		)}`
	end
	humanoid.HealthChanged:Connect(update)
	humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(update)
	update()
end

-- The gun controller reports ammo here.
function Hud.setAmmo(current: number, magazine: number, reloading: boolean)
	if reloading then
		ammoLabel.Text = "Reloading..."
		ammoLabel.TextColor3 = Color3.fromRGB(255, 150, 120)
	else
		ammoLabel.Text = `{current} / {magazine}`
		ammoLabel.TextColor3 = if current <= math.ceil(magazine * 0.25)
			then Color3.fromRGB(255, 120, 100)
			else Color3.fromRGB(255, 225, 120)
	end
end

function Hud.flashPower()
	Kit.pop(powerLabel, 1.12)
end

function Hud.flashCoins()
	Kit.pop(coinsLabel.Parent :: GuiObject, 1.1)
end

function Hud.flashBag()
	Kit.pop(bagLabel.Parent :: GuiObject, 1.12)
end

function Hud.screen(): ScreenGui
	return screen
end

-- Screen position of the bag pill, where collected ores fly to.
function Hud.bagTarget(): Vector2
	local pillFrame = bagLabel.Parent :: GuiObject
	return pillFrame.AbsolutePosition + pillFrame.AbsoluteSize / 2
end

function Hud.coinTarget(): Vector2
	local pillFrame = coinsLabel.Parent :: GuiObject
	return pillFrame.AbsolutePosition + pillFrame.AbsoluteSize / 2
end

function Hud:Init()
	screen = Kit.new("ScreenGui", {
		Name = "Hud",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	buildMenuGrid()
	buildTop()
	buildBottom()
	buildPills()
	buildRight()
end

function Hud:Start()
	ClientState.StatsChanged:Connect(refreshStats)
	ClientState.RunChanged:Connect(refreshRun)
	-- The countdown drains every frame toward the next stage or wave.
	RunService.RenderStepped:Connect(function()
		if not nextBar or not nextBar.Visible then
			return
		end
		local left = math.max(0, nextDeadline - os.clock())
		nextFill.Size = UDim2.fromScale(math.clamp(left / nextTotal, 0, 1), 1)
		nextLabel.Text = `{if nextIsWave then "Next wave" else "Next stage"} in {math.ceil(left)}s`
	end)
	if ClientState.profile then
		refreshStats()
	end
	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(watchHealth)
	if player.Character then
		task.spawn(watchHealth, player.Character)
	end
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		for _, info in MENU_BUTTONS do
			if info.key and input.KeyCode == info.key then
				Menus.toggle(info.name)
			end
		end
		if input.KeyCode == Enum.KeyCode.B and ClientState.run.active then
			Net.event("LeaveArena"):FireServer()
		elseif input.KeyCode == Enum.KeyCode.F then
			setAuto(not Hud.autoFire)
		end
	end)
	-- The daily badge can turn on while the player idles.
	task.spawn(function()
		while true do
			task.wait(5)
			refreshStats()
		end
	end)
end

return Hud
