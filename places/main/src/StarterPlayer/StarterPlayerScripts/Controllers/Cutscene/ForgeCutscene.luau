--!strict

--[[
	The forging cutscene, played on this client's private forge set. Melt: the player's ores drop
	into the crucible and melt. Pour: the crucible tips and fills a mold shaped like the new gun.
	Hammer: four strikes, each timed by the caller's strike function, shape the glowing gun. Quench:
	it plunges into the barrel. Reveal: it rises with a card of its stats.

	Everything is built from the gun's catalog entry, so every gun gets the same cutscene.
]]

const Players = game:GetService("Players")
const RunService = game:GetService("RunService")
const TweenService = game:GetService("TweenService")

const Balance = require("@game/ReplicatedStorage/Shared/Balance")
const Format = require("@game/ReplicatedStorage/Shared/Format")
const Armor = require("@game/ReplicatedStorage/Shared/Armor")
const ArmorBuilder = require("@game/ReplicatedStorage/Shared/ArmorBuilder")
const GunBuilder = require("@game/ReplicatedStorage/Shared/GunBuilder")
const GunStats = require("@game/ReplicatedStorage/Shared/GunStats")
const Guns = require("@game/ReplicatedStorage/Shared/Guns")
const Net = require("@game/ReplicatedStorage/Shared/Net")
const OreBuilder = require("@game/ReplicatedStorage/Shared/OreBuilder")
const Ores = require("@game/ReplicatedStorage/Shared/Ores")
const Rarity = require("@game/ReplicatedStorage/Shared/Rarity")
const RevealStyles = require("@game/ReplicatedStorage/Shared/RevealStyles")
const Types = require("@game/ReplicatedStorage/Shared/Types")
const Effects = require("../Effects")
const ForgeSet = require("./ForgeSet")
const ImpactFrames = require("./ImpactFrames")
const TierCutscene = require("./TierCutscene")
const Hud = require("../Hud")
const Kit = require("../UI/Kit")
const Menus = require("../Menus")

export type Start = { token: string, gunId: string, rarity: number, oreIds: { string } }
export type Result =
	{ item: Types.GunItem?, armor: Types.ArmorItem?, new: boolean, better: boolean }

const MOLTEN = Color3.fromRGB(255, 130, 30)
const GRADE_COLORS = {
	S = Color3.fromRGB(255, 215, 60),
	A = Color3.fromRGB(120, 230, 110),
	B = Color3.fromRGB(110, 190, 255),
	C = Color3.fromRGB(200, 200, 210),
	D = Color3.fromRGB(200, 140, 120),
}

local ForgeCutscene = {}

-- True while a cutscene or its reveal is on screen.
ForgeCutscene.playing = false
-- Set by the Skip button; the melt and pour check it and jump ahead.
ForgeCutscene.skipRequested = false

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local screen: ScreenGui
local skipButton: TextButton
local aborted = false
local stage: Model? = nil
local revealSpin: RBXScriptConnection? = nil

------------------------------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------------------------------

local function setControls(enabled: boolean)
	-- Anchoring the root keeps the character from walking off while the camera is away. It works
	-- whether or not the place uses the default PlayerModule.
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.Anchored = not enabled
	end
end

-- The camera glide in progress. A new shot cancels it, or a skipped step's glide would keep
-- dragging the camera back after the next shot had moved it.
local cameraGlide: Tween? = nil

local function shot(eye: Vector3, focus: Vector3, fieldOfView: number?)
	if cameraGlide then
		cameraGlide:Cancel()
		cameraGlide = nil
	end
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = fieldOfView or 55
	camera.CFrame = CFrame.lookAt(eye, focus)
end

local function glide(eye: Vector3, focus: Vector3, seconds: number)
	if cameraGlide then
		cameraGlide:Cancel()
	end
	local tween = TweenService:Create(
		camera,
		TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{ CFrame = CFrame.lookAt(eye, focus) }
	)
	cameraGlide = tween
	tween:Play()
end

local function shake(strength: number)
	task.spawn(function()
		for _ = 1, 5 do
			camera.CFrame *= CFrame.new(
				(math.random() - 0.5) * strength,
				(math.random() - 0.5) * strength,
				0
			)
			task.wait(0.03)
		end
	end)
end

-- Waits unless the player skipped or the cutscene was aborted. Returns false when cut short.
local function hold(seconds: number, skippable: boolean): boolean
	local ends = os.clock() + seconds
	while os.clock() < ends do
		if aborted or (skippable and ForgeCutscene.skipRequested) then
			return false
		end
		task.wait()
	end
	return true
end

local function tweenNumber(from: number, to: number, seconds: number, apply: (number) -> ())
	local value = Instance.new("NumberValue")
	value.Value = from
	value.Changed:Connect(apply)
	apply(from)
	local tween = TweenService:Create(
		value,
		TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		{ Value = to }
	)
	tween:Play()
	tween.Completed:Once(function()
		value:Destroy()
	end)
end

type Paint = { part: BasePart, color: Color3, material: Enum.Material }

--[[
	A copy of the forged item, anchored, recording its real colors. `id` names a gun (lying flat with
	its barrel along +X) or an armor piece. Nil when the id is in neither catalog.
]]
local function buildGun(id: string, reveal: boolean?): (Model?, { Paint })
	local gunDef = Guns.get(id)
	local armorDef = Armor.get(id)
	local paints: { Paint } = {}
	local model: Model
	if gunDef then
		model = GunBuilder.build(gunDef)
	elseif armorDef then
		model = ArmorBuilder.build(armorDef)
	else
		return nil, paints
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			if descendant.Transparency == 1 then
				continue
			end
			table.insert(
				paints,
				{ part = descendant, color = descendant.Color, material = descendant.Material }
			)
		elseif descendant:IsA("ParticleEmitter") then
			descendant.Enabled = reveal == true
		end
	end
	return model, paints
end

local function paintMolten(paints: { Paint }, share: number)
	for _, paint in paints do
		paint.part.Color = MOLTEN:Lerp(paint.color, share)
		paint.part.Material = if share >= 1 then paint.material else Enum.Material.Neon
	end
end

local function layFlat(model: Model, at: CFrame)
	-- Barrels run along the gun's -Z; turning it makes the barrel point along +X, side up.
	local boxCFrame = model:GetBoundingBox()
	local offset = boxCFrame:ToObjectSpace(model:GetPivot())
	model:PivotTo(
		at * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(0, 0, math.rad(90)) * offset
	)
	-- Turned on its side, a piece's bounds can sit off to one side (armor more than guns), so slide
	-- it until its middle is over `at`.
	local center = model:GetBoundingBox().Position
	local shift = at.Position - center
	model:PivotTo(model:GetPivot() + Vector3.new(shift.X, 0, shift.Z))
end

------------------------------------------------------------------------------------------------
-- The five steps
------------------------------------------------------------------------------------------------

local function melt(set: ForgeSet.Set, start: Start, rarityColor: Color3)
	local top = Vector3.new(set.metal.Position.X, set.metalTop + 1, set.metal.Position.Z)
	shot(top + Vector3.new(0, 15, 0.01), top)
	glide(top + Vector3.new(0, 11, 2), top, 1.6)
	set.crucible:PivotTo(set.crucibleHinge)
	set.metal.Color = MOLTEN
	set.metal.Size = Vector3.new(6, 0.4, 6)
	set.metal.Position = Vector3.new(set.metal.Position.X, set.metalBottom, set.metal.Position.Z)
	Kit.sound(Kit.Sounds.Charge, 0.4)
	local drops = math.max(#start.oreIds, 1)
	for index, oreId in start.oreIds do
		local def = Ores.get(oreId)
		if not def then
			continue
		end
		local ore = OreBuilder.build(def)
		ore:ScaleTo(1.6)
		local spot = top + Vector3.new((index - (drops + 1) / 2) * 1.2, 8, 0)
		ore:PivotTo(CFrame.new(spot))
		ore.Parent = stage
		tweenNumber(0, 1, 0.35, function(t)
			ore:PivotTo(
				CFrame.new(spot:Lerp(top - Vector3.new(0, 1.5, 0), t))
					* CFrame.Angles(t * 2, t * 3, 0)
			)
		end)
		task.delay(0.35, function()
			Kit.sound(Kit.Sounds.Pop, 0.35, 0.8 + index * 0.08)
			ore:Destroy()
		end)
		-- Each ore raises the molten surface a little more.
		local level = set.metalBottom + (set.metalTop - set.metalBottom) * (index / drops)
		tweenNumber(set.metal.Position.Y, level, 0.3, function(y)
			set.metal.Position = Vector3.new(set.metal.Position.X, y, set.metal.Position.Z)
		end)
		if not hold(0.22, true) then
			return
		end
	end
	if not hold(0.45, true) then
		return
	end
	-- A flash of the rolled rarity's color, as a tease.
	set.metal.Color = rarityColor
	TweenService:Create(set.metal, TweenInfo.new(0.5), { Color = MOLTEN }):Play()
	Kit.sound(Kit.Sounds.Ding, 0.3, 1.4)
	hold(0.45, true)
end

local function pour(set: ForgeSet.Set, gun: Model, paints: { Paint })
	local mold = set.moldCenter.Position
	shot(mold + Vector3.new(12, 8, 15), mold + Vector3.new(0, 5, -6))
	glide(mold + Vector3.new(12, 7, 15), mold + Vector3.new(0, 4, -6), 1.6)
	layFlat(gun, set.moldCenter)
	gun.Parent = stage
	paintMolten(paints, 0)
	for _, paint in paints do
		paint.part.Transparency = 1
	end
	-- Tip the crucible toward the mold.
	tweenNumber(0, 1, 0.5, function(t)
		set.crucible:PivotTo(set.crucibleHinge * CFrame.Angles(math.rad(70) * t, 0, 0))
	end)
	if not hold(0.45, true) then
		return
	end
	-- The stream falls from the lip's height straight into the middle of the mold.
	local lip = set.crucibleHinge.Position + Vector3.new(0, 0.5, 1.5)
	local length = (lip.Y - mold.Y)
	set.stream.Size = Vector3.new(1.1, length, 1.1)
	set.stream.CFrame = CFrame.new(Vector3.new(mold.X, mold.Y + length / 2, mold.Z))
	set.stream.Transparency = 0.05
	Kit.sound(Kit.Sounds.Whoosh, 0.3, 0.6)
	-- The cavity fills: the glowing gun fades in from nothing.
	for _, paint in paints do
		TweenService:Create(paint.part, TweenInfo.new(0.9), { Transparency = 0 }):Play()
	end
	set.metal.Position -= Vector3.new(0, 1.5, 0)
	if not hold(1, true) then
		return
	end
	set.stream.Transparency = 1
	tweenNumber(1, 0, 0.4, function(t)
		set.crucible:PivotTo(set.crucibleHinge * CFrame.Angles(math.rad(70) * t, 0, 0))
	end)
	hold(0.3, true)
end

-- Raises the hammer, lets the caller time the strike, then slams. Returns the strike's accuracy.
local function hammerStrike(
	set: ForgeSet.Set,
	index: number,
	strike: (number) -> number,
	paints: { Paint },
	rarity: number
): number
	tweenNumber(0, 1, 0.35, function(t)
		set.hammer:PivotTo(set.hammerGrip * CFrame.Angles(0, 0, math.rad(-55) * t))
	end)
	local accuracy = strike(index)
	-- Slam.
	tweenNumber(1, 0, 0.08, function(t)
		set.hammer:PivotTo(set.hammerGrip * CFrame.Angles(0, 0, math.rad(-55) * t))
	end)
	task.wait(0.08)
	local sparkCount = math.floor(12 + accuracy * 40 + math.max(rarity - 3, 0) * 10)
	set.sparks:Emit(sparkCount)
	shake(0.15 + accuracy * 0.5)
	Kit.sound(Kit.Sounds.Boom, 0.25 + accuracy * 0.2, 1.6 - accuracy * 0.3)
	paintMolten(paints, index / Balance.STRIKES * 0.75)
	return accuracy
end

local function quench(set: ForgeSet.Set, gun: Model, paints: { Paint })
	local barrel = set.barrelTop.Position
	shot(barrel + Vector3.new(-8, 6, 10), barrel + Vector3.new(0, 2, 0))
	local above = CFrame.new(barrel + Vector3.new(0, 7, 0))
	gun:PivotTo(above * CFrame.Angles(0, math.rad(90), 0))
	tweenNumber(0, 1, 0.45, function(t)
		gun:PivotTo(
			CFrame.new(barrel + Vector3.new(0, 7 - 10 * t, 0)) * CFrame.Angles(0, math.rad(90), 0)
		)
	end)
	task.wait(0.45)
	set.steam:Emit(40)
	Kit.sound(Kit.Sounds.Poof, 0.5, 0.7)
	paintMolten(paints, 1)
	task.wait(0.6)
end

------------------------------------------------------------------------------------------------
-- Reveal card
------------------------------------------------------------------------------------------------

local function statLine(
	parent: Instance,
	order: number,
	label: string,
	value: string,
	color: Color3
)
	local row = Kit.new("Frame", {
		Size = UDim2.fromScale(1, 0.24),
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = parent,
	})
	Kit.text({
		Text = label,
		Size = UDim2.fromScale(0.55, 0.9),
		TextXAlignment = Enum.TextXAlignment.Left,
		Stroke = 2.5,
		Parent = row,
	})
	Kit.text({
		Text = value,
		Size = UDim2.fromScale(0.45, 0.9),
		Position = UDim2.fromScale(0.55, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = color,
		Stroke = 2.5,
		Parent = row,
	})
end

local function restore()
	if revealSpin then
		revealSpin:Disconnect()
		revealSpin = nil
	end
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = 70
	Players.LocalPlayer:SetAttribute("ForgeCamera", false)
	Hud.screen().Enabled = true
	setControls(true)
	if stage then
		stage:Destroy()
		stage = nil
	end
	screen:ClearAllChildren()
	skipButton = nil :: any
	ForgeCutscene.playing = false
end

--[[
	Shows the forged gun rising out of the barrel and a card with its grade and stats. Equip and
	Continue both end the cutscene and hand the camera back. `label` replaces "NEW!" on the card,
	such as "EVOLVED!". When no cutscene is playing (an evolution), the reveal takes over the camera
	itself.
]]
function ForgeCutscene.reveal(result: Result, label: string?)
	local item = result.item
	local armorItem = result.armor
	local gunDef = if item then Guns.get(item.id) else nil
	local armorDef = if armorItem then Armor.get(armorItem.id) else nil
	local id = if item then item.id elseif armorItem then armorItem.id else ""
	local tier = if gunDef then gunDef.rarity elseif armorDef then armorDef.rarity else nil
	local grade: Types.Grade = if item then item.grade elseif armorItem then armorItem.grade else "D"
	if not tier then
		restore()
		return
	end
	local displayName = if gunDef then gunDef.name elseif armorDef then armorDef.name else id
	local kindLabel = if gunDef then gunDef.kind elseif armorDef then armorDef.slot else ""
	if not ForgeCutscene.playing then
		ForgeCutscene.playing = true
		Menus.close()
		Players.LocalPlayer:SetAttribute("ForgeCamera", true)
		Hud.screen().Enabled = false
		setControls(false)
	end
	local tag = label or (if result.new then "NEW!" else nil)
	local set = ForgeSet.get()
	local rarity = Rarity.get(tier)
	local barrel = set.barrelTop.Position
	local revealStage = stage or Instance.new("Model")
	stage = revealStage
	revealStage.Parent = workspace
	-- An abort (the character died) runs restore() mid-reveal; after any wait, stop if it did.
	local function alive(): boolean
		return ForgeCutscene.playing and stage == revealStage
	end
	local gun = buildGun(id, true) :: Model
	gun.Parent = revealStage
	local glow = Instance.new("Part")
	glow.Anchored = true
	glow.CanCollide = false
	glow.Transparency = 1
	glow.Position = barrel + Vector3.new(0, 6, 0)
	glow.Parent = revealStage
	local light = Instance.new("PointLight")
	light.Color = rarity.color
	light.Range = 28
	light.Brightness = if tier >= 4 then 6 else 3
	light.Parent = glow
	shot(barrel + Vector3.new(0, 7, 15), barrel + Vector3.new(0, 6, 0), 45)
	local started = os.clock()
	local spin = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		local rise = math.min(t / 0.8, 1)
		gun:PivotTo(
			CFrame.new(barrel + Vector3.new(0, -2 + 8 * rise + math.sin(t * 2) * 0.3, 0))
				* CFrame.Angles(0, math.pi / 2 + t * 0.8, 0)
		)
	end)
	revealSpin = spin
	set.steam:Emit(20)
	Kit.sound(Kit.Sounds.Ding, 0.5, 1 + tier * 0.04)
	if tier >= 4 then
		Kit.sound(Kit.Sounds.Boom, 0.3, 1.2)
	end
	if RevealStyles.forRarity(tier) then
		-- Let the gun rise into view, then hit the impact frame before the card.
		task.wait(0.5)
		-- Past Eternal, the tier's own cutscene plays first.
		if alive() and tier >= 9 then
			TierCutscene.play(tier, screen, alive)
		end
		if alive() then
			ImpactFrames.play(tier, gun, screen, revealStage, alive)
		end
		if not alive() then
			return
		end
	end
	if tier >= 5 then
		Effects.confetti({ rarity.color, rarity.glow, Color3.new(1, 1, 1) }, 80)
	end

	-- The card, with a slowly turning sunburst behind it.
	local holder = Kit.new("Frame", {
		Size = UDim2.fromScale(0.34, 0.5),
		Position = UDim2.fromScale(0.97, 0.5),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		Parent = screen,
	})
	Kit.new("UISizeConstraint", { MaxSize = Vector2.new(460, 420), Parent = holder })
	local rays = Kit.new("Frame", {
		Size = UDim2.fromScale(1.6, 1.6),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 0,
		Parent = holder,
	})
	Kit.aspect(1).Parent = rays
	for index = 0, 11 do
		local ray = Kit.new("Frame", {
			Size = UDim2.fromScale(0.06, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = index * 15,
			BackgroundColor3 = rarity.glow,
			BackgroundTransparency = if tier >= 4 then 0.45 else 0.7,
			BorderSizePixel = 0,
			Parent = rays,
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
	local card = Kit.panel({ Size = UDim2.fromScale(1, 1), Parent = holder })
	local stroke = card:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = rarity.color
	end
	Kit.text({
		Text = displayName .. (if tag then `  {tag}` else ""),
		Size = UDim2.fromScale(0.72, 0.14),
		Position = UDim2.fromScale(0.05, 0.04),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = rarity.color:Lerp(Color3.new(1, 1, 1), 0.25),
		Stroke = 3.5,
		Parent = card,
	})
	Kit.text({
		Text = `{rarity.name} {kindLabel}`,
		Size = UDim2.fromScale(0.7, 0.08),
		Position = UDim2.fromScale(0.05, 0.18),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = rarity.color,
		Stroke = 2,
		Parent = card,
	})
	local badge = Kit.new("Frame", {
		Size = UDim2.fromScale(0.2, 0.2),
		Position = UDim2.fromScale(0.95, 0.04),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = GRADE_COLORS[grade] or Kit.Colors.Grey,
		Parent = card,
	})
	Kit.aspect(1).Parent = badge
	Kit.corner(12).Parent = badge
	Kit.stroke(3, Kit.Colors.Ink, Enum.ApplyStrokeMode.Border).Parent = badge
	Kit.text({
		Text = grade,
		Size = UDim2.fromScale(0.8, 0.8),
		Position = UDim2.fromScale(0.1, 0.1),
		Stroke = 3,
		Parent = badge,
	})
	local stats = Kit.new("Frame", {
		Size = UDim2.fromScale(0.9, 0.42),
		Position = UDim2.fromScale(0.05, 0.3),
		BackgroundTransparency = 1,
		Parent = card,
	})
	Kit.new(
		"UIListLayout",
		{ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0.02, 0), Parent = stats }
	)
	if item and gunDef then
		statLine(
			stats,
			1,
			"💥 Power",
			Format.abbreviate(item.power),
			Color3.fromRGB(255, 200, 90)
		)
		statLine(
			stats,
			2,
			"⚡ Speed",
			`{string.format("%.1f", GunStats.fireRate(gunDef.kind, item.speed))}/s ({Format.multiplier(
				item.speed
			)})`,
			Color3.fromRGB(120, 220, 255)
		)
		statLine(
			stats,
			3,
			"🎯 Training",
			`+{Format.abbreviate(item.train)}/shot`,
			Color3.fromRGB(150, 255, 130)
		)
	elseif armorItem then
		statLine(
			stats,
			1,
			"🛡️ Blocks",
			`{Format.percent(armorItem.defense)} of each hit`,
			Color3.fromRGB(150, 210, 255)
		)
	end

	local function finish(equip: boolean)
		spin:Disconnect()
		if equip and item then
			Net.event("Equip"):FireServer(item.uid)
		elseif equip and armorItem then
			Net.event("EquipArmor"):FireServer(armorItem.uid)
		end
		restore()
	end
	Kit.button({
		name = "Equip",
		color = Kit.Colors.Green,
		dark = Kit.Colors.GreenDark,
		size = UDim2.fromScale(0.43, 0.15),
		position = UDim2.fromScale(0.05, 0.8),
		text = if result.better then "Equip (Stronger!)" else "Equip",
		parent = card,
		onClick = function()
			finish(true)
		end,
	})
	Kit.button({
		name = "Continue",
		color = Kit.Colors.Blue,
		dark = Kit.Colors.BlueDark,
		size = UDim2.fromScale(0.43, 0.15),
		position = UDim2.fromScale(0.52, 0.8),
		text = "Continue",
		parent = card,
		onClick = function()
			finish(false)
		end,
	})
	Kit.pop(holder, 1.25)
	task.spawn(function()
		while rays.Parent do
			rays.Rotation = (os.clock() - started) * 18
			task.wait()
		end
	end)
end

------------------------------------------------------------------------------------------------
-- Playing
------------------------------------------------------------------------------------------------

--[[
	Plays melt, pour, hammer, and quench for a forge the server has started. `strike(index)` runs
	one timing-game strike and returns its accuracy. Returns the four accuracies; strikes not played
	because the cutscene was aborted count as 0.
]]
function ForgeCutscene.play(start: Start, strike: (number) -> number): { number }
	local accuracies = table.create(Balance.STRIKES, 0)
	local built, paints = buildGun(start.gunId)
	if not built then
		return accuracies
	end
	local gun: Model = built
	ForgeCutscene.playing = true
	ForgeCutscene.skipRequested = false
	aborted = false
	Menus.close()
	Players.LocalPlayer:SetAttribute("ForgeCamera", true)
	Hud.screen().Enabled = false
	setControls(false)
	local set = ForgeSet.get()
	stage = Instance.new("Model");
	(stage :: Model).Name = "ForgeStage"
	(stage :: Model).Parent = workspace
	local rarityColor = Rarity.get(start.rarity).color

	skipButton = Kit.button({
		name = "Skip",
		color = Kit.Colors.Grey,
		dark = Kit.Colors.GreyDark,
		size = UDim2.fromScale(0.1, 0.07),
		position = UDim2.fromScale(0.97, 0.94),
		anchor = Vector2.new(1, 1),
		text = "Skip ⏩",
		parent = screen,
		onClick = function()
			ForgeCutscene.skipRequested = true
		end,
	})

	melt(set, start, rarityColor)
	if not aborted then
		pour(set, gun, paints)
	end
	if skipButton then
		skipButton:Destroy()
		skipButton = nil :: any
	end
	set.stream.Transparency = 1
	set.crucible:PivotTo(set.crucibleHinge)
	if aborted then
		return accuracies
	end

	-- Hammer: the glowing gun on the anvil, four timed strikes.
	gun.Parent = stage
	paintMolten(paints, 0)
	for _, paint in paints do
		paint.part.Transparency = 0
	end
	layFlat(gun, set.anvilTop * CFrame.new(0, 0.6, 0))
	local anvil = set.anvilTop.Position
	shot(anvil + Vector3.new(-3, 7, 9), anvil + Vector3.new(0, 1, 0), 50)
	for index = 1, Balance.STRIKES do
		if aborted then
			break
		end
		accuracies[index] = hammerStrike(set, index, strike, paints, start.rarity)
	end
	if aborted then
		return accuracies
	end
	task.wait(0.3)
	quench(set, gun, paints)
	gun:Destroy()
	return accuracies
end

-- Stops a cutscene mid-way (death, reset) and hands the camera back.
function ForgeCutscene.abort()
	if not ForgeCutscene.playing then
		return
	end
	aborted = true
	restore()
end

-- The screen point over the gun on the anvil, where the timing rings appear.
function ForgeCutscene.anvilScreenPoint(): Vector2
	local set = ForgeSet.get()
	local point = camera:WorldToViewportPoint(set.anvilTop.Position + Vector3.new(0, 1, 0))
	return Vector2.new(point.X, point.Y)
end

function ForgeCutscene:Init()
	screen = Kit.new("ScreenGui", {
		Name = "ForgeCutscene",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 30,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
end

return ForgeCutscene
