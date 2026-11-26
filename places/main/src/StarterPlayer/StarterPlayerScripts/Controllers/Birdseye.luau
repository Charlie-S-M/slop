--!strict
-- Screen-facing pixel characters retain the existing models for movement and hit detection.
const Input = game:GetService("UserInputService")
const Players = game:GetService("Players")
const RunService = game:GetService("RunService")
const PixelSprites = require("@game/ReplicatedStorage/Shared/PixelSprites")
const Guns = require("@game/ReplicatedStorage/Shared/Guns")
const Ores = require("@game/ReplicatedStorage/Shared/Ores")
const Pets = require("@game/ReplicatedStorage/Shared/Pets")

local Birdseye = {}
local player = Players.LocalPlayer
local ink = Color3.fromRGB(28, 21, 42)
local stations = {
	Forge = "ForgeIcon",
	Rebirth = "Gem",
	Portal = "PortalIcon",
	Leaderboard = "Trophy",
}
local painted: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
type Target = { anchor: BasePart, key: string, size: number }
local targets: { [Model]: Target } = {}

-- Match the cursor to the opaque sprite pixels before firing the physical shot from the muzzle.
function Birdseye.targetAt(point: Vector2): BasePart?
	local camera = workspace.CurrentCamera
	if not camera then
		return nil
	end
	local best: BasePart? = nil
	local nearest = math.huge
	for model, target in targets do
		if
			model:GetAttribute("Dead")
			or (model:GetAttribute("Owner") and model:GetAttribute("Owner") ~= player.UserId)
		then
			continue
		end
		-- Where the icon is drawn, which for a pinned target is on the floor below it.
		local gui = target.anchor:FindFirstChild("PixelIcon")
		local drawn = target.anchor.Position
			+ if gui and gui:IsA("BillboardGui") then gui.StudsOffsetWorldSpace else Vector3.zero
		local center, visible = camera:WorldToViewportPoint(drawn)
		if not visible or center.Z <= 0 or center.Z >= nearest then
			continue
		end
		local edge =
			camera:WorldToViewportPoint(drawn + camera.CFrame.RightVector * target.size / 2)
		local width = 2 * (edge.X - center.X)
		if width <= 0 then
			continue
		end
		local x = 1 + math.floor(16 * ((point.X - center.X) / width + 0.5))
		local y = 1 + math.floor(16 * ((point.Y - center.Y) / width + 0.5))
		local row = PixelSprites.SPRITES[target.key][y]
		if x >= 1 and x <= 16 and row and row:sub(x, x) ~= "." then
			nearest = center.Z
			best = target.anchor
		end
	end
	return best
end

-- The height of the floor under a point. Floors are "Tile", "Base", or "Lane" parts or thin slabs;
-- anything else the ray meets first (a hidden wall ledge, a board, a pad) is passed through.
local function floorBelow(position: Vector3, ignore: Instance): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local skipped: { Instance } = { ignore }
	for _ = 1, 12 do
		params.FilterDescendantsInstances = skipped
		local hit = workspace:Raycast(position, Vector3.new(0, -400, 0), params)
		if not hit then
			return nil
		end
		local part = hit.Instance
		if
			part.Name == "Tile"
			or part.Name == "Base"
			or part.Name == "Lane"
			or (part:IsA("BasePart") and part.Size.Y <= 0.6)
		then
			return hit.Position.Y
		end
		table.insert(skipped, part)
	end
	return nil
end

const SIDES = { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis }

-- The middle of the wall a torch hangs on. The nearest wall brick around the torch is its wall;
-- a ray at just that brick from behind finds the far face, and the middle is between the two.
-- Nil when the torch isn't on a wall (the portal's torches hang on pillars).
local function wallMiddle(torch: Model): Vector3?
	const start = torch:GetBoundingBox().Position
	const params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { torch }
	local nearest: RaycastResult? = nil
	local direction = Vector3.zero
	for _, side in SIDES do
		const hit = workspace:Raycast(start, side * 8, params)
		-- Only the wall the torch was built on counts, not a nearby building's wall.
		const wall = hit and hit.Instance:FindFirstAncestor("Wall")
		if
			hit
			and wall
			and wall.Parent == torch.Parent
			and (not nearest or hit.Distance < nearest.Distance)
		then
			nearest = hit
			direction = side
		end
	end
	if not nearest then
		return nil
	end
	const only = RaycastParams.new()
	only.FilterType = Enum.RaycastFilterType.Include
	only.FilterDescendantsInstances = { nearest.Instance }
	const behind = nearest.Position + direction * 40
	const outer = workspace:Raycast(behind, -direction * 40, only)
	if not outer then
		return nil
	end
	return (nearest.Position + outer.Position) / 2
end

local function icon(
	owner: Instance,
	anchor: BasePart,
	key: string,
	body: Color3,
	accent: Color3,
	size: number,
	at: Vector3?
)
	if painted[owner] then
		return
	end
	painted[owner] = true
	local gui = Instance.new("BillboardGui")
	gui.Name = "PixelIcon"
	gui.Adornee = anchor
	gui.Size = UDim2.fromScale(size, size)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = math.huge
	PixelSprites.draw(gui, key, body, accent)
	gui.Parent = anchor
	-- The camera is a perspective one, so an icon drawn up high (a castle's cap, a wall torch, a
	-- floating crystal) slides against the floor as it moves. Anything that stays put is drawn on
	-- the floor instead, under the middle of its model, so every icon keeps its place on the map.
	if
		anchor.Anchored
		and not owner:IsA("Tool")
		and not owner:GetAttribute("EnemyId")
		and not owner:GetAttribute("OrePickup")
	then
		local center = at
			or if owner:IsA("Model") then owner:GetBoundingBox().Position else anchor.Position
		local floor = floorBelow(center, owner)
		if floor then
			local offset = Vector3.new(center.X, floor + 0.5, center.Z) - anchor.Position
			gui.StudsOffsetWorldSpace = offset
		end
	end
end

-- Hides a model's 3D look on this client. Characters also lose faces, clothes, and shadows, so
-- nothing of the avatar shows under its pixel icon.
local function hidePart(item: Instance)
	if item:IsA("BasePart") then
		item.LocalTransparencyModifier = 1
		item.CastShadow = false
	elseif item:IsA("Decal") then
		item.Transparency = 1
	end
end

-- Characters are hidden by Transparency itself: Roblox's camera code keeps resetting a character's
-- LocalTransparencyModifier, which let the avatar show through while moving. This is local only.
local function hideCharacterPart(item: Instance)
	if item:IsA("BasePart") then
		item.Transparency = 1
		item.CastShadow = false
	elseif item:IsA("Decal") then
		item.Transparency = 1
	end
end

local function conceal(model: Model)
	for _, child in model:GetDescendants() do
		hidePart(child)
	end
end

local function style(model: Model)
	if painted[model] then
		return
	end
	local anchor = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not anchor then
		return
	end
	local shape = model:GetAttribute("Shape")
	local key: string
	local body = anchor.Color
	local accent = body:Lerp(Color3.new(1, 1, 1), 0.4)
	local size = 7
	if model:GetAttribute("EnemyId") then
		local torso = model:FindFirstChild("Torso") or model:FindFirstChild("Body")
		if torso and torso:IsA("BasePart") then
			body = torso.Color
		end
		key = if model:GetAttribute("Boss")
			then "BossIcon"
			elseif shape == "Humanoid" then "Ranger"
			elseif shape == "Floater" then "Winged"
			elseif shape == "Blob" then "Slime"
			else "Critter"
		size = math.max(6, model:GetExtentsSize().Magnitude * 0.86)
	elseif model:GetAttribute("OrePickup") then
		local ore = Ores.get(tostring(model:GetAttribute("OreId")))
		if ore then
			body = ore.color
		end
		key = if ore then PixelSprites.forOre(ore.style) else "Gem"
		accent = body:Lerp(Color3.new(1, 1, 1), 0.35)
		size = 5
	elseif model.Parent and model.Parent.Name == "Pets" then
		local pet = Pets.get(model.Name)
		if not pet then
			return
		end
		key = PixelSprites.forPet(pet.style)
		body, accent = pet.body, pet.accent
		size = 4
	elseif model:GetAttribute("TrainingTarget") or model.Name == "TrainingDummy" then
		key = "TargetIcon"
		anchor = model:FindFirstChild("Board") :: BasePart or anchor
		body, accent = Color3.fromRGB(200, 60, 44), Color3.fromRGB(255, 197, 89)
	elseif model.Name == "Lamp" or model.Name == "Torch" then
		key = "Lantern"
		body, accent = Color3.fromRGB(142, 97, 58), Color3.fromRGB(255, 203, 70)
		size = 7
	elseif model.Name == "Tower" and model:FindFirstChild("Cap") then
		key = "Keep"
		body, accent = Color3.fromRGB(107, 116, 154), Color3.fromRGB(189, 198, 224)
		anchor = model:FindFirstChild("Cap") :: BasePart
		size = 24
	elseif model.Name == "Tree" then
		key = "TreeIcon"
		body, accent = Color3.fromRGB(46, 134, 74), Color3.fromRGB(127, 214, 78)
		size = 15
	else
		return
	end
	conceal(model)
	-- Wall torches sit on the middle of their wall, so every one lines up the same way.
	icon(
		model,
		anchor,
		key,
		body,
		accent,
		size,
		if model.Name == "Torch" then wallMiddle(model) else nil
	)
	if model:GetAttribute("EnemyId") then
		local gui = anchor:FindFirstChild("PixelIcon") :: BillboardGui?
		if gui then
			local function visible()
				gui.Enabled = model:GetAttribute("Dead") ~= true
			end
			model:GetAttributeChangedSignal("Dead"):Connect(visible)
			visible()
		end
	end
	if
		model:GetAttribute("EnemyId")
		or model:GetAttribute("TrainingTarget")
		or model.Name == "TrainingDummy"
	then
		local hit = model:FindFirstChild("Torso") or model:FindFirstChild("Body") or anchor
		targets[model] =
			{ anchor = if hit:IsA("BasePart") then hit else anchor, key = key, size = size }
		model.Destroying:Once(function()
			targets[model] = nil
		end)
	end
end

local function tileArt(tile: BasePart)
	if tile:FindFirstChild("PixelTile") then
		return
	end
	local surface = Instance.new("SurfaceGui")
	surface.Name = "PixelTile"
	surface.Face = Enum.NormalId.Top
	surface.CanvasSize = Vector2.new(32, 32)
	surface.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	surface.LightInfluence = 0
	surface.MaxDistance = math.huge
	local seed = math.floor(tile.Position.X * 31 + tile.Position.Z * 19)
	local random = Random.new(seed)
	for i = 1, 4 do
		local fleck = Instance.new("Frame")
		fleck.BorderSizePixel = 0
		fleck.BackgroundColor3 = if i == 1 then Color3.new(1, 1, 1) else ink
		fleck.BackgroundTransparency = 0.83
		fleck.Position = UDim2.fromOffset(random:NextInteger(2, 24), random:NextInteger(2, 27))
		fleck.Size = UDim2.fromOffset(random:NextInteger(2, 5), 1)
		fleck.Parent = surface
	end
	surface.Parent = tile
end

-- Draw the static map on the floor grid. The original parts retain their collision,
-- proximity prompts and paint attributes when the server changes the arena biome.
local mapLayer = Instance.new("Folder")
mapLayer.Name = "PixelMap"
local function flatten(part: BasePart)
	if part.Transparency >= 1 or part.LocalTransparencyModifier >= 1 then
		return
	end
	local arena = part:FindFirstAncestor("Arenas")
	if not arena and not part:FindFirstAncestor("Lobby") then
		return
	end
	if part:FindFirstAncestorWhichIsA("Tool") then
		return
	end
	if arena then
		local parent: Instance? = part.Parent
		while parent and parent ~= arena do
			if parent:IsA("Folder") and parent.Name:sub(1, 4) == "Run_" then
				return
			end
			parent = parent.Parent
		end
	end
	if part:FindFirstAncestor("Target") then
		return
	end
	local name = part.Name
	if
		name == "Stud"
		or name == "Puff"
		or name == "Roof"
		or name == "Awning"
		or name == "Leaderboard"
		or name == "BoardFrame"
		or name == "BoardLeg"
	then
		part.LocalTransparencyModifier = 1
		return
	end
	-- Existing floor tiles provide the base layer. Collapse solid buildings into map footprints.
	if name == "Tile" or name == "Base" or part.Position.Y < 1 or part.Size.Y < 0.6 then
		return
	end
	if part:FindFirstAncestor("Wall") and name ~= "Core" then
		part.LocalTransparencyModifier = 1
		return
	end
	local cf = part.CFrame
	local half = part.Size / 2
	local x = math.abs(cf.RightVector.X) * half.X
		+ math.abs(cf.UpVector.X) * half.Y
		+ math.abs(cf.LookVector.X) * half.Z
	local z = math.abs(cf.RightVector.Z) * half.X
		+ math.abs(cf.UpVector.Z) * half.Y
		+ math.abs(cf.LookVector.Z) * half.Z
	part.LocalTransparencyModifier = 1
	if x < 0.4 or z < 0.4 then
		return
	end
	local lowX, lowZ = math.floor(cf.X - x + 0.5), math.floor(cf.Z - z + 0.5)
	local highX, highZ = math.ceil(cf.X + x - 0.5), math.ceil(cf.Z + z - 0.5)
	local stamp = Instance.new("Part")
	stamp.Name = "MapTile"
	stamp.Anchored = true
	stamp.CanCollide = false
	stamp.CanQuery = false
	stamp.CanTouch = false
	stamp.CastShadow = false
	stamp.Material = Enum.Material.SmoothPlastic
	stamp.Size = Vector3.new(math.max(1, highX - lowX), 0.05, math.max(1, highZ - lowZ))
	local y = 0.35 + math.clamp(cf.Y * 0.035, 0, 2)
	stamp.Position = Vector3.new((lowX + highX) / 2, y, (lowZ + highZ) / 2)
	stamp.Color = part.Color
	stamp.Transparency = part.Transparency
	stamp.Parent = mapLayer
	part:GetPropertyChangedSignal("Color"):Connect(function()
		stamp.Color = part.Color
	end)
	part.Destroying:Once(function()
		stamp:Destroy()
	end)
end

local function inspect(item: Instance)
	if
		item:IsA("SurfaceGui")
		and item.Name == "Gui"
		and item.Parent
		and item.Parent:IsA("BasePart")
		and item.Parent.Name == "StageSign"
	then
		item.Face = Enum.NormalId.Top
		item.AlwaysOnTop = true
	elseif
		item:IsA("SurfaceGui")
		and item.Parent
		and item.Parent:IsA("BasePart")
		and item.Parent.Name == "Leaderboard"
	then
		-- The board stands on edge, so from above it's a line; its list opens from a prompt instead.
		item.Enabled = false
	elseif item:IsA("BillboardGui") and item.Name ~= "PixelIcon" then
		-- The camera sits far above the floor, so signs must draw at any distance.
		item.MaxDistance = math.huge
		local offset = item.StudsOffsetWorldSpace
		if item:FindFirstChild("ZoneLabel") then
			-- A training pad's multiplier, written across the pad's upper half.
			item.StudsOffsetWorldSpace = Vector3.new(0, 1, -3)
			item.Size = UDim2.fromScale(15, 4.2)
			item.AlwaysOnTop = true
		elseif item:FindFirstChild("LockLabel") then
			item.StudsOffsetWorldSpace = Vector3.new(0, 1, 3)
			item.Size = UDim2.fromScale(13, 2.6)
			item.AlwaysOnTop = true
		elseif offset.Y > 2 and offset.Z == 0 then
			item.StudsOffsetWorldSpace = Vector3.new(offset.X, 1, -offset.Y * 0.7)
		end
	elseif item:IsA("Model") then
		style(item)
	elseif item:IsA("BasePart") then
		if item.Name == "Tile" then
			tileArt(item)
		end
		local station = item:GetAttribute("Station")
		if typeof(station) == "string" then
			local trophy = station == "Leaderboard"
			icon(
				item,
				item,
				(stations :: any)[station] or "Shop",
				if trophy then Color3.fromRGB(255, 196, 60) else Color3.fromRGB(100, 116, 162),
				if trophy then Color3.fromRGB(255, 240, 170) else Color3.fromRGB(255, 177, 70),
				13
			)
		elseif
			item.Name == "Crate"
			and (item:FindFirstAncestor("Lobby") or item:FindFirstAncestor("Arenas"))
		then
			item.LocalTransparencyModifier = 1
			icon(
				item,
				item,
				"CrateIcon",
				item.Color,
				Color3.fromRGB(248, 188, 106),
				item.Size.X * 1.5
			)
		elseif item.Name == "DefenseCrystal" then
			item.LocalTransparencyModifier = 1
			icon(item, item, "Gem", item.Color, Color3.fromRGB(158, 251, 255), 15)
		elseif item.Name == "Roof" or item.Name == "Awning" or item.Name == "Puff" then
			item.LocalTransparencyModifier = 1
		end
		flatten(item)
		local parent = item.Parent
		if parent and parent:IsA("Model") then
			style(parent)
		end
	end
end

local weapons: { [Tool]: { root: BasePart, gui: BillboardGui, layer: Frame } } = {}
local function drawGun(tool: Tool, root: BasePart)
	if weapons[tool] then
		return
	end
	local def = Guns.get(tostring(tool:GetAttribute("GunId")))
	local handle = tool:FindFirstChild("Handle")
	if not def or not handle or not handle:IsA("BasePart") then
		return
	end
	icon(tool, handle, PixelSprites.forGun(def.kind), def.body, def.accent, 5)
	local gui = handle:FindFirstChild("PixelIcon") :: BillboardGui?
	if not gui then
		return
	end
	gui.Adornee = root
	local layer = Instance.new("Frame")
	layer.BackgroundTransparency = 1
	layer.Size = UDim2.fromScale(1, 1)
	for _, child in gui:GetChildren() do
		child.Parent = layer
	end
	layer.Parent = gui
	weapons[tool] = { root = root, gui = gui, layer = layer }
	local connection: RBXScriptConnection
	connection = tool.AncestryChanged:Connect(function()
		if tool.Parent ~= root.Parent then
			connection:Disconnect()
			weapons[tool] = nil
			painted[tool] = nil
			gui:Destroy()
		end
	end)
end

-- Each character's pixel figure: an idle pose and two stride frames, each facing left or right.
type Walker = {
	root: BasePart,
	layers: { [string]: Frame },
	facing: string,
	stride: number,
	shown: string,
}
local walkers: { [Model]: Walker } = {}
const POSES = { "Ranger", "RangerStepA", "RangerStepB" }

local function walker(model: Model, root: BasePart)
	if walkers[model] then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "PixelIcon"
	gui.Adornee = root
	gui.Size = UDim2.fromScale(8, 8)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = math.huge
	local layers: { [string]: Frame } = {}
	for _, pose in POSES do
		for _, side in { "R", "L" } do
			local layer = Instance.new("Frame")
			layer.Name = pose .. side
			layer.BackgroundTransparency = 1
			layer.Size = UDim2.fromScale(1, 1)
			layer.Visible = false
			local key = if side == "L" then PixelSprites.flipped(pose) else pose
			PixelSprites.draw(
				layer,
				key,
				Color3.fromRGB(48, 126, 177),
				Color3.fromRGB(255, 187, 101)
			)
			layer.Parent = gui
			layers[pose .. side] = layer
		end
	end
	layers.RangerR.Visible = true
	gui.Parent = root
	painted[model] = true
	walkers[model] = { root = root, layers = layers, facing = "R", stride = 0, shown = "RangerR" }
	model.Destroying:Once(function()
		walkers[model] = nil
	end)
end

-- Picks each walker's frame from how fast and which way it's moving, so the figure strides in step.
local function animateWalkers(dt: number)
	for model, walk in walkers do
		if not model.Parent then
			walkers[model] = nil
			continue
		end
		local velocity = walk.root.AssemblyLinearVelocity
		local speed = Vector2.new(velocity.X, velocity.Z).Magnitude
		if velocity.X > 0.5 then
			walk.facing = "R"
		elseif velocity.X < -0.5 then
			walk.facing = "L"
		end
		local pose = "Ranger"
		local bob = 0
		if speed > 1 then
			-- Five to ten frames a second, quicker the faster the walk, so legs never flicker.
			walk.stride = (walk.stride + dt * math.clamp(speed * 0.15, 5, 10)) % 4
			local phase = math.floor(walk.stride)
			pose = if phase == 0
				then "RangerStepA"
				elseif phase == 2 then "RangerStepB"
				else "Ranger"
			bob = math.abs(math.sin(walk.stride * math.pi / 2)) * 0.035
		else
			walk.stride = 0
		end
		local key = pose .. walk.facing
		if key ~= walk.shown then
			walk.layers[walk.shown].Visible = false
			walk.layers[key].Visible = true
			walk.shown = key
		end
		walk.layers[key].Position = UDim2.fromScale(0, -bob)
	end
end

local function character(model: Model)
	local anchor = model:WaitForChild("HumanoidRootPart", 10)
	if not anchor or not anchor:IsA("BasePart") then
		return
	end
	for _, item in model:GetDescendants() do
		hideCharacterPart(item)
	end
	local held = model:FindFirstChildOfClass("Tool")
	if held then
		drawGun(held, anchor)
	end
	model.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			task.defer(drawGun, child, anchor)
		end
	end)
	model.DescendantAdded:Connect(function(item)
		hideCharacterPart(item)
	end)
	walker(model, anchor)
end

local function watch(who: Player)
	who.CharacterAdded:Connect(character)
	if who.Character then
		task.spawn(character, who.Character)
	end
end

const CAMERA_HEIGHT = 400
local zoom = 1
local targetZoom = 1
local pinchStart = 1
local function adjust(multiplier: number)
	if player:GetAttribute("ForgeCamera") then
		return
	end
	targetZoom = math.clamp(targetZoom * multiplier, 0.8, 4.5)
end

function Birdseye:Start()
	Input.InputChanged:Connect(function(input, processed)
		if not processed and input.UserInputType == Enum.UserInputType.MouseWheel then
			adjust(1.22 ^ -input.Position.Z)
		end
	end)
	Input.TouchPinch:Connect(function(_, scale, _, state, processed)
		if state == Enum.UserInputState.Begin then
			pinchStart = targetZoom
		end
		if not processed and not player:GetAttribute("ForgeCamera") and scale > 0 then
			targetZoom = math.clamp(pinchStart / scale, 0.8, 4.5)
		end
	end)
	Input.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Minus or input.KeyCode == Enum.KeyCode.DPadDown then
			adjust(1.3)
		elseif input.KeyCode == Enum.KeyCode.Equals or input.KeyCode == Enum.KeyCode.DPadUp then
			adjust(1 / 1.3)
		end
	end)
	mapLayer.Parent = workspace
	for _, who in Players:GetPlayers() do
		watch(who)
	end
	Players.PlayerAdded:Connect(watch)
	workspace.DescendantAdded:Connect(function(item)
		if
			item:IsA("Model")
			or item:IsA("BasePart")
			or item:IsA("BillboardGui")
			or item:IsA("SurfaceGui")
		then
			task.defer(inspect, item)
		end
	end)
	for _, item in workspace:GetDescendants() do
		inspect(item)
	end
	RunService:BindToRenderStep("Birdseye", Enum.RenderPriority.Camera.Value, function(dt: number)
		animateWalkers(dt)
		if player:GetAttribute("ForgeCamera") then
			return
		end
		local camera = workspace.CurrentCamera
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not camera or not root or not root:IsA("BasePart") then
			return
		end
		for _, weapon in weapons do
			local forward = weapon.root.CFrame.LookVector
			weapon.gui.StudsOffsetWorldSpace = Vector3.new(forward.X * 2.6, 1, forward.Z * 2.6)
			weapon.layer.Rotation = math.deg(math.atan2(forward.Z, forward.X))
		end
		local focus = root.Position
		camera.CameraType = Enum.CameraType.Scriptable
		zoom += (targetZoom - zoom) * (1 - math.exp(-12 * dt))
		-- A high camera with a narrow view is close to orthographic. Zooming only widens the view;
		-- the camera stays at one height, so nothing passes a draw distance as you zoom out.
		camera.FieldOfView =
			math.deg(2 * math.atan(math.tan(math.rad(18)) * 100 * zoom / CAMERA_HEIGHT))
		camera.Focus = CFrame.new(focus)
		camera.CFrame =
			CFrame.lookAt(focus + Vector3.new(0, CAMERA_HEIGHT, 0), focus, Vector3.new(0, 0, -1))
	end)
end
return Birdseye
