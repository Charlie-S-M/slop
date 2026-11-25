--!strict

--[[
	Every shot goes through here. The client says what its ray hit; the server checks the gun's fire
	rate and ammo, the distance, and what was hit, then works out training power or enemy damage
	from server-side stats. The client never says how much damage a shot does.
]]

const Players = game:GetService("Players")

const Balance = require("@game/ReplicatedStorage/Shared/Balance")
const GunStats = require("@game/ReplicatedStorage/Shared/GunStats")
const Guns = require("@game/ReplicatedStorage/Shared/Guns")
const Net = require("@game/ReplicatedStorage/Shared/Net")
const PetStats = require("@game/ReplicatedStorage/Shared/PetStats")
const Types = require("@game/ReplicatedStorage/Shared/Types")
const Arena = require("./Arena")
const PlayerData = require("./PlayerData")
const RateLimit = require("./RateLimit")

const MAX_RANGE = 420
const PAD_RADIUS = 13
const CRIT_CHANCE = 0.12
const CRIT_MULTIPLIER = 2

type AmmoState = { ammo: number, reloadUntil: number, uid: string }

local Combat = {}

local ammoStates: { [Player]: AmmoState } = {}
local hitFx: UnreliableRemoteEvent
local shotFx: UnreliableRemoteEvent
local trainFx: UnreliableRemoteEvent

local function equippedGun(player: Player): (Guns.GunDef?, Types.GunItem?)
	local profile = PlayerData.get(player)
	if not profile then
		return nil, nil
	end
	local item = PlayerData.equippedGun(profile)
	return Guns.get(item.id), GunStats.effective(item)
end

-- The player must be holding the gun the profile says is equipped.
local function holdingGun(player: Player, uid: string): Tool?
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	if tool and tool:GetAttribute("GunUid") == uid then
		return tool
	end
	return nil
end

local function spendAmmo(player: Player, uid: string, stats: Guns.KindStats): boolean
	local now = os.clock()
	local state = ammoStates[player]
	if not state or state.uid ~= uid then
		local fresh = { ammo = stats.magazine, reloadUntil = 0, uid = uid }
		ammoStates[player] = fresh
		state = fresh
	end
	-- A little slack keeps lag from eating legitimate shots right after a reload.
	if now < state.reloadUntil - 0.15 then
		return false
	end
	if state.ammo <= 0 then
		state.ammo = stats.magazine
	end
	state.ammo -= 1
	if state.ammo <= 0 then
		state.reloadUntil = now + stats.reloadTime * 0.85
	end
	return true
end

local function findTrainingTarget(instance: Instance): Model?
	local current: Instance? = instance
	for _ = 1, 4 do
		if not current then
			return nil
		end
		if current:IsA("Model") and current:GetAttribute("TrainingTarget") then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function padFor(zone: number): BasePart?
	local lobby = workspace:FindFirstChild("Lobby")
	local training = lobby and lobby:FindFirstChild("Training")
	local zoneModel = training and training:FindFirstChild(`Zone{zone}`)
	local pad = zoneModel and zoneModel:FindFirstChild("Pad")
	return if pad and pad:IsA("BasePart") then pad else nil
end

local function onTraining(
	player: Player,
	target: Model,
	root: BasePart,
	train: number,
	kind: Guns.GunKind,
	aim: Vector3
)
	local profile = PlayerData.get(player)
	local zone = target:GetAttribute("Zone")
	if not profile or typeof(zone) ~= "number" then
		return
	end
	local zoneDef = Balance.TRAINING_ZONES[zone]
	if not zoneDef or profile.rebirths < zoneDef.rebirthsNeeded then
		return
	end
	local pad = padFor(zone)
	if not pad then
		return
	end
	local offset = root.Position - pad.Position
	if Vector3.new(offset.X, 0, offset.Z).Magnitude > PAD_RADIUS then
		return
	end
	local gain = Balance.trainingGain(
		train,
		kind,
		zoneDef.multiplier,
		profile.upgrades.Training or 0
	) * PetStats.multiplier(profile.pets, profile.equippedPets, "Training") * Balance.towerBonus(
		profile.towerBest
	)
	PlayerData.addPower(player, gain)
	PlayerData.addXp(player, 1)
	trainFx:FireClient(player, gain, aim)
end

local function onEnemyHit(
	player: Player,
	instance: Instance,
	pelletsHit: number,
	gunPower: number,
	kind: Guns.GunKind,
	gunId: string,
	aim: Vector3
)
	local enemy = Arena.enemyFromInstance(player, instance)
	local profile = PlayerData.get(player)
	if not enemy or not profile then
		return
	end
	local stats = Guns.kindStats(kind)
	local perPellet = Balance.pelletDamage(
		profile.power,
		gunPower,
		kind,
		profile.rebirths,
		profile.level,
		gunId
	) * PetStats.multiplier(profile.pets, profile.equippedPets, "Damage") * Balance.prestigeDamage(
		profile.prestige
	)
	local crit = math.random() < CRIT_CHANCE
	local amount = perPellet * pelletsHit * (if crit then CRIT_MULTIPLIER else 1)
	if stats.splashRadius > 0 then
		local center = enemy.position + Vector3.new(0, enemy.rootHeight, 0)
		for _, other in Arena.enemiesNear(player, center, stats.splashRadius) do
			if other ~= enemy then
				local killed = Arena.damage(player, other, amount * 0.6)
				hitFx:FireClient(
					player,
					other.position + Vector3.new(0, other.rootHeight * 2, 0),
					amount * 0.6,
					false,
					killed
				)
			end
		end
	end
	local killed = Arena.damage(player, enemy, amount)
	hitFx:FireClient(player, aim, amount, crit, killed)
end

local function onShoot(player: Player, target: unknown, pellets: unknown, aim: unknown)
	local def, item = equippedGun(player)
	if not def or not item then
		return
	end
	local uid = item.uid
	local stats = Guns.kindStats(def.kind)
	-- Allow a quarter more than the gun's rate to absorb network jitter.
	local fireRate = GunStats.fireRate(def.kind, item.speed)
	if not RateLimit.allow(player, "Shoot", fireRate * 1.25, math.max(3, stats.burst + 1)) then
		return
	end
	if not holdingGun(player, uid) then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return
	end
	if not spendAmmo(player, uid, stats) then
		return
	end
	if typeof(aim) ~= "Vector3" or aim ~= aim then
		return
	end
	if (aim - root.Position).Magnitude > MAX_RANGE then
		return
	end

	-- Others in the lobby see the tracer.
	for _, other in Players:GetPlayers() do
		if
			other ~= player
			and not other:GetAttribute("InRun")
			and not player:GetAttribute("InRun")
		then
			shotFx:FireClient(other, player, aim)
		end
	end

	local groups = if typeof(target) == "table"
		then target :: { any }
		else { { part = target, count = pellets, point = aim } }
	local remaining = stats.pellets
	local trained = false
	for i = 1, stats.pellets do
		local hit = groups[i]
		if remaining == 0 or typeof(hit) ~= "table" then
			break
		end
		local part, count, point = hit.part, hit.count, hit.point
		if
			typeof(part) ~= "Instance"
			or not part:IsA("BasePart")
			or typeof(count) ~= "number"
			or count ~= count
			or count < 1
			or typeof(point) ~= "Vector3"
			or point ~= point
			or (point - root.Position).Magnitude > MAX_RANGE
			or (part.Position - root.Position).Magnitude > MAX_RANGE + part.Size.Magnitude
		then
			continue
		end
		local accepted = math.min(math.floor(count), remaining)
		remaining -= accepted
		local training = findTrainingTarget(part)
		if training then
			if not trained then
				onTraining(player, training, root, item.train, def.kind, point)
				trained = true
			end
		else
			onEnemyHit(player, part, accepted, item.power, def.kind, def.id, point)
		end
	end
end

function Combat:Start()
	hitFx = Net.unreliable("HitFx")
	shotFx = Net.unreliable("ShotFx")
	trainFx = Net.unreliable("TrainFx")

	Net.event("Shoot").OnServerEvent:Connect(onShoot)
	Net.event("Reload").OnServerEvent:Connect(function(player)
		if not RateLimit.allow(player, "Reload", 2, 2) then
			return
		end
		local def, item = equippedGun(player)
		local state = ammoStates[player]
		if def and item and state and state.uid == item.uid then
			local stats = Guns.kindStats(def.kind)
			if state.ammo < stats.magazine and os.clock() >= state.reloadUntil then
				state.ammo = stats.magazine
				state.reloadUntil = os.clock() + stats.reloadTime * 0.85
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		ammoStates[player] = nil
	end)
end

return Combat
