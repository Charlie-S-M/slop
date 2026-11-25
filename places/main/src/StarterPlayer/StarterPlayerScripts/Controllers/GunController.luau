--!strict

--[[
	Fires the equipped gun. Holding the trigger (mouse, touch, or gamepad) or turning on Auto fires
	at the gun's rate; each shot raycasts from the camera, tells the server what it hit, and plays
	the tracer, muzzle flash, recoil, and sound locally right away.
]]

const Players = game:GetService("Players")
const RunService = game:GetService("RunService")
const TweenService = game:GetService("TweenService")
const UserInputService = game:GetService("UserInputService")

const Balance = require("@game/ReplicatedStorage/Shared/Balance")
const GunBuilder = require("@game/ReplicatedStorage/Shared/GunBuilder")
const Guns = require("@game/ReplicatedStorage/Shared/Guns")
const Net = require("@game/ReplicatedStorage/Shared/Net")
const Rarity = require("@game/ReplicatedStorage/Shared/Rarity")
const ClientState = require("./ClientState")
const Hud = require("./Hud")
const Kit = require("./UI/Kit")
const Menus = require("./Menus")

const RANGE = 400
const AUTO_RANGE = 170

local GunController = {}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local tool: Tool? = nil
local triggerHeld = false
local nextShot = 0
local ammo = 0
local magazine = 0
local reloadUntil = 0
local burstCount = 0
local recoil = 0
local aimScreen: Vector2? = nil
local effectsFolder: Folder
local shootRemote: RemoteEvent
local reloadRemote: RemoteEvent
local random = Random.new()

------------------------------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------------------------------

local function currentGun(): (Guns.GunDef?, Guns.KindStats?)
	local _, def = ClientState.equipped()
	if not def then
		return nil, nil
	end
	return def, Guns.kindStats(def.kind)
end

local function rayParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { effectsFolder }
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	return params
end

local function isEnemyPart(instance: Instance): boolean
	local current: Instance? = instance
	for _ = 1, 4 do
		if not current then
			return false
		end
		if current:IsA("Model") and current:GetAttribute("EnemyId") ~= nil then
			return current:GetAttribute("Dead") ~= true
		end
		current = current.Parent
	end
	return false
end

local function isTrainingPart(instance: Instance): boolean
	local current: Instance? = instance
	for _ = 1, 3 do
		if not current then
			return false
		end
		if current:IsA("Model") and current:GetAttribute("TrainingTarget") then
			return true
		end
		current = current.Parent
	end
	return false
end

local function muzzlePosition(): Vector3?
	if not tool then
		return nil
	end
	local muzzle = GunBuilder.muzzleOf(tool)
	return if muzzle then muzzle.WorldPosition else nil
end

------------------------------------------------------------------------------------------------
-- Auto aim
------------------------------------------------------------------------------------------------

-- The nearest living enemy in the player's own run, or the target of the pad they stand on.
local function autoTarget(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	if player:GetAttribute("InRun") then
		local best: BasePart? = nil
		local bestDistance = AUTO_RANGE
		local arenas = workspace:FindFirstChild("Arenas")
		if not arenas then
			return nil
		end
		for _, arena in arenas:GetChildren() do
			local runFolder = arena:FindFirstChild(`Run_{player.UserId}`)
			if runFolder then
				for _, enemy in runFolder:GetChildren() do
					if
						enemy:IsA("Model")
						and enemy:GetAttribute("EnemyId")
						and not enemy:GetAttribute("Dead")
					then
						local body = enemy:FindFirstChild("Torso")
							or enemy:FindFirstChild("Head")
							or enemy.PrimaryPart
						if body and body:IsA("BasePart") then
							local distance = (body.Position - root.Position).Magnitude
							if distance < bestDistance then
								bestDistance = distance
								best = body
							end
						end
					end
				end
			end
		end
		return best
	end
	local lobby = workspace:FindFirstChild("Lobby")
	local training = lobby and lobby:FindFirstChild("Training")
	if not training then
		return nil
	end
	local profile = ClientState.profile
	for _, zone in training:GetChildren() do
		local pad = zone:FindFirstChild("Pad")
		local target = zone:FindFirstChild("Target")
		local index = zone:GetAttribute("Zone")
		if pad and pad:IsA("BasePart") and target and typeof(index) == "number" then
			local offset = root.Position - pad.Position
			local zoneDef = Balance.TRAINING_ZONES[index]
			if
				Vector3.new(offset.X, 0, offset.Z).Magnitude <= 12
				and profile
				and zoneDef
				and profile.rebirths >= zoneDef.rebirthsNeeded
			then
				local board = target:FindFirstChild("Board")
				return if board and board:IsA("BasePart") then board else nil
			end
		end
	end
	return nil
end

------------------------------------------------------------------------------------------------
-- Effects
------------------------------------------------------------------------------------------------

local function tracer(from: Vector3, to: Vector3, color: Color3, width: number)
	local length = (to - from).Magnitude
	if length < 0.5 then
		return
	end
	local beam = Instance.new("Part")
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.CastShadow = false
	beam.Material = Enum.Material.Neon
	beam.Color = color
	beam.Size = Vector3.new(width, width, length)
	beam.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -length / 2)
	beam.Parent = effectsFolder
	TweenService:Create(
		beam,
		TweenInfo.new(0.12),
		{ Transparency = 1, Size = Vector3.new(width * 0.2, width * 0.2, length) }
	):Play()
	task.delay(0.14, function()
		beam:Destroy()
	end)
end

local function impact(position: Vector3, color: Color3, size: number)
	local burst = Instance.new("Part")
	burst.Anchored = true
	burst.CanCollide = false
	burst.CanQuery = false
	burst.CanTouch = false
	burst.CastShadow = false
	burst.Material = Enum.Material.Neon
	burst.Shape = Enum.PartType.Ball
	burst.Color = color
	burst.Size = Vector3.one * size * 0.4
	burst.Position = position
	burst.Parent = effectsFolder
	TweenService:Create(
		burst,
		TweenInfo.new(0.16, Enum.EasingStyle.Quad),
		{ Size = Vector3.one * size, Transparency = 1 }
	):Play()
	task.delay(0.18, function()
		burst:Destroy()
	end)
end

local function explosion(position: Vector3, radius: number, color: Color3)
	local ball = Instance.new("Part")
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.CastShadow = false
	ball.Material = Enum.Material.Neon
	ball.Shape = Enum.PartType.Ball
	ball.Color = color
	ball.Size = Vector3.one * 2
	ball.Position = position
	ball.Parent = effectsFolder
	local ring = ball:Clone()
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.4, 2, 2)
	ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	ring.Color = Color3.fromRGB(255, 240, 180)
	ring.Parent = effectsFolder
	TweenService:Create(
		ball,
		TweenInfo.new(0.35, Enum.EasingStyle.Quad),
		{ Size = Vector3.one * radius * 2, Transparency = 1 }
	):Play()
	TweenService:Create(
		ring,
		TweenInfo.new(0.4, Enum.EasingStyle.Quad),
		{ Size = Vector3.new(0.4, radius * 2.6, radius * 2.6), Transparency = 1 }
	):Play()
	Kit.sound(Kit.Sounds.Boom, 0.35, 1.3)
	task.delay(0.45, function()
		ball:Destroy()
		ring:Destroy()
	end)
end

local function muzzleFlash(position: Vector3, color: Color3, size: number)
	local flash = Instance.new("Part")
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanQuery = false
	flash.CanTouch = false
	flash.CastShadow = false
	flash.Material = Enum.Material.Neon
	flash.Shape = Enum.PartType.Ball
	flash.Color = color:Lerp(Color3.new(1, 1, 1), 0.5)
	flash.Size = Vector3.one * size
	flash.Position = position
	flash.Parent = effectsFolder
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 10
	light.Brightness = 3
	light.Parent = flash
	TweenService
		:Create(flash, TweenInfo.new(0.07), { Size = Vector3.one * size * 0.2, Transparency = 1 })
		:Play()
	task.delay(0.08, function()
		flash:Destroy()
	end)
end

local function shotSound(kind: Guns.GunKind)
	if kind == "Shotgun" or kind == "Launcher" then
		Kit.sound(Kit.Sounds.Blast, 0.35, if kind == "Launcher" then 0.7 else 1)
	elseif kind == "Sniper" then
		Kit.sound(Kit.Sounds.Blast, 0.4, 0.8)
	elseif kind == "Minigun" then
		Kit.sound(Kit.Sounds.Pew, 0.16, 1.35)
	elseif kind == "SMG" or kind == "Rifle" then
		Kit.sound(Kit.Sounds.Pew, 0.22, 1.15)
	else
		Kit.sound(Kit.Sounds.Pew, 0.3, 1)
	end
end

------------------------------------------------------------------------------------------------
-- Shooting
------------------------------------------------------------------------------------------------

local function setAmmoDisplay()
	Hud.setAmmo(ammo, magazine, os.clock() < reloadUntil)
end

local function startReload(stats: Guns.KindStats)
	if os.clock() < reloadUntil or ammo >= stats.magazine then
		return
	end
	reloadUntil = os.clock() + stats.reloadTime
	reloadRemote:FireServer()
	Kit.sound(if stats.pellets > 1 then Kit.Sounds.Pump else Kit.Sounds.Reload, 0.35)
	setAmmoDisplay()
	task.delay(stats.reloadTime, function()
		if os.clock() >= reloadUntil - 0.01 then
			ammo = stats.magazine
			setAmmoDisplay()
		end
	end)
end

-- Where the shot aims: the auto target, or the point under the cursor or touch.
local function aimRay(autoPart: BasePart?): Ray
	if autoPart then
		local from = camera.CFrame.Position
		return Ray.new(from, (autoPart.Position - from).Unit)
	end
	local point = aimScreen or UserInputService:GetMouseLocation()
	return camera:ViewportPointToRay(point.X, point.Y)
end

local function fire(def: Guns.GunDef, stats: Guns.KindStats, autoPart: BasePart?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local ray = aimRay(autoPart)
	local params = rayParams()
	local rarity = Rarity.get(def.rarity)
	local color = def.accent:Lerp(rarity.glow, 0.3)
	local origin = muzzlePosition() or (root.Position + Vector3.new(0, 1.5, 0))

	local hits: { [BasePart]: number } = {}
	local hitPositions: { [BasePart]: Vector3 } = {}
	local firstEnd: Vector3? = nil
	for _ = 1, stats.pellets do
		local spreadRad = math.rad(stats.spread + recoil * 0.3)
		local direction = (CFrame.lookAt(Vector3.zero, ray.Direction) * CFrame.Angles(
			random:NextNumber(-spreadRad, spreadRad),
			random:NextNumber(-spreadRad, spreadRad),
			0
		)).LookVector
		local result = workspace:Raycast(ray.Origin, direction * RANGE, params)
		local endPoint = if result then result.Position else ray.Origin + direction * RANGE
		firstEnd = firstEnd or endPoint
		tracer(
			origin,
			endPoint,
			color,
			if def.kind == "Sniper" then 0.35 else 0.18 * Rarity.get(def.rarity).gunScale
		)
		if result then
			local part = result.Instance
			if part:IsA("BasePart") and (isEnemyPart(part) or isTrainingPart(part)) then
				hits[part] = (hits[part] or 0) + 1
				hitPositions[part] = result.Position
				impact(result.Position, color, 1.6)
			else
				impact(result.Position, Color3.fromRGB(255, 240, 200), 0.8)
			end
		end
	end

	-- Report the part most pellets hit; the server checks everything else.
	local bestPart: BasePart? = nil
	local bestCount = 0
	for part, count in hits do
		if count > bestCount then
			bestPart = part
			bestCount = count
		end
	end
	local aimPoint = if bestPart then hitPositions[bestPart] else firstEnd
	shootRemote:FireServer(bestPart, bestCount, aimPoint)

	if def.kind == "Launcher" and aimPoint then
		explosion(aimPoint, stats.splashRadius, color)
	end
	muzzleFlash(origin, color, 1.2 * rarity.gunScale)
	shotSound(def.kind)

	-- Turn the character toward the shot so the gun points where the bullets go.
	if aimPoint then
		local flat = Vector3.new(aimPoint.X, root.Position.Y, aimPoint.Z)
		if (flat - root.Position).Magnitude > 1 then
			root.CFrame = CFrame.lookAt(root.Position, flat)
		end
	end
	recoil = math.min(recoil + stats.recoil, 12)
end

local function step()
	local def, stats = currentGun()
	if not def or not stats or not tool or tool.Parent ~= player.Character then
		return
	end
	if magazine ~= stats.magazine then
		magazine = stats.magazine
		ammo = math.min(ammo, magazine)
	end
	local now = os.clock()
	if now < reloadUntil then
		return
	end
	local wantsFire = triggerHeld and not Menus.isOpen()
	local autoPart: BasePart? = nil
	if not wantsFire and Hud.autoFire then
		autoPart = autoTarget()
		wantsFire = autoPart ~= nil
	end
	if not wantsFire or now < nextShot then
		return
	end
	if ammo <= 0 then
		startReload(stats)
		return
	end
	ammo -= 1
	nextShot = now + 1 / stats.fireRate
	if stats.burst > 1 then
		burstCount += 1
		if burstCount >= stats.burst then
			burstCount = 0
			nextShot += 0.22
		end
	end
	fire(def, stats, autoPart)
	setAmmoDisplay()
	if ammo <= 0 then
		startReload(stats)
	end
end

------------------------------------------------------------------------------------------------
-- Tool tracking
------------------------------------------------------------------------------------------------

local function onTool(newTool: Tool)
	if newTool:GetAttribute("GunUid") == nil then
		return
	end
	tool = newTool
	local def, stats = currentGun()
	if def and stats then
		magazine = stats.magazine
		ammo = stats.magazine
		reloadUntil = 0
		setAmmoDisplay()
	end
	newTool.Activated:Connect(function()
		triggerHeld = true
	end)
	newTool.Deactivated:Connect(function()
		triggerHeld = false
	end)
	newTool.Unequipped:Connect(function()
		triggerHeld = false
	end)
end

local function watchCharacter(character: Model)
	triggerHeld = false
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			onTool(child)
		end
	end)
	local held = character:FindFirstChildOfClass("Tool")
	if held then
		onTool(held)
	end
end

local function drawOtherShot(shooter: Player, aim: Vector3)
	local character = shooter.Character
	local held = character and character:FindFirstChildOfClass("Tool")
	if not held then
		return
	end
	local muzzle = GunBuilder.muzzleOf(held)
	if not muzzle then
		return
	end
	local id = held:GetAttribute("GunId")
	local def = if typeof(id) == "string" then Guns.get(id) else nil
	local color = if def then def.accent else Color3.fromRGB(255, 230, 120)
	tracer(muzzle.WorldPosition, aim, color, 0.15)
end

function GunController:Init()
	effectsFolder = Instance.new("Folder")
	effectsFolder.Name = "LocalEffects"
	effectsFolder.Parent = workspace
end

function GunController.effects(): Folder
	return effectsFolder
end

GunController.explosion = explosion

function GunController:Start()
	shootRemote = Net.event("Shoot")
	reloadRemote = Net.event("Reload")

	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		watchCharacter(player.Character)
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.Touch then
			aimScreen = Vector2.new(input.Position.X, input.Position.Y)
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			aimScreen = nil
		end
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.R then
			local _, stats = currentGun()
			if stats then
				startReload(stats)
			end
		elseif input.KeyCode == Enum.KeyCode.ButtonR2 then
			triggerHeld = true
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch and triggerHeld then
			aimScreen = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.ButtonR2 then
			triggerHeld = false
		end
	end)

	-- Runs right after the camera scripts so the recoil kick isn't overwritten.
	RunService:BindToRenderStep("PewGun", Enum.RenderPriority.Camera.Value + 1, function(dt)
		step()
		-- Recoil kicks the camera up and settles back.
		if recoil > 0.01 then
			local kick = recoil * dt * 6
			camera.CFrame *= CFrame.Angles(math.rad(kick * 0.4), 0, 0)
			recoil = math.max(0, recoil - dt * 30)
		end
	end)

	Net.unreliable("ShotFx").OnClientEvent:Connect(drawOtherShot)
	ClientState.ProfileChanged:Connect(function()
		local _, stats = currentGun()
		if stats and stats.magazine ~= magazine then
			magazine = stats.magazine
			ammo = stats.magazine
			setAmmoDisplay()
		end
	end)
end

return GunController
