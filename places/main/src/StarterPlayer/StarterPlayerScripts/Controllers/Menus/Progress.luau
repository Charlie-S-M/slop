--!strict

-- Three small menus: Rebirth (trade power for permanent boosts), Daily (a reward every 20 hours),
-- and Gauntlet (pick a starting stage).

const TweenService = game:GetService("TweenService")

const Balance = require("@game/ReplicatedStorage/Shared/Balance")
const Biomes = require("@game/ReplicatedStorage/Shared/Biomes")
const Format = require("@game/ReplicatedStorage/Shared/Format")
const Net = require("@game/ReplicatedStorage/Shared/Net")
const ClientState = require("../ClientState")
const Kit = require("../UI/Kit")
const Menus = require("../Menus")

local Progress = {}

------------------------------------------------------------------------------------------------
-- Rebirth
------------------------------------------------------------------------------------------------

local rebirthBuilt = false
local rebirthCount: TextLabel
local rebirthFill: Frame
local rebirthNeed: TextLabel
local rebirthRewards: TextLabel
local rebirthButton: TextButton

local function refreshRebirth()
	local profile = ClientState.profile
	if not profile or not rebirthBuilt then
		return
	end
	local cost = Balance.rebirthCost(profile.rebirths)
	local share = math.clamp(profile.power / cost, 0, 1)
	rebirthCount.Text = `Rebirths: {Format.abbreviate(profile.rebirths)}`
	TweenService:Create(rebirthFill, Kit.FAST, { Size = UDim2.fromScale(math.max(share, 0.02), 1) })
		:Play()
	rebirthNeed.Text = `⚡ {Format.abbreviate(profile.power)} / {Format.abbreviate(cost)} Power`
	local nextZone: Balance.TrainingZone? = nil
	for _, zone in Balance.TRAINING_ZONES do
		if zone.rebirthsNeeded == profile.rebirths + 1 then
			nextZone = zone
		end
	end
	local nowMultiplier = Balance.rebirthDamageMultiplier(profile.rebirths)
	local nextMultiplier = Balance.rebirthDamageMultiplier(profile.rebirths + 1)
	local lines = {
		`💥 Damage {Format.multiplier(nowMultiplier)} → {Format.multiplier(nextMultiplier)}`,
		`❤️ +25% max health`,
	}
	if nextZone then
		table.insert(lines, `🎯 Unlocks the {nextZone.multiplier}x Power pad`)
	end
	table.insert(lines, "⚠️ Resets your Power to 0")
	rebirthRewards.Text = table.concat(lines, "\n")
	if share >= 1 then
		Kit.setButtonColor(rebirthButton, Kit.Colors.Purple, Kit.Colors.PurpleDark)
		Kit.setButtonText(rebirthButton, "🔄 REBIRTH!")
	else
		Kit.setButtonColor(rebirthButton, Kit.Colors.Grey, Kit.Colors.GreyDark)
		Kit.setButtonText(rebirthButton, `Need {Format.abbreviate(cost - profile.power)} more`)
	end
end

local function buildRebirth(content: Frame)
	rebirthBuilt = true
	rebirthCount = Kit.text({
		Text = "",
		Size = UDim2.fromScale(1, 0.12),
		Stroke = 3.5,
		TextColor3 = Color3.fromRGB(220, 170, 255),
		Parent = content,
	})
	local back = Kit.new("Frame", {
		Size = UDim2.fromScale(0.9, 0.1),
		Position = UDim2.fromScale(0.05, 0.16),
		BackgroundColor3 = Kit.Colors.Ink,
		Parent = content,
	})
	Kit.cornerScale(0.5).Parent = back
	Kit.stroke(3, Kit.Colors.Ink, Enum.ApplyStrokeMode.Border).Parent = back
	rebirthFill = Kit.new("Frame", {
		Size = UDim2.fromScale(0.02, 1),
		BackgroundColor3 = Kit.Colors.Purple,
		BorderSizePixel = 0,
		Parent = back,
	})
	Kit.cornerScale(0.5).Parent = rebirthFill
	Kit.gradient(Color3.fromRGB(230, 170, 255), Color3.fromRGB(140, 60, 240)).Parent = rebirthFill
	rebirthNeed = Kit.text({
		Text = "",
		Size = UDim2.fromScale(0.94, 0.8),
		Position = UDim2.fromScale(0.03, 0.1),
		ZIndex = 3,
		Stroke = 2.5,
		Parent = back,
	})
	rebirthRewards = Kit.text({
		Text = "",
		Size = UDim2.fromScale(0.86, 0.42),
		Position = UDim2.fromScale(0.07, 0.31),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Stroke = 2.5,
		Parent = content,
	})
	rebirthButton = Kit.button({
		name = "Rebirth",
		color = Kit.Colors.Purple,
		dark = Kit.Colors.PurpleDark,
		size = UDim2.fromScale(0.7, 0.16),
		position = UDim2.fromScale(0.15, 0.8),
		text = "REBIRTH",
		parent = content,
		onClick = function()
			Net.event("Rebirth"):FireServer()
		end,
	})
	refreshRebirth()
end

------------------------------------------------------------------------------------------------
-- Daily
------------------------------------------------------------------------------------------------

local dailyBuilt = false
local dailyStatus: TextLabel
local dailyStreak: TextLabel
local dailyButton: TextButton

local function refreshDaily()
	local profile = ClientState.profile
	if not profile or not dailyBuilt then
		return
	end
	local remaining = Balance.DAILY_COOLDOWN - (os.time() - profile.lastDaily)
	dailyStreak.Text =
		`🔥 Streak: {profile.dailyStreak} day{if profile.dailyStreak == 1 then "" else "s"}`
	if remaining <= 0 then
		dailyStatus.Text = "Your reward is ready!"
		Kit.setButtonColor(dailyButton, Kit.Colors.Green, Kit.Colors.GreenDark)
		Kit.setButtonText(dailyButton, "🎁 CLAIM")
	else
		dailyStatus.Text = `Next reward in {Format.duration(remaining)}`
		Kit.setButtonColor(dailyButton, Kit.Colors.Grey, Kit.Colors.GreyDark)
		Kit.setButtonText(dailyButton, "Come back soon")
	end
end

local function buildDaily(content: Frame)
	dailyBuilt = true
	Kit.text({
		Text = "🎁",
		Size = UDim2.fromScale(0.3, 0.3),
		Position = UDim2.fromScale(0.35, 0),
		Stroke = 0,
		Gradient = false,
		FontFace = Kit.FONT_BODY,
		Parent = content,
	})
	dailyStreak = Kit.text({
		Text = "",
		Size = UDim2.fromScale(0.8, 0.1),
		Position = UDim2.fromScale(0.1, 0.32),
		TextColor3 = Color3.fromRGB(255, 170, 70),
		Stroke = 3,
		Parent = content,
	})
	Kit.text({
		Text = "Coins based on your best stage, plus 3 ores.\nClaim every day to grow your streak bonus!",
		Size = UDim2.fromScale(0.86, 0.2),
		Position = UDim2.fromScale(0.07, 0.44),
		Stroke = 2,
		Parent = content,
	})
	dailyStatus = Kit.text({
		Text = "",
		Size = UDim2.fromScale(0.8, 0.09),
		Position = UDim2.fromScale(0.1, 0.66),
		Stroke = 2.5,
		Parent = content,
	})
	dailyButton = Kit.button({
		name = "Claim",
		color = Kit.Colors.Green,
		dark = Kit.Colors.GreenDark,
		size = UDim2.fromScale(0.6, 0.15),
		position = UDim2.fromScale(0.2, 0.8),
		text = "CLAIM",
		parent = content,
		onClick = function()
			Net.event("ClaimDaily"):FireServer()
		end,
	})
	refreshDaily()
	task.spawn(function()
		while dailyButton.Parent do
			if Menus.isOpen("Daily") then
				refreshDaily()
			end
			task.wait(1)
		end
	end)
end

------------------------------------------------------------------------------------------------
-- Gauntlet
------------------------------------------------------------------------------------------------

local gauntletBuilt = false
local stageList: ScrollingFrame
local bestLabel: TextLabel

local function refreshGauntlet()
	local profile = ClientState.profile
	if not profile or not gauntletBuilt then
		return
	end
	bestLabel.Text = `🏆 Best stage cleared: {profile.bestStage}`
	for _, child in stageList:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	-- The Infinite Tower sits at the top of the list.
	local unlocked = Balance.towerUnlocked(profile.power)
	local startFloor = Balance.towerStartFloor(profile.towerBest)
	local tower = Kit.button({
		name = "Tower",
		color = if unlocked then Color3.fromRGB(110, 80, 200) else Kit.Colors.GreyDark,
		dark = if unlocked then Color3.fromRGB(70, 45, 140) else Kit.Colors.Ink,
		size = UDim2.new(1, -10, 0, 84),
		parent = stageList,
		onClick = function()
			if Balance.towerUnlocked(profile.power) then
				Kit.sound(Kit.Sounds.Teleport, 0.5)
				Net.event("EnterTower"):FireServer()
				Menus.close()
			end
		end,
	})
	tower.LayoutOrder = 0
	local towerFace = tower:FindFirstChild("Face") :: Frame
	Kit.text({
		Text = "🗼 Infinite Tower",
		Size = UDim2.fromScale(0.6, 0.5),
		Position = UDim2.fromScale(0.04, 0.08),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
		Stroke = 3,
		Parent = towerFace,
	})
	Kit.text({
		Text = if unlocked
			then `Best floor {profile.towerBest}  ·  Bonus ×{string.format(
				"%.1f",
				Balance.towerBonus(profile.towerBest)
			)}  ·  Enter at floor {startFloor}`
			else `Opens at ⚡ {Format.abbreviate(Balance.TOWER_UNLOCK_POWER)} Power ({Format.abbreviate(
				math.max(0, Balance.TOWER_UNLOCK_POWER - profile.power)
			)} to go)`,
		Size = UDim2.fromScale(0.92, 0.34),
		Position = UDim2.fromScale(0.04, 0.58),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(220, 210, 255),
		ZIndex = 3,
		Stroke = 2,
		Parent = towerFace,
	})
	for order, stage in Balance.checkpoints(profile.bestStage) do
		local biome = Biomes.forStage(stage)
		local ascension = Biomes.ascension(stage)
		local button = Kit.button({
			name = `Stage{stage}`,
			color = biome.wall,
			dark = biome.wall:Lerp(Color3.new(0, 0, 0), 0.4),
			size = UDim2.new(1, -10, 0, 84),
			parent = stageList,
			onClick = function()
				Kit.sound(Kit.Sounds.Teleport, 0.5)
				Net.event("EnterArena"):FireServer(stage)
				Menus.close()
			end,
		})
		button.LayoutOrder = order
		local face = button:FindFirstChild("Face") :: Frame
		Kit.text({
			Text = `Stage {stage}`,
			Size = UDim2.fromScale(0.4, 0.5),
			Position = UDim2.fromScale(0.04, 0.08),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 3,
			Stroke = 3,
			Parent = face,
		})
		Kit.text({
			Text = biome.name .. (if ascension > 0 then `  ·  Ascension {ascension}` else ""),
			Size = UDim2.fromScale(0.6, 0.34),
			Position = UDim2.fromScale(0.04, 0.58),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = biome.glow:Lerp(Color3.new(1, 1, 1), 0.5),
			ZIndex = 3,
			Stroke = 2,
			Parent = face,
		})
		Kit.text({
			Text = `Suggested ⚡ {Format.abbreviate(Balance.suggestedDamage(stage))}`,
			Size = UDim2.fromScale(0.42, 0.4),
			Position = UDim2.fromScale(0.96, 0.3),
			AnchorPoint = Vector2.new(1, 0),
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 3,
			Stroke = 2.5,
			Parent = face,
		})
	end
end

local function buildGauntlet(content: Frame)
	gauntletBuilt = true
	bestLabel = Kit.text({
		Text = "",
		Size = UDim2.fromScale(1, 0.08),
		Stroke = 3,
		TextColor3 = Color3.fromRGB(255, 215, 80),
		Parent = content,
	})
	Kit.text({
		Text = "Enemies grow bigger and stronger every stage. Die and you drop your ores!",
		Size = UDim2.fromScale(1, 0.06),
		Position = UDim2.fromScale(0, 0.09),
		Stroke = 2,
		Parent = content,
	})
	stageList = Kit.new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 0.82),
		Position = UDim2.fromScale(0, 0.17),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = content,
	})
	Kit.new(
		"UIListLayout",
		{ Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = stageList }
	)
	Kit.new(
		"UIPadding",
		{ PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), Parent = stageList }
	)
	refreshGauntlet()
end

function Progress:Init()
	Menus.register({
		name = "Rebirth",
		title = "Rebirth",
		color = Kit.Colors.Purple,
		size = Vector2.new(0.42, 0.56),
		build = buildRebirth,
		onOpen = refreshRebirth,
	})
	Menus.register({
		name = "Daily",
		title = "Daily Reward",
		color = Kit.Colors.Green,
		size = Vector2.new(0.36, 0.52),
		build = buildDaily,
		onOpen = refreshDaily,
	})
	Menus.register({
		name = "Gauntlet",
		title = "The Gauntlet",
		color = Kit.Colors.Red,
		size = Vector2.new(0.46, 0.66),
		build = buildGauntlet,
		onOpen = refreshGauntlet,
	})
end

function Progress:Start()
	ClientState.StatsChanged:Connect(function()
		if Menus.isOpen("Rebirth") then
			refreshRebirth()
		elseif Menus.isOpen("Daily") then
			refreshDaily()
		end
	end)
	ClientState.ProfileChanged:Connect(function()
		if Menus.isOpen("Gauntlet") then
			refreshGauntlet()
		end
	end)
	-- Entering a run closes any open menu.
	ClientState.RunChanged:Connect(function(run)
		if run.active and run.state == "starting" then
			Menus.close()
		end
	end)
end

return Progress
