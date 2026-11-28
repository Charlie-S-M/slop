--!strict

--[[
	The Gauntlet. Each player who steps through the portal gets a private arena far from the lobby
	and fights stage after stage of enemies that grow bigger, tougher, and harder-hitting. Enemies
	are anchored models the server moves itself; clients only animate and decorate them.

	A run ends when the player leaves (keeping their ores) or dies (losing every ore in the bag).
]]

const Players = game:GetService("Players")
const RunService = game:GetService("RunService")

const Attachments = require("@game/ReplicatedStorage/Shared/Attachments")
const ArmorStats = require("@game/ReplicatedStorage/Shared/ArmorStats")
const Balance = require("@game/ReplicatedStorage/Shared/Balance")
const Biomes = require("@game/ReplicatedStorage/Shared/Biomes")
const Net = require("@game/ReplicatedStorage/Shared/Net")
const PetStats = require("@game/ReplicatedStorage/Shared/PetStats")
const OreBuilder = require("@game/ReplicatedStorage/Shared/OreBuilder")
const Ores = require("@game/ReplicatedStorage/Shared/Ores")
const PrestigeShop = require("@game/ReplicatedStorage/Shared/PrestigeShop")
const Rarity = require("@game/ReplicatedStorage/Shared/Rarity")
const Strike = require("@game/ReplicatedStorage/Shared/Strike")
const Types = require("@game/ReplicatedStorage/Shared/Types")
const Upgrades = require("@game/ReplicatedStorage/Shared/Upgrades")
const ArenaBuilder = require("./World/ArenaBuilder")
const EnemyBuilder = require("./World/EnemyBuilder")
const Boosts = require("./Boosts")
const Loadout = require("./Loadout")
const PlayerData = require("./PlayerData")
const QuestKeeper = require("./QuestKeeper")
const RateLimit = require("./RateLimit")

type EnemyDef = Biomes.EnemyDef

export type Enemy = {
	id: number,
	def: EnemyDef,
	model: Model,
	root: BasePart,
	stage: number,
	health: number,
	maxHealth: number,
	damage: number,
	speed: number,
	scale: number,
	isBoss: boolean,
	isMini: boolean,
	-- Feet position on the arena floor.
	position: Vector3,
	yaw: number,
	rootHeight: number,
	reach: number,
	radius: number,
	lastAttack: number,
	nextRanged: number,
	alive: boolean,
	strafe: number,
}

type Pickup = {
	ore: Ores.OreDef,
	model: Model,
	position: Vector3,
	born: number,
}

type Run = {
	player: Player,
	slot: number,
	arena: Model,
	origin: Vector3,
	stage: number,
	biome: Biomes.BiomeDef,
	enemies: { Enemy },
	pickups: { Pickup },
	state: "starting" | "fighting" | "break" | "ended",
	totalEnemies: number,
	container: Folder,
	connections: { RBXScriptConnection },
	bagFullWarned: boolean,
	bossName: string?,
	-- A Tower run: stages are floors (stage - TOWER_STAGE_OFFSET) and clears raise towerBest.
	tower: boolean,
	crystal: BasePart?,
	integrity: number,
	capacity: number,
	nextWave: number,
	-- When the current break ends, and a token that a skip bumps so a stale timer can't also fire.
	nextAt: number,
	breakToken: number,
	-- Where the player was at the last step, so mobs can swing at anyone running past.
	lastSpot: Vector3?,
}

-- With Auto Skip on, the beat between a cleared stage and the next one.
const AUTO_SKIP_SECONDS = 0.8
const MAX_SLOTS = 16
const SLOT_SPACING = 420
const ARENA_BASE = Vector3.new(4000, 0, 0)
const LOBBY_RETURN = CFrame.new(0, 4, 108) * CFrame.Angles(0, 0, 0)
const PROJECTILE_SPEED = 60
const MAX_PICKUPS = 70
const MELEE_COOLDOWN = 1.25
-- How far past a mob's own reach its swing catches a player.
const PASSING_REACH = 4

local Arena = {}

local runs: { [Player]: Run } = {}
local arenas: { [number]: Model } = {}
local slotOwners: { [number]: Player } = {}
local nextEnemyId = 0
local random = Random.new()

local runRemote: RemoteEvent
local attackRemote: RemoteEvent
local rewardRemote: RemoteEvent
local chestRemote: RemoteEvent
local notifyRemote: RemoteEvent

local arenasFolder: Folder

------------------------------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------------------------------

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function notify(player: Player, text: string, color: Color3?)
	notifyRemote:FireClient(player, text, color)
end

local function sendRunInfo(run: Run, cleared: boolean?)
	local alive = 0
	local elite = false
	for _, enemy in run.enemies do
		if enemy.alive then
			alive += 1
			-- Bosses only: "mini" enemies are a Splitter's halves, which show up on ordinary stages.
			elite = elite or enemy.isBoss
		end
	end
	runRemote:FireClient(run.player, {
		active = run.state ~= "ended",
		stage = run.stage,
		biome = run.biome.index,
		enemiesLeft = alive,
		elite = elite and cleared ~= true,
		enemiesTotal = run.totalEnemies,
		isBoss = Balance.isBossStage(run.stage),
		suggested = Balance.suggestedDamage(run.stage),
		bossName = run.bossName,
		tower = run.tower,
		integrity = math.ceil(100 * run.integrity / run.capacity),
		floor = if run.tower then Balance.towerFloor(run.stage) else nil,
		cleared = cleared == true,
		state = run.state,
		-- Seconds until the next stage or wave, for the countdown bar and its Skip button.
		nextIn = if run.tower
			then math.max(0, run.nextWave - os.clock())
			elseif run.state == "break" then math.max(0, run.nextAt - os.clock())
			else nil,
		nextTotal = if run.tower then Balance.TOWER_WAVE_SECONDS else Balance.STAGE_BREAK_SECONDS,
	})
end

local function weightedPick<T>(items: { T }, weights: { number }): T
	local total = 0
	for index = 1, #items do
		total += weights[index] or 1
	end
	local roll = random:NextNumber() * total
	for index, item in items do
		roll -= weights[index] or 1
		if roll <= 0 then
			return item
		end
	end
	return items[#items]
end

-- Enemies spawn at least this far from the player, so none appears on top of them.
const SPAWN_GAP = 40

-- A random point in the spawn box away from the player: the first of a few rolls that keeps
-- SPAWN_GAP studs of room, or the farthest roll when the player stands in the middle of the box.
local function spawnPoint(run: Run): Vector3
	local root = rootOf(run.player)
	local best = run.origin
	local bestGap = -1
	for _ = 1, 12 do
		local point = run.origin
			+ Vector3.new(
				random:NextNumber(ArenaBuilder.SPAWN_MIN.X, ArenaBuilder.SPAWN_MAX.X),
				0,
				random:NextNumber(ArenaBuilder.SPAWN_MIN.Z, ArenaBuilder.SPAWN_MAX.Z)
			)
		if not root then
			return point
		end
		local gap = (Vector3.new(point.X, 0, point.Z) - Vector3.new(
			root.Position.X,
			0,
			root.Position.Z
		)).Magnitude
		if gap >= SPAWN_GAP then
			return point
		end
		if gap > bestGap then
			best, bestGap = point, gap
		end
	end
	return best
end

local function setStageSign(run: Run)
	local sign = run.arena:FindFirstChild("StageSign")
	local gui = sign and sign:FindFirstChild("Gui")
	local label = gui and gui:FindFirstChild("Stage")
	if label and label:IsA("TextLabel") then
		local name = if run.tower
			then `FLOOR {Balance.towerFloor(run.stage)}`
			else `STAGE {run.stage}`
		label.Text = if Balance.isBossStage(run.stage) then `BOSS · {name}` else name
	end
end

------------------------------------------------------------------------------------------------
-- Enemies
------------------------------------------------------------------------------------------------

local function spawnEnemy(
	run: Run,
	def: EnemyDef,
	isBoss: boolean,
	isMini: boolean,
	position: Vector3?,
	spawnStageNumber: number?
)
	local stage = spawnStageNumber or run.stage
	local scale = Balance.enemyScale(stage, isBoss)
	if isMini then
		scale *= 0.55
	end
	local health = Balance.enemyHealth(stage) * def.hpMultiplier
	if isBoss then
		health *= Balance.bossHealthMultiplier()
	end
	if isMini then
		health *= 0.25
	end
	local damage = Balance.enemyDamage(stage)
	if isBoss then
		damage *= 2.5
	elseif def.behavior == "Ranged" then
		-- Ranged enemies hit from anywhere, so each shot is lighter.
		damage *= 0.6
	elseif def.behavior == "Tank" then
		damage *= 1.4
	elseif def.behavior == "Fast" then
		damage *= 0.7
	end

	local model = EnemyBuilder.build(def, scale, isBoss)
	local root = model.PrimaryPart :: BasePart
	nextEnemyId += 1
	local spawnAt = position or spawnPoint(run)
	if isBoss then
		spawnAt = run.origin + Vector3.new(0, 0, ArenaBuilder.SPAWN_MIN.Z + 20)
	end
	local rootHeight = EnemyBuilder.rootHeight(model)
	local enemy: Enemy = {
		id = nextEnemyId,
		stage = stage,
		def = def,
		model = model,
		root = root,
		health = health,
		maxHealth = health,
		damage = damage,
		speed = def.speed * (1 + (scale - 1) * 0.22),
		scale = scale,
		isBoss = isBoss,
		isMini = isMini,
		position = spawnAt,
		yaw = math.pi,
		rootHeight = rootHeight,
		reach = root.Size.Z / 2 + 3.5,
		radius = math.max(root.Size.X, root.Size.Z) / 2,
		lastAttack = os.clock(),
		nextRanged = os.clock() + random:NextNumber(1.5, 3),
		alive = true,
		strafe = if random:NextNumber() < 0.5 then -1 else 1,
	}
	model:SetAttribute("EnemyId", enemy.id)
	model:SetAttribute("Health", health)
	model:SetAttribute("MaxHealth", health)
	model:SetAttribute("Scale", scale)
	model:SetAttribute("Behavior", def.behavior)
	model:SetAttribute("Owner", run.player.UserId)
	model:PivotTo(
		CFrame.new(spawnAt + Vector3.new(0, rootHeight, 0)) * CFrame.Angles(0, enemy.yaw, 0)
	)
	model.Parent = run.container
	table.insert(run.enemies, enemy)
	return enemy
end

local function spawnStage(run: Run)
	local stage = run.stage
	local biome = run.biome
	local count = Balance.enemyCount(stage)
	if run.tower then
		run.nextWave = os.clock() + Balance.TOWER_WAVE_SECONDS
	end
	run.bossName = nil
	if Balance.isBossStage(stage) then
		local boss = spawnEnemy(run, biome.boss, true, false, nil)
		run.bossName = biome.boss.name
		boss.model:SetAttribute("DisplayName", biome.boss.name)
		count -= 1
	end
	for _ = 1, count do
		local def = weightedPick(biome.enemies, { 5, 3, 2 })
		spawnEnemy(run, def, false, false, nil)
	end
	run.totalEnemies = #run.enemies
	run.state = "fighting"
	setStageSign(run)
	sendRunInfo(run)
end

local function dropOres(run: Run, enemy: Enemy)
	local profile = PlayerData.get(run.player)
	local drops = 0
	if enemy.isBoss then
		drops = Balance.BOSS_ORE_DROPS
	elseif
		not enemy.isMini
		and random:NextNumber()
			< Balance.oreDropChance(
				if profile
					then PetStats.multiplier(profile.pets, profile.equippedPets, "Ores")
						* Balance.prestigeOres(profile.prestige)
					else 1
			)
	then
		drops = 1
	end
	local pool = Ores.forBiome(Biomes.forStage(enemy.stage).index)
	if #pool == 0 then
		return
	end
	local weights = if enemy.isBoss then Ores.BOSS_WEIGHTS else Ores.NORMAL_WEIGHTS
	for _ = 1, drops do
		local ore = weightedPick(pool, weights)
		local offset = Vector3.new(random:NextNumber(-4, 4), 0, random:NextNumber(-4, 4))
			* (if enemy.isBoss then 2 else 1)
		local position = Vector3.new(enemy.position.X, run.origin.Y + 1.6, enemy.position.Z)
			+ offset
		local model = OreBuilder.build(ore)
		model:ScaleTo(1.5)
		model:SetAttribute("OreId", ore.id)
		model:SetAttribute("OrePickup", true)
		model:PivotTo(CFrame.new(position))
		local tag = Instance.new("BillboardGui")
		tag.Name = "Tag"
		tag.Size = UDim2.fromScale(6, 1.4)
		tag.StudsOffsetWorldSpace = Vector3.new(0, 0, -2.8)
		tag.MaxDistance = 90
		tag.LightInfluence = 0
		tag.Parent = model.PrimaryPart
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold)
		label.TextScaled = true
		label.Text = ore.name
		label.TextColor3 = Rarity.get(ore.rarity).color:Lerp(Color3.new(1, 1, 1), 0.25)
		label.Parent = tag
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = Color3.fromRGB(20, 20, 30)
		stroke.Parent = label
		if ore.rarity >= 3 then
			local beam = Instance.new("PointLight")
			beam.Color = Rarity.get(ore.rarity).color
			beam.Range = 8
			beam.Brightness = 1.5
			beam.Parent = model.PrimaryPart
		end
		model.Parent = run.container
		table.insert(
			run.pickups,
			{ ore = ore, model = model, position = position, born = os.clock() }
		)
		if #run.pickups > MAX_PICKUPS then
			local oldest = table.remove(run.pickups, 1)
			if oldest then
				oldest.model:Destroy()
			end
		end
	end
end

--[[
	Boss kills record the boss as defeated, and the Glassfall Foundry boss drops a Glassheart: always
	on the player's first kill, sometimes after. Materials go straight into the profile, so dying
	later in the run can't lose them.
]]
local function awardBossMaterials(run: Run, enemy: Enemy, profile: Types.Profile)
	local bossId = enemy.def.id
	local firstKill = not profile.bossesDefeated[bossId]
	profile.bossesDefeated[bossId] = true
	local material = Balance.BOSS_MATERIALS[bossId]
	if material then
		local count = Balance.bossMaterialDrop(firstKill, random:NextNumber())
		if count > 0 then
			profile.materials[material] = (profile.materials[material] or 0) + count
			rewardRemote:FireClient(run.player, {
				kind = "material",
				id = material,
				count = count,
				position = enemy.position + Vector3.new(0, enemy.rootHeight * 2, 0),
			})
		end
	end
	PlayerData.markState(run.player)
end

-- Every boss leaves a chest: usually coins, sometimes (CHEST_PART_CHANCE) an attachment whose rarity
-- is rolled on the reel, which Part Luck tilts toward rarer parts.
local function openChest(run: Run, enemy: Enemy, profile: Types.Profile)
	if random:NextNumber() < Balance.CHEST_PART_CHANCE then
		local luck = Upgrades.value("PartLuck", profile.upgrades.PartLuck or 0)
			* PrestigeShop.multiplier(profile.prestigeShop, "PartLuck")
		local rarity = Balance.reelRarity(random:NextNumber(), luck)
		local pool = Attachments.ofRarity(rarity)
		if #pool > 0 then
			local def = pool[random:NextInteger(1, #pool)]
			profile.attachments[def.id] = (profile.attachments[def.id] or 0) + 1
			PlayerData.markState(run.player)
			chestRemote:FireClient(run.player, { kind = "part", partId = def.id, rarity = rarity })
			return
		end
	end
	local coins = Balance.enemyCoins(enemy.stage)
		* Balance.CHEST_COIN_KILLS
		* Upgrades.value("CoinBoost", profile.upgrades.CoinBoost or 0)
		* Balance.towerBonus(profile.towerBest)
		* Boosts.coins(run.player, profile)
		* Boosts.bossLoot(run.player)
	PlayerData.addCoins(run.player, coins)
	chestRemote:FireClient(run.player, { kind = "coins", coins = coins })
end

local function killEnemy(run: Run, enemy: Enemy)
	if not enemy.alive then
		return
	end
	enemy.alive = false
	enemy.model:SetAttribute("Health", 0)
	enemy.model:SetAttribute("Dead", true)
	-- The death animation lingers, but shots must reach the live mob behind it.
	for _, part in enemy.model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanQuery = false
		end
	end
	local index = table.find(run.enemies, enemy)
	if index then
		table.remove(run.enemies, index)
	end
	local player = run.player
	local profile = PlayerData.get(player)
	if profile then
		local coinBoost = Upgrades.value("CoinBoost", profile.upgrades.CoinBoost or 0)
		local coins = Balance.enemyCoins(enemy.stage)
			* coinBoost
			* (if enemy.isBoss then 6 else 1)
			* (if enemy.isMini then 0.3 else 1)
			* Balance.towerBonus(profile.towerBest)
			* Boosts.coins(player, profile)
		local xp = Balance.enemyXp(enemy.stage) * (if enemy.isBoss then 5 else 1)
		PlayerData.addCoins(player, coins)
		PlayerData.addXp(player, xp)
		profile.kills += 1
		if
			math.random()
			< Balance.rubyChance(
				profile.prestigeShop.RubyChance or 0,
				profile.upgrades.RubyChance or 0
			)
		then
			profile.rubies += 1
		end
		if enemy.isBoss then
			Balance.rubyQuestProgress(profile, "bosses", 1)
		end
		if enemy.stage >= Balance.RUBY_VETERAN_STAGE then
			Balance.rubyQuestProgress(profile, "veterans", 1)
		end
		PlayerData.markState(player)
		QuestKeeper.record(player, "Kills", 1)
		if enemy.isBoss then
			QuestKeeper.record(player, "Bosses", 1)
		end
		rewardRemote:FireClient(player, {
			kind = "kill",
			coins = math.floor(coins),
			xp = xp,
			position = enemy.position + Vector3.new(0, enemy.rootHeight * 2, 0),
			boss = enemy.isBoss,
			name = enemy.def.name,
		})
	end
	dropOres(run, enemy)
	if enemy.isBoss and profile then
		awardBossMaterials(run, enemy, profile)
		openChest(run, enemy, profile)
	end
	if enemy.def.behavior == "Splitter" and not enemy.isMini then
		for side = -1, 1, 2 do
			local mini = spawnEnemy(
				run,
				enemy.def,
				false,
				true,
				enemy.position + Vector3.new(side * enemy.radius, 0, 0),
				enemy.stage
			)
			run.totalEnemies += 1
			mini.model:SetAttribute("DisplayName", `Mini {enemy.def.name}`)
		end
	end
	local model = enemy.model
	task.delay(0.7, function()
		model:Destroy()
	end)
	sendRunInfo(run)
end

------------------------------------------------------------------------------------------------
-- Runs
------------------------------------------------------------------------------------------------

local function arenaForSlot(slot: number): Model
	local existing = arenas[slot]
	if existing and existing.Parent then
		return existing
	end
	local origin = ARENA_BASE + Vector3.new(0, 0, (slot - 1) * SLOT_SPACING)
	local arena = ArenaBuilder.build(arenasFolder, origin, `Arena{slot}`)
	arenas[slot] = arena
	return arena
end

local function clearRunObjects(run: Run)
	for _, enemy in run.enemies do
		enemy.alive = false
	end
	run.enemies = {}
	run.pickups = {}
	run.container:ClearAllChildren()
end

local function endRun(run: Run, returnToLobby: boolean)
	if run.state == "ended" then
		return
	end
	run.state = "ended"
	for _, connection in run.connections do
		connection:Disconnect()
	end
	clearRunObjects(run)
	run.container:Destroy()
	runs[run.player] = nil
	slotOwners[run.slot] = nil
	run.player:SetAttribute("InRun", false)
	run.player:SetAttribute("Stage", nil)
	if run.player.Parent then
		runRemote:FireClient(run.player, { active = false, stage = run.stage })
	end
	if returnToLobby then
		local character = run.player.Character
		if character then
			character:PivotTo(LOBBY_RETURN)
		end
	end
end

local function startNextStage(run: Run)
	if run.state == "ended" then
		return
	end
	local previousBiome = run.biome
	run.biome = Biomes.forStage(run.stage)
	if run.biome ~= previousBiome then
		ArenaBuilder.theme(run.arena, run.biome)
	end
	spawnStage(run)
end

local function onStageCleared(run: Run)
	run.state = "break"
	QuestKeeper.record(run.player, if run.tower then "Floors" else "Stages", 1)
	local profile = PlayerData.get(run.player)
	if profile and run.tower then
		local floor = Balance.towerFloor(run.stage)
		if floor > profile.towerBest then
			local before = Balance.towerBonus(profile.towerBest)
			profile.towerBest = floor
			PlayerData.markState(run.player)
			if Balance.towerBonus(floor) > before then
				notify(
					run.player,
					`Tower checkpoint! Training and coins are now ×{string.format(
						"%.1f",
						Balance.towerBonus(floor)
					)} for good.`,
					Color3.fromRGB(150, 230, 255)
				)
			end
		end
	elseif profile and run.stage > profile.bestStage then
		profile.bestStage = run.stage
		profile.peakStage = math.max(profile.peakStage, run.stage)
		Loadout.refreshStats(run.player)
		PlayerData.markState(run.player)
	end
	if run.tower then
		run.stage += 1
		run.player:SetAttribute("Stage", run.stage)
		startNextStage(run)
		return
	end
	run.breakToken += 1
	local token = run.breakToken
	-- Auto Skip is honored here, not by a request from the client: stages cleared faster than the
	-- skip request's rate limit used to sit through the whole break.
	local wait = if profile and profile.settings.autoSkip
		then AUTO_SKIP_SECONDS
		else Balance.STAGE_BREAK_SECONDS
	run.nextAt = os.clock() + wait
	sendRunInfo(run, true)
	task.delay(wait, function()
		if run.state ~= "break" or run.breakToken ~= token then
			return
		end
		run.stage += 1
		run.player:SetAttribute("Stage", run.stage)
		startNextStage(run)
	end)
end

local function freeSlot(): number?
	for slot = 1, MAX_SLOTS do
		if not slotOwners[slot] then
			return slot
		end
	end
	return nil
end

local function startRun(player: Player, startStage: number, tower: boolean?)
	if runs[player] then
		return
	end
	local root = rootOf(player)
	local humanoid = humanoidOf(player)
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	local slot = freeSlot()
	if not slot then
		notify(player, "All arenas are busy. Try again in a moment!")
		return
	end
	slotOwners[slot] = player
	local arena = arenaForSlot(slot)
	local origin = Vector3.new(
		arena:GetAttribute("OriginX") :: number,
		arena:GetAttribute("OriginY") :: number,
		arena:GetAttribute("OriginZ") :: number
	)
	local container = Instance.new("Folder")
	container.Name = `Run_{player.UserId}`
	container.Parent = arena

	local run: Run = {
		player = player,
		slot = slot,
		arena = arena,
		origin = origin,
		stage = startStage,
		biome = Biomes.forStage(startStage),
		enemies = {},
		pickups = {},
		state = "starting",
		totalEnemies = 0,
		container = container,
		connections = {},
		bagFullWarned = false,
		bossName = nil,
		tower = tower == true,
		crystal = nil,
		integrity = Balance.enemyDamage(startStage) * Balance.CRYSTAL_HITS,
		capacity = Balance.enemyDamage(startStage) * Balance.CRYSTAL_HITS,
		nextWave = math.huge,
		nextAt = 0,
		breakToken = 0,
		lastSpot = nil,
	}
	if run.tower then
		local crystal = Instance.new("Part")
		crystal.Name = "DefenseCrystal"
		crystal.Size = Vector3.new(6, 9, 6)
		crystal.Anchored = true
		crystal.CanCollide = false
		crystal.CanQuery = false
		crystal.Color = Color3.fromRGB(59, 242, 255)
		crystal.Material = Enum.Material.Neon
		crystal.CFrame = CFrame.new(origin + Vector3.new(0, 6, 60))
			* CFrame.Angles(0, 0, math.rad(35))
		crystal.Parent = container
		run.crystal = crystal
	end
	runs[player] = run
	player:SetAttribute("InRun", true)
	player:SetAttribute("Stage", startStage)
	ArenaBuilder.theme(arena, run.biome)
	setStageSign(run)

	table.insert(
		run.connections,
		humanoid.Died:Connect(function()
			local profile = PlayerData.get(player)
			if profile then
				local lost = if Boosts.keepsOres(player) then 0 else PlayerData.bagCount(profile)
				if lost > 0 then
					profile.bag = {}
				end
				PlayerData.markState(player)
				if lost > 0 then
					notify(
						player,
						`You were defeated and dropped {lost} ores!`,
						Color3.fromRGB(255, 90, 90)
					)
				else
					notify(player, "You were defeated!", Color3.fromRGB(255, 90, 90))
				end
			end
			endRun(run, false)
		end)
	)

	local character = player.Character
	if character then
		character:PivotTo(
			CFrame.new(
				origin + (if run.tower then Vector3.new(0, 3, 70) else ArenaBuilder.PLAYER_START)
			)
		)
	end
	sendRunInfo(run)
	task.delay(2, function()
		if run.state == "starting" then
			startNextStage(run)
		end
	end)
end

------------------------------------------------------------------------------------------------
-- Simulation
------------------------------------------------------------------------------------------------

local function damageObjective(run: Run, amount: number)
	if run.tower then
		if run.integrity <= 0 then
			return
		end
		run.integrity = math.max(0, run.integrity - amount)
		sendRunInfo(run)
		if run.integrity == 0 then
			task.defer(function()
				if runs[run.player] == run then
					notify(run.player, "The crystal shattered!")
					endRun(run, true)
				end
			end)
		end
		return
	end
	local humanoid = humanoidOf(run.player)
	if humanoid and humanoid.Health > 0 then
		local profile = PlayerData.get(run.player)
		local blocked = if profile
			then ArmorStats.blocked(profile.armor, profile.equippedArmor)
			else 0
		humanoid:TakeDamage(amount * (1 - blocked))
	end
end

local function launchProjectile(run: Run, enemy: Enemy, targetPosition: Vector3)
	local from = enemy.position + Vector3.new(0, enemy.rootHeight * 1.3, 0)
	local distance = (targetPosition - from).Magnitude
	local travel = distance / PROJECTILE_SPEED
	attackRemote:FireClient(run.player, {
		kind = "projectile",
		from = from,
		to = targetPosition,
		time = travel,
		color = enemy.def.accent,
		size = math.clamp(1 + enemy.scale * 0.25, 1, 5),
	})
	local hitRadius = 3.5 + math.min(enemy.scale, 6) * 0.4
	task.delay(travel, function()
		if run.state ~= "fighting" and run.state ~= "break" then
			return
		end
		local root = run.crystal or rootOf(run.player)
		if root and (root.Position - targetPosition).Magnitude <= hitRadius then
			damageObjective(run, enemy.damage)
		end
	end)
end

local function stepRun(run: Run, dt: number, now: number, roots: { BasePart }, cframes: { CFrame })
	if run.state ~= "fighting" and run.state ~= "break" then
		return
	end
	local playerRoot = rootOf(run.player)
	if not playerRoot then
		return
	end
	if run.tower and now >= run.nextWave and run.integrity > 0 then
		onStageCleared(run)
	end
	local target = if run.crystal then run.crystal.Position else playerRoot.Position
	local flatTarget = Vector3.new(target.X, run.origin.Y, target.Z)
	local halfWidth = ArenaBuilder.WIDTH / 2 - 3
	local halfLength = ArenaBuilder.LENGTH / 2 - 3
	local spot = playerRoot.Position
	local from = run.lastSpot or spot
	run.lastSpot = spot

	for _, enemy in run.enemies do
		if not enemy.alive then
			continue
		end
		local toPlayer = flatTarget - enemy.position
		local distance = toPlayer.Magnitude
		local direction = if distance > 0.01 then toPlayer / distance else Vector3.zero
		local move = Vector3.zero
		local behavior = enemy.def.behavior
		local isRanged = behavior == "Ranged"
		if isRanged then
			if distance > 46 + enemy.radius then
				move = direction
			elseif distance < 26 + enemy.radius then
				move = -direction
			else
				move = Vector3.new(-direction.Z, 0, direction.X) * enemy.strafe * 0.6
			end
		elseif distance > enemy.reach then
			move = direction
		end

		-- Keep enemies from stacking inside each other.
		for _, other in run.enemies do
			if other ~= enemy and other.alive then
				local apart = enemy.position - other.position
				local gap = apart.Magnitude
				local minimum = enemy.radius + other.radius
				if gap > 0.01 and gap < minimum then
					move += apart / gap * (1 - gap / minimum) * 1.5
				end
			end
		end

		if move.Magnitude > 1 then
			move = move.Unit
		end
		local newPosition = enemy.position + move * enemy.speed * dt
		local local_ = newPosition - run.origin
		newPosition = run.origin
			+ Vector3.new(
				math.clamp(local_.X, -halfWidth, halfWidth),
				0,
				math.clamp(local_.Z, -halfLength, halfLength)
			)
		enemy.position = newPosition
		if distance > 0.5 then
			enemy.yaw = math.atan2(-direction.X, -direction.Z)
		end

		local hover = 0
		if enemy.def.shape == "Floater" then
			hover = (2.5 + math.sin(now * 2 + enemy.id) * 0.8) * enemy.scale
		end
		table.insert(roots, enemy.root)
		table.insert(
			cframes,
			CFrame.new(newPosition + Vector3.new(0, enemy.rootHeight + hover, 0))
				* CFrame.Angles(0, enemy.yaw, 0)
		)

		if run.state ~= "fighting" then
			continue
		end
		-- In the Gauntlet a swing catches anyone who comes close, running past included. In the
		-- Tower the mobs are after the crystal.
		local close = if run.tower
			then not isRanged and distance <= enemy.reach + 1
			else Strike.reaches(enemy.position, from, spot, enemy.reach + PASSING_REACH)
		if close and now - enemy.lastAttack >= MELEE_COOLDOWN then
			enemy.lastAttack = now
			attackRemote:FireClient(run.player, { kind = "melee", enemy = enemy.model })
			damageObjective(run, enemy.damage)
		end
		if isRanged then
			if now >= enemy.nextRanged and distance < 140 then
				enemy.nextRanged = now
					+ (if enemy.isBoss then 1.5 else 2.6)
					+ random:NextNumber(0, 0.6)
				launchProjectile(run, enemy, target)
				if enemy.isBoss then
					-- Bosses throw a spread of three.
					local side = Vector3.new(-direction.Z, 0, direction.X)
					launchProjectile(run, enemy, target + side * 9)
					launchProjectile(run, enemy, target - side * 9)
				end
			end
		end
	end
end

local function collectPickups(run: Run)
	if run.state == "ended" then
		return
	end
	local root = rootOf(run.player)
	local profile = PlayerData.get(run.player)
	if not root or not profile then
		return
	end
	local radius = Boosts.collectRadius(run.player)
		or Upgrades.value("Magnet", profile.upgrades.Magnet or 0)
	local capacity = Upgrades.value("BagSize", profile.upgrades.BagSize or 0)
	local carried = PlayerData.bagCount(profile)
	if carried < capacity then
		run.bagFullWarned = false
	end
	local index = 1
	while index <= #run.pickups do
		local pickup = run.pickups[index]
		if (pickup.position - root.Position).Magnitude <= radius then
			if carried >= capacity then
				if not run.bagFullWarned then
					run.bagFullWarned = true
					notify(
						run.player,
						"Your ore bag is full! Head back to forge or sell.",
						Color3.fromRGB(255, 200, 60)
					)
				end
				break
			end
			table.remove(run.pickups, index)
			profile.bag[pickup.ore.id] = (profile.bag[pickup.ore.id] or 0) + 1
			carried += 1
			QuestKeeper.record(run.player, "Ores", 1)
			local isNew = not profile.oreIndex[pickup.ore.id]
			profile.oreIndex[pickup.ore.id] = true
			PlayerData.markState(run.player)
			rewardRemote:FireClient(run.player, {
				kind = "ore",
				oreId = pickup.ore.id,
				position = pickup.position,
				new = isNew,
			})
			pickup.model:Destroy()
		else
			index += 1
		end
	end
end

------------------------------------------------------------------------------------------------
-- Public API for Combat
------------------------------------------------------------------------------------------------

function Arena.runOf(player: Player): Run?
	return runs[player]
end

-- Finds the living enemy in this player's run that a hit instance belongs to.
function Arena.enemyFromInstance(player: Player, instance: Instance): Enemy?
	local run = runs[player]
	if not run or not instance:IsDescendantOf(run.container) then
		return nil
	end
	local current: Instance? = instance
	while current and current ~= run.container do
		if current:IsA("Model") and current:GetAttribute("EnemyId") ~= nil then
			local id = current:GetAttribute("EnemyId")
			for _, enemy in run.enemies do
				if enemy.id == id and enemy.alive then
					return enemy
				end
			end
			return nil
		end
		current = current.Parent
	end
	return nil
end

function Arena.enemiesNear(player: Player, position: Vector3, radius: number): { Enemy }
	local run = runs[player]
	local list = {}
	if not run then
		return list
	end
	for _, enemy in run.enemies do
		if enemy.alive then
			local center = enemy.position + Vector3.new(0, enemy.rootHeight, 0)
			if (center - position).Magnitude <= radius + enemy.radius then
				table.insert(list, enemy)
			end
		end
	end
	return list
end

-- Applies damage to an enemy. Returns true when the hit killed it.
function Arena.damage(player: Player, enemy: Enemy, amount: number): boolean
	local run = runs[player]
	if not run or not enemy.alive or run.state ~= "fighting" then
		return false
	end
	enemy.health -= amount
	if enemy.health <= 0 then
		killEnemy(run, enemy)
		if not run.tower and #run.enemies == 0 and run.state == "fighting" then
			onStageCleared(run)
		end
		return true
	end
	enemy.model:SetAttribute("Health", enemy.health)
	return false
end

------------------------------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------------------------------

function Arena:Init()
	arenasFolder = Instance.new("Folder")
	arenasFolder.Name = "Arenas"
	arenasFolder.Parent = workspace
end

function Arena:Start()
	runRemote = Net.event("Run")
	attackRemote = Net.event("EnemyAttack")
	rewardRemote = Net.event("Reward")
	chestRemote = Net.event("ChestOpened")
	notifyRemote = Net.event("Notify")

	Net.event("EnterArena").OnServerEvent:Connect(function(player, stage: unknown)
		if not RateLimit.allow(player, "EnterArena", 0.5, 2) then
			return
		end
		if typeof(stage) ~= "number" or stage ~= stage or stage ~= math.floor(stage) then
			return
		end
		local profile = PlayerData.get(player)
		if not profile then
			return
		end
		if not table.find(Balance.checkpoints(profile.bestStage), stage) then
			return
		end
		startRun(player, stage)
	end)

	-- Skips the wait: in a break, the next stage starts now; in the Tower, the next wave comes now.
	Net.event("SkipWait").OnServerEvent:Connect(function(player)
		if not RateLimit.allow(player, "SkipWait", 1, 2) then
			return
		end
		local run = runs[player]
		if not run or run.state == "ended" then
			return
		end
		if run.tower then
			if run.integrity > 0 then
				run.nextWave = os.clock()
			end
		elseif run.state == "break" then
			run.breakToken += 1
			run.stage += 1
			run.player:SetAttribute("Stage", run.stage)
			startNextStage(run)
		end
	end)

	Net.event("EnterTower").OnServerEvent:Connect(function(player)
		if not RateLimit.allow(player, "EnterArena", 0.5, 2) then
			return
		end
		local profile = PlayerData.get(player)
		if not profile then
			return
		end
		if not Balance.towerUnlocked(profile.power) then
			notify(player, "The Tower opens at 1B Power!")
			return
		end
		startRun(player, Balance.towerStage(Balance.towerStartFloor(profile.towerBest)), true)
	end)

	Net.event("LeaveArena").OnServerEvent:Connect(function(player)
		if not RateLimit.allow(player, "LeaveArena", 1, 2) then
			return
		end
		local run = runs[player]
		if run then
			endRun(run, true)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local run = runs[player]
		if run then
			endRun(run, false)
		end
	end)

	local pickupTimer = 0
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		local roots: { BasePart } = {}
		local cframes: { CFrame } = {}
		for _, run in runs do
			stepRun(run, math.min(dt, 0.1), now, roots, cframes)
		end
		if #roots > 0 then
			workspace:BulkMoveTo(roots, cframes, Enum.BulkMoveMode.FireCFrameChanged)
		end
		pickupTimer += dt
		if pickupTimer >= 0.12 then
			pickupTimer = 0
			for _, run in runs do
				collectPickups(run)
			end
		end
	end)
end

return Arena
