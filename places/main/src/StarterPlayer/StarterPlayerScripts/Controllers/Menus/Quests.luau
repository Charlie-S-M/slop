--!strict

--[[
	Quests: a voxel knight hands out four dailies and three longer challenges. Finished quests are
	claimed for coins and stars; stars raise the quest rank. Each daily can be swapped once, and
	New Quests (Robux) deals a fresh set. Claiming three dailies fills the daily chest.
]]

const RunService = game:GetService("RunService")
const TweenService = game:GetService("TweenService")

const Format = require("@game/ReplicatedStorage/Shared/Format")
const Net = require("@game/ReplicatedStorage/Shared/Net")
const Quests = require("@game/ReplicatedStorage/Shared/Quests")
const Types = require("@game/ReplicatedStorage/Shared/Types")
const ClientState = require("../ClientState")
const Kit = require("../UI/Kit")
const Purchases = require("../UI/Purchases")
const Menus = require("../Menus")

local QuestsMenu = {}

const KNIGHT_NAME = "SIR PEW"
const LINES = {
	"Monsters won't beat themselves!",
	"A true knight finishes every quest.",
	"Stars make the rank, recruit!",
	"Too tough? Swap it, no shame.",
	"Three dailies fill the chest!",
}
const STEEL = Color3.fromRGB(170, 178, 192)
const STEEL_DARK = Color3.fromRGB(105, 112, 128)

local built = false
local tab: "daily" | "challenge" = "daily"
local list: ScrollingFrame
local tabButtons: { [string]: TextButton } = {}
local rankTitle: TextLabel
local rankName: TextLabel
local rankFill: Frame
local rankCount: TextLabel
local rankNext: TextLabel
local speech: TextLabel
local resetLabel: TextLabel
local pips: { Frame } = {}
local chestButton: TextButton
local lastList = ""

-- A blocky knight, every piece a box on a half-stud grid so he reads as 3D pixel art.
local function buildKnight(viewport: ViewportFrame): Model
	local knight = Instance.new("Model")
	local function box(size: Vector3, at: Vector3, color: Color3, material: Enum.Material?)
		local part = Instance.new("Part")
		part.Anchored = true
		part.Size = size
		part.CFrame = CFrame.new(at)
		part.Color = color
		part.Material = material or Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = knight
	end
	-- Legs and boots.
	box(Vector3.new(0.9, 2, 1), Vector3.new(-0.55, 1.5, 0), STEEL_DARK)
	box(Vector3.new(0.9, 2, 1), Vector3.new(0.55, 1.5, 0), STEEL_DARK)
	box(Vector3.new(1, 0.5, 1.3), Vector3.new(-0.55, 0.25, -0.1), Color3.fromRGB(70, 55, 45))
	box(Vector3.new(1, 0.5, 1.3), Vector3.new(0.55, 0.25, -0.1), Color3.fromRGB(70, 55, 45))
	-- Body with a red tabard and a gold belt.
	box(Vector3.new(2.4, 2.4, 1.4), Vector3.new(0, 3.7, 0), STEEL)
	box(Vector3.new(1.2, 2.5, 0.2), Vector3.new(0, 3.65, -0.72), Color3.fromRGB(200, 45, 55))
	box(Vector3.new(2.5, 0.35, 1.5), Vector3.new(0, 2.65, 0), Color3.fromRGB(230, 180, 60))
	-- Shoulders and arms.
	box(Vector3.new(1, 0.6, 1.6), Vector3.new(-1.65, 4.8, 0), STEEL)
	box(Vector3.new(1, 0.6, 1.6), Vector3.new(1.65, 4.8, 0), STEEL)
	box(Vector3.new(0.8, 2, 0.9), Vector3.new(-1.6, 3.6, 0), STEEL_DARK)
	box(Vector3.new(0.8, 2, 0.9), Vector3.new(1.6, 3.6, 0), STEEL_DARK)
	-- Helmet with a dark visor slit and a red plume.
	box(Vector3.new(1.8, 1.8, 1.8), Vector3.new(0, 5.9, 0), STEEL, Enum.Material.Metal)
	box(Vector3.new(1.4, 0.25, 0.1), Vector3.new(0, 6, -0.92), Color3.fromRGB(25, 25, 35))
	box(Vector3.new(0.2, 0.9, 0.1), Vector3.new(0, 5.55, -0.92), Color3.fromRGB(25, 25, 35))
	box(Vector3.new(0.4, 0.7, 1.6), Vector3.new(0, 7.1, 0.1), Color3.fromRGB(220, 50, 60))
	box(Vector3.new(0.4, 0.5, 0.6), Vector3.new(0, 6.9, 0.9), Color3.fromRGB(220, 50, 60))
	-- Shield on the left arm: blue with a gold cross.
	box(Vector3.new(0.3, 2, 1.6), Vector3.new(-2.15, 3.5, -0.2), Color3.fromRGB(50, 90, 200))
	box(Vector3.new(0.32, 1.7, 0.3), Vector3.new(-2.16, 3.5, -0.2), Color3.fromRGB(240, 200, 70))
	box(Vector3.new(0.32, 0.3, 1.3), Vector3.new(-2.16, 3.7, -0.2), Color3.fromRGB(240, 200, 70))
	-- Sword in the right hand, point up.
	box(Vector3.new(0.3, 0.3, 0.3), Vector3.new(1.6, 2.5, -0.3), Color3.fromRGB(110, 70, 45))
	box(Vector3.new(0.3, 0.9, 0.3), Vector3.new(1.6, 2.45, -0.3), Color3.fromRGB(110, 70, 45))
	box(Vector3.new(1, 0.25, 0.35), Vector3.new(1.6, 2.95, -0.3), Color3.fromRGB(240, 200, 70))
	box(Vector3.new(0.25, 2.8, 0.15), Vector3.new(1.6, 4.45, -0.3), Color3.fromRGB(225, 230, 240))
	knight.Parent = viewport
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	local center, size = knight:GetBoundingBox()
	local distance = size.Magnitude * 1.55
	camera.CFrame = CFrame.lookAt(
		center.Position + Vector3.new(-distance * 0.3, size.Y * 0.08, -distance),
		center.Position
	)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	return knight
end

local function book(): Types.QuestBook?
	local profile = ClientState.profile
	return profile and profile.quests
end

local function questCard(quest: Types.Quest, index: number, order: number)
	local profile = ClientState.profile
	local def = Quests.KINDS[quest.kind]
	if not profile or not def then
		return
	end
	local done = Quests.done(quest)
	local card = Kit.new("Frame", {
		BackgroundColor3 = def.color,
		LayoutOrder = order,
		Size = UDim2.new(0.97, 0, 0, 96),
		Parent = list,
	})
	Kit.corner(14).Parent = card
	Kit.stroke(3, Kit.Colors.Ink, Enum.ApplyStrokeMode.Border).Parent = card
	Kit.gradient(def.color:Lerp(Color3.new(1, 1, 1), 0.15), def.color:Lerp(Color3.new(), 0.2)).Parent =
		card
	Kit.iconTile(def.glyph, Color3.fromRGB(245, 240, 235), UDim2.fromScale(0.13, 0.78), card).Position =
		UDim2.fromScale(0.02, 0.11)
	if quest.hard then
		local tag = Kit.text({
			Text = "HARD",
			Size = UDim2.fromScale(0.12, 0.26),
			Position = UDim2.fromScale(0.015, -0.12),
			TextColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 0,
			BackgroundColor3 = Color3.fromRGB(215, 45, 50),
			Stroke = 2,
			ZIndex = 3,
			Parent = card,
		})
		Kit.corner(6).Parent = tag
	end
	Kit.text({
		Text = Quests.describe(quest),
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromScale(0.17, 0.08),
		Size = UDim2.fromScale(0.5, 0.4),
		Stroke = 3,
		Parent = card,
	})
	local track = Kit.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(28, 28, 50),
		Position = UDim2.fromScale(0.17, 0.56),
		Size = UDim2.fromScale(0.5, 0.3),
		Parent = card,
	})
	Kit.cornerScale(0.5).Parent = track
	local fill = Kit.new("Frame", {
		BackgroundColor3 = if done then Kit.Colors.Green else Kit.Colors.Gold,
		Size = UDim2.fromScale(math.clamp(quest.progress / quest.target, 0, 1), 1),
		Parent = track,
	})
	Kit.cornerScale(0.5).Parent = fill
	Kit.text({
		Text = `{Format.commas(quest.progress)}/{Format.commas(quest.target)}`,
		Size = UDim2.fromScale(1, 0.85),
		Position = UDim2.fromScale(0, 0.08),
		Stroke = 2,
		ZIndex = 2,
		Parent = track,
	})
	Kit.text({
		Text = `💰 +{Format.abbreviate(Quests.coins(quest, profile.bestStage))}`,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromScale(0.69, 0.1),
		Size = UDim2.fromScale(0.13, 0.36),
		Stroke = 2.5,
		Parent = card,
	})
	Kit.text({
		Text = `⭐ {quest.stars}`,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromScale(0.69, 0.54),
		Size = UDim2.fromScale(0.13, 0.36),
		TextColor3 = Color3.fromRGB(255, 215, 80),
		Stroke = 2.5,
		Parent = card,
	})
	local action: string?
	local color, dark = Kit.Colors.Grey, Kit.Colors.GreyDark
	if quest.claimed then
		action = "✓ Done"
	elseif done then
		action = "Claim"
		color, dark = Kit.Colors.Green, Kit.Colors.GreenDark
	elseif tab == "daily" and not quest.swapped then
		action = "Swap"
		color, dark = Color3.fromRGB(90, 100, 200), Color3.fromRGB(55, 60, 150)
	end
	if action then
		Kit.button({
			name = "Action",
			color = color,
			dark = dark,
			size = UDim2.fromScale(0.15, 0.7),
			position = UDim2.fromScale(0.83, 0.15),
			text = action,
			parent = card,
			onClick = function()
				if action == "Claim" then
					Kit.sound(Kit.Sounds.Coin, 0.5)
					Net.event("QuestClaim"):FireServer(tab, index)
				elseif action == "Swap" then
					Net.event("QuestSwap"):FireServer(index)
				end
			end,
		})
	end
end

local function refresh()
	local current = book()
	local profile = ClientState.profile
	if not built or not current or not profile then
		return
	end
	for key, button in tabButtons do
		if key == tab then
			Kit.setButtonColor(button, Kit.Colors.Gold, Kit.Colors.GoldDark)
		else
			Kit.setButtonColor(button, Kit.Colors.Grey, Kit.Colors.GreyDark)
		end
	end
	local info = Quests.rank(current.stars)
	rankTitle.Text = `Quest Rank {info.rank}`
	rankName.Text = info.name
	rankCount.Text = `{info.into}/{info.need}`
	rankNext.Text = `Next: {info.nextName}`
	TweenService:Create(
		rankFill,
		Kit.FAST,
		{ Size = UDim2.fromScale(math.max(info.into / info.need, 0.04), 1) }
	):Play()
	for index, pip in pips do
		pip.BackgroundColor3 = if index <= current.chestPips
			then Kit.Colors.Gold
			else Color3.fromRGB(60, 66, 100)
	end
	if current.chestOpened then
		Kit.setButtonColor(chestButton, Kit.Colors.Grey, Kit.Colors.GreyDark)
		Kit.setButtonText(chestButton, "Opened")
	elseif current.chestPips >= Quests.CHEST_PIPS then
		Kit.setButtonColor(chestButton, Kit.Colors.Green, Kit.Colors.GreenDark)
		Kit.setButtonText(chestButton, "Open!")
	else
		Kit.setButtonColor(chestButton, Kit.Colors.Grey, Kit.Colors.GreyDark)
		Kit.setButtonText(chestButton, `{current.chestPips}/{Quests.CHEST_PIPS}`)
	end
	-- Rebuild the cards only when a quest changed, not every refresh.
	local quests: { Types.Quest } = if tab == "daily" then current.daily else current.challenge
	local parts: { string } = { tab, tostring(profile.bestStage) }
	for _, quest in quests do
		table.insert(
			parts,
			`{quest.kind}:{quest.target}:{quest.progress}:{quest.claimed}:{quest.swapped}`
		)
	end
	local signature = table.concat(parts, "|")
	if signature == lastList then
		return
	end
	lastList = signature
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for index, quest in quests do
		questCard(quest, index, index)
	end
end

local function build(content: Frame)
	built = true
	-- The knight's card.
	local knightCard = Kit.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(80, 150, 230),
		Size = UDim2.fromScale(0.3, 0.44),
		Position = UDim2.fromScale(0.01, 0.01),
		Parent = content,
	})
	Kit.corner(14).Parent = knightCard
	Kit.stroke(3, Kit.Colors.Ink, Enum.ApplyStrokeMode.Border).Parent = knightCard
	Kit.gradient(Color3.fromRGB(140, 200, 255), Color3.fromRGB(60, 120, 220)).Parent = knightCard
	local viewport = Kit.new("ViewportFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0.86),
		Ambient = Color3.fromRGB(200, 200, 210),
		LightColor = Color3.fromRGB(255, 250, 240),
		Parent = knightCard,
	}) :: ViewportFrame
	local knight = buildKnight(viewport)
	local pivot = knight:GetPivot()
	RunService.RenderStepped:Connect(function()
		if Menus.isOpen("Quests") then
			local t = os.clock()
			knight:PivotTo(pivot * CFrame.Angles(0, math.sin(t * 0.8) * 0.25, 0))
		end
	end)
	Kit.text({
		Text = KNIGHT_NAME,
		Size = UDim2.fromScale(0.9, 0.16),
		Position = UDim2.fromScale(0.05, 0.82),
		Stroke = 3,
		Parent = knightCard,
	})
	-- His speech bubble.
	local bubble = Kit.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		Size = UDim2.fromScale(0.3, 0.14),
		Position = UDim2.fromScale(0.01, 0.47),
		Parent = content,
	})
	Kit.corner(12).Parent = bubble
	Kit.stroke(3, Kit.Colors.Ink, Enum.ApplyStrokeMode.Border).Parent = bubble
	speech = Kit.text({
		Text = LINES[1],
		TextColor3 = Color3.fromRGB(40, 40, 60),
		Size = UDim2.fromScale(0.9, 0.8),
		Position = UDim2.fromScale(0.05, 0.1),
		Stroke = 0,
		Gradient = false,
		Parent = bubble,
	})
	-- Rank card.
	local rankCard = Kit.panel({
		Size = UDim2.fromScale(0.3, 0.34),
		Position = UDim2.fromScale(0.01, 0.64),
		Parent = content,
	})
	rankTitle = Kit.text({
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.fromScale(0.9, 0.22),
		Position = UDim2.fromScale(0.06, 0.06),
		Parent = rankCard,
	})
	rankName = Kit.text({
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 205, 70),
		Size = UDim2.fromScale(0.9, 0.2),
		Position = UDim2.fromScale(0.06, 0.3),
		Parent = rankCard,
	})
	local track = Kit.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(28, 28, 50),
		Size = UDim2.fromScale(0.88, 0.16),
		Position = UDim2.fromScale(0.06, 0.55),
		Parent = rankCard,
	})
	Kit.cornerScale(0.5).Parent = track
	rankFill = Kit.new("Frame", {
		BackgroundColor3 = Kit.Colors.Purple,
		Size = UDim2.fromScale(0.04, 1),
		Parent = track,
	})
	Kit.cornerScale(0.5).Parent = rankFill
	Kit.gradient(Color3.fromRGB(220, 170, 255), Color3.fromRGB(140, 80, 240)).Parent = rankFill
	rankCount = Kit.text({
		Text = "",
		Size = UDim2.fromScale(1, 0.85),
		Position = UDim2.fromScale(0, 0.08),
		Stroke = 2,
		ZIndex = 2,
		Parent = track,
	})
	rankNext = Kit.text({
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.fromScale(0.9, 0.18),
		Position = UDim2.fromScale(0.06, 0.76),
		Parent = rankCard,
	})
	-- Tabs, the reset timer, and New Quests.
	for index, key in { "daily", "challenge" } do
		tabButtons[key] = Kit.button({
			name = key,
			color = Kit.Colors.Grey,
			dark = Kit.Colors.GreyDark,
			size = UDim2.fromScale(0.2, 0.09),
			position = UDim2.fromScale(0.33 + (index - 1) * 0.21, 0.01),
			text = if key == "daily" then "Daily" else "Challenge",
			parent = content,
			onClick = function()
				tab = key :: any
				lastList = ""
				refresh()
			end,
		})
	end
	Kit.button({
		name = "NewQuests",
		color = Kit.Colors.Green,
		dark = Kit.Colors.GreenDark,
		size = UDim2.fromScale(0.24, 0.09),
		position = UDim2.fromScale(0.75, 0.01),
		text = "🔁 New Quests  R$49",
		parent = content,
		onClick = function()
			Purchases.prompt("NewQuests")
		end,
	})
	resetLabel = Kit.text({
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Color3.fromRGB(190, 205, 225),
		Size = UDim2.fromScale(0.4, 0.04),
		Position = UDim2.fromScale(0.59, 0.11),
		Stroke = 1.5,
		Gradient = false,
		Parent = content,
	})
	list = Kit.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0.67, 0.66),
		Position = UDim2.fromScale(0.325, 0.16),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		Parent = content,
	})
	Kit.new("UIListLayout", {
		Padding = UDim.new(0, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = list,
	})
	Kit.new("UIPadding", { PaddingTop = UDim.new(0, 12), Parent = list })
	-- The daily chest and Claim All.
	local chest = Kit.panel({
		Size = UDim2.fromScale(0.42, 0.15),
		Position = UDim2.fromScale(0.33, 0.84),
		Parent = content,
	})
	Kit.text({
		Text = "🎁 Daily Chest",
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.fromScale(0.55, 0.45),
		Position = UDim2.fromScale(0.04, 0.06),
		Parent = chest,
	})
	for index = 1, Quests.CHEST_PIPS do
		local pip = Kit.new("Frame", {
			Size = UDim2.fromScale(0.15, 0.24),
			Position = UDim2.fromScale(0.05 + (index - 1) * 0.17, 0.6),
			BackgroundColor3 = Color3.fromRGB(60, 66, 100),
			Parent = chest,
		})
		Kit.cornerScale(0.5).Parent = pip
		table.insert(pips, pip)
	end
	chestButton = Kit.button({
		name = "Chest",
		color = Kit.Colors.Grey,
		dark = Kit.Colors.GreyDark,
		size = UDim2.fromScale(0.34, 0.7),
		position = UDim2.fromScale(0.62, 0.15),
		text = "0/3",
		parent = chest,
		onClick = function()
			Net.event("QuestChest"):FireServer()
		end,
	})
	Kit.button({
		name = "ClaimAll",
		color = Color3.fromRGB(90, 100, 200),
		dark = Color3.fromRGB(55, 60, 150),
		size = UDim2.fromScale(0.23, 0.15),
		position = UDim2.fromScale(0.765, 0.84),
		text = "Claim All",
		parent = content,
		onClick = function()
			Kit.sound(Kit.Sounds.Coin, 0.5)
			Net.event("QuestClaim"):FireServer("all")
		end,
	})
	refresh()
	task.spawn(function()
		local line = 1
		while content.Parent do
			if Menus.isOpen("Quests") then
				local now = os.time()
				local left = 86400 - now % 86400
				resetLabel.Text = `New quests in {Format.duration(left)}`
				if now % 6 == 0 then
					line = line % #LINES + 1
					speech.Text = LINES[line]
				end
			end
			task.wait(1)
		end
	end)
end

function QuestsMenu:Init()
	Menus.register({
		name = "Quests",
		title = "📜 Quests",
		color = Kit.Colors.Orange,
		size = Vector2.new(0.68, 0.74),
		build = build,
		onOpen = function()
			lastList = ""
			refresh()
		end,
	})
end

function QuestsMenu:Start()
	local player = game:GetService("Players").LocalPlayer
	local guide = Kit.new("ScreenGui", {
		Name = "ForgeTutorial",
		ResetOnSpawn = false,
		DisplayOrder = 11,
		Enabled = false,
		Parent = player:WaitForChild("PlayerGui"),
	}) :: ScreenGui
	local card = Kit.panel({
		Position = UDim2.fromScale(0.98, 0.12),
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.new(0.62, 0, 0, 82),
		Parent = guide,
	})
	Kit.new("UISizeConstraint", { MaxSize = Vector2.new(300, 82), Parent = card })
	local portrait = Kit.new("ViewportFrame", {
		Size = UDim2.fromOffset(62, 68),
		Position = UDim2.fromOffset(3, 7),
		BackgroundTransparency = 1,
		Parent = card,
	})
	buildKnight(portrait)
	Kit.text({
		Text = KNIGHT_NAME,
		TextColor3 = Kit.Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(66, 4),
		Size = UDim2.new(1, -72, 0, 18),
		Parent = card,
	})
	local instruction = Kit.text({
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(66, 23),
		Size = UDim2.new(1, -72, 0, 53),
		Stroke = 1.5,
		Parent = card,
	})
	local function refreshGuide()
		local profile = ClientState.profile
		guide.Enabled = profile ~= nil
			and profile.forges == 0
			and profile.prestige == 0
			and not player:GetAttribute("ForgeCamera")
			and (not Menus.isOpen() or Menus.isOpen("Forge"))
		if not guide.Enabled then
			return
		end
		if Menus.isOpen("Forge") then
			instruction.Text =
				"Select Gun, add ore, then hit Forge. Tap when the hammer rings line up."
		elseif ClientState.bagCount() > 0 then
			instruction.Text = if ClientState.run.active
				then "You have ore! Leave the Gauntlet and head to the Forge."
				else "Open the Forge stall to craft your first gun."
		elseif ClientState.run.active then
			instruction.Text = "Shoot the enemies and pick up a dropped ore."
		else
			instruction.Text = "Open Gauntlet and enter Stage 1 to find ore."
		end
	end
	Menus.Opened:Connect(refreshGuide)
	ClientState.RunChanged:Connect(refreshGuide)
	player:GetAttributeChangedSignal("ForgeCamera"):Connect(refreshGuide)
	refreshGuide()
	ClientState.ProfileChanged:Connect(function()
		refreshGuide()
		if Menus.isOpen("Quests") then
			refresh()
		end
	end)
end

return QuestsMenu
