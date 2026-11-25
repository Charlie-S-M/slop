--!strict

--[[
	The private forge set for the forging cutscene: a dark brick room far above the map with a
	crucible on chains, a mold tray, an anvil, a hammer, and a water barrel. It's built only on this
	client, once, the first time a forge plays, so other players never see it.
]]

local ForgeSet = {}

export type Set = {
	root: Model,
	origin: Vector3,
	-- The crucible model pivots on its hinge, so turning its pivot tips it toward the mold.
	crucible: Model,
	crucibleHinge: CFrame,
	metal: BasePart,
	metalBottom: number,
	metalTop: number,
	moldCenter: CFrame,
	anvilTop: CFrame,
	-- The hammer pivots at its grip; its pivot's angle sets how raised it is.
	hammer: Model,
	hammerGrip: CFrame,
	barrelTop: CFrame,
	steam: ParticleEmitter,
	sparks: ParticleEmitter,
	stream: BasePart,
}

const ORIGIN = Vector3.new(0, 600, -4000)

local current: Set? = nil

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function block(
	parent: Instance,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	name: string?
): Part
	local part = Instance.new("Part")
	part.Name = name or "Block"
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function stud(parent: Instance, position: Vector3, color: Color3)
	local part = block(
		parent,
		Vector3.new(0.38, 1.15, 1.15),
		CFrame.new(position + Vector3.new(0, 0.19, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color
	)
	part.Shape = Enum.PartType.Cylinder
	part.CastShadow = false
end

local function light(parent: BasePart, color: Color3, range: number, brightness: number)
	local point = Instance.new("PointLight")
	point.Color = color
	point.Range = range
	point.Brightness = brightness
	point.Shadows = true
	point.Parent = parent
end

local function buildRoom(root: Model)
	local floorColor = rgb(52, 50, 62)
	block(
		root,
		Vector3.new(90, 2, 70),
		CFrame.new(ORIGIN + Vector3.new(0, -1, 0)),
		floorColor,
		nil,
		"Floor"
	)
	-- Floor tiles with dark seams, like the rest of the game.
	for x = -4, 4 do
		for z = -3, 3 do
			block(
				root,
				Vector3.new(9.6, 0.3, 9.6),
				CFrame.new(ORIGIN + Vector3.new(x * 10, 0.15, z * 10)),
				if (x + z) % 2 == 0 then rgb(66, 64, 78) else rgb(60, 58, 72)
			)
		end
	end
	-- Dark brick walls on three sides and a ceiling keep the scene lit only by the forge.
	local wallColor = rgb(40, 38, 50)
	for _, wall in
		{
			{ Vector3.new(90, 50, 2), Vector3.new(0, 24, -35) },
			{ Vector3.new(2, 50, 70), Vector3.new(-45, 24, 0) },
			{ Vector3.new(2, 50, 70), Vector3.new(45, 24, 0) },
			{ Vector3.new(90, 2, 70), Vector3.new(0, 49, 0) },
			{ Vector3.new(90, 50, 2), Vector3.new(0, 24, 35) },
		}
	do
		block(root, wall[1], CFrame.new(ORIGIN + wall[2]), wallColor, nil, "Wall")
	end
	for row = 0, 8 do
		for col = -8, 8 do
			local offset = if row % 2 == 0 then 0 else 2.5
			block(
				root,
				Vector3.new(4.7, 2.3, 0.6),
				CFrame.new(ORIGIN + Vector3.new(col * 5 + offset, 1.5 + row * 2.5, -33.8)),
				if (row + col) % 3 == 0 then rgb(48, 46, 60) else rgb(44, 42, 56)
			)
		end
	end
	-- A low ember glow along the back wall.
	local strip = block(
		root,
		Vector3.new(80, 0.5, 0.5),
		CFrame.new(ORIGIN + Vector3.new(0, 0.6, -33)),
		rgb(255, 110, 30),
		Enum.Material.Neon
	)
	strip.Transparency = 0.3
end

local function buildCrucible(root: Model): (Model, CFrame, BasePart, number, number, BasePart)
	local crucible = Instance.new("Model")
	crucible.Name = "Crucible"
	local center = ORIGIN + Vector3.new(-13, 13, -4)
	local steel = rgb(150, 155, 168)
	local dark = rgb(95, 98, 110)
	block(crucible, Vector3.new(8, 1, 8), CFrame.new(center + Vector3.new(0, -3, 0)), dark)
	for _, side in
		{
			{ Vector3.new(8, 6, 1), Vector3.new(0, 0, 3.5) },
			{ Vector3.new(8, 6, 1), Vector3.new(0, 0, -3.5) },
			{ Vector3.new(1, 6, 6), Vector3.new(3.5, 0, 0) },
			{ Vector3.new(1, 6, 6), Vector3.new(-3.5, 0, 0) },
		}
	do
		block(crucible, side[1], CFrame.new(center + side[2]), steel)
	end
	-- A light rim around the open top, with a stud at each corner.
	local rim = rgb(220, 222, 230)
	for _, bar in
		{
			{ Vector3.new(8.6, 0.8, 1.2), Vector3.new(0, 3.2, 3.7) },
			{ Vector3.new(8.6, 0.8, 1.2), Vector3.new(0, 3.2, -3.7) },
			{ Vector3.new(1.2, 0.8, 6.2), Vector3.new(3.7, 3.2, 0) },
			{ Vector3.new(1.2, 0.8, 6.2), Vector3.new(-3.7, 3.2, 0) },
		}
	do
		block(crucible, bar[1], CFrame.new(center + bar[2]), rim)
	end
	for x = -1, 1, 2 do
		for z = -1, 1, 2 do
			stud(crucible, center + Vector3.new(x * 3.7, 3.6, z * 3.7), rim)
		end
	end
	-- A pouring lip on the side facing the mold (+Z).
	block(
		crucible,
		Vector3.new(2.4, 0.6, 1.6),
		CFrame.new(center + Vector3.new(0, 2.9, 4.4)),
		steel
	)
	local metalBottom = center.Y - 2.3
	local metalTop = center.Y + 2.4
	local metal = block(
		crucible,
		Vector3.new(6, 0.4, 6),
		CFrame.new(center.X, metalBottom, center.Z),
		rgb(255, 130, 30),
		Enum.Material.Neon,
		"Metal"
	)
	light(metal, rgb(255, 140, 50), 26, 3)
	-- Chains up to the ceiling, part of the model so they tilt with it.
	for x = -1, 1, 2 do
		block(
			crucible,
			Vector3.new(0.5, 18, 0.5),
			CFrame.new(center + Vector3.new(x * 4.1, 12, 0)),
			rgb(200, 200, 210),
			Enum.Material.Metal
		)
	end
	-- The hinge sits at the lip so tilting pours from there.
	local hinge = CFrame.new(center + Vector3.new(0, 1, 3.5))
	crucible.PrimaryPart = metal
	crucible.WorldPivot = hinge
	crucible.Parent = root

	local stream = block(
		root,
		Vector3.new(1.2, 1, 1.2),
		CFrame.new(center),
		rgb(255, 150, 40),
		Enum.Material.Neon,
		"Stream"
	)
	stream.Transparency = 1
	return crucible, hinge, metal, metalBottom, metalTop, stream
end

local function buildMold(root: Model): CFrame
	local center = ORIGIN + Vector3.new(-13, 0.9, 9)
	block(
		root,
		Vector3.new(14, 1.4, 8),
		CFrame.new(center),
		rgb(70, 70, 82),
		Enum.Material.Metal,
		"Mold"
	)
	block(
		root,
		Vector3.new(12.6, 0.2, 6.6),
		CFrame.new(center + Vector3.new(0, 0.62, 0)),
		rgb(30, 28, 34),
		nil,
		"Cavity"
	)
	return CFrame.new(center + Vector3.new(0, 1.1, 0))
end

local function buildAnvil(root: Model): CFrame
	local base = ORIGIN + Vector3.new(0, 0, 0)
	local iron = rgb(78, 82, 94)
	block(root, Vector3.new(6, 1.4, 7), CFrame.new(base + Vector3.new(0, 0.7, 0)), rgb(64, 66, 78))
	block(
		root,
		Vector3.new(3.4, 3.2, 4.4),
		CFrame.new(base + Vector3.new(0, 2.9, 0)),
		rgb(64, 66, 78)
	)
	local top = block(
		root,
		Vector3.new(5.2, 2, 9),
		CFrame.new(base + Vector3.new(0, 5.5, 0)),
		iron,
		Enum.Material.Metal,
		"AnvilTop"
	)
	block(
		root,
		Vector3.new(2.6, 1.4, 3),
		CFrame.new(base + Vector3.new(0, 5.7, -6)),
		iron,
		Enum.Material.Metal
	)
	for x = -1, 1, 2 do
		for z = -1, 1 do
			stud(root, base + Vector3.new(x * 1.6, 1.4, z * 2.2), rgb(64, 66, 78))
		end
	end
	light(top, rgb(255, 170, 90), 18, 1.5)
	return CFrame.new(top.Position + Vector3.new(0, 1.05, 0))
end

local function buildHammer(root: Model, anvilTop: CFrame): (Model, CFrame)
	local hammer = Instance.new("Model")
	hammer.Name = "Hammer"
	-- The grip sits beside the anvil; the head reaches over the anvil's middle.
	local grip = anvilTop * CFrame.new(7.5, 1, 0)
	local handle =
		block(hammer, Vector3.new(7.5, 0.8, 0.8), grip * CFrame.new(-3.75, 0, 0), rgb(130, 90, 55))
	block(hammer, Vector3.new(0.9, 0.9, 0.9), grip, rgb(60, 60, 70))
	local head = block(
		hammer,
		Vector3.new(2.4, 2.6, 4),
		grip * CFrame.new(-7.6, 0, 0),
		rgb(110, 115, 128),
		Enum.Material.Metal
	)
	block(
		hammer,
		Vector3.new(2.6, 0.6, 4.2),
		head.CFrame * CFrame.new(0, -1.1, 0),
		rgb(200, 205, 215),
		Enum.Material.Metal
	)
	hammer.PrimaryPart = handle
	hammer.WorldPivot = grip
	hammer.Parent = root
	return hammer, grip
end

local function buildBarrel(root: Model): (CFrame, ParticleEmitter)
	local center = ORIGIN + Vector3.new(13, 0, -2)
	local wood = rgb(190, 120, 60)
	local body = block(
		root,
		Vector3.new(6, 7, 7),
		CFrame.new(center + Vector3.new(0, 3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		wood
	)
	body.Shape = Enum.PartType.Cylinder
	for _, y in { 1, 5 } do
		local hoop = block(
			root,
			Vector3.new(0.5, 7.3, 7.3),
			CFrame.new(center + Vector3.new(0, y, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			rgb(70, 80, 110)
		)
		hoop.Shape = Enum.PartType.Cylinder
	end
	local water = block(
		root,
		Vector3.new(0.3, 6.4, 6.4),
		CFrame.new(center + Vector3.new(0, 6.05, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		rgb(60, 200, 255),
		Enum.Material.Neon,
		"Water"
	)
	water.Shape = Enum.PartType.Cylinder
	water.Transparency = 0.15
	light(water, rgb(90, 200, 255), 14, 1)
	local steam = Instance.new("ParticleEmitter")
	steam.Name = "Steam"
	steam.Texture = "rbxasset://textures/particles/smoke_main.dds"
	steam.Color = ColorSequence.new(Color3.new(1, 1, 1))
	steam.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	steam.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 7) })
	steam.Lifetime = NumberRange.new(1, 1.8)
	steam.Speed = NumberRange.new(6, 12)
	steam.SpreadAngle = Vector2.new(25, 25)
	steam.Rate = 0
	steam.EmissionDirection = Enum.NormalId.Right
	steam.Parent = water
	return CFrame.new(center + Vector3.new(0, 6.2, 0)), steam
end

local function buildSparks(root: Model, anvilTop: CFrame): ParticleEmitter
	local emitterPart = block(
		root,
		Vector3.new(0.2, 0.2, 0.2),
		anvilTop * CFrame.new(0, 0.4, 0),
		Color3.new(0, 0, 0)
	)
	emitterPart.Transparency = 1
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Sparks"
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(rgb(255, 230, 120), rgb(255, 110, 30))
	sparks.LightEmission = 1
	sparks.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	sparks.Lifetime = NumberRange.new(0.3, 0.7)
	sparks.Speed = NumberRange.new(14, 30)
	sparks.SpreadAngle = Vector2.new(80, 80)
	sparks.Acceleration = Vector3.new(0, -60, 0)
	sparks.EmissionDirection = Enum.NormalId.Top
	sparks.Rate = 0
	sparks.Parent = emitterPart
	return sparks
end

-- Returns the set, building it the first time.
function ForgeSet.get(): Set
	if current and current.root.Parent then
		return current
	end
	local root = Instance.new("Model")
	root.Name = "ForgeSet"
	buildRoom(root)
	local crucible, hinge, metal, metalBottom, metalTop, stream = buildCrucible(root)
	local moldCenter = buildMold(root)
	local anvilTop = buildAnvil(root)
	local hammer, grip = buildHammer(root, anvilTop)
	local barrelTop, steam = buildBarrel(root)
	local sparks = buildSparks(root, anvilTop)
	root.Parent = workspace
	local set: Set = {
		root = root,
		origin = ORIGIN,
		crucible = crucible,
		crucibleHinge = hinge,
		metal = metal,
		metalBottom = metalBottom,
		metalTop = metalTop,
		moldCenter = moldCenter,
		anvilTop = anvilTop,
		hammer = hammer,
		hammerGrip = grip,
		barrelTop = barrelTop,
		steam = steam,
		sparks = sparks,
		stream = stream,
	}
	current = set
	return set
end

return ForgeSet
