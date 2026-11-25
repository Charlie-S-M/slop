--!strict

--[[
	Builds a Gauntlet arena: a long walled brick court. The player enters at the south end (+Z) and
	enemies pour in from the north. Every surface is painted by name so Arena.theme() can recolor
	the whole court when the run crosses into a new biome.
]]

const Biomes = require("@game/ReplicatedStorage/Shared/Biomes")
const Bricks = require("./Bricks")
const Props = require("./Props")

local ArenaBuilder = {}

ArenaBuilder.WIDTH = 150
ArenaBuilder.LENGTH = 300
ArenaBuilder.WALL_HEIGHT = 34
-- Where the player stands at the start of each stage, relative to the arena's origin.
ArenaBuilder.PLAYER_START = Vector3.new(0, 3, 128)
-- The box enemies spawn in, relative to the origin: X and Z ranges.
ArenaBuilder.SPAWN_MIN = Vector3.new(-55, 0, -130)
ArenaBuilder.SPAWN_MAX = Vector3.new(55, 0, -10)

local function pillar(parent: Instance, position: Vector3)
	local column = Bricks.part(parent, {
		name = "Pillar",
		size = Vector3.new(6, ArenaBuilder.WALL_HEIGHT + 4, 6),
		cframe = CFrame.new(position + Vector3.new(0, (ArenaBuilder.WALL_HEIGHT + 4) / 2, 0)),
		color = Color3.new(1, 1, 1),
		paint = "trim",
	})
	Bricks.studTop(parent, column, "trim", 2, 9)
	local strip = Bricks.part(parent, {
		name = "GlowStrip",
		size = Vector3.new(6.3, 1.2, 6.3),
		cframe = CFrame.new(position + Vector3.new(0, ArenaBuilder.WALL_HEIGHT * 0.6, 0)),
		color = Color3.new(1, 1, 1),
		paint = "glow",
		material = Enum.Material.Neon,
		collide = false,
	})
	strip.CanQuery = false
end

-- Builds an arena with its floor top at origin.Y. Returns the model; its "StageSign" holds the
-- stage label the server updates.
function ArenaBuilder.build(parent: Instance, origin: Vector3, name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	local width = ArenaBuilder.WIDTH
	local length = ArenaBuilder.LENGTH
	local height = ArenaBuilder.WALL_HEIGHT
	local white = Color3.new(1, 1, 1)

	Bricks.floor(model, CFrame.new(origin), width, length, 15, white, white, "floor", "floorAlt")
	-- A center lane down the middle, like a runway toward the enemies.
	local lane = Bricks.part(model, {
		name = "Lane",
		size = Vector3.new(14, 0.2, length - 20),
		cframe = CFrame.new(origin + Vector3.new(0, 0.05, 0)),
		color = white,
		paint = "trim",
		collide = false,
	})
	lane.CanQuery = false

	local walls = {
		{ cframe = CFrame.new(origin + Vector3.new(0, 0, -length / 2)), length = width },
		{
			cframe = CFrame.new(origin + Vector3.new(0, 0, length / 2))
				* CFrame.Angles(0, math.pi, 0),
			length = width,
		},
		{
			cframe = CFrame.new(origin + Vector3.new(width / 2, 0, 0))
				* CFrame.Angles(0, -math.pi / 2, 0),
			length = length,
		},
		{
			cframe = CFrame.new(origin + Vector3.new(-width / 2, 0, 0))
				* CFrame.Angles(0, math.pi / 2, 0),
			length = length,
		},
	}
	for _, wall in walls do
		local base = wall.cframe
		local wallLength = wall.length
		Bricks.wall(
			model,
			base,
			wallLength,
			height,
			4,
			white,
			white,
			"wall",
			"wallAlt",
			8,
			3.4,
			true
		)
		Bricks.part(model, {
			name = "Ledge",
			size = Vector3.new(wallLength + 4, 1.4, 6),
			cframe = base * CFrame.new(0, height + 0.7, 0),
			color = white,
			paint = "trim",
		})
		-- A glowing band low on every wall.
		local band = Bricks.part(model, {
			name = "Band",
			size = Vector3.new(wallLength - 2, 1, 0.4),
			cframe = base * CFrame.new(0, 4, 2.2),
			color = white,
			paint = "glow",
			material = Enum.Material.Neon,
			collide = false,
		})
		band.CanQuery = false
	end

	for index = 0, 4 do
		local z = -length / 2 + 30 + index * 60
		pillar(model, origin + Vector3.new(width / 2 - 4, 0, z))
		pillar(model, origin + Vector3.new(-width / 2 + 4, 0, z))
	end

	-- Barrels and crates in the corners give the court some depth.
	for _, corner in
		{
			Vector3.new(1, 0, 1),
			Vector3.new(-1, 0, 1),
			Vector3.new(1, 0, -1),
			Vector3.new(-1, 0, -1),
		}
	do
		local spot = origin
			+ Vector3.new(corner.X * (width / 2 - 12), 0, corner.Z * (length / 2 - 12))
		local crate = Props.crate(model, CFrame.new(spot + Vector3.new(0, 2.5, 0)), 5)
		crate:SetAttribute("Paint", "wallAlt")
		Props.barrel(model, spot + Vector3.new(-corner.X * 7, 0, 0))
	end

	-- The stage sign high on the north wall, facing the player.
	local signBoard = Bricks.part(model, {
		name = "StageSign",
		size = Vector3.new(48, 12, 1),
		cframe = CFrame.new(origin + Vector3.new(0, height - 9, -length / 2 + 2.6)),
		color = white,
		paint = "wallDark",
	})
	local surface = Instance.new("SurfaceGui")
	surface.Name = "Gui"
	surface.Face = Enum.NormalId.Back
	surface.CanvasSize = Vector2.new(960, 240)
	surface.LightInfluence = 0
	surface.Parent = signBoard
	local label = Instance.new("TextLabel")
	label.Name = "Stage"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = Props.FONT
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = "STAGE 1"
	label.Parent = surface
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 6
	stroke.Color = Color3.fromRGB(20, 20, 30)
	stroke.Parent = label

	model:SetAttribute("OriginX", origin.X)
	model:SetAttribute("OriginY", origin.Y)
	model:SetAttribute("OriginZ", origin.Z)
	model.Parent = parent
	return model
end

-- The paint palette for a biome.
function ArenaBuilder.palette(biome: Biomes.BiomeDef): { [string]: Color3 }
	local black = Color3.new(0, 0, 0)
	return {
		floor = biome.floor,
		floorAlt = biome.floor:Lerp(biome.floorAccent, 0.14),
		floorDark = biome.floor:Lerp(black, 0.45),
		wall = biome.wall,
		wallAlt = biome.wall:Lerp(biome.wallAccent, 0.18),
		wallDark = biome.wall:Lerp(black, 0.4),
		trim = biome.trim,
		glow = biome.glow,
	}
end

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function mushroom(parent: Instance, position: Vector3, scale: number, cap: Color3)
	Bricks.part(parent, {
		size = Vector3.new(2.4, 7, 2.4) * scale,
		cframe = CFrame.new(position + Vector3.new(0, 3.5 * scale, 0)),
		color = rgb(240, 230, 210),
	})
	local top = Bricks.part(parent, {
		size = Vector3.new(9, 3, 9) * scale,
		cframe = CFrame.new(position + Vector3.new(0, 8 * scale, 0)),
		color = cap,
	})
	Bricks.part(parent, {
		size = Vector3.new(6, 1.6, 6) * scale,
		cframe = CFrame.new(position + Vector3.new(0, 10 * scale, 0)),
		color = cap,
	})
	for index = 1, 4 do
		local angle = index * math.pi / 2 + 0.4
		Bricks.part(parent, {
			size = Vector3.new(1.4, 0.4, 1.4) * scale,
			cframe = top.CFrame
				* CFrame.new(math.cos(angle) * 3 * scale, 1.6 * scale, math.sin(angle) * 3 * scale),
			color = rgb(255, 255, 255),
			collide = false,
		})
	end
end

local function cactus(parent: Instance, position: Vector3, scale: number)
	local green = rgb(80, 170, 80)
	Bricks.part(parent, {
		size = Vector3.new(2.6, 12, 2.6) * scale,
		cframe = CFrame.new(position + Vector3.new(0, 6 * scale, 0)),
		color = green,
	})
	for side = -1, 1, 2 do
		Bricks.part(parent, {
			size = Vector3.new(3, 1.8, 1.8) * scale,
			cframe = CFrame.new(position + Vector3.new(side * 2.4 * scale, (5 + side) * scale, 0)),
			color = green,
		})
		Bricks.part(parent, {
			size = Vector3.new(1.8, 4, 1.8) * scale,
			cframe = CFrame.new(position + Vector3.new(side * 3.4 * scale, (7 + side) * scale, 0)),
			color = green,
		})
	end
	Bricks.part(parent, {
		size = Vector3.new(1.2, 1, 1.2) * scale,
		cframe = CFrame.new(position + Vector3.new(0, 12.4 * scale, 0)),
		color = rgb(255, 120, 160),
	})
end

local function iceSpike(parent: Instance, position: Vector3, scale: number)
	for index = 0, 2 do
		local spike = Bricks.part(parent, {
			size = Vector3.new(3 - index * 0.6, 10 - index * 2, 3 - index * 0.6) * scale,
			cframe = CFrame.new(
				position + Vector3.new(index * 2.4 * scale - 2.4 * scale, (5 - index) * scale, 0)
			) * CFrame.Angles(0, index, (index - 1) * 0.25),
			color = rgb(160, 225, 255),
			material = Enum.Material.Glass,
		})
		spike.Transparency = 0.2
	end
	Bricks.part(parent, {
		size = Vector3.new(7, 1, 5) * scale,
		cframe = CFrame.new(position + Vector3.new(0, 0.5 * scale, 0)),
		color = rgb(240, 248, 255),
	})
end

local function lavaPool(parent: Instance, position: Vector3, scale: number)
	Bricks.part(parent, {
		size = Vector3.new(12, 1, 12) * scale,
		cframe = CFrame.new(position + Vector3.new(0, 0.3, 0)),
		color = rgb(60, 45, 45),
	})
	local lava = Bricks.part(parent, {
		size = Vector3.new(9, 1, 9) * scale,
		cframe = CFrame.new(position + Vector3.new(0, 0.45, 0)),
		color = rgb(255, 110, 20),
		material = Enum.Material.Neon,
		collide = false,
	})
	local fire = Instance.new("Fire")
	fire.Size = 6 * scale
	fire.Heat = 8
	fire.Color = rgb(255, 140, 40)
	fire.SecondaryColor = rgb(255, 60, 20)
	fire.Parent = lava
	local light = Instance.new("PointLight")
	light.Color = rgb(255, 130, 40)
	light.Range = 20
	light.Brightness = 2
	light.Parent = lava
	for index = 1, 3 do
		Bricks.part(parent, {
			size = Vector3.new(3, 4 + index, 3) * scale,
			cframe = CFrame.new(
				position
					+ Vector3.new(
						math.cos(index * 2.1) * 7 * scale,
						(2 + index / 2) * scale,
						math.sin(index * 2.1) * 7 * scale
					)
			) * CFrame.Angles(0.2 * index, index, 0.1),
			color = rgb(40, 30, 50),
		})
	end
end

local function voidCrystal(parent: Instance, position: Vector3, scale: number)
	for index = 0, 2 do
		local crystal = Bricks.part(parent, {
			size = Vector3.new(3, 11 - index * 3, 3) * scale,
			cframe = CFrame.new(
				position + Vector3.new((index - 1) * 3 * scale, (6 - index) * scale, 0)
			) * CFrame.Angles(0, 0.8, (index - 1) * 0.35),
			color = if index == 1 then rgb(80, 240, 230) else rgb(190, 110, 255),
			material = Enum.Material.Neon,
			collide = false,
		})
		crystal.Transparency = 0.1
	end
	local light = Instance.new("PointLight")
	light.Color = rgb(190, 120, 255)
	light.Range = 18
	light.Brightness = 2
	light.Parent = parent:FindFirstChildWhichIsA("BasePart")
end

-- A brick kiln with a glowing mouth and a chimney, for the Glassfall Foundry.
-- `facing` is -1 or 1: which way along X the mouth opens, toward the middle of the arena.
local function kiln(parent: Instance, position: Vector3, scale: number, facing: number)
	local body = Bricks.part(parent, {
		size = Vector3.new(10, 9, 8) * scale,
		cframe = CFrame.new(position + Vector3.new(0, 4.5 * scale, 0)),
		color = rgb(95, 80, 78),
	})
	Bricks.studTop(parent, body, nil, 2, 16)
	local mouth = Bricks.part(parent, {
		size = Vector3.new(0.6, 3.5, 5) * scale,
		cframe = body.CFrame * CFrame.new(facing * 5.05 * scale, -1.5 * scale, 0),
		color = rgb(255, 160, 60),
		material = Enum.Material.Neon,
		collide = false,
	})
	local fire = Instance.new("Fire")
	fire.Size = 4 * scale
	fire.Heat = 5
	fire.Color = rgb(255, 170, 70)
	fire.SecondaryColor = rgb(255, 90, 40)
	fire.Parent = mouth
	local light = Instance.new("PointLight")
	light.Color = rgb(255, 160, 80)
	light.Range = 20
	light.Brightness = 2
	light.Parent = mouth
	Bricks.part(parent, {
		size = Vector3.new(3, 8, 3) * scale,
		cframe = body.CFrame * CFrame.new(2.5 * scale, 8.5 * scale, 1.5 * scale),
		color = rgb(80, 68, 66),
	})
end

-- A pile of glowing glass shards in teal, amber, and violet.
local function glassCluster(parent: Instance, position: Vector3, scale: number)
	local colors = { rgb(130, 230, 240), rgb(255, 180, 80), rgb(200, 150, 255) }
	for index = 0, 4 do
		local height = (10 - index * 1.6) * scale
		local shard = Bricks.part(parent, {
			size = Vector3.new(2.2, height, 2.2) * scale,
			cframe = CFrame.new(
				position
					+ Vector3.new(
						math.cos(index * 1.3) * 3 * scale,
						height / 2,
						math.sin(index * 1.3) * 3 * scale
					)
			) * CFrame.Angles(0, index, (index - 2) * 0.22),
			color = colors[index % #colors + 1],
			material = Enum.Material.Glass,
			collide = false,
		})
		shard.Transparency = 0.25
	end
	local core = Bricks.part(parent, {
		size = Vector3.new(2.6, 2.6, 2.6) * scale,
		cframe = CFrame.new(position + Vector3.new(0, 1.6 * scale, 0)),
		color = rgb(255, 200, 120),
		material = Enum.Material.Neon,
		collide = false,
		shape = Enum.PartType.Ball,
	})
	local light = Instance.new("PointLight")
	light.Color = rgb(255, 190, 120)
	light.Range = 16
	light.Brightness = 1.5
	light.Parent = core
end

-- Props along the side walls that match the biome. Rebuilt whenever the arena changes biome.
function ArenaBuilder.decorate(arena: Model, biome: Biomes.BiomeDef)
	local old = arena:FindFirstChild("Decor")
	if old then
		old:Destroy()
	end
	local decor = Instance.new("Model")
	decor.Name = "Decor"
	local origin = Vector3.new(
		arena:GetAttribute("OriginX") :: number,
		arena:GetAttribute("OriginY") :: number,
		arena:GetAttribute("OriginZ") :: number
	)
	local random = Random.new(biome.index * 31)
	for index = 0, 7 do
		local side = if index % 2 == 0 then 1 else -1
		local z = -ArenaBuilder.LENGTH / 2 + 50 + math.floor(index / 2) * 60
		local spot = origin
			+ Vector3.new(side * (ArenaBuilder.WIDTH / 2 - 15), 0, z + random:NextNumber(-8, 8))
		local scale = random:NextNumber(1, 1.5)
		if biome.index == 1 then
			Props.tree(decor, spot, scale * 1.4)
			Props.flowers(decor, spot + Vector3.new(-side * 6, 0, 3), index)
		elseif biome.index == 2 then
			mushroom(
				decor,
				spot,
				scale,
				if index % 3 == 0 then rgb(220, 50, 60) else rgb(150, 90, 200)
			)
		elseif biome.index == 3 then
			cactus(decor, spot, scale)
		elseif biome.index == 4 then
			iceSpike(decor, spot, scale)
		elseif biome.index == 5 then
			lavaPool(decor, spot, scale * 0.9)
		elseif biome.index == 7 then
			if index % 2 == 0 then
				kiln(decor, spot, scale, -side)
			else
				glassCluster(decor, spot, scale)
			end
		elseif biome.index == 8 then
			-- Ice spires and frosted crystal heaps under the aurora.
			if math.floor(index / 2) % 2 == 0 then
				glassCluster(decor, spot, scale)
			else
				voidCrystal(decor, spot + Vector3.new(0, 2, 0), scale)
			end
		else
			voidCrystal(decor, spot + Vector3.new(0, 2, 0), scale)
		end
	end
	decor.Parent = arena
end

function ArenaBuilder.theme(arena: Model, biome: Biomes.BiomeDef)
	Bricks.repaint(arena, ArenaBuilder.palette(biome))
	if arena:GetAttribute("DecorBiome") ~= biome.index then
		arena:SetAttribute("DecorBiome", biome.index)
		ArenaBuilder.decorate(arena, biome)
	end
	local sign = arena:FindFirstChild("StageSign")
	local label = sign and sign:FindFirstChild("Gui") and (sign :: any).Gui:FindFirstChild("Stage")
	if label and label:IsA("TextLabel") then
		label.TextColor3 = biome.glow:Lerp(Color3.new(1, 1, 1), 0.4)
	end
end

return ArenaBuilder
