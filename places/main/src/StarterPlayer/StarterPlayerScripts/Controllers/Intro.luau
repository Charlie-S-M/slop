--!strict

--[[
	The intro screen shown when a player joins: a sunburst behind a 3D anvil whose hammer keeps
	striking, the game's title, a loading bar that follows the asset preload, and rotating tips.
	A click or tap skips it once loading has had a moment.
]]

const ContentProvider = game:GetService("ContentProvider")
const MarketplaceService = game:GetService("MarketplaceService")
const Players = game:GetService("Players")
const RunService = game:GetService("RunService")
const TweenService = game:GetService("TweenService")
const UserInputService = game:GetService("UserInputService")

const Kit = require("./UI/Kit")

local Intro = {}

const MIN_SECONDS = 3.5
const MAX_SECONDS = 9
const TIPS = {
	"Clear every monster in a stage to open the next door",
	"Forge new guns from the ores you bring back",
	"Pets boost your ore drops, training, and damage",
	"Rebirth to trade your Power for permanent boosts",
	"Stand on a training pad to grow your Power",
	"Climb the Infinite Tower to defend the crystal",
	"Finish quests to rank up and earn chests",
}
const STUD_COLOR = Color3.fromRGB(150, 150, 158)

local function brick(parent: Instance, size: Vector3, at: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.Size = size
	part.CFrame = at
	part.Color = color
	part.TopSurface = Enum.SurfaceType.Studs
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = parent
	return part
end

-- A studded anvil with glowing metal on top and a hammer that swings down onto it.
local function buildAnvil(viewport: ViewportFrame): (Model, CFrame)
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	local anvil = Instance.new("Model")
	anvil.Parent = world
	brick(anvil, Vector3.new(5, 1.2, 3.2), CFrame.new(0, 0.6, 0), Color3.fromRGB(110, 110, 118))
	brick(anvil, Vector3.new(3, 2, 2), CFrame.new(0, 2.2, 0), Color3.fromRGB(120, 120, 128))
	brick(anvil, Vector3.new(7, 1.4, 2.6), CFrame.new(0.4, 3.9, 0), STUD_COLOR)
	brick(anvil, Vector3.new(2, 1, 1.6), CFrame.new(4.6, 3.9, 0), STUD_COLOR)
	local metal = brick(
		anvil,
		Vector3.new(3.6, 0.3, 0.8),
		CFrame.new(-0.2, 4.75, 0),
		Color3.fromRGB(255, 200, 60)
	)
	metal.Material = Enum.Material.Neon
	local hammer = Instance.new("Model")
	hammer.Parent = world
	local head = brick(
		hammer,
		Vector3.new(1.6, 2.4, 1.6),
		CFrame.new(0, 0, 0),
		Color3.fromRGB(140, 140, 150)
	)
	brick(hammer, Vector3.new(4.6, 0.5, 0.5), CFrame.new(2.9, 0, 0), Color3.fromRGB(130, 85, 50))
	brick(hammer, Vector3.new(0.9, 0.7, 0.7), CFrame.new(5.4, 0, 0), Color3.fromRGB(40, 40, 46))
	hammer.PrimaryPart = head
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.CFrame = CFrame.lookAt(Vector3.new(4, 9, 15), Vector3.new(0.6, 4, 0))
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	-- The hammer hinges at its handle's end; at angle 0 its head rests on the glowing metal.
	return hammer, CFrame.new(5.2, 5.95, 0)
end

-- Thin translucent rays around the screen's center; the whole fan turns slowly.
local function buildRays(parent: Instance): Frame
	local fan = Kit.new("Frame", {
		Name = "Rays",
		Size = UDim2.fromScale(2.4, 2.4),
		Position = UDim2.fromScale(0.5, 0.42),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	Kit.aspect(1).Parent = fan
	for index = 1, 12 do
		local ray = Kit.new("Frame", {
			Size = UDim2.fromScale(0.05, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = index * 15,
			BackgroundColor3 = Color3.fromRGB(255, 236, 190),
			BackgroundTransparency = 0.72,
			BorderSizePixel = 0,
			Parent = fan,
		})
		Kit.new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Rotation = 90,
			Parent = ray,
		})
	end
	return fan
end

local function title(): string
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(game.PlaceId)
	end)
	local name = if ok
			and typeof(info) == "table"
			and typeof(info.Name) == "string"
		then info.Name
		else "Gun Exponential!"
	-- Drop build tags like "(ALPHA)" and the "2D" prefix from the shown title.
	name = name:gsub("%s*%b()", ""):gsub("^2D%s+", "")
	return name
end

function Intro:Start()
	local screen = Kit.new("ScreenGui", {
		Name = "Intro",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 100,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	local root = Kit.new("CanvasGroup", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(255, 150, 60),
		Parent = screen,
	})
	Kit.new("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(255, 170, 70), Color3.fromRGB(190, 50, 40)),
		Rotation = 90,
		Parent = root,
	})
	local fan = buildRays(root)
	local viewport = Kit.new("ViewportFrame", {
		Size = UDim2.fromScale(0.42, 0.5),
		Position = UDim2.fromScale(0.5, 0.33),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(200, 190, 180),
		LightColor = Color3.fromRGB(255, 235, 200),
		Parent = root,
	}) :: ViewportFrame
	local hammer, pivot = buildAnvil(viewport)
	hammer:PivotTo(pivot * CFrame.new(-5.4, 0, 0))
	local heading = Kit.text({
		Text = "Gun Exponential!",
		Size = UDim2.fromScale(0.7, 0.1),
		Position = UDim2.fromScale(0.5, 0.6),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Stroke = 5,
		StrokeColor = Color3.fromRGB(70, 30, 20),
		Parent = root,
	})
	-- The experience's own name replaces the stand-in once it arrives; the lookup yields.
	task.spawn(function()
		heading.Text = title()
	end)
	local status = Kit.text({
		Text = "Loading guns...",
		Size = UDim2.fromScale(0.4, 0.05),
		Position = UDim2.fromScale(0.5, 0.71),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Stroke = 3,
		Parent = root,
	})
	local track = Kit.new("Frame", {
		Size = UDim2.fromScale(0.5, 0.062),
		Position = UDim2.fromScale(0.5, 0.79),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(90, 30, 25),
		Parent = root,
	})
	Kit.cornerScale(0.5).Parent = track
	Kit.stroke(3, Color3.fromRGB(255, 240, 220), Enum.ApplyStrokeMode.Border).Parent = track
	local fill = Kit.new("Frame", {
		Size = UDim2.fromScale(0.02, 1),
		BackgroundColor3 = Color3.fromRGB(255, 210, 80),
		Parent = track,
	})
	Kit.cornerScale(0.5).Parent = fill
	Kit.gradient(Color3.fromRGB(255, 235, 150), Color3.fromRGB(255, 180, 50)).Parent = fill
	local percent = Kit.text({
		Text = "0%",
		Size = UDim2.fromScale(0.3, 0.7),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 3,
		Stroke = 2.5,
		Parent = track,
	})
	local tip = Kit.text({
		Text = `Tip: {TIPS[math.random(#TIPS)]}`,
		Size = UDim2.fromScale(0.7, 0.05),
		Position = UDim2.fromScale(0.5, 0.87),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Stroke = 3,
		Parent = root,
	})
	local skipHint = Kit.text({
		Text = "Click anywhere to skip",
		Size = UDim2.fromScale(0.4, 0.045),
		Position = UDim2.fromScale(0.5, 0.95),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextColor3 = Color3.fromRGB(255, 225, 210),
		TextTransparency = 0.3,
		Stroke = 2,
		Parent = root,
	})

	local started = os.clock()
	local done = false
	local loaded = 0
	local total = 1
	task.spawn(function()
		local assets = game:GetService("ReplicatedStorage"):GetDescendants()
		total = math.max(#assets, 1)
		pcall(function()
			ContentProvider:PreloadAsync(assets, function()
				loaded += 1
			end)
		end)
		loaded = total
	end)

	local function finish()
		if done then
			return
		end
		done = true
		local out = TweenService:Create(root, Kit.SMOOTH, { GroupTransparency = 1 })
		out.Completed:Once(function()
			screen:Destroy()
		end)
		out:Play()
	end
	UserInputService.InputBegan:Connect(function(input)
		if
			not done
			and os.clock() - started > 0.6
			and (
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			finish()
		end
	end)

	local tipTimer = 0
	local ready = false
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function(dt: number)
		if done then
			connection:Disconnect()
			return
		end
		local elapsed = os.clock() - started
		fan.Rotation = (fan.Rotation + dt * 8) % 360
		-- The hammer lifts and slams down about once a second.
		local swing = (elapsed * 1.1) % 1
		local angle = if swing < 0.75
			then math.rad(-35 * math.sin(swing / 0.75 * math.pi / 2))
			else math.rad(-35 * (1 - (swing - 0.75) / 0.25))
		hammer:PivotTo(pivot * CFrame.Angles(0, 0, angle) * CFrame.new(-5.4, 0, 0))
		skipHint.TextTransparency = 0.3 + 0.25 * math.sin(elapsed * 3)
		-- The bar follows the preload but never finishes before the minimum time.
		local share = math.min(loaded / total, elapsed / MIN_SECONDS)
		if elapsed > MAX_SECONDS then
			share = 1
		end
		fill.Size = UDim2.fromScale(math.max(share, 0.02), 1)
		percent.Text = `{math.floor(share * 100)}%`
		tipTimer += dt
		if tipTimer > 3 then
			tipTimer = 0
			tip.Text = `Tip: {TIPS[math.random(#TIPS)]}`
		end
		if share >= 1 and not ready then
			ready = true
			status.Text = "Ready!"
			task.delay(0.35, finish)
		end
	end)
end

return Intro
