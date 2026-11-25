--!strict

--[[
	Feedback effects: floating damage numbers, "+power" popups, ores and coins flying into the HUD,
	toasts, level-up and rebirth celebrations, and enemy attack visuals.
]]

const Players = game:GetService("Players")
const TweenService = game:GetService("TweenService")

const Format = require("@game/ReplicatedStorage/Shared/Format")
const Net = require("@game/ReplicatedStorage/Shared/Net")
const Ores = require("@game/ReplicatedStorage/Shared/Ores")
const Rarity = require("@game/ReplicatedStorage/Shared/Rarity")
const Upgrades = require("@game/ReplicatedStorage/Shared/Upgrades")
const ClientState = require("./ClientState")
const GunController = require("./GunController")
const Hud = require("./Hud")
const Kit = require("./UI/Kit")

local Effects = {}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local screen: ScreenGui
local toastHolder: Frame
local anchorPart: Part
local activeNumbers = 0

const MAX_NUMBERS = 36

------------------------------------------------------------------------------------------------
-- World-space numbers
------------------------------------------------------------------------------------------------

function Effects.worldText(
	position: Vector3,
	text: string,
	color: Color3,
	size: number,
	rise: number?
)
	if activeNumbers >= MAX_NUMBERS then
		return
	end
	activeNumbers += 1
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position
		+ Vector3.new(math.random() * 2 - 1, math.random() * 1.5, math.random() * 2 - 1)
	attachment.Parent = anchorPart
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(size * 2.4, size)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 250
	gui.Adornee = attachment
	gui.Parent = attachment
	local label = Kit.text({
		Text = text,
		TextColor3 = color,
		Stroke = 3,
		Parent = gui,
	})
	local scale = Instance.new("UIScale")
	scale.Scale = 0.3
	scale.Parent = label
	TweenService:Create(scale, Kit.BOUNCY, { Scale = 1 }):Play()
	TweenService:Create(gui, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffsetWorldSpace = Vector3.new(0, rise or 4, 0),
	}):Play()
	task.delay(0.55, function()
		TweenService:Create(label, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
		local stroke = label:FindFirstChildOfClass("UIStroke")
		if stroke then
			TweenService:Create(stroke, TweenInfo.new(0.35), { Transparency = 1 }):Play()
		end
	end)
	task.delay(0.95, function()
		attachment:Destroy()
		activeNumbers -= 1
	end)
end

------------------------------------------------------------------------------------------------
-- Screen popups
------------------------------------------------------------------------------------------------

local pendingPower = 0
local powerFlushQueued = false

local function popupAt(
	screenPosition: UDim2,
	text: string,
	color: Color3,
	height: number,
	rotation: number
)
	local label = Kit.text({
		Text = text,
		TextColor3 = color,
		Size = UDim2.fromScale(0.22, height),
		Position = screenPosition,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = rotation,
		Stroke = 4,
		Gradient = false,
		ZIndex = 20,
		Parent = screen,
	})
	Kit.gradient(Color3.fromRGB(255, 245, 150), color).Parent = label
	local scale = Instance.new("UIScale")
	scale.Scale = 0.2
	scale.Parent = label
	TweenService:Create(scale, Kit.BOUNCY, { Scale = 1 }):Play()
	TweenService:Create(label, TweenInfo.new(1, Enum.EasingStyle.Quad), {
		Position = screenPosition - UDim2.fromScale(0, 0.08),
	}):Play()
	task.delay(0.6, function()
		TweenService:Create(label, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
		local stroke = label:FindFirstChildOfClass("UIStroke")
		if stroke then
			TweenService:Create(stroke, TweenInfo.new(0.35), { Transparency = 1 }):Play()
		end
	end)
	task.delay(1, function()
		label:Destroy()
	end)
end

-- Training gains pile up for a moment and pop as one big number somewhere around the screen.
function Effects.powerGain(amount: number)
	pendingPower += amount
	if powerFlushQueued then
		return
	end
	powerFlushQueued = true
	task.delay(0.09, function()
		powerFlushQueued = false
		local total = pendingPower
		pendingPower = 0
		local x = 0.5 + (math.random() - 0.5) * 0.55
		local y = 0.3 + math.random() * 0.4
		popupAt(
			UDim2.fromScale(x, y),
			`+{Format.abbreviate(total)}`,
			Color3.fromRGB(255, 130, 30),
			0.09,
			(math.random() - 0.5) * 16
		)
		Hud.flashPower()
	end)
end

--[[
	Flies a glyph from a world position into a HUD element, then pops the element. Used for ores
	going into the bag and coins going into the purse.
]]
local function flyToHud(
	from: Vector3,
	glyph: string,
	target: Vector2,
	color: Color3,
	onArrive: () -> ()
)
	local point, onScreen = camera:WorldToViewportPoint(from)
	local start = if onScreen then Vector2.new(point.X, point.Y) else camera.ViewportSize / 2
	local icon = Kit.iconTile(glyph, color, UDim2.fromOffset(44, 44), screen)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromOffset(start.X, start.Y)
	icon.ZIndex = 30
	local tween = TweenService:Create(
		icon,
		TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{
			Position = UDim2.fromOffset(target.X, target.Y),
			Size = UDim2.fromOffset(26, 26),
		}
	)
	tween:Play()
	tween.Completed:Once(function()
		icon:Destroy()
		onArrive()
	end)
end

------------------------------------------------------------------------------------------------
-- Toasts and banners
------------------------------------------------------------------------------------------------

function Effects.toast(text: string, color: Color3?)
	local frame = Kit.new("Frame", {
		Size = UDim2.fromScale(1, 0.3),
		BackgroundColor3 = Kit.Colors.Ink,
		BackgroundTransparency = 0.25,
		Parent = toastHolder,
	})
	Kit.cornerScale(0.5).Parent = frame
	Kit.text({
		Text = text,
		TextColor3 = color or Kit.Colors.White,
		Size = UDim2.fromScale(0.94, 0.75),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Stroke = 2.5,
		Parent = frame,
	})
	Kit.pop(frame, 1.15)
	task.delay(3, function()
		TweenService:Create(frame, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
		for _, child in frame:GetDescendants() do
			if child:IsA("TextLabel") then
				TweenService:Create(child, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
			elseif child:IsA("UIStroke") then
				TweenService:Create(child, TweenInfo.new(0.3), { Transparency = 1 }):Play()
			end
		end
		task.wait(0.32)
		frame:Destroy()
	end)
end

-- A big centered banner, for level ups, rebirths, and stage clears.
function Effects.banner(text: string, top: Color3, bottom: Color3, subtitle: string?)
	local holder = Kit.new("Frame", {
		Size = UDim2.fromScale(0.6, 0.16),
		Position = UDim2.fromScale(0.5, 0.36),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 40,
		Parent = screen,
	})
	local title = Kit.text({
		Text = text,
		Size = UDim2.fromScale(1, if subtitle then 0.72 else 1),
		Stroke = 5,
		Gradient = false,
		ZIndex = 41,
		Parent = holder,
	})
	Kit.gradient(top, bottom).Parent = title
	if subtitle then
		Kit.text({
			Text = subtitle,
			Size = UDim2.fromScale(0.8, 0.3),
			Position = UDim2.fromScale(0.5, 0.72),
			AnchorPoint = Vector2.new(0.5, 0),
			Stroke = 3,
			ZIndex = 41,
			Parent = holder,
		})
	end
	local scale = Instance.new("UIScale")
	scale.Scale = 0.2
	scale.Parent = holder
	TweenService:Create(scale, TweenInfo.new(0.45, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(1.6, function()
		TweenService:Create(
			scale,
			TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In),
			{ Scale = 0 }
		):Play()
		task.wait(0.27)
		holder:Destroy()
	end)
end

-- Colored confetti bursting from the middle of the screen.
function Effects.confetti(colors: { Color3 }, count: number)
	for _ = 1, count do
		local piece = Kit.new("Frame", {
			Size = UDim2.fromOffset(math.random(8, 16), math.random(12, 22)),
			Position = UDim2.fromScale(0.5, 0.4),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = colors[math.random(1, #colors)],
			Rotation = math.random(0, 360),
			ZIndex = 35,
			Parent = screen,
		})
		local angle = math.random() * math.pi * 2
		local distance = 0.2 + math.random() * 0.4
		local target = UDim2.fromScale(
			0.5 + math.cos(angle) * distance,
			0.4 + math.sin(angle) * distance * 0.8 + 0.25
		)
		TweenService
			:Create(piece, TweenInfo.new(1.2 + math.random() * 0.5, Enum.EasingStyle.Quad), {
				Position = target,
				Rotation = piece.Rotation + math.random(-360, 360),
				BackgroundTransparency = 1,
			})
			:Play()
		task.delay(1.8, function()
			piece:Destroy()
		end)
	end
end

local function screenFlash(color: Color3)
	local flash = Kit.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.35,
		ZIndex = 50,
		Parent = screen,
	})
	TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
	task.delay(0.55, function()
		flash:Destroy()
	end)
end

-- Red edges around the screen when the player is hit. One set of edges is reused, so many hits in
-- a row deepen the red a little instead of stacking full-screen flashes.
local hurtEdges: { Frame } = {}

local function hurtVignette()
	if #hurtEdges == 0 then
		local sides = {
			{ UDim2.fromScale(1, 0.13), UDim2.fromScale(0, 0), 90 },
			{ UDim2.fromScale(1, 0.13), UDim2.fromScale(0, 0.87), -90 },
			{ UDim2.fromScale(0.09, 1), UDim2.fromScale(0, 0), 0 },
			{ UDim2.fromScale(0.09, 1), UDim2.fromScale(0.91, 0), 180 },
		}
		for _, side in sides do
			local edge = Kit.new("Frame", {
				Size = side[1],
				Position = side[2],
				BackgroundColor3 = Color3.fromRGB(255, 30, 40),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = 45,
				Parent = screen,
			})
			Kit.new("UIGradient", {
				Transparency = NumberSequence.new(0, 1),
				Rotation = side[3],
				Parent = edge,
			})
			table.insert(hurtEdges, edge)
		end
	end
	for _, edge in hurtEdges do
		edge.BackgroundTransparency = math.max(0.5, edge.BackgroundTransparency - 0.3)
		TweenService
			:Create(edge, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 })
			:Play()
	end
end

------------------------------------------------------------------------------------------------
-- Enemy attacks
------------------------------------------------------------------------------------------------

local function projectile(from: Vector3, to: Vector3, travel: number, color: Color3, size: number)
	local ball = Instance.new("Part")
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.CastShadow = false
	ball.Material = Enum.Material.Neon
	ball.Shape = Enum.PartType.Ball
	ball.Color = color
	ball.Size = Vector3.one * size
	ball.Position = from
	ball.Parent = GunController.effects()
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = size * 4
	light.Parent = ball
	-- A warning ring where it will land.
	local marker = Instance.new("Part")
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.Material = Enum.Material.Neon
	marker.Shape = Enum.PartType.Cylinder
	marker.Color = Color3.fromRGB(255, 70, 70)
	marker.Transparency = 0.5
	marker.Size = Vector3.new(0.2, 1, 1)
	marker.CFrame = CFrame.new(to.X, to.Y - 2.8, to.Z) * CFrame.Angles(0, 0, math.rad(90))
	marker.Parent = GunController.effects()
	TweenService
		:Create(
			marker,
			TweenInfo.new(travel),
			{ Size = Vector3.new(0.2, 7, 7), Transparency = 0.2 }
		)
		:Play()
	-- An arc: rise a little in the middle of the flight.
	local start = os.clock()
	local connection: RBXScriptConnection
	connection = game:GetService("RunService").RenderStepped:Connect(function()
		local t = math.clamp((os.clock() - start) / travel, 0, 1)
		local arc = math.sin(t * math.pi) * math.min((to - from).Magnitude * 0.12, 10)
		ball.Position = from:Lerp(to, t) + Vector3.new(0, arc, 0)
		if t >= 1 then
			connection:Disconnect()
			ball:Destroy()
			marker:Destroy()
			local splash = Instance.new("Part")
			splash.Anchored = true
			splash.CanCollide = false
			splash.CanQuery = false
			splash.Material = Enum.Material.Neon
			splash.Shape = Enum.PartType.Ball
			splash.Color = color
			splash.Size = Vector3.one * size
			splash.Position = to
			splash.Parent = GunController.effects()
			TweenService:Create(
				splash,
				TweenInfo.new(0.25),
				{ Size = Vector3.one * size * 4, Transparency = 1 }
			):Play()
			task.delay(0.3, function()
				splash:Destroy()
			end)
		end
	end)
end

local function onEnemyAttack(info: any)
	if info.kind == "projectile" then
		projectile(info.from, info.to, info.time, info.color, info.size)
	elseif info.kind == "melee" then
		local model = info.enemy
		if typeof(model) == "Instance" and model:IsA("Model") then
			model:SetAttribute("AttackAt", os.clock())
		end
	end
end

------------------------------------------------------------------------------------------------
-- Rewards
------------------------------------------------------------------------------------------------

local function onReward(info: any)
	if info.kind == "kill" then
		local position: Vector3 = info.position
		if info.boss then
			Effects.banner(
				"BOSS DEFEATED!",
				Color3.fromRGB(255, 240, 120),
				Color3.fromRGB(255, 120, 40),
				info.name
			)
			Effects.confetti({ Kit.Colors.Gold, Kit.Colors.Orange, Kit.Colors.White }, 60)
			Kit.sound(Kit.Sounds.Boom, 0.5)
		end
		Effects.worldText(
			position,
			`+{Format.abbreviate(info.coins)} 💰`,
			Color3.fromRGB(255, 215, 60),
			1.6,
			6
		)
		Kit.sound(Kit.Sounds.Coin, 0.25, 1.1)
		Hud.flashCoins()
	elseif info.kind == "ore" then
		local ore = Ores.get(info.oreId)
		if not ore then
			return
		end
		local rarity = Rarity.get(ore.rarity)
		Kit.sound(Kit.Sounds.Pop, 0.4, 1 + ore.rarity * 0.05)
		flyToHud(info.position, "💎", Hud.bagTarget(), ore.color, function()
			Hud.flashBag()
		end)
		Effects.worldText(
			info.position + Vector3.new(0, 2, 0),
			`+1 {ore.name}`,
			rarity.color:Lerp(Color3.new(1, 1, 1), 0.2),
			1.5,
			5
		)
		if info.new then
			Effects.toast(`New ore discovered: {ore.name}!`, rarity.color)
		end
	elseif info.kind == "coins" then
		Kit.sound(Kit.Sounds.CoinRetro, 0.4)
		popupAt(
			UDim2.fromScale(0.5, 0.6),
			`+{Format.abbreviate(info.coins)} 💰`,
			Color3.fromRGB(255, 200, 40),
			0.08,
			0
		)
		Hud.flashCoins()
	elseif info.kind == "upgrade" then
		Kit.sound(Kit.Sounds.Surge, 0.4)
		local def = Upgrades.get(info.id)
		if def then
			Effects.toast(`{def.name} → level {info.level}`, def.color)
		end
	elseif info.kind == "rebirth" then
		Kit.sound(Kit.Sounds.Surge, 0.6, 0.7)
		Kit.sound(Kit.Sounds.Ding, 0.5)
		screenFlash(Color3.fromRGB(190, 120, 255))
		Effects.banner(
			"REBIRTH!",
			Color3.fromRGB(240, 190, 255),
			Color3.fromRGB(150, 70, 255),
			`Rebirth {info.rebirths} · More damage and a new training pad`
		)
		Effects.confetti(
			{ Kit.Colors.Purple, Kit.Colors.Pink, Kit.Colors.Teal, Kit.Colors.White },
			90
		)
	elseif info.kind == "daily" then
		Kit.sound(Kit.Sounds.Ding, 0.5)
		Effects.banner(
			"DAILY REWARD!",
			Color3.fromRGB(190, 255, 150),
			Color3.fromRGB(60, 200, 80),
			`+{Format.abbreviate(info.coins)} coins · +{info.ores} ores · Streak {info.streak}`
		)
		Effects.confetti({ Kit.Colors.Green, Kit.Colors.Gold, Kit.Colors.White }, 50)
	end
end

function Effects:Init()
	screen = Kit.new("ScreenGui", {
		Name = "Effects",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 20,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	toastHolder = Kit.new("Frame", {
		Name = "Toasts",
		Size = UDim2.fromScale(0.36, 0.16),
		Position = UDim2.fromScale(0.5, 0.15),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Parent = screen,
	})
	Kit.new("UISizeConstraint", { MaxSize = Vector2.new(560, 150), Parent = toastHolder })
	Kit.new("UIListLayout", {
		Padding = UDim.new(0.04, 0),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = toastHolder,
	})

	anchorPart = Instance.new("Part")
	anchorPart.Name = "EffectAnchor"
	anchorPart.Anchored = true
	anchorPart.CanCollide = false
	anchorPart.CanQuery = false
	anchorPart.CanTouch = false
	anchorPart.Transparency = 1
	anchorPart.Size = Vector3.one
	anchorPart.CFrame = CFrame.new()
	anchorPart.Parent = workspace
end

function Effects:Start()
	Net.unreliable("HitFx").OnClientEvent
		:Connect(function(position: Vector3, amount: number, crit: boolean, killed: boolean)
			local color = if crit
				then Color3.fromRGB(255, 80, 60)
				elseif killed then Color3.fromRGB(255, 220, 80)
				else Color3.fromRGB(255, 255, 255)
			local text = Format.abbreviate(amount) .. (if crit then "!" else "")
			Effects.worldText(position, text, color, if crit then 2.2 else 1.6)
		end)
	Net.unreliable("TrainFx").OnClientEvent:Connect(function(amount: number)
		Effects.powerGain(amount)
	end)
	Net.event("Notify").OnClientEvent:Connect(function(text: string, color: Color3?)
		Effects.toast(text, color)
		Kit.sound(Kit.Sounds.Error, 0.2)
	end)
	Net.event("EnemyAttack").OnClientEvent:Connect(onEnemyAttack)
	-- Any drop in health, from a melee swing or a projectile, reddens the screen edges.
	local function watchHealth(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
		if not humanoid then
			return
		end
		local last = humanoid.Health
		humanoid.HealthChanged:Connect(function(health)
			if health < last - 0.5 then
				hurtVignette()
			end
			last = health
		end)
	end
	player.CharacterAdded:Connect(watchHealth)
	if player.Character then
		task.spawn(watchHealth, player.Character)
	end
	Net.event("Reward").OnClientEvent:Connect(onReward)
	ClientState.LeveledUp:Connect(function(level)
		Kit.sound(Kit.Sounds.Ding, 0.35, 1.2)
		Effects.banner(
			`LEVEL {level}!`,
			Color3.fromRGB(255, 240, 140),
			Color3.fromRGB(255, 150, 40),
			"+2% damage · more health"
		)
	end)
	local lastStage = 0
	ClientState.RunChanged:Connect(function(run)
		if run.cleared then
			Kit.sound(Kit.Sounds.Ding, 0.4)
			Effects.banner(
				"CLEAR!",
				Color3.fromRGB(170, 255, 140),
				Color3.fromRGB(60, 200, 80),
				`Stage {run.stage + 1} next`
			)
		elseif run.active and run.state == "fighting" and run.stage ~= lastStage then
			lastStage = run.stage
			if run.isBoss then
				Kit.sound(Kit.Sounds.Boom, 0.4, 0.8)
				Effects.banner(
					`BOSS: {run.bossName or "???"}`,
					Color3.fromRGB(255, 150, 150),
					Color3.fromRGB(220, 40, 60),
					`Stage {run.stage}`
				)
			end
		elseif not run.active then
			lastStage = 0
		end
	end)
end

return Effects
