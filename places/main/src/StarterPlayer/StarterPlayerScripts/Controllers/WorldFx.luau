--!strict

--[[
	Client-side life for the world: enemies swing their limbs, show health bars, and burst into
	confetti cubes when they die; ore pickups bob and spin; lobby stations get interaction prompts;
	and training pads hide their locks once unlocked.
]]

const Players = game:GetService("Players")
const RunService = game:GetService("RunService")
const TweenService = game:GetService("TweenService")

const Balance = require("@game/ReplicatedStorage/Shared/Balance")
const Biomes = require("@game/ReplicatedStorage/Shared/Biomes")
const Format = require("@game/ReplicatedStorage/Shared/Format")
const Ores = require("@game/ReplicatedStorage/Shared/Ores")
const Rarity = require("@game/ReplicatedStorage/Shared/Rarity")
const ClientState = require("./ClientState")
const GunController = require("./GunController")
const Kit = require("./UI/Kit")
const Menus = require("./Menus")

type Tracked = {
	model: Model,
	root: BasePart,
	joints: { [string]: Motor6D },
	shape: string,
	last: Vector3,
	phase: number,
	speed: number,
	bar: Frame?,
	barText: TextLabel?,
	dead: boolean,
}

local WorldFx = {}

local player = Players.LocalPlayer
local tracked: { [Model]: Tracked } = {}
local pickups: { [Model]: { base: CFrame, seed: number } } = {}
local bossGui: ScreenGui
local bossFrame: Frame
local bossFill: Frame
local bossName: TextLabel
local bossHp: TextLabel
local bossModel: Model? = nil

const STATION_MENUS = {
	Forge = { menu = "Forge", text = "Forge a Gun" },
	Rebirth = { menu = "Rebirth", text = "Rebirth" },
	Portal = { menu = "Gauntlet", text = "Enter the Gauntlet" },
	Leaderboard = { menu = "Leaderboard", text = "Leaderboard" },
	Shop = { menu = "Shop", text = "Open Shop" },
	Wheel = { menu = "Wheel", text = "Spin the Wheel" },
}

------------------------------------------------------------------------------------------------
-- Enemies
------------------------------------------------------------------------------------------------

local function healthBar(model: Model, root: BasePart): (Frame, TextLabel)
	local scale = (model:GetAttribute("Scale") :: number?) or 1
	local gui = Instance.new("BillboardGui")
	gui.Name = "HealthBar"
	-- Studs plus a pixel floor, so far-away bars stay readable and big enemies get big bars.
	gui.Size = UDim2.new(math.clamp(2.6 * scale, 2.6, 30), 90, math.clamp(0.7 * scale, 0.7, 8), 30)
	gui.StudsOffsetWorldSpace =
		Vector3.new(0, 1, -math.max(4, model:GetExtentsSize().Magnitude * 0.38))
	gui.LightInfluence = 0
	gui.MaxDistance = 220
	-- Drawn in the world, so walls hide bars of enemies behind them.
	gui.AlwaysOnTop = false
	gui.Adornee = root
	gui.Parent = root

	Kit.text({
		Name = "Name",
		Text = (model:GetAttribute("DisplayName") :: string?) or model.Name,
		Size = UDim2.fromScale(1, 0.45),
		TextColor3 = if model:GetAttribute("Boss")
			then Color3.fromRGB(255, 120, 120)
			else Color3.new(1, 1, 1),
		Stroke = 2,
		Parent = gui,
	})
	local back = Kit.new("Frame", {
		Size = UDim2.fromScale(1, 0.45),
		Position = UDim2.fromScale(0, 0.52),
		BackgroundColor3 = Kit.Colors.Ink,
		Parent = gui,
	})
	Kit.cornerScale(0.5).Parent = back
	Kit.stroke(2, Kit.Colors.Ink, Enum.ApplyStrokeMode.Border).Parent = back
	local fill = Kit.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(90, 230, 80),
		BorderSizePixel = 0,
		Parent = back,
	})
	Kit.cornerScale(0.5).Parent = fill
	local text = Kit.text({
		Text = "",
		Size = UDim2.fromScale(0.95, 0.85),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Stroke = 1.5,
		ZIndex = 3,
		Parent = back,
	})
	return fill, text
end

local function updateHealth(entry: Tracked)
	local health = (entry.model:GetAttribute("Health") :: number?) or 0
	local maxHealth = (entry.model:GetAttribute("MaxHealth") :: number?) or 1
	local share = math.clamp(health / maxHealth, 0, 1)
	if entry.bar then
		TweenService:Create(entry.bar, Kit.FAST, {
			Size = UDim2.fromScale(share, 1),
			BackgroundColor3 = Color3.fromRGB(235, 60, 60):Lerp(Color3.fromRGB(90, 230, 80), share),
		}):Play()
	end
	if entry.barText then
		entry.barText.Text = Format.abbreviate(math.max(0, health))
	end
	if bossModel == entry.model then
		TweenService:Create(bossFill, Kit.FAST, { Size = UDim2.fromScale(share, 1) }):Play()
		bossHp.Text = `{Format.abbreviate(math.max(0, health))} / {Format.abbreviate(maxHealth)}`
	end
end

local function deathBurst(entry: Tracked)
	local model = entry.model
	local root = entry.root
	local scale = (model:GetAttribute("Scale") :: number?) or 1
	Kit.sound(Kit.Sounds.Poof, 0.35, 1.3 - math.min(scale, 8) * 0.06)
	local colors = {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part ~= root then
			table.insert(colors, part.Color)
			TweenService:Create(part, TweenInfo.new(0.35), { Transparency = 1 }):Play()
		end
	end
	local effects = GunController.effects()
	for index = 1, 10 do
		local cube = Instance.new("Part")
		cube.Anchored = true
		cube.CanCollide = false
		cube.CanQuery = false
		cube.CanTouch = false
		cube.Size = Vector3.one * scale * (0.4 + math.random() * 0.5)
		cube.Color = colors[(index % math.max(#colors, 1)) + 1] or Color3.new(1, 1, 1)
		cube.CFrame = root.CFrame
			* CFrame.new(
				(math.random() - 0.5) * 2 * scale,
				(math.random() - 0.3) * 2 * scale,
				(math.random() - 0.5) * 2 * scale
			)
		cube.Parent = effects
		local fling = Vector3.new(
			math.random() - 0.5,
			math.random() * 0.8 + 0.4,
			math.random() - 0.5
		).Unit * scale * (5 + math.random() * 5)
		TweenService:Create(cube, TweenInfo.new(0.6, Enum.EasingStyle.Quad), {
			CFrame = cube.CFrame
				* CFrame.new(fling)
				* CFrame.Angles(math.random() * 4, math.random() * 4, 0),
			Size = Vector3.one * 0.1,
			Transparency = 0.6,
		}):Play()
		task.delay(0.62, function()
			cube:Destroy()
		end)
	end
	local ring = Instance.new("Part")
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.Material = Enum.Material.Neon
	ring.Shape = Enum.PartType.Ball
	ring.Color = Color3.new(1, 1, 1)
	ring.Size = Vector3.one * scale * 2
	ring.CFrame = root.CFrame
	ring.Parent = effects
	TweenService
		:Create(ring, TweenInfo.new(0.3), { Size = Vector3.one * scale * 7, Transparency = 1 })
		:Play()
	task.delay(0.32, function()
		ring:Destroy()
	end)
	if bossModel == model then
		bossModel = nil
		bossFrame.Visible = false
	end
end

local function track(model: Model)
	if tracked[model] or model:GetAttribute("Owner") ~= player.UserId then
		return
	end
	local root = model:FindFirstChild("Root")
	if not root or not root:IsA("BasePart") then
		return
	end
	local joints: { [string]: Motor6D } = {}
	for _, joint in root:GetChildren() do
		if joint:IsA("Motor6D") then
			joints[joint.Name] = joint
		end
	end
	local fill, text = healthBar(model, root)
	local entry: Tracked = {
		model = model,
		root = root,
		joints = joints,
		shape = (model:GetAttribute("Shape") :: string?) or "Humanoid",
		last = root.Position,
		phase = math.random() * 10,
		speed = 0,
		bar = fill,
		barText = text,
		dead = false,
	}
	tracked[model] = entry
	updateHealth(entry)
	if model:GetAttribute("Boss") then
		bossModel = model
		bossName.Text = (model:GetAttribute("DisplayName") :: string?) or model.Name
		bossFrame.Visible = true
		Kit.pop(bossFrame, 1.2)
		updateHealth(entry)
	end
	model:GetAttributeChangedSignal("Health"):Connect(function()
		updateHealth(entry)
		-- A quick white flash when hit.
		for _, part in model:GetChildren() do
			if part:IsA("BasePart") and part.Name ~= "Root" and part.Name ~= "Detail" then
				local original = part:GetAttribute("BaseColor") :: Color3?
				if not original then
					part:SetAttribute("BaseColor", part.Color)
					original = part.Color
				end
				part.Color = Color3.new(1, 1, 1)
				TweenService:Create(part, TweenInfo.new(0.12), { Color = original :: Color3 })
					:Play()
			end
		end
	end)
	model:GetAttributeChangedSignal("Dead"):Connect(function()
		if not entry.dead then
			entry.dead = true
			deathBurst(entry)
		end
	end)
	-- Spawn pop: grow in from nothing.
	for _, joint in joints do
		joint.Transform = CFrame.new(0, -root.Size.Y, 0)
	end
	model.Destroying:Connect(function()
		tracked[model] = nil
		if bossModel == model then
			bossModel = nil
			bossFrame.Visible = false
		end
	end)
end

local function animate(dt: number)
	local now = os.clock()
	for model, entry in tracked do
		if entry.dead or not model.Parent then
			continue
		end
		local position = entry.root.Position
		local moved = Vector3.new(position.X - entry.last.X, 0, position.Z - entry.last.Z).Magnitude
		entry.last = position
		local scale = (model:GetAttribute("Scale") :: number?) or 1
		local targetSpeed = if dt > 0 then moved / dt / scale else 0
		entry.speed += (targetSpeed - entry.speed) * math.min(dt * 10, 1)
		local walking = math.clamp(entry.speed / 6, 0, 1)
		entry.phase += dt * (4 + entry.speed * 0.9)
		local swing = math.sin(entry.phase) * 0.75 * walking
		local attackAt = model:GetAttribute("AttackAt") :: number?
		local attack = if attackAt and now - attackAt < 0.3
			then math.sin((now - attackAt) / 0.3 * math.pi)
			else 0
		local joints = entry.joints
		local lerp = math.min(dt * 12, 1)

		local function set(name: string, target: CFrame)
			local joint = joints[name]
			if joint then
				joint.Transform = joint.Transform:Lerp(target, lerp)
			end
		end

		if entry.shape == "Humanoid" or entry.shape == "Brute" then
			local bob = math.abs(math.sin(entry.phase)) * 0.15 * walking
			set("LeftLeg", CFrame.Angles(swing, 0, 0))
			set("RightLeg", CFrame.Angles(-swing, 0, 0))
			set("LeftArm", CFrame.Angles(-swing * 0.4 - attack * 1.2, 0, 0))
			set("RightArm", CFrame.Angles(swing * 0.4 - attack * 1.2, 0, 0))
			set("Torso", CFrame.new(0, bob, 0) * CFrame.Angles(attack * 0.25, 0, 0))
			set(
				"Head",
				CFrame.new(0, bob, 0) * CFrame.Angles(math.sin(now * 2 + entry.phase) * 0.08, 0, 0)
			)
		elseif entry.shape == "Blob" then
			local hop = math.abs(math.sin(entry.phase * 0.8)) * 0.9 * math.max(walking, 0.3)
			set("Torso", CFrame.new(0, hop, 0))
			set(
				"Head",
				CFrame.new(0, hop * 1.2, 0) * CFrame.Angles(0, 0, math.sin(entry.phase) * 0.1)
			)
		elseif entry.shape == "Critter" then
			local fast = math.sin(entry.phase * 2) * 0.9 * walking
			set("LeftLeg", CFrame.Angles(fast, 0, 0))
			set("RightLeg", CFrame.Angles(-fast, 0, 0))
			set("LeftArm", CFrame.Angles(-fast, 0, 0))
			set("RightArm", CFrame.Angles(fast, 0, 0))
			set("Torso", CFrame.new(0, math.abs(fast) * 0.1, 0))
			set("Head", CFrame.Angles(-attack * 0.5, 0, 0))
		else
			set("Torso", CFrame.Angles(now * 3 % (math.pi * 2), 0, 0))
			set("Head", CFrame.new(0, math.sin(now * 2) * 0.2, 0))
			set("LeftLeg", CFrame.Angles(math.sin(now * 3) * 0.3, 0, 0))
		end
	end
end

------------------------------------------------------------------------------------------------
-- Ore pickups
------------------------------------------------------------------------------------------------

local function trackPickup(model: Model)
	if pickups[model] then
		return
	end
	local oreId = model:GetAttribute("OreId")
	local ore = if typeof(oreId) == "string" then Ores.get(oreId) else nil
	pickups[model] = { base = model:GetPivot(), seed = math.random() * 10 }
	if ore and ore.rarity >= 4 then
		-- Rare drops get a tall light beam so they're easy to spot.
		local beam = Instance.new("Part")
		beam.Name = "Beam"
		beam.Anchored = true
		beam.CanCollide = false
		beam.CanQuery = false
		beam.CanTouch = false
		beam.CastShadow = false
		beam.Material = Enum.Material.Neon
		beam.Shape = Enum.PartType.Cylinder
		beam.Color = Rarity.get(ore.rarity).color
		beam.Transparency = 0.55
		beam.Size = Vector3.new(26, 1.2, 1.2)
		beam.CFrame = model:GetPivot() * CFrame.new(0, 13, 0) * CFrame.Angles(0, 0, math.rad(90))
		beam.Parent = model
	end
	model.Destroying:Connect(function()
		pickups[model] = nil
	end)
end

local function animatePickups()
	local now = os.clock()
	for model, info in pickups do
		if model.Parent then
			local offset = CFrame.new(0, math.sin(now * 3 + info.seed) * 0.4 + 0.4, 0)
				* CFrame.Angles(0, now * 1.6 + info.seed, 0)
			local beam = model:FindFirstChild("Beam")
			model:PivotTo(info.base * offset)
			if beam and beam:IsA("BasePart") then
				beam.CFrame = info.base * CFrame.new(0, 13, 0) * CFrame.Angles(0, 0, math.rad(90))
			end
		end
	end
end

------------------------------------------------------------------------------------------------
-- Lobby
------------------------------------------------------------------------------------------------

local function setupStations()
	local lobby = workspace:WaitForChild("Lobby", 30)
	if not lobby then
		return
	end
	local function bind(part: Instance)
		local station = part:GetAttribute("Station")
		if typeof(station) == "string" and part:IsA("BasePart") then
			local info = STATION_MENUS[station]
			if info and not part:FindFirstChild("StationPrompt") then
				local prompt = Instance.new("ProximityPrompt")
				prompt.Name = "StationPrompt"
				prompt.ActionText = info.text
				prompt.ObjectText = ""
				prompt.KeyboardKeyCode = Enum.KeyCode.E
				prompt.HoldDuration = 0
				prompt.MaxActivationDistance = if station == "Forge"
					then 32
					elseif station == "Portal" then 22
					else 16
				prompt.RequiresLineOfSight = false
				prompt.Style = Enum.ProximityPromptStyle.Default
				prompt.Parent = part
				prompt.Triggered:Connect(function()
					Menus.open(info.menu)
				end)
			end
		end
		if part:GetAttribute("Spin") and part:IsA("BasePart") then
			local base = part.CFrame
			local rate = part:GetAttribute("Spin") :: number
			RunService.RenderStepped:Connect(function()
				local t = os.clock()
				part.CFrame = base
					* CFrame.new(0, math.sin(t * 1.5) * 0.6, 0)
					* CFrame.Angles(0, t * rate, 0)
			end)
		end
	end
	lobby.DescendantAdded:Connect(bind)
	for _, part in lobby:GetDescendants() do
		bind(part)
	end
end

local function refreshPadLocks()
	local profile = ClientState.profile
	local lobby = workspace:FindFirstChild("Lobby")
	local training = lobby and lobby:FindFirstChild("Training")
	if not profile or not training then
		return
	end
	for _, zone in training:GetChildren() do
		local index = zone:GetAttribute("Zone")
		local pad = zone:FindFirstChild("Pad")
		local zoneDef = if typeof(index) == "number" then Balance.TRAINING_ZONES[index] else nil
		if pad and zoneDef then
			local unlocked = profile.rebirths >= zoneDef.rebirthsNeeded
			for _, gui in pad:GetChildren() do
				if gui:IsA("BillboardGui") then
					local lock = gui:FindFirstChild("LockLabel") or gui:FindFirstChild("Text")
					if lock and lock.Name == "LockLabel" then
						gui.Enabled = not unlocked
					end
				end
			end
		end
	end
end

------------------------------------------------------------------------------------------------
-- Biome mood
------------------------------------------------------------------------------------------------

type Mood = { atmosphereColor: Color3, atmosphereDecay: Color3, tint: Color3, ambient: Color3 }

local lobbyMood: Mood? = nil
local currentBiome = 0

local function captureLobbyMood()
	local Lighting = game:GetService("Lighting")
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local correction = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if atmosphere and correction then
		lobbyMood = {
			atmosphereColor = atmosphere.Color,
			atmosphereDecay = atmosphere.Decay,
			tint = correction.TintColor,
			ambient = Lighting.OutdoorAmbient,
		}
	end
end

local function applyMood(mood: Mood)
	local Lighting = game:GetService("Lighting")
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local correction = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	local info = TweenInfo.new(1.2, Enum.EasingStyle.Quad)
	if atmosphere then
		TweenService
			:Create(
				atmosphere,
				info,
				{ Color = mood.atmosphereColor, Decay = mood.atmosphereDecay }
			)
			:Play()
	end
	if correction then
		TweenService:Create(correction, info, { TintColor = mood.tint }):Play()
	end
	TweenService:Create(Lighting, info, { OutdoorAmbient = mood.ambient }):Play()
end

-- Each biome tints the fog and light so a new biome feels like a new place.
local function onRun(run: any)
	if not lobbyMood then
		return
	end
	if not run.active then
		currentBiome = 0
		applyMood(lobbyMood)
		return
	end
	local index = run.biome or 1
	if index == currentBiome then
		return
	end
	currentBiome = index
	local biome = Biomes.List[index]
	if not biome then
		return
	end
	applyMood({
		atmosphereColor = biome.fogColor,
		atmosphereDecay = biome.fogColor:Lerp(Color3.new(0, 0, 0), 0.35),
		tint = Color3.new(1, 1, 1):Lerp(biome.fogColor, 0.18),
		ambient = biome.ambient,
	})
end

------------------------------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------------------------------

function WorldFx:Init()
	bossGui = Kit.new("ScreenGui", {
		Name = "BossBar",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		Parent = player:WaitForChild("PlayerGui"),
	})
	bossFrame = Kit.new("Frame", {
		Size = UDim2.fromScale(0.42, 0.075),
		Position = UDim2.fromScale(0.5, 0.135),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = bossGui,
	})
	Kit.new("UISizeConstraint", { MaxSize = Vector2.new(620, 80), Parent = bossFrame })
	bossName = Kit.text({
		Text = "Boss",
		Size = UDim2.fromScale(1, 0.45),
		TextColor3 = Color3.fromRGB(255, 130, 120),
		Stroke = 3,
		Parent = bossFrame,
	})
	local back = Kit.new("Frame", {
		Size = UDim2.fromScale(1, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		BackgroundColor3 = Kit.Colors.Ink,
		Parent = bossFrame,
	})
	Kit.cornerScale(0.5).Parent = back
	Kit.stroke(3, Kit.Colors.Ink, Enum.ApplyStrokeMode.Border).Parent = back
	bossFill = Kit.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(235, 50, 70),
		BorderSizePixel = 0,
		Parent = back,
	})
	Kit.cornerScale(0.5).Parent = bossFill
	Kit.gradient(Color3.fromRGB(255, 110, 110), Color3.fromRGB(200, 30, 60)).Parent = bossFill
	bossHp = Kit.text({
		Text = "",
		Size = UDim2.fromScale(0.95, 0.8),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 3,
		Parent = back,
	})
end

function WorldFx:Start()
	task.spawn(setupStations)
	local arenas = workspace:WaitForChild("Arenas", 30)
	if arenas then
		arenas.DescendantAdded:Connect(function(instance)
			if instance:IsA("Model") then
				local model: Model = instance
				-- Attributes arrive with the instance, but give the children a frame to replicate.
				task.defer(function()
					if model:GetAttribute("EnemyId") then
						track(model)
					elseif model:GetAttribute("OrePickup") then
						trackPickup(model)
					end
				end)
			end
		end)
	end
	RunService.RenderStepped:Connect(function(dt)
		animate(dt)
		animatePickups()
	end)
	ClientState.StatsChanged:Connect(refreshPadLocks)
	captureLobbyMood()
	ClientState.RunChanged:Connect(onRun)
end

return WorldFx
