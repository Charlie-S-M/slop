--!strict

--[[
	The lobby's farm animals: pixel sprites walking short loops from server time (FarmRoutes), so
	every client sees them in the same place. Shooting one tells the server; the animal hops up,
	tumbles off the map, and walks back in from the same spot once the server says it's back.
]]

const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")

const FarmRoutes = require("@game/ReplicatedStorage/Shared/FarmRoutes")
const Net = require("@game/ReplicatedStorage/Shared/Net")
const PixelSprites = require("@game/ReplicatedStorage/Shared/PixelSprites")
const Kit = require("./UI/Kit")

local FarmAnimals = {}

const palettes = {
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

-- The knock-off: a hop up for HOP seconds, then a tumbling fall off the map for FALL seconds.
const HOP = 0.28
const FALL = 0.9
const HOP_HEIGHT = 7
const FALL_DEPTH = 90

type Animal = {
	index: number,
	route: FarmRoutes.Route,
	anchor: Part,
	gui: BillboardGui,
	right: Frame,
	left: Frame,
	-- Server time the knock-off started and where, while it plays; the server time it's back.
	knockedAt: number?,
	knockedFrom: Vector3?,
	downUntil: number,
}

local flock: { Animal } = {}
local byAnchor: { [Instance]: Animal } = {}

local function facing(gui: BillboardGui, species: string, left: boolean): Frame
	local layer = Instance.new("Frame")
	layer.BackgroundTransparency = 1
	layer.AnchorPoint = Vector2.new(0.5, 0.5)
	layer.Position = UDim2.fromScale(0.5, 0.5)
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

local function shiftOf(index: number): Vector2
	local value = ReplicatedStorage:GetAttribute(`AnimalShift{index}`)
	return if typeof(value) == "Vector2" then value else Vector2.zero
end

-- Starts the knock-off from `from`, unless it's already playing.
local function knock(animal: Animal, from: Vector3, untilTime: number)
	if animal.knockedAt and animal.downUntil > workspace:GetServerTimeNow() then
		animal.downUntil = untilTime
		return
	end
	animal.knockedAt = workspace:GetServerTimeNow()
	animal.knockedFrom = from
	animal.downUntil = untilTime
end

local function follow(animal: Animal)
	local function read()
		local down = ReplicatedStorage:GetAttribute(`AnimalDown{animal.index}`)
		if typeof(down) ~= "number" or down <= workspace:GetServerTimeNow() then
			return
		end
		local hitAt = ReplicatedStorage:GetAttribute(`AnimalHitAt{animal.index}`)
		knock(animal, if typeof(hitAt) == "Vector3" then hitAt else animal.anchor.Position, down)
	end
	ReplicatedStorage:GetAttributeChangedSignal(`AnimalDown{animal.index}`):Connect(read)
	read()
end

-- The animal a shot hit, from the part the ray struck; nil when it isn't one.
function FarmAnimals.fromPart(part: Instance): number?
	local animal = byAnchor[part]
	if not animal or animal.knockedAt then
		return nil
	end
	return animal.index
end

-- Knocks the animal down right away on this client and tells the server.
function FarmAnimals.shoot(index: number)
	local animal = flock[index]
	if not animal or animal.knockedAt then
		return
	end
	Kit.sound(Kit.Sounds.Pop, 0.45, 0.7 + math.random() * 0.3)
	knock(animal, animal.anchor.Position, workspace:GetServerTimeNow() + FarmRoutes.RESPAWN_SECONDS)
	Net.event("ShootAnimal"):FireServer(index)
end

local function place(animal: Animal, now: number)
	local route = animal.route
	if animal.knockedAt then
		local from = animal.knockedFrom or animal.anchor.Position
		local t = now - animal.knockedAt
		local layer = if animal.left.Visible then animal.left else animal.right
		if t < HOP then
			local share = t / HOP
			animal.anchor.Position = from + Vector3.new(0, HOP_HEIGHT * (1 - (1 - share) ^ 2), 0)
			layer.Rotation = share * 90
			return
		elseif t < HOP + FALL then
			local share = (t - HOP) / FALL
			animal.anchor.Position = from
				+ Vector3.new(0, HOP_HEIGHT - FALL_DEPTH * share * share, 0)
			layer.Rotation = 90 + share * 540
			return
		elseif now < animal.downUntil then
			animal.gui.Enabled = false
			return
		end
		-- Back: walking again from where it was shot.
		animal.knockedAt = nil
		animal.knockedFrom = nil
		animal.left.Rotation = 0
		animal.right.Rotation = 0
	end
	local _, _, left = FarmRoutes.walk(route, now)
	animal.anchor.Position = FarmRoutes.position(route, now, shiftOf(animal.index))
	animal.left.Visible = left
	animal.right.Visible = not left
end

function FarmAnimals:Start()
	local folder = Instance.new("Folder")
	folder.Name = "FarmAnimals"
	folder.Parent = workspace
	for index, route in FarmRoutes.ROUTES do
		-- Invisible but solid to shots, about the size of the sprite.
		local anchor = Instance.new("Part")
		anchor.Name = route.species
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanTouch = false
		anchor.CanQuery = true
		anchor.Transparency = 1
		anchor.Size = Vector3.new(route.size * 0.6, 6, route.size * 0.6)
		anchor.Parent = folder
		local gui = Instance.new("BillboardGui")
		gui.Name = "PixelAnimal"
		gui.Adornee = anchor
		gui.Size = UDim2.fromScale(route.size, route.size)
		gui.LightInfluence = 0
		gui.AlwaysOnTop = true
		gui.MaxDistance = math.huge
		gui.Parent = anchor
		local animal: Animal = {
			index = index,
			route = route,
			anchor = anchor,
			gui = gui,
			right = facing(gui, route.species, false),
			left = facing(gui, route.species, true),
			knockedAt = nil,
			knockedFrom = nil,
			downUntil = 0,
		}
		table.insert(flock, animal)
		byAnchor[anchor] = animal
		follow(animal)
	end
	local elapsed = 1
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		-- Walking updates 24 times a second; a knock-off plays every frame so it reads smoothly.
		local tumbling = false
		for _, animal in flock do
			tumbling = tumbling or animal.knockedAt ~= nil
		end
		if elapsed < 1 / 24 and not tumbling then
			return
		end
		elapsed = 0
		local visible = not Players.LocalPlayer:GetAttribute("InRun")
			and not Players.LocalPlayer:GetAttribute("ForgeCamera")
		local now = workspace:GetServerTimeNow()
		for _, animal in flock do
			animal.gui.Enabled = visible
			if visible then
				place(animal, now)
			end
			animal.anchor.CanQuery = visible and animal.knockedAt == nil
		end
	end)
end

return FarmAnimals
