--!strict

--[[
	Builds a gun out of bricks. Each kind has a blueprint of blocks; colors come from the gun's
	catalog entry, and rarity decides size, glowing trim, and effects. Barrels point along the
	handle's -Z axis, and the "Muzzle" attachment sits at the barrel tip.
]]

const Attachments = require("./Attachments")
const Guns = require("./Guns")
const Rarity = require("./Rarity")

type ColorKey = "body" | "accent" | "trim" | "metal" | "dark"

type Block = {
	size: Vector3,
	offset: Vector3,
	color: ColorKey,
	-- "Cylinder" blocks are drawn with their axis along Z.
	shape: ("Block" | "Cylinder")?,
	-- Accent blocks glow once the gun is Rare or better.
	glow: boolean?,
}

local function block(
	sx: number,
	sy: number,
	sz: number,
	ox: number,
	oy: number,
	oz: number,
	color: ColorKey,
	glow: boolean?
): Block
	return {
		size = Vector3.new(sx, sy, sz),
		offset = Vector3.new(ox, oy, oz),
		color = color,
		glow = glow,
	}
end

local function tube(
	diameter: number,
	length: number,
	ox: number,
	oy: number,
	oz: number,
	color: ColorKey,
	glow: boolean?
): Block
	return {
		size = Vector3.new(diameter, diameter, length),
		offset = Vector3.new(ox, oy, oz),
		color = color,
		shape = "Cylinder",
		glow = glow,
	}
end

-- Every blueprint starts with the handle block, which becomes the tool's Handle.
const HANDLE = block(0.3, 0.85, 0.42, 0, -0.28, 0.16, "trim")

type Blueprint = { blocks: { Block }, muzzle: Vector3 }

const BLUEPRINTS: { [Guns.GunKind]: Blueprint } = {
	Pistol = {
		muzzle = Vector3.new(0, 0.3, -1.6),
		blocks = {
			HANDLE,
			block(0.36, 0.42, 1.55, 0, 0.27, -0.42, "body"),
			block(0.38, 0.1, 1.2, 0, 0.46, -0.45, "accent", true),
			tube(0.24, 0.45, 0, 0.3, -1.38, "metal"),
			block(0.08, 0.22, 0.36, 0, -0.06, -0.3, "dark"),
			block(0.12, 0.12, 0.14, 0, 0.55, 0.15, "dark"),
			block(0.12, 0.12, 0.14, 0, 0.55, -1.05, "dark"),
		},
	},
	SMG = {
		muzzle = Vector3.new(0, 0.26, -2),
		blocks = {
			HANDLE,
			block(0.42, 0.52, 1.6, 0, 0.22, -0.5, "body"),
			block(0.44, 0.12, 1.3, 0, 0.45, -0.55, "accent", true),
			tube(0.22, 0.7, 0, 0.26, -1.62, "metal"),
			block(0.24, 0.85, 0.32, 0, -0.48, -0.78, "accent"),
			block(0.22, 0.3, 0.75, 0, 0.12, 0.62, "trim"),
			block(0.3, 0.45, 0.14, 0, 0.0, 1.0, "dark"),
			block(0.1, 0.3, 0.1, 0, 0.6, -0.1, "dark"),
		},
	},
	Rifle = {
		muzzle = Vector3.new(0, 0.26, -2.95),
		blocks = {
			HANDLE,
			block(0.42, 0.55, 2.2, 0, 0.22, -0.55, "body"),
			block(0.48, 0.42, 0.95, 0, 0.2, -1.55, "accent", true),
			tube(0.2, 1.0, 0, 0.26, -2.45, "metal"),
			block(0.26, 0.9, 0.36, 0, -0.5, -0.7, "dark"),
			block(0.34, 0.55, 1.05, 0, 0.08, 0.98, "trim"),
			block(0.22, 0.22, 0.6, 0, 0.62, -0.5, "dark"),
			block(0.44, 0.08, 2.0, 0, 0.5, -0.6, "accent", true),
		},
	},
	Shotgun = {
		muzzle = Vector3.new(0, 0.36, -2.45),
		blocks = {
			HANDLE,
			block(0.46, 0.5, 1.3, 0, 0.2, -0.2, "body"),
			tube(0.34, 1.75, 0, 0.36, -1.5, "metal"),
			tube(0.26, 1.5, 0, 0.06, -1.4, "dark"),
			block(0.42, 0.32, 0.75, 0, 0.06, -1.4, "accent", true),
			block(0.36, 0.58, 1.15, 0, 0.02, 1.0, "trim"),
			block(0.38, 0.12, 0.9, 0, 0.47, -0.2, "accent", true),
		},
	},
	Burst = {
		muzzle = Vector3.new(0, 0.26, -2.6),
		blocks = {
			HANDLE,
			block(0.42, 0.58, 1.9, 0, 0.22, -0.5, "body"),
			block(0.46, 0.14, 1.6, 0, 0.5, -0.55, "accent", true),
			tube(0.2, 0.8, 0, 0.26, -1.95, "metal"),
			tube(0.3, 1.0, 0, 0.78, -0.5, "dark"),
			block(0.12, 0.14, 0.12, 0, 0.78, -1.05, "accent", true),
			block(0.26, 0.75, 0.34, 0, -0.45, -0.65, "dark"),
			block(0.32, 0.5, 0.9, 0, 0.1, 0.85, "trim"),
		},
	},
	Sniper = {
		muzzle = Vector3.new(0, 0.26, -4.1),
		blocks = {
			HANDLE,
			block(0.42, 0.52, 2.5, 0, 0.2, -0.65, "body"),
			tube(0.17, 2.1, 0, 0.26, -3.0, "metal"),
			block(0.26, 0.26, 0.4, 0, 0.26, -3.95, "dark"),
			tube(0.34, 1.5, 0, 0.82, -0.55, "dark"),
			block(0.36, 0.08, 1.1, 0, 0.82, -0.55, "accent", true),
			block(0.1, 0.3, 0.1, 0, 0.55, -0.2, "dark"),
			block(0.1, 0.3, 0.1, 0, 0.55, -0.95, "dark"),
			block(0.26, 0.6, 0.3, 0, -0.35, -0.8, "accent"),
			block(0.34, 0.6, 1.3, 0, 0.05, 1.1, "trim"),
			block(0.46, 0.1, 2.2, 0, 0.47, -0.7, "accent", true),
		},
	},
	Minigun = {
		muzzle = Vector3.new(0, 0.3, -3.0),
		blocks = {
			HANDLE,
			block(0.75, 0.75, 1.4, 0, 0.3, -0.25, "body"),
			block(0.78, 0.18, 1.2, 0, 0.72, -0.25, "accent", true),
			tube(0.12, 2.1, 0.17, 0.47, -1.9, "metal"),
			tube(0.12, 2.1, -0.17, 0.47, -1.9, "metal"),
			tube(0.12, 2.1, 0.17, 0.13, -1.9, "metal"),
			tube(0.12, 2.1, -0.17, 0.13, -1.9, "metal"),
			tube(0.12, 2.1, 0, 0.6, -1.9, "metal"),
			tube(0.12, 2.1, 0, 0.0, -1.9, "metal"),
			tube(0.62, 0.18, 0, 0.3, -1.2, "accent", true),
			tube(0.62, 0.18, 0, 0.3, -2.7, "dark"),
			block(0.55, 0.7, 0.65, 0.55, 0.15, -0.2, "accent"),
			block(0.12, 0.12, 0.9, 0, 0.85, 0.15, "dark"),
		},
	},
	Launcher = {
		muzzle = Vector3.new(0, 0.5, -2.4),
		blocks = {
			HANDLE,
			tube(0.6, 3.2, 0, 0.5, -0.5, "body"),
			tube(0.66, 0.22, 0, 0.5, -1.9, "accent", true),
			tube(0.66, 0.22, 0, 0.5, 0.9, "accent", true),
			tube(0.42, 0.3, 0, 0.5, -2.2, "dark"),
			block(0.28, 0.28, 0.6, 0, 0.95, -0.3, "dark"),
			block(0.3, 0.7, 0.35, 0, -0.15, -0.9, "trim"),
			block(0.1, 0.32, 0.1, 0.32, 0.5, 0.4, "accent"),
		},
	},
}

local GunBuilder = {}

GunBuilder.BASE_SCALE = 1.15

local function colorFor(def: Guns.GunDef, key: ColorKey): Color3
	if key == "body" then
		return def.body
	elseif key == "accent" then
		return def.accent
	elseif key == "trim" then
		return def.trim
	elseif key == "metal" then
		return def.trim:Lerp(Color3.fromRGB(150, 155, 165), 0.6)
	end
	return def.trim:Lerp(Color3.new(0, 0, 0), 0.45)
end

local function makePart(name: string, info: Block, color: Color3, rarity: number): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = info.size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	if info.shape == "Cylinder" then
		part.Shape = Enum.PartType.Cylinder
		-- Cylinders run along X, so the Z length moves into X before the part is turned.
		part.Size = Vector3.new(info.size.Z, info.size.Y, info.size.X)
	end
	if info.glow and rarity >= 3 then
		part.Material = Enum.Material.Neon
	elseif info.color == "metal" or info.color == "dark" then
		part.Material = Enum.Material.Metal
		part.Reflectance = 0.05
	end
	return part
end

local function buildCollection(def: Guns.GunDef, power: number?): Model?
	local folder = game.ReplicatedStorage:FindFirstChild("ForgeModels")
	local template = folder and folder:FindFirstChild(def.id)
	if not template or not template:IsA("Model") then
		return nil
	end
	local model = template:Clone()
	local grip = model:FindFirstChild("Handle") :: BasePart
	grip.Name = "Grip"
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.one * 0.1
	handle.Transparency = 1
	handle.CanCollide = false
	handle.CanQuery = false
	handle.CanTouch = false
	handle.Massless = true
	handle.Parent = model
	model.PrimaryPart = handle
	local tier = def.rarity
	local rarity = Rarity.get(tier)
	local palette = {
		Grip = def.trim,
		Stock = def.trim,
		Body = def.body,
		Shell = def.body:Lerp(Color3.new(1, 1, 1), 0.18),
		Metal = Color3.fromRGB(90, 102, 119),
		Tip = def.trim,
		Glow = def.accent,
		Crystal = rarity.glow,
	}
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and part ~= handle then
			part.Anchored = false
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.Massless = true
			if def.id ~= "PrismCarbine" then
				part.Color = palette[part.Name] or def.body
				part.Material = if (part.Name == "Glow" and tier >= 2)
						or part.Name == "Crystal"
					then Enum.Material.Neon
					elseif part.Name == "Metal" then Enum.Material.Metal
					else Enum.Material.SmoothPlastic
			end
			local weld = Instance.new("WeldConstraint")
			weld.Part0, weld.Part1 = handle, part
			weld.Parent = part
		end
	end
	local tip = (model:FindFirstChild("Tip") or model:FindFirstChild("Violet aperture")) :: BasePart
	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.Position = tip.Position - Vector3.zAxis * tip.Size.X / 2
	muzzle.Parent = handle
	if tier >= 3 then
		local light = Instance.new("PointLight")
		light.Color = def.accent
		light.Range = 2 + tier * 0.5
		light.Brightness = 0.25 + tier * 0.1
		light.Parent = muzzle
		local sparks = Instance.new("ParticleEmitter")
		sparks.Name = "ForgeGlints"
		sparks.Texture = "rbxassetid://92851213685130"
		sparks.Color = ColorSequence.new(def.accent, rarity.glow)
		sparks.LightEmission = 1
		sparks.Lifetime = NumberRange.new(0.35, 0.7)
		sparks.Rate = 2 + (tier - 3) * 2
		sparks.Speed = NumberRange.new(0.12, 0.65)
		sparks.SpreadAngle = Vector2.new(180, 180)
		sparks.Size = NumberSequence.new(0.14 + tier * 0.02, 0)
		sparks.Parent = muzzle
	end
	if tier >= 4 then
		for i = 1, tier - 3 do
			local angle = 2 * math.pi * i / (tier - 3)
			local function anchor(z: number, radius: number): Attachment
				local a = Instance.new("Attachment")
				a.Position = Vector3.new(
					math.cos(angle) * radius,
					muzzle.Position.Y + math.sin(angle) * radius,
					z
				)
				a.Orientation = Vector3.new(0, 0, math.deg(angle))
				a.Parent = handle
				return a
			end
			local arc = Instance.new("Beam")
			arc.Name = "EnergyArc"
			arc.Attachment0 = anchor(muzzle.Position.Z * 0.25, 0.25)
			arc.Attachment1 = anchor(muzzle.Position.Z * 0.92, 0.15)
			arc.CurveSize0 = 0.32
			arc.CurveSize1 = -0.28
			arc.Width0 = 0.035
			arc.Width1 = 0.012
			arc.FaceCamera = true
			arc.LightEmission = 1
			arc.Color = ColorSequence.new(def.accent, rarity.glow)
			arc.Parent = handle
		end
	end
	if tier >= 6 then
		local orbit = Instance.new("ParticleEmitter")
		orbit.Name = "StarCorona"
		orbit.Texture = "rbxassetid://92851213685130"
		orbit.Color = ColorSequence.new(rarity.color, rarity.glow)
		orbit.LightEmission = 1
		orbit.Rate = if tier == 7 then 10 else 5
		orbit.Lifetime = NumberRange.new(0.5, 1)
		orbit.Speed = NumberRange.new(0.3, 0.8)
		orbit.SpreadAngle = Vector2.new(180, 180)
		orbit.RotSpeed = NumberRange.new(-90, 90)
		orbit.Size = NumberSequence.new(0.3, 0)
		orbit.Parent = grip
	end
	model:ScaleTo(
		rarity.gunScale
			* GunBuilder.BASE_SCALE
			* (1 + math.clamp(math.log10(math.max(power or 1, 1)) * 0.03, 0, 0.4))
	)
	return model
end

--[[
	Builds the gun model. The handle is anchored-free and every other part is welded to it, so the
	result works both as a tool and, once anchored, as a display piece.
]]
function GunBuilder.build(def: Guns.GunDef, power: number?): Model
	local rarity = Rarity.get(def.rarity)
	local collection = buildCollection(def, power)
	if collection then
		return collection
	end
	local blueprint = BLUEPRINTS[def.kind]
	local model = Instance.new("Model")
	model.Name = def.id

	local handle: BasePart? = nil
	for index, info in blueprint.blocks do
		local part = makePart(
			if index == 1 then "Handle" else `Part{index}`,
			info,
			colorFor(def, info.color),
			def.rarity
		)
		local rotation = if info.shape == "Cylinder"
			then CFrame.Angles(0, math.rad(90), 0)
			else CFrame.identity
		part.CFrame = CFrame.new(info.offset) * rotation
		part.Parent = model
		if index == 1 then
			handle = part
			model.PrimaryPart = part
		end
	end
	assert(handle, "gun blueprint has no handle")

	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.Position = blueprint.muzzle
	muzzle.Parent = handle

	-- Higher rarities get extra flair: a fin pair from Epic, a halo ring from Legendary.
	if def.rarity >= 4 then
		for side = -1, 1, 2 do
			local fin = makePart(
				"Fin",
				block(0.06, 0.4, 0.7, 0, 0, 0, "accent", true),
				def.accent,
				def.rarity
			)
			fin.CFrame = CFrame.new(side * 0.26, 0.55, -0.2)
				* CFrame.Angles(0, 0, math.rad(side * -25))
			fin.Parent = model
		end
	end
	if def.rarity >= 5 then
		local ring =
			makePart("Halo", tube(0.9, 0.08, 0, 0, 0, "accent", true), def.accent, def.rarity)
		ring.Transparency = 0.25
		ring.CFrame = CFrame.new(blueprint.muzzle + Vector3.new(0, 0, 0.35))
			* CFrame.Angles(0, math.rad(90), 0)
		ring.Parent = model
	end

	if def.rarity >= 4 then
		local glowPart = model:FindFirstChild("Part2") :: BasePart?
		if glowPart then
			local light = Instance.new("PointLight")
			light.Color = rarity.glow
			light.Range = 6
			light.Brightness = 1.2
			light.Parent = glowPart

			local sparkle = Instance.new("ParticleEmitter")
			sparkle.Name = "RarityAura"
			sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			sparkle.Color = ColorSequence.new(rarity.color, rarity.glow)
			sparkle.LightEmission = 1
			sparkle.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.3, 0.35),
				NumberSequenceKeypoint.new(1, 0),
			})
			sparkle.Lifetime = NumberRange.new(0.5, 0.9)
			sparkle.Rate = 6 + (def.rarity - 4) * 6
			sparkle.Speed = NumberRange.new(0.3, 1)
			sparkle.SpreadAngle = Vector2.new(180, 180)
			sparkle.Parent = glowPart
		end
	end

	-- Weld everything to the handle so the model moves as one piece.
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and child ~= handle then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = child
			weld.Parent = child
		end
	end

	-- Bigger rarities make bigger guns, on top of a chunky base size that reads from behind.
	-- Power adds a little more: every tenfold jump in power makes the gun 3% bigger.
	local powerScale = 1 + math.clamp(math.log10(math.max(power or 1, 1)) * 0.03, 0, 0.4)
	model:ScaleTo(rarity.gunScale * GunBuilder.BASE_SCALE * powerScale)
	return model
end

--[[
	Adds a brick per attachment, in the part's rarity color, laid out on the gun's bounding box
	(barrel along -Z): a scope on top, a grip under the front, a muzzle extension past the barrel, a
	magazine under the middle, and a charm hanging off the back. Each is welded to the Handle.
]]
function GunBuilder.addParts(model: Model, parts: { [string]: string }?)
	local handle = model:FindFirstChild("Handle")
	if not parts or not handle or not handle:IsA("BasePart") then
		return
	end
	local box, size = model:GetBoundingBox()
	local unit = math.max(size.X, size.Y) * 0.25
	const layout: { [string]: { offset: Vector3, size: Vector3 } } = {
		Scope = {
			offset = Vector3.new(0, size.Y * 0.55, -size.Z * 0.1),
			size = Vector3.new(unit, unit, size.Z * 0.35),
		},
		Grip = {
			offset = Vector3.new(0, -size.Y * 0.35, -size.Z * 0.3),
			size = Vector3.new(unit * 0.8, unit * 2, unit * 0.8),
		},
		Barrel = {
			offset = Vector3.new(0, size.Y * 0.1, -size.Z * 0.56),
			size = Vector3.new(unit * 1.2, unit * 1.2, size.Z * 0.15),
		},
		Magazine = {
			offset = Vector3.new(0, -size.Y * 0.45, 0),
			size = Vector3.new(unit * 0.9, unit * 2.2, unit * 1.3),
		},
		Keychain = {
			offset = Vector3.new(size.X * 0.4, -size.Y * 0.3, size.Z * 0.42),
			size = Vector3.new(unit * 0.7, unit * 0.7, unit * 0.7),
		},
	}
	for slot, id in parts do
		local def = Attachments.get(id)
		local spot = layout[slot]
		if def and spot and def.slot == slot then
			local brick = Instance.new("Part")
			brick.Name = `Part_{slot}`
			brick.Anchored = false
			brick.CanCollide = false
			brick.CanQuery = false
			brick.CanTouch = false
			brick.Massless = true
			brick.Material = if def.rarity >= 5
				then Enum.Material.Neon
				else Enum.Material.SmoothPlastic
			brick.Color = Rarity.get(def.rarity).color
			brick.Shape = if slot == "Keychain" then Enum.PartType.Ball else Enum.PartType.Block
			brick.Size = spot.size
			brick.CFrame = box * CFrame.new(spot.offset)
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = brick
			weld.Parent = brick
			brick.Parent = model
		end
	end
end

--[[
	Wraps a built gun in a Tool. Every part is unanchored and welded, and the grip turns the barrel
	to point where the character faces.
]]
function GunBuilder.buildTool(
	def: Guns.GunDef,
	uid: string,
	power: number?,
	parts: { [string]: string }?
): Tool
	local model = GunBuilder.build(def, power)
	GunBuilder.addParts(model, parts)
	local tool = Instance.new("Tool")
	tool.Name = def.name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ManualActivationOnly = false
	tool:SetAttribute("GunId", def.id)
	tool:SetAttribute("GunUid", uid)
	for _, child in model:GetChildren() do
		child.Parent = tool
	end
	model:Destroy()
	-- The barrel runs along -Z; this grip lines that up with the hand's forward direction.
	tool.Grip = CFrame.new(0, -0.1, 0.15) * CFrame.Angles(0, 0, 0)
	return tool
end

-- The muzzle position in world space, for tracers and flashes.
function GunBuilder.muzzleOf(container: Instance): Attachment?
	local handle = container:FindFirstChild("Handle")
	if handle then
		return handle:FindFirstChild("Muzzle") :: Attachment?
	end
	return nil
end

return GunBuilder
