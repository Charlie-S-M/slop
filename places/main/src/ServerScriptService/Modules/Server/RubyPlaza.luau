--!strict
local Plaza = {}
Plaza.origin = Vector3.new(-510, 0, -510)
Plaza.entry = Vector3.new(-82, 3, -82)
local function brick(parent, name, pos, size, color, material: Enum.Material?)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.Position = pos
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Studs
	part.Parent = parent
	return part
end
local function sign(part, title)
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromOffset(160, 36)
	board.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
	board.MaxDistance = 75
	board.AlwaysOnTop = true
	board.Parent = part
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextSize = 17
	label.TextColor3 = Color3.fromRGB(255, 231, 206)
	label.TextStrokeTransparency = 0
	label.Text = title
	label.Parent = board
	return label
end
local function station(part, title, key)
	sign(part, title)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RubyStation"
	prompt:SetAttribute("Station", key)
	prompt.ObjectText = title
	prompt.ActionText = "Open"
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 15
	prompt.Parent = part
end
function Plaza:Init()
	local root = Instance.new("Model")
	root.Name = "RubyExchange"
	local stone = Color3.fromRGB(65, 55, 77)
	local brass = Color3.fromRGB(222, 159, 70)
	local ruby = Color3.fromRGB(236, 45, 92)
	local water = Color3.fromRGB(52, 201, 219)
	local function tile(name, x, y, z, w, h, d, col, mat: Enum.Material?)
		return brick(
			root,
			name,
			Plaza.origin + Vector3.new(x, y, z),
			Vector3.new(w, h, d),
			col,
			mat
		)
	end
	tile("Market square", 0, -1, 0, 140, 2, 140, stone)
	local paving = Color3.fromRGB(96, 79, 102)
	for _, x in { -24, 24 } do
		tile("Market promenade", x, 0.05, 0, 12, 0.1, 126, paving)
	end
	for _, z in { -30, 30 } do
		tile("Crosswalk", 0, 0.06, z, 106, 0.12, 9, paving)
	end
	for _, x in { -19, 19 } do
		for _, z in { -18, 18 } do
			tile("Lantern plinth", x, 1, z, 4, 2, 4, brass)
			local gem = tile("Ruby lantern", x, 4, z, 2.5, 4, 2.5, ruby, Enum.Material.Neon)
			gem.Orientation = Vector3.new(0, 45, 14)
		end
	end
	for _, x in { -66, 66 } do
		tile("Parapet", x, 3, 0, 3, 6, 140, brass)
	end
	for _, z in { -68, 68 } do
		tile("Parapet", 0, 3, z, 135, 6, 3, brass)
	end
	tile("Waterfall basin", 0, 0.5, 0, 28, 1, 24, water, Enum.Material.Glass)
	for i = 1, 4 do
		tile("Quarry ledge", 0, i * 3, -5 - i, 25 - i * 3, 6, 12, stone)
	end
	for i = -3, 3 do
		local fall = tile(
			"Waterfall",
			i * 2,
			7,
			-1.4,
			2,
			14,
			1.6,
			water:Lerp(Color3.new(1, 1, 1), math.abs(i) % 2 * 0.3),
			Enum.Material.Glass
		)
		fall.CanCollide = false
		local lip = Instance.new("Attachment")
		lip.Position = Vector3.new(0, 6.8, 0.9)
		lip.Parent = fall
		local droplets = Instance.new("ParticleEmitter")
		droplets.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		droplets.Color = ColorSequence.new(water, Color3.fromRGB(225, 255, 255))
		droplets.Size = NumberSequence.new(0.35)
		droplets.EmissionDirection = Enum.NormalId.Bottom
		droplets.Lifetime = NumberRange.new(0.75, 0.95)
		droplets.Rate = 8
		droplets.Speed = NumberRange.new(12, 15)
		droplets.Acceleration = Vector3.new(0, -10, 0)
		droplets.Parent = lip
		tile("Foam", i * 2, 1.1, 0, 2.3, 0.5, 4, Color3.fromRGB(188, 250, 255))
	end
	for i = 1, 8 do
		local x = if i <= 4 then -43 else 43
		local z = ((i - 1) % 4 - 1.5) * 24
		tile("Stall counter", x, 1.7, z, 17, 3.4, 7, brass)
		for _, dx in { -7, 7 } do
			tile("Awning post", x + dx, 5, z - 2, 1, 7, 1, stone)
		end
		local awning = tile(
			"Canvas",
			x,
			8.5,
			z,
			18,
			1,
			10,
			if i % 2 == 0 then ruby else Color3.fromRGB(122, 82, 182)
		)
		awning.CanCollide = false
		station(
			tile("Stall display", x, 3.8, z + 2, 12, 1, 2, stone),
			"Seller stall " .. i,
			"Stall" .. i
		)
	end
	tile("Terminal desk", 0, 2, 38, 15, 4, 7, brass)
	local monitor = tile(
		"Listing terminal",
		0,
		6,
		38,
		11,
		5,
		1,
		Color3.fromRGB(81, 225, 222),
		Enum.Material.Neon
	)
	station(monitor, "Market computer", "Market")
	for i, title in { "Recent Sales", "Most Net Worth", "Most Sold • 7 Days" } do
		local panel = tile("Market board", (i - 2) * 30, 5, -51, 25, 10, 2, stone)
		station(panel, title, "Board" .. i)
		local face = Instance.new("SurfaceGui")
		face.Face = Enum.NormalId.Back
		face.CanvasSize = Vector2.new(600, 320)
		face.Parent = panel
		local label = Instance.new("TextLabel")
		label.Name = "BoardText" .. i
		label.BackgroundColor3 = Color3.fromRGB(34, 25, 46)
		label.Size = UDim2.fromScale(1, 1)
		label.TextColor3 = Color3.fromRGB(255, 220, 150)
		label.Font = Enum.Font.FredokaOne
		label.TextSize = 29
		label.Text = title
		label.Parent = face
	end
	station(tile("Contracts", 22, 2, 42, 9, 4, 6, ruby), "Ruby contracts", "Quests")
	station(tile("Return gate", 0, 2, 58, 9, 4, 5, stone), "Return to forge", "Exit")
	local gate = brick(
		root,
		"Trading lobby gate",
		Plaza.entry,
		Vector3.new(11, 5, 5),
		ruby,
		Enum.Material.Neon
	)
	station(gate, "Trading lobbies", "Join")
	root.Parent = workspace
end
return Plaza
