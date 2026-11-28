--!strict

--[[
	Building blocks for the toy-brick world: plain blocks, studded tops, brick walls with seams,
	and tiled floors. Every part can carry a "Paint" attribute naming the theme color it takes, so
	an arena can be recolored for a new biome without rebuilding it.
]]

local Bricks = {}

export type Props = {
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	name: string?,
	paint: string?,
	collide: boolean?,
	shadow: boolean?,
	transparency: number?,
	shape: Enum.PartType?,
}

const STUD_DIAMETER = 1.15
const STUD_HEIGHT = 0.38

function Bricks.part(parent: Instance, props: Props): Part
	local part = Instance.new("Part")
	part.Name = props.name or "Brick"
	part.Anchored = true
	part.Size = props.size
	part.CFrame = props.cframe
	part.Color = props.color
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = if props.collide == nil then true else props.collide
	part.CastShadow = if props.shadow == nil then true else props.shadow
	part.Transparency = props.transparency or 0
	if props.shape then
		part.Shape = props.shape
	end
	if props.paint then
		part:SetAttribute("Paint", props.paint)
	end
	part.Parent = parent
	return part
end

-- One stud: a short cylinder standing on a surface, centered at the given point.
function Bricks.stud(
	parent: Instance,
	position: Vector3,
	color: Color3,
	paint: string?,
	scale: number?
): Part
	local s = scale or 1
	local stud = Bricks.part(parent, {
		name = "Stud",
		size = Vector3.new(STUD_HEIGHT * s, STUD_DIAMETER * s, STUD_DIAMETER * s),
		cframe = CFrame.new(position + Vector3.new(0, STUD_HEIGHT * s / 2, 0))
			* CFrame.Angles(0, 0, math.rad(90)),
		color = color,
		paint = paint,
		collide = false,
		shadow = false,
		shape = Enum.PartType.Cylinder,
	})
	stud.CanQuery = false
	stud.CanTouch = false
	return stud
end

--[[
	Covers the top face of a block with studs on a grid. The spacing grows on big faces so one face
	never makes more than maxStuds parts.
]]
function Bricks.studTop(
	parent: Instance,
	block: BasePart,
	paint: string?,
	spacing: number?,
	maxStuds: number?
)
	local size = block.Size
	local step = spacing or 2
	local limit = maxStuds or 160
	while (math.floor(size.X / step) * math.floor(size.Z / step)) > limit do
		step *= 1.5
	end
	local countX = math.max(1, math.floor(size.X / step))
	local countZ = math.max(1, math.floor(size.Z / step))
	local top = block.CFrame * CFrame.new(0, size.Y / 2, 0)
	for ix = 1, countX do
		for iz = 1, countZ do
			local x = (ix - (countX + 1) / 2) * step
			local z = (iz - (countZ + 1) / 2) * step
			local position = (top * CFrame.new(x, 0, z)).Position
			Bricks.stud(parent, position, block.Color, paint)
		end
	end
end

--[[
	A wall of individual bricks in a running bond, with thin seams between them so every brick
	reads on its own. The wall's CFrame sits at the bottom-center of its face; its length runs along
	the CFrame's X axis. Rows alternate two paints for a subtle two-tone look, and the top row gets
	studs.
]]
function Bricks.wall(
	parent: Instance,
	base: CFrame,
	length: number,
	height: number,
	thickness: number,
	colorA: Color3,
	colorB: Color3,
	paintA: string?,
	paintB: string?,
	brickLength: number?,
	brickHeight: number?,
	studs: boolean?
): Model
	local model = Instance.new("Model")
	model.Name = "Wall"
	model.Parent = parent
	local bl = brickLength or 6
	local bh = brickHeight or 2.5
	local seam = 0.12
	local rows = math.max(1, math.floor(height / bh + 0.5))
	bh = height / rows

	-- A solid core behind the bricks keeps the seams from showing daylight and handles collision.
	local core = Bricks.part(model, {
		name = "Core",
		size = Vector3.new(length, height, thickness * 0.8),
		cframe = base * CFrame.new(0, height / 2, 0),
		color = colorA:Lerp(Color3.new(0, 0, 0), 0.35),
		paint = if paintA then paintA .. "Dark" else nil,
		shadow = true,
	})
	core.CanQuery = true

	for row = 1, rows do
		local offset = if row % 2 == 0 then bl / 2 else 0
		local x = -length / 2 - offset
		local y = (row - 0.5) * bh
		local useA = row % 2 == 1
		while x < length / 2 do
			local left = math.max(x, -length / 2)
			local right = math.min(x + bl, length / 2)
			local width = right - left
			if width > 0.5 then
				local brick = Bricks.part(model, {
					size = Vector3.new(width - seam, bh - seam, thickness),
					cframe = base * CFrame.new((left + right) / 2, y, 0),
					color = if useA then colorA else colorB,
					paint = if useA then paintA else paintB,
					collide = false,
					shadow = false,
				})
				brick.CanQuery = false
				if studs ~= false and row == rows then
					Bricks.studTop(model, brick, if useA then paintA else paintB, 2, 12)
				end
			end
			x += bl
		end
	end
	return model
end

--[[
	A floor of square tiles with seams, laid on a dark base plate. Tiles alternate two paints in a
	checker so the floor reads as tiles from far away.
]]
function Bricks.floor(
	parent: Instance,
	center: CFrame,
	sizeX: number,
	sizeZ: number,
	tile: number,
	colorA: Color3,
	colorB: Color3,
	paintA: string?,
	paintB: string?
): Model
	local model = Instance.new("Model")
	model.Name = "Floor"
	model.Parent = parent
	local base = Bricks.part(model, {
		name = "Base",
		size = Vector3.new(sizeX, 2, sizeZ),
		cframe = center * CFrame.new(0, -1.1, 0),
		color = colorA:Lerp(Color3.new(0, 0, 0), 0.4),
		paint = if paintA then paintA .. "Dark" else nil,
	})
	base.CanQuery = true
	local countX = math.floor(sizeX / tile)
	local countZ = math.floor(sizeZ / tile)
	local tileX = sizeX / countX
	local tileZ = sizeZ / countZ
	for ix = 1, countX do
		for iz = 1, countZ do
			local checker = (ix + iz) % 2 == 0
			local piece = Bricks.part(model, {
				name = "Tile",
				size = Vector3.new(tileX - 0.3, 0.6, tileZ - 0.3),
				cframe = center * CFrame.new(
					(ix - (countX + 1) / 2) * tileX,
					-0.3,
					(iz - (countZ + 1) / 2) * tileZ
				),
				color = if checker then colorA else colorB,
				paint = if checker then paintA else paintB,
				shadow = false,
			})
			piece.CanQuery = true
		end
	end
	return model
end

-- A puffy cloud made of white blocks, for the sky around the lobby.
function Bricks.cloud(parent: Instance, center: Vector3, scale: number, seed: number)
	local random = Random.new(seed)
	local model = Instance.new("Model")
	model.Name = "Cloud"
	model.Parent = parent
	local count = random:NextInteger(4, 7)
	for index = 1, count do
		local width = random:NextNumber(8, 16) * scale
		local height = random:NextNumber(4, 8) * scale
		local depth = random:NextNumber(8, 14) * scale
		local offset = Vector3.new(
			(index - count / 2) * 7 * scale + random:NextNumber(-2, 2) * scale,
			random:NextNumber(-1, 3) * scale,
			random:NextNumber(-4, 4) * scale
		)
		local puff = Bricks.part(model, {
			name = "Puff",
			size = Vector3.new(width, height, depth),
			cframe = CFrame.new(center + offset),
			color = Color3.fromRGB(255, 255, 255),
			collide = false,
			shadow = false,
		})
		puff.CanQuery = false
		puff.CanTouch = false
		if index % 2 == 0 then
			Bricks.studTop(model, puff, nil, 2.2 * scale, 20)
		end
	end
	return model
end

-- Recolors every painted part under a root from a palette of paint names to colors.
function Bricks.repaint(root: Instance, palette: { [string]: Color3 })
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") then
			local paint = descendant:GetAttribute("Paint")
			if typeof(paint) == "string" then
				local color = palette[paint]
				if color then
					descendant.Color = color
				end
			end
		end
	end
end

return Bricks
