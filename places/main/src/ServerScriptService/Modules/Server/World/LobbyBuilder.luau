--!strict

--[[
	Builds the lobby: a walled brick plaza with training pads to the north, the forge workshop to
	the east, the upgrade stall and rebirth altar to the west, and the Gauntlet portal to the south.
	Run it once in Studio to bake the map, or let the server build it when the place has none.
]]

const Balance = require("@game/ReplicatedStorage/Shared/Balance")
const Bricks = require("./Bricks")
const Props = require("./Props")

local LobbyBuilder = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

const PLAZA_X = 240
const PLAZA_Z = 300
const WALL_HEIGHT = 26
const WALL_THICK = 4

const STONE = rgb(160, 172, 196)
const STONE_ALT = rgb(146, 158, 184)
const WALL_A = rgb(70, 130, 230)
const WALL_B = rgb(60, 115, 210)
const TRIM = rgb(235, 238, 245)
const CARPET = rgb(225, 45, 60)
const BANNER = rgb(220, 50, 55)
const GOLD = rgb(255, 205, 60)

-- Colors for the eight training pads, from the starting pad to the last.
const PAD_COLORS = {
	rgb(110, 210, 90),
	rgb(70, 200, 200),
	rgb(70, 140, 255),
	rgb(160, 90, 255),
	rgb(255, 90, 200),
	rgb(255, 150, 40),
	rgb(240, 60, 60),
	rgb(255, 210, 40),
}

local function battlements(parent: Instance, base: CFrame, length: number, color: Color3)
	local step = 8
	local count = math.floor(length / step)
	for index = 0, count - 1 do
		local x = -length / 2 + step * index + step / 4 + 2
		local merlon = Bricks.part(parent, {
			name = "Merlon",
			size = Vector3.new(4, 4, WALL_THICK + 0.4),
			cframe = base * CFrame.new(x, WALL_HEIGHT + 2, 0),
			color = color,
		})
		Bricks.studTop(parent, merlon, nil, 2, 4)
	end
	-- A light trim ledge where the battlements meet the wall.
	Bricks.part(parent, {
		name = "Ledge",
		size = Vector3.new(length, 1, WALL_THICK + 1.2),
		cframe = base * CFrame.new(0, WALL_HEIGHT + 0.5, 0),
		color = TRIM,
	})
end

local function tower(parent: Instance, position: Vector3)
	local model = Instance.new("Model")
	model.Name = "Tower"
	model.Parent = parent
	local size = 18
	local height = WALL_HEIGHT + 14
	Bricks.wall(
		model,
		CFrame.new(position + Vector3.new(0, 0, size / 2)),
		size,
		height,
		2,
		WALL_A,
		WALL_B,
		nil,
		nil,
		6,
		2.5,
		false
	)
	Bricks.wall(
		model,
		CFrame.new(position + Vector3.new(0, 0, -size / 2)) * CFrame.Angles(0, math.pi, 0),
		size,
		height,
		2,
		WALL_A,
		WALL_B,
		nil,
		nil,
		6,
		2.5,
		false
	)
	Bricks.wall(
		model,
		CFrame.new(position + Vector3.new(size / 2, 0, 0)) * CFrame.Angles(0, math.pi / 2, 0),
		size,
		height,
		2,
		WALL_A,
		WALL_B,
		nil,
		nil,
		6,
		2.5,
		false
	)
	Bricks.wall(
		model,
		CFrame.new(position + Vector3.new(-size / 2, 0, 0)) * CFrame.Angles(0, -math.pi / 2, 0),
		size,
		height,
		2,
		WALL_A,
		WALL_B,
		nil,
		nil,
		6,
		2.5,
		false
	)
	Bricks.part(model, {
		name = "Cap",
		size = Vector3.new(size + 3, 1.4, size + 3),
		cframe = CFrame.new(position + Vector3.new(0, height + 0.7, 0)),
		color = TRIM,
	})
	-- Corner merlons and a stepped red roof.
	for _, corner in
		{
			Vector3.new(1, 0, 1),
			Vector3.new(-1, 0, 1),
			Vector3.new(1, 0, -1),
			Vector3.new(-1, 0, -1),
		}
	do
		local merlon = Bricks.part(model, {
			name = "Merlon",
			size = Vector3.new(4.5, 4, 4.5),
			cframe = CFrame.new(
				position + corner * (size / 2 - 0.75) + Vector3.new(0, height + 3.4, 0)
			),
			color = WALL_A,
		})
		Bricks.studTop(model, merlon, nil, 2, 4)
	end
	local roofSizes = { 14, 10.5, 7, 3.5 }
	for index, width in roofSizes do
		local layer = Bricks.part(model, {
			name = "Roof",
			size = Vector3.new(width, 3, width),
			cframe = CFrame.new(position + Vector3.new(0, height + 1.4 + index * 3 - 1.5, 0)),
			color = if index % 2 == 0 then rgb(200, 40, 50) else rgb(225, 55, 60),
		})
		if index == #roofSizes then
			Bricks.studTop(model, layer, nil, 1.8, 4)
		end
	end
	local flagPole = Bricks.part(model, {
		name = "Pole",
		size = Vector3.new(0.5, 8, 0.5),
		cframe = CFrame.new(position + Vector3.new(0, height + 17, 0)),
		color = rgb(80, 80, 90),
	})
	Bricks.part(model, {
		name = "Flag",
		size = Vector3.new(0.2, 3, 4.5),
		cframe = flagPole.CFrame * CFrame.new(0, 2.2, 2.3),
		color = GOLD,
		collide = false,
	})
end

local function perimeter(parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Walls"
	model.Parent = parent
	local halfX = PLAZA_X / 2
	local halfZ = PLAZA_Z / 2
	local sides = {
		-- North wall: faces the plaza (+Z).
		{ cframe = CFrame.new(0, 0, -halfZ), length = PLAZA_X },
		{ cframe = CFrame.new(0, 0, halfZ) * CFrame.Angles(0, math.pi, 0), length = PLAZA_X },
		{ cframe = CFrame.new(halfX, 0, 0) * CFrame.Angles(0, -math.pi / 2, 0), length = PLAZA_Z },
		{ cframe = CFrame.new(-halfX, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), length = PLAZA_Z },
	}
	for _, side in sides do
		local base = side.cframe
		local length = side.length
		Bricks.wall(
			model,
			base,
			length,
			WALL_HEIGHT,
			WALL_THICK,
			WALL_A,
			WALL_B,
			nil,
			nil,
			6,
			2.6,
			false
		)
		battlements(model, base, length, WALL_A)
		-- Banners every 40 studs along the inner face, with a torch between each pair.
		local count = math.floor(length / 40)
		for index = 1, count do
			local x = -length / 2 + (index - 0.5) * (length / count)
			local inner = base * CFrame.new(x, WALL_HEIGHT - 3, WALL_THICK / 2 + 0.4)
			Props.banner(model, inner, 6, 12, BANNER, GOLD)
			if index < count then
				local torchX = x + length / count / 2
				local torchPosition = (base * CFrame.new(torchX, 11, WALL_THICK / 2 + 0.2)).Position
				Props.torch(model, torchPosition, base.LookVector)
			end
		end
	end
	for _, corner in
		{
			Vector3.new(halfX, 0, halfZ),
			Vector3.new(-halfX, 0, halfZ),
			Vector3.new(halfX, 0, -halfZ),
			Vector3.new(-halfX, 0, -halfZ),
		}
	do
		tower(model, corner)
	end
end

local function trainingGrounds(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Training"
	folder.Parent = parent
	local spacing = 27
	for index, zone in Balance.TRAINING_ZONES do
		local zoneModel = Instance.new("Model")
		zoneModel.Name = `Zone{index}`
		zoneModel:SetAttribute("Zone", index)
		zoneModel.Parent = folder
		local x = -spacing * 3.5 + (index - 1) * spacing
		local color = PAD_COLORS[index]

		local pad = Bricks.part(zoneModel, {
			name = "Pad",
			size = Vector3.new(20, 1, 20),
			cframe = CFrame.new(x, 0.5, -92),
			color = color,
		})
		pad:SetAttribute("Zone", index)
		Bricks.part(zoneModel, {
			name = "PadRim",
			size = Vector3.new(22, 0.6, 22),
			cframe = CFrame.new(x, 0.3, -92),
			color = TRIM,
		})
		local glow = Bricks.part(zoneModel, {
			name = "Glow",
			size = Vector3.new(16, 0.2, 16),
			cframe = CFrame.new(x, 1.05, -92),
			color = color:Lerp(Color3.new(1, 1, 1), 0.35),
			material = Enum.Material.Neon,
			collide = false,
			shadow = false,
		})
		glow.Transparency = 0.7
		Bricks.studTop(zoneModel, pad, nil, 2.5, 30)

		local multiplierText = `{zone.multiplier}x Power`
		local label = Props.label(
			pad,
			multiplierText,
			color:Lerp(Color3.new(1, 1, 1), 0.35),
			Vector3.new(0, 9, 0),
			12
		)
		label.Name = "ZoneLabel"
		if zone.rebirthsNeeded > 0 then
			local lock = Props.label(
				pad,
				`🔒 Rebirth {zone.rebirthsNeeded}`,
				Color3.fromRGB(255, 255, 255),
				Vector3.new(0, 5.6, 0),
				8
			)
			lock.Name = "LockLabel"
		end

		-- The target: a bullseye board on two posts, facing the pad.
		local target = Instance.new("Model")
		target.Name = "Target"
		target:SetAttribute("Zone", index)
		target:SetAttribute("TrainingTarget", true)
		target.Parent = zoneModel
		local boardCenter = Vector3.new(x, 11, -128)
		for side = -1, 1, 2 do
			Bricks.part(target, {
				name = "Post",
				size = Vector3.new(1.2, 11, 1.2),
				cframe = CFrame.new(x + side * 6, 5.5, -129.5),
				color = rgb(120, 85, 55),
			})
		end
		local rings = {
			{ diameter = 13, color = rgb(240, 240, 245) },
			{ diameter = 10.4, color = rgb(230, 50, 55) },
			{ diameter = 7.8, color = rgb(240, 240, 245) },
			{ diameter = 5.2, color = rgb(230, 50, 55) },
			{ diameter = 2.6, color = GOLD },
		}
		for ringIndex, ring in rings do
			local disc = Bricks.part(target, {
				name = if ringIndex == 1 then "Board" else "Ring",
				size = Vector3.new(0.6 + ringIndex * 0.12, ring.diameter, ring.diameter),
				cframe = CFrame.new(boardCenter + Vector3.new(0, 0, ringIndex * 0.06))
					* CFrame.Angles(0, math.rad(90), 0),
				color = ring.color,
				shape = Enum.PartType.Cylinder,
			})
			disc:SetAttribute("Zone", index)
			if ringIndex == 1 then
				target.PrimaryPart = disc
			end
		end
		Bricks.part(target, {
			name = "Frame",
			size = Vector3.new(14.5, 1, 1.4),
			cframe = CFrame.new(boardCenter + Vector3.new(0, 7.2, -0.5)),
			color = color,
		})
	end
	-- A low fence behind the targets catches stray shots visually.
	Bricks.wall(
		folder,
		CFrame.new(0, 0, -138),
		spacing * 8 + 4,
		4,
		2,
		TRIM,
		STONE_ALT,
		nil,
		nil,
		4,
		2,
		true
	)
end

local function forgeWorkshop(parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Forge"
	model.Parent = parent
	local origin = Vector3.new(92, 0, -8)

	Bricks.floor(
		model,
		CFrame.new(origin + Vector3.new(0, 0.6, 0)),
		40,
		48,
		8,
		rgb(150, 110, 90),
		rgb(135, 98, 80),
		nil,
		nil
	)
	-- Back wall and side walls, open toward the plaza.
	Bricks.wall(
		model,
		CFrame.new(origin + Vector3.new(20, 0, 0)) * CFrame.Angles(0, -math.pi / 2, 0),
		48,
		22,
		2,
		rgb(160, 95, 70),
		rgb(145, 85, 62),
		nil,
		nil,
		4,
		2,
		true
	)
	Bricks.wall(
		model,
		CFrame.new(origin + Vector3.new(0, 0, -24)),
		40,
		22,
		2,
		rgb(160, 95, 70),
		rgb(145, 85, 62),
		nil,
		nil,
		4,
		2,
		true
	)
	Bricks.wall(
		model,
		CFrame.new(origin + Vector3.new(0, 0, 24)) * CFrame.Angles(0, math.pi, 0),
		40,
		22,
		2,
		rgb(160, 95, 70),
		rgb(145, 85, 62),
		nil,
		nil,
		4,
		2,
		true
	)
	-- Slanted roof made of stepped slabs.
	for step = 0, 4 do
		Bricks.part(model, {
			name = "Roof",
			size = Vector3.new(9, 1.4, 54),
			cframe = CFrame.new(origin + Vector3.new(16 - step * 8, 22 + step * 1.4, 0)),
			color = if step % 2 == 0 then rgb(90, 70, 70) else rgb(105, 82, 80),
		})
	end
	-- Chimney with smoke.
	local chimney = Bricks.part(model, {
		name = "Chimney",
		size = Vector3.new(6, 16, 6),
		cframe = CFrame.new(origin + Vector3.new(14, 30, -16)),
		color = rgb(120, 70, 55),
	})
	local smoke = Instance.new("Smoke")
	smoke.Color = rgb(200, 200, 205)
	smoke.Opacity = 0.25
	smoke.RiseVelocity = 7
	smoke.Size = 6
	smoke.Parent = chimney

	-- The furnace: a glowing mouth in a stone block.
	local furnace = Bricks.part(model, {
		name = "Furnace",
		size = Vector3.new(10, 12, 12),
		cframe = CFrame.new(origin + Vector3.new(13, 6.6, -12)),
		color = rgb(110, 110, 120),
	})
	Bricks.studTop(model, furnace, nil, 2, 20)
	local mouth = Bricks.part(model, {
		name = "FurnaceGlow",
		size = Vector3.new(0.6, 5, 7),
		cframe = CFrame.new(origin + Vector3.new(7.8, 4.6, -12)),
		color = rgb(255, 120, 30),
		material = Enum.Material.Neon,
		collide = false,
	})
	local fire = Instance.new("Fire")
	fire.Size = 5
	fire.Heat = 4
	fire.Color = rgb(255, 140, 40)
	fire.SecondaryColor = rgb(255, 60, 20)
	fire.Parent = mouth
	local furnaceLight = Instance.new("PointLight")
	furnaceLight.Color = rgb(255, 140, 60)
	furnaceLight.Range = 26
	furnaceLight.Brightness = 2.2
	furnaceLight.Parent = mouth

	-- The crucible of molten metal, hanging over a trough.
	local crucible = Bricks.part(model, {
		name = "Crucible",
		size = Vector3.new(8, 5, 8),
		cframe = CFrame.new(origin + Vector3.new(4, 9, 12)),
		color = rgb(130, 135, 145),
	})
	Bricks.part(model, {
		name = "Molten",
		size = Vector3.new(6.6, 0.4, 6.6),
		cframe = crucible.CFrame * CFrame.new(0, 2.4, 0),
		color = rgb(255, 150, 30),
		material = Enum.Material.Neon,
		collide = false,
	})
	for side = -1, 1, 2 do
		Bricks.part(model, {
			name = "Chain",
			size = Vector3.new(0.5, 10, 0.5),
			cframe = crucible.CFrame * CFrame.new(side * 3.6, 7.5, 0),
			color = rgb(220, 220, 228),
			collide = false,
		})
	end
	Bricks.part(model, {
		name = "Trough",
		size = Vector3.new(10, 1.6, 4),
		cframe = CFrame.new(origin + Vector3.new(2, 1.6, 12)),
		color = rgb(90, 90, 100),
	})
	local lava = Bricks.part(model, {
		name = "TroughLava",
		size = Vector3.new(9, 0.3, 3),
		cframe = CFrame.new(origin + Vector3.new(2, 2.4, 12)),
		color = rgb(255, 120, 20),
		material = Enum.Material.Neon,
		collide = false,
	})
	local lavaLight = Instance.new("PointLight")
	lavaLight.Color = rgb(255, 150, 60)
	lavaLight.Range = 16
	lavaLight.Parent = lava

	-- The anvil, where the forge prompt lives.
	local anvilBase = Bricks.part(model, {
		name = "AnvilBase",
		size = Vector3.new(3, 3, 4),
		cframe = CFrame.new(origin + Vector3.new(-6, 2.6, -2)),
		color = rgb(70, 70, 80),
	})
	local anvil = Bricks.part(model, {
		name = "Anvil",
		size = Vector3.new(4.4, 1.8, 7),
		cframe = anvilBase.CFrame * CFrame.new(0, 2.4, 0),
		color = rgb(85, 88, 98),
		material = Enum.Material.Metal,
	})
	Bricks.part(model, {
		name = "AnvilHorn",
		size = Vector3.new(2.4, 1.2, 2.6),
		cframe = anvil.CFrame * CFrame.new(0, 0.2, -4.6),
		color = rgb(85, 88, 98),
		material = Enum.Material.Metal,
	})
	Bricks.part(model, {
		name = "AnvilFoot",
		size = Vector3.new(5, 1.2, 6),
		cframe = CFrame.new(origin + Vector3.new(-6, 1.2, -2)),
		color = rgb(70, 70, 80),
	})
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Sparks"
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(rgb(255, 220, 90), rgb(255, 100, 30))
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.25, 0)
	sparks.Lifetime = NumberRange.new(0.3, 0.6)
	sparks.Rate = 10
	sparks.Speed = NumberRange.new(8, 14)
	sparks.SpreadAngle = Vector2.new(60, 60)
	sparks.Acceleration = Vector3.new(0, -40, 0)
	sparks.EmissionDirection = Enum.NormalId.Top
	sparks.Parent = anvil
	anvil:SetAttribute("Station", "Forge")
	Props.label(anvil, "Forge", rgb(255, 170, 60), Vector3.new(0, 9, 0), 12)

	-- Selling happens in the Backpack, so the workshop has no sell counter.
	for index = 1, 3 do
		Props.barrel(
			model,
			origin + Vector3.new(15, 1.2, 4 + index * 4.5),
			if index == 2 then rgb(220, 70, 60) else rgb(60, 120, 220)
		)
	end
	Props.crate(model, CFrame.new(origin + Vector3.new(-16, 3.2, -18)), 4)
	Props.crate(
		model,
		CFrame.new(origin + Vector3.new(-12, 3.2, -18)) * CFrame.Angles(0, 0.3, 0),
		4
	)
	Props.crate(
		model,
		CFrame.new(origin + Vector3.new(-14, 7.2, -18)) * CFrame.Angles(0, -0.2, 0),
		4
	)
end

local function rebirthAltar(parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Rebirth"
	model.Parent = parent
	local origin = Vector3.new(-88, 0, 48)
	local steps = { { 22, 1.2 }, { 17, 1.2 }, { 12, 1.2 } }
	local y = 0
	for index, step in steps do
		local slab = Bricks.part(model, {
			name = "Step",
			size = Vector3.new(step[1], step[2], step[1]),
			cframe = CFrame.new(origin + Vector3.new(0, y + step[2] / 2, 0)),
			color = if index % 2 == 0 then rgb(170, 120, 255) else TRIM,
		})
		if index == 1 then
			Bricks.studTop(model, slab, nil, 2.5, 40)
		end
		y += step[2]
	end
	local crystal = Bricks.part(model, {
		name = "Crystal",
		size = Vector3.new(5, 9, 5),
		cframe = CFrame.new(origin + Vector3.new(0, y + 7, 0)) * CFrame.Angles(0, math.rad(45), 0),
		color = rgb(190, 120, 255),
		material = Enum.Material.Neon,
		collide = false,
	})
	crystal.Transparency = 0.1
	crystal:SetAttribute("Spin", 0.6)
	crystal:SetAttribute("Station", "Rebirth")
	local light = Instance.new("PointLight")
	light.Color = rgb(200, 140, 255)
	light.Range = 24
	light.Brightness = 2
	light.Parent = crystal
	local aura = Instance.new("ParticleEmitter")
	aura.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	aura.Color = ColorSequence.new(rgb(220, 160, 255), rgb(120, 220, 255))
	aura.LightEmission = 1
	aura.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.4, 0.7),
		NumberSequenceKeypoint.new(1, 0),
	})
	aura.Lifetime = NumberRange.new(1, 1.8)
	aura.Rate = 14
	aura.Speed = NumberRange.new(1, 3)
	aura.SpreadAngle = Vector2.new(180, 180)
	aura.Parent = crystal
	Props.label(crystal, "Rebirth", rgb(220, 160, 255), Vector3.new(0, 9, 0), 12)
end

local function portal(parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Portal"
	model.Parent = parent
	local origin = Vector3.new(0, 0, 128)
	-- Stone pillars and a stepped arch.
	for side = -1, 1, 2 do
		local pillar = Bricks.part(model, {
			name = "Pillar",
			size = Vector3.new(6, 30, 6),
			cframe = CFrame.new(origin + Vector3.new(side * 15, 15, 0)),
			color = rgb(150, 150, 165),
		})
		Bricks.studTop(model, pillar, nil, 2, 9)
		Props.torch(model, origin + Vector3.new(side * 15, 18, -3.2), Vector3.new(0, 0, -1))
	end
	local lintel = Bricks.part(model, {
		name = "Lintel",
		size = Vector3.new(36, 6, 7),
		cframe = CFrame.new(origin + Vector3.new(0, 33, 0)),
		color = rgb(135, 135, 150),
	})
	Bricks.studTop(model, lintel, nil, 2, 40)
	local swirl = Bricks.part(model, {
		name = "PortalFace",
		size = Vector3.new(24, 30, 1),
		cframe = CFrame.new(origin + Vector3.new(0, 15, 0)),
		color = rgb(255, 60, 220),
		material = Enum.Material.Neon,
		collide = false,
	})
	swirl.Transparency = 0.15
	swirl:SetAttribute("Station", "Portal")
	local particles = Instance.new("ParticleEmitter")
	particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	particles.Color = ColorSequence.new(rgb(255, 120, 250), rgb(120, 240, 255))
	particles.LightEmission = 1
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.3, 1.2),
		NumberSequenceKeypoint.new(1, 0),
	})
	particles.Lifetime = NumberRange.new(1, 2)
	particles.Rate = 40
	particles.Speed = NumberRange.new(2, 6)
	particles.SpreadAngle = Vector2.new(30, 30)
	particles.EmissionDirection = Enum.NormalId.Front
	particles.Parent = swirl
	local light = Instance.new("PointLight")
	light.Color = rgb(255, 100, 230)
	light.Range = 40
	light.Brightness = 3
	light.Parent = swirl
	Props.label(lintel, "The Gauntlet", rgb(255, 140, 240), Vector3.new(0, 8, 0), 18)
	-- A dark backing so the portal reads as a doorway.
	Bricks.part(model, {
		name = "Backing",
		size = Vector3.new(26, 30, 1),
		cframe = CFrame.new(origin + Vector3.new(0, 15, 1.2)),
		color = rgb(40, 20, 60),
	})
end

local function carpetAndDecor(parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Decor"
	model.Parent = parent
	-- Red carpet from the spawn to the portal, with gold edges.
	Bricks.part(model, {
		name = "Carpet",
		size = Vector3.new(16, 0.3, 96),
		cframe = CFrame.new(0, 0.15, 78),
		color = CARPET,
		collide = false,
	})
	for side = -1, 1, 2 do
		Bricks.part(model, {
			name = "CarpetEdge",
			size = Vector3.new(1, 0.35, 96),
			cframe = CFrame.new(side * 8.5, 0.17, 78),
			color = GOLD,
			collide = false,
		})
		for index = 0, 4 do
			Props.lamp(model, Vector3.new(side * 13, 0, 40 + index * 20))
		end
	end
	-- Trees and flowers in the plaza corners.
	local treeSpots = {
		Vector3.new(-100, 0, 120),
		Vector3.new(-80, 0, 132),
		Vector3.new(100, 0, 120),
		Vector3.new(82, 0, 134),
		Vector3.new(-104, 0, 92),
		Vector3.new(104, 0, 90),
		Vector3.new(-60, 0, 100),
		Vector3.new(60, 0, 100),
	}
	for index, spot in treeSpots do
		Props.tree(model, spot, 1 + (index % 3) * 0.2)
		Props.flowers(model, spot + Vector3.new(6, 0, 4), index)
	end
	-- The leaderboard beside the spawn, facing it.
	for side = -1, 1, 2 do
		Bricks.part(model, {
			name = "BoardLeg",
			size = Vector3.new(1.4, 26, 1.4),
			cframe = CFrame.new(-38, 13, 22 + side * 11),
			color = rgb(120, 85, 55),
			collide = false,
		})
	end
	local board = Bricks.part(model, {
		name = "Leaderboard",
		size = Vector3.new(1.2, 18, 24),
		cframe = CFrame.new(-37.6, 15, 22),
		color = rgb(40, 44, 66),
		collide = false,
	})
	board:SetAttribute("Station", "Leaderboard")
	Bricks.part(model, {
		name = "BoardFrame",
		size = Vector3.new(1, 19.4, 25.4),
		cframe = CFrame.new(-38.2, 15, 22),
		color = GOLD,
		collide = false,
	})
	local surface = Instance.new("SurfaceGui")
	surface.Name = "Gui"
	surface.Face = Enum.NormalId.Right
	surface.CanvasSize = Vector2.new(720, 540)
	surface.LightInfluence = 0
	surface.Parent = board
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.16)
	title.FontFace = Props.FONT
	title.TextScaled = true
	title.TextColor3 = rgb(255, 215, 70)
	title.Text = "🏆 Top Shooters"
	title.Parent = surface
	local titleStroke = Instance.new("UIStroke")
	titleStroke.Thickness = 4
	titleStroke.Color = rgb(20, 20, 30)
	titleStroke.Parent = title
	for row = 1, 8 do
		local label = Instance.new("TextLabel")
		label.Name = `Row{row}`
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0.05, 0.17 + (row - 1) * 0.1)
		label.Size = UDim2.fromScale(0.9, 0.09)
		label.FontFace = Props.FONT
		label.TextScaled = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = if row == 1
			then rgb(255, 220, 90)
			elseif row == 2 then rgb(220, 225, 235)
			elseif row == 3 then rgb(230, 160, 100)
			else rgb(255, 255, 255)
		label.Text = ""
		label.Parent = surface
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.Color = rgb(20, 20, 30)
		stroke.Parent = label
	end

	-- The spawn pad.
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(14, 1, 14)
	spawn.CFrame = CFrame.new(0, 0.5, 20)
	spawn.Color = rgb(70, 200, 220)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = model
	Bricks.studTop(model, spawn, nil, 2.5, 30)
	Bricks.part(model, {
		name = "SpawnRim",
		size = Vector3.new(16, 0.6, 16),
		cframe = CFrame.new(0, 0.3, 20),
		color = TRIM,
	})
end

local function skyAndGround(parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Surroundings"
	model.Parent = parent
	-- Grass beyond the walls, with brick hills and trees.
	Bricks.part(model, {
		name = "Grass",
		size = Vector3.new(2400, 2, 2400),
		-- Below the plaza's base plate, so the two never fight over the same surface.
		cframe = CFrame.new(0, -3.2, 0),
		color = rgb(100, 195, 80),
	})
	local random = Random.new(7)
	for index = 1, 40 do
		local angle = random:NextNumber(0, math.pi * 2)
		local distance = random:NextNumber(200, 520)
		local spot = Vector3.new(math.cos(angle) * distance, -2.2, math.sin(angle) * distance)
		if index % 3 == 0 then
			local hill = Bricks.part(model, {
				name = "Hill",
				size = Vector3.new(
					random:NextNumber(30, 60),
					random:NextNumber(6, 14),
					random:NextNumber(30, 60)
				),
				cframe = CFrame.new(spot),
				color = rgb(90, 180, 75),
			})
			Bricks.studTop(model, hill, nil, 4, 40)
		else
			Props.tree(model, spot, random:NextNumber(1.4, 2.4))
		end
	end
	for index = 1, 26 do
		local angle = (index / 26) * math.pi * 2 + random:NextNumber(-0.1, 0.1)
		local distance = random:NextNumber(320, 620)
		Bricks.cloud(
			model,
			Vector3.new(
				math.cos(angle) * distance,
				random:NextNumber(70, 160),
				math.sin(angle) * distance
			),
			random:NextNumber(1.6, 3),
			index
		)
	end
end

--[[
	The Lucky Wheel's stand, west of the spawn where the Upgrades stall used to be: a big upright
	wheel of red and cream slices on a gold rim. The base is the "Wheel" station. Public so the
	server can add it to a lobby baked before the wheel existed.
]]
function LobbyBuilder.wheelStand(parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "Wheel"
	local origin = Vector3.new(-88, 0, -14)
	local base = Bricks.part(model, {
		name = "Base",
		size = Vector3.new(16, 1.2, 16),
		cframe = CFrame.new(origin + Vector3.new(0, 0.6, 0)),
		color = rgb(220, 50, 60),
	})
	base:SetAttribute("Station", "Wheel")
	Bricks.part(model, {
		name = "Stand",
		size = Vector3.new(2, 12, 2),
		cframe = CFrame.new(origin + Vector3.new(0, 7, 2)),
		color = GOLD,
	})
	-- The wheel faces the plaza (+X), its slices alternating red and cream.
	for slice = 0, 7 do
		local angle = slice * math.pi / 4
		Bricks.part(model, {
			name = "Slice",
			size = Vector3.new(0.6, 6.2, 2.4),
			cframe = CFrame.new(origin + Vector3.new(1, 14, 0))
				* CFrame.Angles(angle, 0, 0)
				* CFrame.new(0, 3.1, 0),
			color = if slice % 2 == 0 then rgb(225, 50, 60) else rgb(250, 235, 205),
			collide = false,
		})
	end
	Bricks.part(model, {
		name = "Hub",
		size = Vector3.new(1, 2.4, 2.4),
		cframe = CFrame.new(origin + Vector3.new(1.4, 14, 0)),
		color = GOLD,
		material = Enum.Material.Neon,
		collide = false,
	})
	Props.label(base, "🎡 Lucky Wheel", rgb(255, 215, 80), Vector3.new(0, 24, 0), 14)
	model.Parent = parent
	return model
end

--[[
	The Robux shop's stall, just south of the forge: a gold-and-red striped awning over a counter
	piled with coins. The counter is the "Shop" station. Public so the server can add it to a lobby
	baked before the shop existed.
]]
function LobbyBuilder.shopStall(parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "Shop"
	local origin = Vector3.new(88, 0, 52)
	local counter = Bricks.part(model, {
		name = "Counter",
		size = Vector3.new(20, 4, 6),
		cframe = CFrame.new(origin + Vector3.new(0, 2, -4)),
		color = rgb(200, 60, 60),
	})
	counter:SetAttribute("Station", "Shop")
	Bricks.part(model, {
		name = "CounterTop",
		size = Vector3.new(21, 0.6, 7),
		cframe = counter.CFrame * CFrame.new(0, 2.3, 0),
		color = GOLD,
	})
	for side = -1, 1, 2 do
		Bricks.part(model, {
			name = "Post",
			size = Vector3.new(1.2, 15, 1.2),
			cframe = CFrame.new(origin + Vector3.new(side * 10, 7.5, -7)),
			color = rgb(240, 240, 245),
		})
	end
	for stripe = 0, 7 do
		Bricks.part(model, {
			name = "Awning",
			size = Vector3.new(2.75, 1, 12),
			cframe = CFrame.new(origin + Vector3.new(-9.6 + stripe * 2.75, 15.6, -3))
				* CFrame.Angles(math.rad(12), 0, 0),
			color = if stripe % 2 == 0 then rgb(230, 60, 60) else GOLD,
		})
	end
	-- Coin piles on the counter.
	for index = -2, 2 do
		Bricks.part(model, {
			name = "Coins",
			size = Vector3.new(2.4, 1 + (index + 2) % 3 * 0.6, 2.4),
			cframe = CFrame.new(origin + Vector3.new(index * 3.6, 5.2, -4)),
			color = rgb(255, 205, 60),
			material = Enum.Material.Neon,
			collide = false,
		})
	end
	Props.label(counter, "💰 Shop", rgb(255, 215, 80), Vector3.new(0, 16, 0), 14)
	model.Parent = parent
	return model
end

--[[
	Builds the full lobby under a new "Lobby" model in the parent and returns it. The plaza floor's
	top sits at Y = 0.
]]
function LobbyBuilder.build(parent: Instance): Model
	local lobby = Instance.new("Model")
	lobby.Name = "Lobby"
	Bricks.floor(lobby, CFrame.new(0, 0, 0), PLAZA_X, PLAZA_Z, 12, STONE, STONE_ALT, nil, nil)
	perimeter(lobby)
	trainingGrounds(lobby)
	forgeWorkshop(lobby)
	rebirthAltar(lobby)
	LobbyBuilder.shopStall(lobby)
	LobbyBuilder.wheelStand(lobby)
	portal(lobby)
	carpetAndDecor(lobby)
	skyAndGround(lobby)
	lobby.Parent = parent
	return lobby
end

return LobbyBuilder
