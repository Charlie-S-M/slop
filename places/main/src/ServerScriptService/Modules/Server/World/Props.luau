--!strict

-- Decorations and labeled stations shared by the lobby and the arenas.

const Bricks = require("./Bricks")

local Props = {}

const FONT = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold)

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

--[[
	A floating label with chunky outlined text, like a game sign. Returns the TextLabel so callers
	can change it later.
]]
function Props.label(
	adornee: BasePart,
	text: string,
	color: Color3,
	studsOffset: Vector3,
	size: number?
): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromScale((size or 10), (size or 10) * 0.28)
	gui.StudsOffsetWorldSpace = studsOffset
	gui.LightInfluence = 0
	gui.MaxDistance = 260
	gui.AlwaysOnTop = false
	gui.Adornee = adornee
	gui.Parent = adornee

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = FONT
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = color
	label.Parent = gui

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = rgb(20, 20, 30)
	stroke.Parent = label

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(215, 215, 225))
	gradient.Rotation = 90
	gradient.Parent = label
	return label
end

function Props.lamp(parent: Instance, position: Vector3, color: Color3?)
	local model = Instance.new("Model")
	model.Name = "Lamp"
	model.Parent = parent
	local glow = color or rgb(255, 235, 170)
	Bricks.part(model, {
		size = Vector3.new(2.4, 1, 2.4),
		cframe = CFrame.new(position + Vector3.new(0, 0.5, 0)),
		color = rgb(60, 60, 70),
	})
	Bricks.part(model, {
		size = Vector3.new(0.9, 11, 0.9),
		cframe = CFrame.new(position + Vector3.new(0, 6.5, 0)),
		color = rgb(60, 60, 70),
	})
	local bulb = Bricks.part(model, {
		size = Vector3.new(2.2, 2.2, 2.2),
		cframe = CFrame.new(position + Vector3.new(0, 13, 0)),
		color = glow,
		material = Enum.Material.Neon,
		collide = false,
		shadow = false,
	})
	Bricks.part(model, {
		size = Vector3.new(2.8, 0.6, 2.8),
		cframe = CFrame.new(position + Vector3.new(0, 14.4, 0)),
		color = rgb(60, 60, 70),
	})
	local light = Instance.new("PointLight")
	light.Color = glow
	light.Range = 22
	light.Brightness = 1.6
	light.Shadows = false
	light.Parent = bulb
end

function Props.tree(parent: Instance, position: Vector3, scale: number, leaf: Color3?)
	local model = Instance.new("Model")
	model.Name = "Tree"
	model.Parent = parent
	local trunkHeight = 7 * scale
	Bricks.part(model, {
		size = Vector3.new(2.2, trunkHeight, 2.2) * Vector3.new(scale, 1, scale),
		cframe = CFrame.new(position + Vector3.new(0, trunkHeight / 2, 0)),
		color = rgb(120, 80, 50),
	})
	local leaves = leaf or rgb(80, 190, 70)
	local layers = {
		{ 9, 4, 0 },
		{ 7, 3.4, 3.6 },
		{ 4.6, 3, 6.6 },
	}
	for index, layer in layers do
		local block = Bricks.part(model, {
			size = Vector3.new(layer[1], layer[2], layer[1]) * scale,
			cframe = CFrame.new(position + Vector3.new(0, trunkHeight + layer[3] * scale, 0)),
			color = if index == 2 then leaves:Lerp(Color3.new(1, 1, 1), 0.12) else leaves,
		})
		if index == #layers then
			Bricks.studTop(model, block, nil, 2, 9)
		end
	end
end

function Props.crate(parent: Instance, cframe: CFrame, size: number, color: Color3?)
	local tint = color or rgb(190, 130, 70)
	local box = Bricks.part(
		parent,
		{ name = "Crate", size = Vector3.new(size, size, size), cframe = cframe, color = tint }
	)
	local frame = tint:Lerp(Color3.new(0, 0, 0), 0.3)
	for _, axis in { Vector3.new(1, 0, 0), Vector3.new(0, 0, 1) } do
		for side = -1, 1, 2 do
			local offset = axis * (size / 2 + 0.05) * side
			Bricks.part(parent, {
				name = "Slat",
				size = if axis.X ~= 0
					then Vector3.new(0.2, size * 0.98, size * 0.22)
					else Vector3.new(size * 0.22, size * 0.98, 0.2),
				cframe = cframe * CFrame.new(offset),
				color = frame,
				collide = false,
				shadow = false,
			})
		end
	end
	Bricks.studTop(parent, box, nil, 2, 9)
	return box
end

function Props.barrel(parent: Instance, position: Vector3, color: Color3?)
	local tint = color or rgb(60, 120, 220)
	local body = Bricks.part(parent, {
		name = "Barrel",
		size = Vector3.new(4, 3.4, 3.4),
		cframe = CFrame.new(position + Vector3.new(0, 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color = tint,
		shape = Enum.PartType.Cylinder,
	})
	for _, y in { 0.8, 3.2 } do
		Bricks.part(parent, {
			name = "Hoop",
			size = Vector3.new(0.35, 3.55, 3.55),
			cframe = CFrame.new(position + Vector3.new(0, y, 0))
				* CFrame.Angles(0, 0, math.rad(90)),
			color = tint:Lerp(Color3.new(0, 0, 0), 0.35),
			shape = Enum.PartType.Cylinder,
			collide = false,
		})
	end
	return body
end

--[[
	A hanging banner: a cloth strip with a contrasting border and a diamond emblem. The CFrame is
	at the banner's top-center; it hangs down along -Y and faces +Z.
]]
function Props.banner(
	parent: Instance,
	top: CFrame,
	width: number,
	height: number,
	cloth: Color3,
	emblem: Color3
)
	local model = Instance.new("Model")
	model.Name = "Banner"
	model.Parent = parent
	Bricks.part(model, {
		size = Vector3.new(width + 1.2, 0.6, 0.6),
		cframe = top * CFrame.new(0, 0.3, 0),
		color = rgb(70, 60, 55),
		collide = false,
	})
	Bricks.part(model, {
		size = Vector3.new(width, height, 0.25),
		cframe = top * CFrame.new(0, -height / 2, 0),
		color = cloth,
		collide = false,
		shadow = false,
	})
	Bricks.part(model, {
		size = Vector3.new(width - 1, height - 1.4, 0.3),
		cframe = top * CFrame.new(0, -height / 2 + 0.2, 0.05),
		color = cloth:Lerp(Color3.new(1, 1, 1), 0.08),
		collide = false,
		shadow = false,
	})
	local diamond = width * 0.42
	Bricks.part(model, {
		size = Vector3.new(diamond, diamond, 0.35),
		cframe = top * CFrame.new(0, -height * 0.42, 0.12) * CFrame.Angles(0, 0, math.rad(45)),
		color = emblem,
		collide = false,
		shadow = false,
	})
	Bricks.part(model, {
		size = Vector3.new(diamond * 0.5, diamond * 0.5, 0.4),
		cframe = top * CFrame.new(0, -height * 0.42, 0.14) * CFrame.Angles(0, 0, math.rad(45)),
		color = cloth,
		collide = false,
		shadow = false,
	})
	-- A notched tail at the bottom.
	for side = -1, 1, 2 do
		Bricks.part(model, {
			size = Vector3.new(width / 2, width / 2, 0.25),
			cframe = top
				* CFrame.new(side * width / 4, -height, 0)
				* CFrame.Angles(0, 0, math.rad(45)),
			color = cloth,
			collide = false,
			shadow = false,
		})
	end
	return model
end

-- A torch on a wall bracket with a flickering flame.
function Props.torch(parent: Instance, position: Vector3, facing: Vector3)
	local model = Instance.new("Model")
	model.Name = "Torch"
	model.Parent = parent
	local look = CFrame.lookAt(position, position + facing)
	Bricks.part(model, {
		size = Vector3.new(0.8, 0.8, 1.6),
		cframe = look * CFrame.new(0, 0, -0.8),
		color = rgb(60, 55, 55),
		collide = false,
	})
	Bricks.part(model, {
		size = Vector3.new(0.7, 2.6, 0.7),
		cframe = look * CFrame.new(0, 1, -1.6),
		color = rgb(120, 80, 50),
		collide = false,
	})
	local flame = Bricks.part(model, {
		size = Vector3.new(1, 1, 1),
		cframe = look * CFrame.new(0, 2.7, -1.6),
		color = rgb(255, 170, 40),
		material = Enum.Material.Neon,
		collide = false,
		shadow = false,
	})
	flame.Transparency = 0.2
	local fire = Instance.new("Fire")
	fire.Size = 2.5
	fire.Heat = 6
	fire.Color = rgb(255, 150, 40)
	fire.SecondaryColor = rgb(255, 60, 20)
	fire.Parent = flame
	local light = Instance.new("PointLight")
	light.Color = rgb(255, 170, 80)
	light.Range = 16
	light.Brightness = 1.4
	light.Parent = flame
end

-- Flowers: a few colored nubs on a green base.
function Props.flowers(parent: Instance, position: Vector3, seed: number)
	local random = Random.new(seed)
	local colors = { rgb(255, 90, 120), rgb(255, 220, 60), rgb(255, 255, 255), rgb(170, 110, 255) }
	for _ = 1, 5 do
		local offset = Vector3.new(random:NextNumber(-2.5, 2.5), 0, random:NextNumber(-2.5, 2.5))
		Bricks.part(parent, {
			name = "Stem",
			size = Vector3.new(0.3, 1.2, 0.3),
			cframe = CFrame.new(position + offset + Vector3.new(0, 0.6, 0)),
			color = rgb(70, 160, 60),
			collide = false,
			shadow = false,
		})
		Bricks.part(parent, {
			name = "Petal",
			size = Vector3.new(0.9, 0.5, 0.9),
			cframe = CFrame.new(position + offset + Vector3.new(0, 1.35, 0)),
			color = colors[random:NextInteger(1, #colors)],
			collide = false,
			shadow = false,
		})
	end
end

Props.FONT = FONT

return Props
