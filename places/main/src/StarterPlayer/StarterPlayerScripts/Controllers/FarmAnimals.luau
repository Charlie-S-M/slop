--!strict
-- Ambient lobby sprites follow short loops. Server time keeps their routes consistent across clients.
const Players = game:GetService("Players")
const RunService = game:GetService("RunService")
const PixelSprites = require("@game/ReplicatedStorage/Shared/PixelSprites")

local FarmAnimals = {}
local routes = {
	{ species = "Cow", origin = Vector2.new(30, 80), size = 8.5, pace = 3.1, phase = 3 },
	{ species = "Cow", origin = Vector2.new(42, 92), size = 7, pace = 2.7, phase = 13 },
	{ species = "Pig", origin = Vector2.new(-32, 84), size = 6.3, pace = 3.4, phase = 7 },
	{ species = "Pig", origin = Vector2.new(-42, 67), size = 5.5, pace = 3, phase = 21 },
	{ species = "Chicken", origin = Vector2.new(22, 99), size = 4.7, pace = 4.3, phase = 2 },
	{ species = "Chicken", origin = Vector2.new(34, 104), size = 4.2, pace = 4.6, phase = 18 },
}
local palettes = {
	Cow = {
		Color3.fromRGB(242, 239, 228),
		Color3.fromRGB(57, 62, 73),
		Color3.fromRGB(247, 175, 163),
	},
	Pig = {
		Color3.fromRGB(251, 171, 167),
		Color3.fromRGB(244, 139, 151),
		Color3.fromRGB(218, 113, 128),
	},
	Chicken = {
		Color3.fromRGB(229, 220, 194),
		Color3.fromRGB(217, 63, 56),
		Color3.fromRGB(244, 166, 57),
	},
}
local trail = { Vector2.new(-5, -2), Vector2.new(6, -5), Vector2.new(9, 3), Vector2.new(-3, 5) }
local function facing(gui: BillboardGui, species: string, left: boolean): Frame
	local layer = Instance.new("Frame")
	layer.BackgroundTransparency = 1
	layer.Size = UDim2.fromScale(1, 1)
	local colors = palettes[species]
	PixelSprites.draw(layer, species, colors[1], colors[2], colors[3])
	if left then
		for _, strip in layer:GetChildren() do
			if strip:IsA("Frame") then
				strip.Position = UDim2.fromScale(
					1 - strip.Position.X.Scale - strip.Size.X.Scale,
					strip.Position.Y.Scale
				)
			end
		end
	end
	layer.Parent = gui
	return layer
end

function FarmAnimals:Start()
	local folder = Instance.new("Folder")
	folder.Name = "FarmAnimals"
	folder.Parent = workspace
	local flock = {}
	for _, route in routes do
		local anchor = Instance.new("Part")
		anchor.Name = route.species
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanTouch = false
		anchor.CanQuery = false
		anchor.Transparency = 1
		anchor.Size = Vector3.one
		anchor.Parent = folder
		local gui = Instance.new("BillboardGui")
		gui.Name = "PixelAnimal"
		gui.Adornee = anchor
		gui.Size = UDim2.fromScale(route.size, route.size)
		gui.LightInfluence = 0
		gui.AlwaysOnTop = true
		gui.MaxDistance = 520
		gui.Parent = anchor
		table.insert(flock, {
			route = route,
			anchor = anchor,
			gui = gui,
			right = facing(gui, route.species, false),
			left = facing(gui, route.species, true),
		})
	end
	local elapsed = 1
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 1 / 24 then
			return
		end
		elapsed = 0
		local visible = not Players.LocalPlayer:GetAttribute("InRun")
			and not Players.LocalPlayer:GetAttribute("ForgeCamera")
		local now = workspace:GetServerTimeNow()
		for _, animal in flock do
			animal.gui.Enabled = visible
			if not visible then
				continue
			end
			local route = animal.route
			local t = now + route.phase
			local index = math.floor(t / 6) % #trail + 1
			local a, b = trail[index], trail[index % #trail + 1]
			local distance = (b - a).Magnitude
			local progress = math.min((t % 6) * route.pace / distance, 1)
			local pos = route.origin + a:Lerp(b, progress)
			local bob = if progress < 1 then math.abs(math.sin(t * route.pace * 2)) * 0.34 else 0
			animal.anchor.Position = Vector3.new(pos.X, 2, pos.Y - bob)
			animal.left.Visible = b.X < a.X
			animal.right.Visible = not animal.left.Visible
		end
	end)
end
return FarmAnimals
