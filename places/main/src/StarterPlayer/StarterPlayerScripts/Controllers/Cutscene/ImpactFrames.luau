--!strict
--[[
	Impact frames for Legendary-and-up reveals. A few frames of the item's silhouette flash over the
	screen, then the rarity's sequence plays: an ember shockwave, an implosion and burst, or a
	darkened scene with a prismatic halo opening behind the item.

	`play` yields until the card should appear. Whatever lingers (the halo, a light pillar) is put
	in `screen` and `world`, so the caller's own cleanup of those removes it.
]]

const RunService = game:GetService("RunService")
const TweenService = game:GetService("TweenService")

const RevealStyles = require("@game/ReplicatedStorage/Shared/RevealStyles")
const ShotStyles = require("@game/ReplicatedStorage/Shared/ShotStyles")
const Kit = require("../UI/Kit")

local ImpactFrames = {}

local camera = workspace.CurrentCamera
local random = Random.new()

local function circle(parent: Instance, color: Color3, zIndex: number): Frame
	local frame = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = zIndex,
		Parent = parent,
	})
	Kit.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = frame })
	return frame
end

local function ring(parent: Instance, color: Color3, thickness: number, zIndex: number): Frame
	local frame = circle(parent, color, zIndex)
	frame.BackgroundTransparency = 1
	Kit.new("UIStroke", { Color = color, Thickness = thickness, Parent = frame })
	return frame
end

local function tween(
	instance: Instance,
	seconds: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?
)
	TweenService:Create(instance, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad), goal)
		:Play()
end

-- A flat copy of `model` in one color, drawn from the real camera so it sits exactly over the item.
local function silhouette(
	model: Model,
	parent: Instance,
	color: Color3,
	zIndex: number
): ViewportFrame
	local viewport = Kit.new("ViewportFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = color,
		LightColor = Color3.new(0, 0, 0),
		ZIndex = zIndex,
		Parent = parent,
	})
	local copy = model:Clone()
	for _, descendant in copy:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Color = color
			descendant.Material = Enum.Material.SmoothPlastic
			descendant.Transparency = if descendant.Transparency >= 0.99 then 1 else 0
		elseif
			descendant:IsA("Decal")
			or descendant:IsA("Light")
			or descendant:IsA("ParticleEmitter")
			or descendant:IsA("Beam")
			or descendant:IsA("Trail")
		then
			descendant:Destroy()
		end
	end
	copy.Parent = viewport
	local view = Instance.new("Camera")
	view.CFrame = camera.CFrame
	view.FieldOfView = camera.FieldOfView
	view.Parent = viewport
	viewport.CurrentCamera = view
	return viewport
end

-- The few high-contrast frames every top reveal opens with.
local function flashFrames(style: RevealStyles.RevealStyle, model: Model, screen: ScreenGui)
	local back = Kit.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = style.background,
		BorderSizePixel = 0,
		ZIndex = 60,
		Parent = screen,
	})
	local shape = silhouette(model, screen, style.silhouette, 61)
	task.wait(0.07)
	back.BackgroundColor3 = style.silhouette
	shape.Ambient = style.background
	task.wait(0.06)
	back.BackgroundColor3 = style.background
	shape.Ambient = style.silhouette
	task.wait(0.09)
	back:Destroy()
	shape:Destroy()
end

local function screenPoint(model: Model): UDim2
	local point = camera:WorldToViewportPoint(model:GetPivot().Position)
	local size = camera.ViewportSize
	return UDim2.fromScale(point.X / size.X, point.Y / size.Y)
end

local function ember(style: RevealStyles.RevealStyle, at: UDim2, screen: ScreenGui)
	local wave = ring(screen, style.silhouette, 16, 20)
	wave.Position = at
	wave.Size = UDim2.fromScale(0, 0)
	Kit.aspect(1).Parent = wave
	tween(wave, 0.6, { Size = UDim2.fromScale(1.6, 1.6) })
	local stroke = wave:FindFirstChildOfClass("UIStroke") :: UIStroke
	tween(stroke, 0.8, { Transparency = 1, Thickness = 4 })
	for _ = 1, 18 do
		local spark = circle(screen, style.accent, 21)
		spark.Position = at
		spark.Size = UDim2.fromOffset(16, 16)
		local angle = random:NextNumber(0, math.pi * 2)
		local reach = random:NextNumber(0.18, 0.4)
		tween(spark, random:NextNumber(0.5, 0.8), {
			Position = at
				+ UDim2.fromScale(math.cos(angle) * reach, math.sin(angle) * reach * 1.6 + 0.08),
			BackgroundTransparency = 1,
		})
	end
	task.delay(1, function()
		wave:Destroy()
	end)
end

local function implode(style: RevealStyles.RevealStyle, at: UDim2, screen: ScreenGui)
	local motes = {}
	for _ = 1, 26 do
		local mote = circle(screen, style.silhouette, 21)
		local angle = random:NextNumber(0, math.pi * 2)
		mote.Position = at + UDim2.fromScale(math.cos(angle) * 0.45, math.sin(angle) * 0.7)
		mote.Size = UDim2.fromOffset(12, 12)
		tween(mote, 0.45, { Position = at, Size = UDim2.fromOffset(4, 4) }, Enum.EasingStyle.Quint)
		table.insert(motes, mote)
	end
	task.wait(0.45)
	for _, mote in motes do
		mote:Destroy()
	end
	local burst = circle(screen, style.accent, 20)
	burst.Position = at
	burst.Size = UDim2.fromScale(0.05, 0.05)
	Kit.aspect(1).Parent = burst
	tween(burst, 0.5, { Size = UDim2.fromScale(1.4, 1.4), BackgroundTransparency = 1 })
	local flash = Kit.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = style.accent,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		ZIndex = 19,
		Parent = screen,
	})
	tween(flash, 0.35, { BackgroundTransparency = 1 })
	task.delay(0.6, function()
		burst:Destroy()
		flash:Destroy()
	end)
end

-- A slowly spinning rainbow ring behind the item. It stays until `screen` is cleared.
local function halo(at: UDim2, screen: ScreenGui)
	local frame = ring(screen, Color3.new(1, 1, 1), 14, 0)
	frame.Position = at
	frame.Size = UDim2.fromScale(0, 0)
	Kit.aspect(1).Parent = frame
	local stroke = frame:FindFirstChildOfClass("UIStroke") :: UIStroke
	local keypoints = {}
	for index, color in ShotStyles.PRISM do
		table.insert(
			keypoints,
			ColorSequenceKeypoint.new((index - 1) / (#ShotStyles.PRISM - 1), color)
		)
	end
	local gradient =
		Kit.new("UIGradient", { Color = ColorSequence.new(keypoints), Parent = stroke })
	tween(frame, 0.7, { Size = UDim2.fromScale(0.55, 0.55) }, Enum.EasingStyle.Back)
	local spin = RunService.RenderStepped:Connect(function(delta: number)
		gradient.Rotation = (gradient.Rotation + delta * 90) % 360
	end)
	frame.Destroying:Connect(function()
		spin:Disconnect()
	end)
end

local function darken(amount: number, screen: ScreenGui)
	local shade = Kit.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 0,
		Parent = screen,
	})
	tween(shade, 0.4, { BackgroundTransparency = 1 - amount })
end

local function pillar(model: Model, world: Instance, color: Color3)
	local base = model:GetPivot().Position
	local beam = Instance.new("Part")
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CastShadow = false
	beam.Material = Enum.Material.Neon
	beam.Shape = Enum.PartType.Cylinder
	beam.Color = color
	beam.Transparency = 0.2
	beam.Size = Vector3.new(0.5, 3, 3)
	beam.CFrame = CFrame.new(base) * CFrame.Angles(0, 0, math.rad(90))
	beam.Parent = world
	tween(beam, 0.5, {
		Size = Vector3.new(60, 2.2, 2.2),
		CFrame = CFrame.new(base + Vector3.new(0, 30, 0)) * CFrame.Angles(0, 0, math.rad(90)),
	})
	task.delay(1.2, function()
		tween(beam, 0.6, { Transparency = 1 })
	end)
end

--[[
	Plays the impact frame for `tier` over `model`, yielding until the card should show. Does
	nothing below Legendary. Lingering pieces go in `screen` and `world`.
]]
function ImpactFrames.play(tier: number, model: Model, screen: ScreenGui, world: Instance)
	local style = RevealStyles.forRarity(tier)
	if not style then
		return
	end
	local started = os.clock()
	if style.darken > 0 then
		darken(style.darken, screen)
	end
	Kit.sound(Kit.Sounds.Boom, 0.45, if style.kind == "Ember" then 1.1 else 0.85)
	flashFrames(style, model, screen)
	local at = screenPoint(model)
	if style.kind == "Ember" then
		ember(style, at, screen)
	elseif style.kind == "Implode" then
		implode(style, at, screen)
	else
		if style.kind == "Radiant" then
			local white = Kit.new("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BorderSizePixel = 0,
				ZIndex = 59,
				Parent = screen,
			})
			tween(white, 0.5, { BackgroundTransparency = 1 })
			pillar(model, world, style.accent)
		end
		halo(at, screen)
	end
	local left = style.seconds - (os.clock() - started)
	if left > 0 then
		task.wait(left)
	end
end

return ImpactFrames
