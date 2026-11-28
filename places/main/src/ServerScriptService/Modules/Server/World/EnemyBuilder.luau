--!strict

--[[
	Builds blocky enemies. Every enemy is an anchored, invisible "Root" with its body parts joined
	by Motor6Ds named after the limb they drive, so clients can swing arms and legs without the
	server sending animation data. The model's pivot is the Root, which sits at the enemy's feet.
]]

const Biomes = require("@game/ReplicatedStorage/Shared/Biomes")

type EnemyDef = Biomes.EnemyDef

local EnemyBuilder = {}

local function bodyPart(
	model: Model,
	root: BasePart,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = false
	part.Massless = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = true
	part.CastShadow = true
	part.CFrame = root.CFrame * offset
	part.Parent = model
	local joint = Instance.new("Motor6D")
	joint.Name = name
	joint.Part0 = root
	joint.Part1 = part
	joint.C0 = offset
	joint.C1 = CFrame.identity
	joint.Parent = root
	return part
end

-- A detail welded to a body part (eyes, teeth, hats). Details move with their parent limb.
local function detail(
	model: Model,
	parent: BasePart,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?
): Part
	local part = Instance.new("Part")
	part.Name = "Detail"
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = false
	part.Massless = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	if shape then
		part.Shape = shape
	end
	part.CFrame = parent.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = parent
	weld.Part1 = part
	weld.Parent = part
	part.Parent = model
	return part
end

local function eyes(
	model: Model,
	head: BasePart,
	def: EnemyDef,
	spacing: number,
	size: number,
	y: number
)
	local front = -head.Size.Z / 2 - 0.02
	for side = -1, 1, 2 do
		detail(
			model,
			head,
			Vector3.new(size, size, 0.1),
			CFrame.new(side * spacing, y, front),
			Color3.new(1, 1, 1)
		)
		detail(
			model,
			head,
			Vector3.new(size * 0.55, size * 0.55, 0.12),
			CFrame.new(side * spacing, y - size * 0.1, front - 0.02),
			def.accent,
			Enum.Material.Neon
		)
	end
end

local function mouth(model: Model, head: BasePart, width: number, y: number)
	local front = -head.Size.Z / 2 - 0.02
	detail(
		model,
		head,
		Vector3.new(width, 0.18, 0.1),
		CFrame.new(0, y, front),
		Color3.fromRGB(40, 25, 30)
	)
	-- Two little teeth.
	for side = -1, 1, 2 do
		detail(
			model,
			head,
			Vector3.new(0.16, 0.16, 0.1),
			CFrame.new(side * width * 0.25, y - 0.14, front - 0.01),
			Color3.new(1, 1, 1)
		)
	end
end

local function hat(model: Model, head: BasePart, def: EnemyDef)
	local top = head.Size.Y / 2
	local width = head.Size.X
	if def.hat == "Crown" then
		local gold = Color3.fromRGB(255, 205, 50)
		detail(
			model,
			head,
			Vector3.new(width * 0.95, 0.35, width * 0.95),
			CFrame.new(0, top + 0.17, 0),
			gold,
			Enum.Material.Metal
		)
		for index = 0, 3 do
			local angle = index * math.pi / 2
			detail(
				model,
				head,
				Vector3.new(0.3, 0.55, 0.3),
				CFrame.new(
					math.cos(angle) * width * 0.36,
					top + 0.6,
					math.sin(angle) * width * 0.36
				),
				gold,
				Enum.Material.Metal
			)
		end
		detail(
			model,
			head,
			Vector3.new(0.3, 0.3, 0.1),
			CFrame.new(0, top + 0.18, -width * 0.48),
			Color3.fromRGB(255, 60, 80),
			Enum.Material.Neon
		)
	elseif def.hat == "Horns" then
		for side = -1, 1, 2 do
			detail(
				model,
				head,
				Vector3.new(0.3, 0.8, 0.3),
				CFrame.new(side * width * 0.42, top + 0.3, 0) * CFrame.Angles(0, 0, side * -0.45),
				def.accent:Lerp(Color3.new(1, 1, 1), 0.5)
			)
		end
	elseif def.hat == "Helmet" then
		detail(
			model,
			head,
			Vector3.new(width * 1.1, head.Size.Y * 0.55, head.Size.Z * 1.1),
			CFrame.new(0, top - head.Size.Y * 0.2, 0),
			def.cloth,
			Enum.Material.Metal
		)
		detail(
			model,
			head,
			Vector3.new(width * 0.9, 0.12, 0.1),
			CFrame.new(0, 0.05, -head.Size.Z * 0.56),
			def.accent,
			Enum.Material.Neon
		)
	elseif def.hat == "Wrap" then
		for band = 0, 2 do
			detail(
				model,
				head,
				Vector3.new(width * 1.04, 0.16, head.Size.Z * 1.04),
				CFrame.new(0, -0.3 + band * 0.35, 0) * CFrame.Angles(0, 0, (band - 1) * 0.12),
				Color3.fromRGB(245, 240, 225)
			)
		end
	elseif def.hat == "Cap" then
		detail(
			model,
			head,
			Vector3.new(width * 1.25, 0.4, width * 1.25),
			CFrame.new(0, top + 0.2, 0),
			def.cloth
		)
		detail(
			model,
			head,
			Vector3.new(width * 0.7, 0.35, width * 0.7),
			CFrame.new(0, top + 0.5, 0),
			def.cloth
		)
		detail(
			model,
			head,
			Vector3.new(0.3, 0.12, 0.3),
			CFrame.new(width * 0.2, top + 0.42, -width * 0.3),
			Color3.new(1, 1, 1)
		)
	elseif def.hat == "Spikes" then
		for index = -1, 1 do
			detail(
				model,
				head,
				Vector3.new(0.3, 0.7, 0.3),
				CFrame.new(index * width * 0.3, top + 0.3, 0) * CFrame.Angles(0, 0, index * -0.3),
				def.accent,
				Enum.Material.Neon
			)
		end
	end
end

local function makeRoot(model: Model, size: Vector3): Part
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = size
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = true
	root.CFrame = CFrame.new(0, size.Y / 2, 0)
	root.Parent = model
	model.PrimaryPart = root
	return root
end

local function buildHumanoid(model: Model, def: EnemyDef)
	-- About 5 studs tall at scale 1, built around a root at mid-height.
	local root = makeRoot(model, Vector3.new(3.4, 5, 2))
	local half = 2.5
	bodyPart(
		model,
		root,
		"LeftLeg",
		Vector3.new(0.95, 1.8, 0.95),
		CFrame.new(-0.5, 0.9 - half, 0),
		def.cloth:Lerp(Color3.new(0, 0, 0), 0.25)
	)
	bodyPart(
		model,
		root,
		"RightLeg",
		Vector3.new(0.95, 1.8, 0.95),
		CFrame.new(0.5, 0.9 - half, 0),
		def.cloth:Lerp(Color3.new(0, 0, 0), 0.25)
	)
	local torso = bodyPart(
		model,
		root,
		"Torso",
		Vector3.new(2, 1.8, 1.05),
		CFrame.new(0, 2.7 - half, 0),
		def.cloth
	)
	detail(
		model,
		torso,
		Vector3.new(2.04, 0.3, 1.09),
		CFrame.new(0, -0.65, 0),
		def.cloth:Lerp(Color3.new(0, 0, 0), 0.4)
	)
	detail(model, torso, Vector3.new(0.5, 0.5, 0.1), CFrame.new(0.45, 0.35, -0.56), def.accent)
	-- Arms reach forward, the classic zombie pose; the client swings them from here.
	local reach = CFrame.Angles(math.rad(80), 0, 0)
	bodyPart(
		model,
		root,
		"LeftArm",
		Vector3.new(0.9, 1.8, 0.9),
		CFrame.new(-1.45, 3.35 - half, 0) * reach * CFrame.new(0, -0.65, 0),
		def.skin
	)
	bodyPart(
		model,
		root,
		"RightArm",
		Vector3.new(0.9, 1.8, 0.9),
		CFrame.new(1.45, 3.35 - half, 0) * reach * CFrame.new(0, -0.65, 0),
		def.skin
	)
	local head = bodyPart(
		model,
		root,
		"Head",
		Vector3.new(1.3, 1.3, 1.3),
		CFrame.new(0, 4.25 - half, 0),
		def.skin
	)
	eyes(model, head, def, 0.3, 0.32, 0.15)
	mouth(model, head, 0.6, -0.3)
	hat(model, head, def)
end

local function buildBrute(model: Model, def: EnemyDef)
	local root = makeRoot(model, Vector3.new(5.6, 6, 3))
	local half = 3
	bodyPart(
		model,
		root,
		"LeftLeg",
		Vector3.new(1.4, 1.7, 1.4),
		CFrame.new(-0.9, 0.85 - half, 0),
		def.cloth
	)
	bodyPart(
		model,
		root,
		"RightLeg",
		Vector3.new(1.4, 1.7, 1.4),
		CFrame.new(0.9, 0.85 - half, 0),
		def.cloth
	)
	local torso = bodyPart(
		model,
		root,
		"Torso",
		Vector3.new(3.8, 2.8, 2.3),
		CFrame.new(0, 3.1 - half, 0),
		def.skin
	)
	detail(model, torso, Vector3.new(3.84, 0.8, 2.34), CFrame.new(0, -1, 0), def.cloth)
	detail(
		model,
		torso,
		Vector3.new(1.2, 1.2, 0.1),
		CFrame.new(0, 0.3, -1.17),
		def.accent,
		Enum.Material.Neon
	)
	bodyPart(
		model,
		root,
		"LeftArm",
		Vector3.new(1.4, 2.9, 1.4),
		CFrame.new(-2.6, 3.2 - half, 0) * CFrame.new(0, -0.6, 0),
		def.skin:Lerp(Color3.new(0, 0, 0), 0.1)
	)
	bodyPart(
		model,
		root,
		"RightArm",
		Vector3.new(1.4, 2.9, 1.4),
		CFrame.new(2.6, 3.2 - half, 0) * CFrame.new(0, -0.6, 0),
		def.skin:Lerp(Color3.new(0, 0, 0), 0.1)
	)
	local head = bodyPart(
		model,
		root,
		"Head",
		Vector3.new(1.6, 1.4, 1.5),
		CFrame.new(0, 5.2 - half, -0.2),
		def.skin
	)
	eyes(model, head, def, 0.38, 0.34, 0.1)
	mouth(model, head, 0.9, -0.38)
	hat(model, head, def)
end

local function buildBlob(model: Model, def: EnemyDef)
	local root = makeRoot(model, Vector3.new(4.4, 3.6, 4.4))
	local half = 1.8
	local body = bodyPart(
		model,
		root,
		"Torso",
		Vector3.new(4.2, 2.4, 4.2),
		CFrame.new(0, 1.2 - half, 0),
		def.skin
	)
	body.Transparency = 0.08
	local top =
		bodyPart(model, root, "Head", Vector3.new(3, 1.3, 3), CFrame.new(0, 3 - half, 0), def.skin)
	top.Transparency = 0.08
	detail(model, body, Vector3.new(4.24, 0.4, 4.24), CFrame.new(0, -1, 0), def.cloth)
	-- Big cartoon eyes on the front of the body.
	local front = -body.Size.Z / 2 - 0.02
	for side = -1, 1, 2 do
		detail(
			model,
			body,
			Vector3.new(1, 1, 0.12),
			CFrame.new(side * 0.8, 0.45, front),
			Color3.new(1, 1, 1)
		)
		detail(
			model,
			body,
			Vector3.new(0.5, 0.5, 0.14),
			CFrame.new(side * 0.8, 0.35, front - 0.02),
			Color3.fromRGB(30, 30, 40)
		)
	end
	detail(
		model,
		body,
		Vector3.new(1.6, 0.3, 0.12),
		CFrame.new(0, -0.35, front),
		Color3.fromRGB(40, 30, 40)
	)
	hat(model, top, def)
end

local function buildCritter(model: Model, def: EnemyDef)
	local root = makeRoot(model, Vector3.new(2.6, 2.4, 3.4))
	local half = 1.2
	local body = bodyPart(
		model,
		root,
		"Torso",
		Vector3.new(2.2, 1.3, 2.8),
		CFrame.new(0, 1.15 - half, 0.2),
		def.skin
	)
	detail(model, body, Vector3.new(1.6, 0.2, 2.3), CFrame.new(0, -0.62, 0), def.cloth)
	local head = bodyPart(
		model,
		root,
		"Head",
		Vector3.new(1.6, 1.2, 1.2),
		CFrame.new(0, 1.6 - half, -1.5),
		def.skin
	)
	eyes(model, head, def, 0.4, 0.38, 0.25)
	bodyPart(
		model,
		root,
		"LeftLeg",
		Vector3.new(0.45, 0.6, 0.45),
		CFrame.new(-0.8, 0.3 - half, -0.6),
		def.cloth
	)
	bodyPart(
		model,
		root,
		"RightLeg",
		Vector3.new(0.45, 0.6, 0.45),
		CFrame.new(0.8, 0.3 - half, -0.6),
		def.cloth
	)
	bodyPart(
		model,
		root,
		"LeftArm",
		Vector3.new(0.45, 0.6, 0.45),
		CFrame.new(-0.8, 0.3 - half, 1),
		def.cloth
	)
	bodyPart(
		model,
		root,
		"RightArm",
		Vector3.new(0.45, 0.6, 0.45),
		CFrame.new(0.8, 0.3 - half, 1),
		def.cloth
	)
	hat(model, head, def)
end

local function buildFloater(model: Model, def: EnemyDef)
	local root = makeRoot(model, Vector3.new(3.2, 5.5, 3.2))
	local half = 2.75
	local body = bodyPart(
		model,
		root,
		"Head",
		Vector3.new(2.6, 2.6, 2.6),
		CFrame.new(0, 3.8 - half, 0),
		def.skin,
		Enum.Material.SmoothPlastic
	)
	local front = -body.Size.Z / 2 - 0.02
	detail(model, body, Vector3.new(1.3, 1.3, 0.12), CFrame.new(0, 0.1, front), Color3.new(1, 1, 1))
	detail(
		model,
		body,
		Vector3.new(0.7, 0.7, 0.14),
		CFrame.new(0, 0.05, front - 0.02),
		def.accent,
		Enum.Material.Neon
	)
	local ring = bodyPart(
		model,
		root,
		"Torso",
		Vector3.new(0.3, 4, 4),
		CFrame.new(0, 3.8 - half, 0) * CFrame.Angles(0, 0, math.rad(90)),
		def.cloth,
		Enum.Material.Neon
	)
	ring.Shape = Enum.PartType.Cylinder
	ring.Transparency = 0.35
	-- A wispy tail of shrinking blocks below the body.
	local tail = bodyPart(
		model,
		root,
		"LeftLeg",
		Vector3.new(1.6, 1.2, 1.6),
		CFrame.new(0, 2 - half, 0),
		def.skin:Lerp(def.cloth, 0.4)
	)
	detail(model, tail, Vector3.new(1, 1, 1), CFrame.new(0, -1, 0), def.cloth)
	detail(
		model,
		tail,
		Vector3.new(0.5, 0.7, 0.5),
		CFrame.new(0, -1.8, 0),
		def.cloth,
		Enum.Material.Neon
	)
	hat(model, body, def)
end

--[[
	Builds an enemy model for a catalog entry at a size multiplier. The returned model's pivot is
	its Root; callers move it with PivotTo or BulkMoveTo. Attributes record what the client needs
	for health bars and labels.
]]
function EnemyBuilder.build(def: EnemyDef, scale: number, isBoss: boolean): Model
	local model = Instance.new("Model")
	model.Name = def.name
	if def.shape == "Humanoid" then
		buildHumanoid(model, def)
	elseif def.shape == "Brute" then
		buildBrute(model, def)
	elseif def.shape == "Blob" then
		buildBlob(model, def)
	elseif def.shape == "Critter" then
		buildCritter(model, def)
	else
		buildFloater(model, def)
	end
	model:SetAttribute("Shape", def.shape)
	model:SetAttribute("Boss", isBoss)
	model:SetAttribute("DisplayName", def.name)
	if isBoss then
		local root = model.PrimaryPart :: BasePart
		local aura = Instance.new("ParticleEmitter")
		aura.Name = "BossAura"
		aura.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		aura.Color = ColorSequence.new(def.accent, Color3.new(1, 1, 1))
		aura.LightEmission = 1
		aura.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.3, 0.6),
			NumberSequenceKeypoint.new(1, 0),
		})
		aura.Lifetime = NumberRange.new(0.8, 1.4)
		aura.Rate = 20
		aura.Speed = NumberRange.new(1, 3)
		aura.SpreadAngle = Vector2.new(180, 180)
		aura.Parent = root
	end
	if scale ~= 1 then
		model:ScaleTo(scale)
	end
	return model
end

-- Height of the root's center above the feet, for placing an enemy on the floor.
function EnemyBuilder.rootHeight(model: Model): number
	local root = model.PrimaryPart
	return if root then root.Size.Y / 2 else 2.5
end

return EnemyBuilder
