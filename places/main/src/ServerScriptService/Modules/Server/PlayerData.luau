--!strict

--[[
	Owns every player's profile. Loads it with a session lock, autosaves, saves on leave and
	shutdown, and sends the client its state. Gameplay code reads and changes the in-memory profile
	through this module and never touches the DataStore.
]]

const DataStoreService = game:GetService("DataStoreService")
const HttpService = game:GetService("HttpService")
const Players = game:GetService("Players")
const RunService = game:GetService("RunService")

const Balance = require("@game/ReplicatedStorage/Shared/Balance")
const GunStats = require("@game/ReplicatedStorage/Shared/GunStats")
const Guns = require("@game/ReplicatedStorage/Shared/Guns")
const Net = require("@game/ReplicatedStorage/Shared/Net")
const Signal = require("@game/ReplicatedStorage/Shared/Signal")
const Types = require("@game/ReplicatedStorage/Shared/Types")

type Profile = Types.Profile

const STORE_NAME = "PewIncremental_v1"
const CURRENT_VERSION = 8
const AUTOSAVE_SECONDS = 60
-- A lock older than this belongs to a server that died without releasing it.
const LOCK_STALE_SECONDS = AUTOSAVE_SECONDS * 3
const LOAD_ATTEMPTS = 6
const SYNC_INTERVAL = 0.1

type Stored = {
	data: Profile?,
	lock: { job: string, time: number }?,
}

type Session = {
	profile: Profile,
	statsDirty: boolean,
	stateDirty: boolean,
	-- False for a Studio session whose DataStore is unreachable; nothing gets saved.
	persistent: boolean,
	saving: boolean,
	released: boolean,
}

local PlayerData = {}

-- Fires once a player's profile is ready.
PlayerData.Loaded = Signal.new() :: Signal.Signal<Player, Profile>
-- Fires after a player's level goes up, with the new level.
PlayerData.LeveledUp = Signal.new() :: Signal.Signal<Player, number>
-- Fires whenever something that affects the character's health, speed, or gun changes.
PlayerData.LoadoutChanged = Signal.new() :: Signal.Signal<Player>

--[[
	Handlers run synchronously, in order, right before a leaving player's final save, so a system
	can settle unfinished work (like a pending forge) into the profile that gets saved. They must
	not yield.
]]
local beforeRelease: { (Player, Profile) -> () } = {}

function PlayerData.onBeforeRelease(handler: (Player, Profile) -> ())
	table.insert(beforeRelease, handler)
end

local sessions: { [Player]: Session } = {}
local store: DataStore? = nil

local function defaultProfile(): Profile
	return {
		version = CURRENT_VERSION,
		power = 0,
		coins = 0,
		rebirths = 0,
		level = 1,
		xp = 0,
		guns = {
			{
				uid = "g1",
				id = Guns.STARTER_ID,
				power = Guns.STARTER_POWER,
				speed = 1,
				train = Guns.STARTER_POWER,
				grade = "B",
				locked = true,
			},
		},
		equipped = "g1",
		nextUid = 2,
		bag = {},
		oreIndex = {},
		gunIndex = { [Guns.STARTER_ID] = true },
		upgrades = {},
		bestStage = 0,
		lastDaily = 0,
		dailyStreak = 0,
		kills = 0,
		forges = 0,
		playSeconds = 0,
		-- Version 3: catalysts and first-kill records. Older saves get these empty.
		materials = {},
		bossesDefeated = {},
		armor = {},
		equippedArmor = {},
		pets = {},
		equippedPets = {},
		towerBest = 0,
		prestige = 0,
		attachments = {},
		robuxSpent = 0,
		settings = { autoMode = false, autoSkip = false, sfx = 1, music = 1 },
		redeemedCodes = {},
		quests = {
			day = 0,
			daily = {},
			challenge = {},
			stars = 0,
			chestPips = 0,
			chestOpened = false,
		},
	}
end

-- Fills fields a saved profile is missing, so new fields never arrive as nil.
local function reconcile(saved: any): Profile
	local profile = defaultProfile()
	if typeof(saved) ~= "table" then
		return profile
	end
	for key, value in saved do
		if (profile :: any)[key] ~= nil and typeof((profile :: any)[key]) == typeof(value) then
			(profile :: any)[key] = value
		end
	end
	if #profile.guns == 0 then
		profile.guns = defaultProfile().guns
	end
	-- Settings saved before a setting existed get its default, so every key is always present.
	const defaults = defaultProfile().settings :: any
	for key, value in defaults do
		if typeof((profile.settings :: any)[key]) ~= typeof(value) then
			(profile.settings :: any)[key] = value
		end
	end
	-- Equipped pets must be owned, unique uids; anything else would hold a slot no card can free.
	local ownedPets: { [string]: boolean } = {}
	for _, pet in profile.pets do
		if typeof(pet) == "table" and typeof(pet.uid) == "string" then
			ownedPets[pet.uid] = true
		end
	end
	local cleanEquipped = {}
	for _, uid in profile.equippedPets do
		if typeof(uid) == "string" and ownedPets[uid] and not table.find(cleanEquipped, uid) then
			table.insert(cleanEquipped, uid)
		end
	end
	profile.equippedPets = cleanEquipped
	-- Version 2 gave guns Speed, Training Power, and a grade; older guns get them filled in.
	for index, item in profile.guns do
		profile.guns[index] = GunStats.migrateGun(item)
	end
	-- The default profile has no pending forge, so the copy loop above skips it.
	if typeof(saved.pendingForge) == "table" and typeof(saved.pendingForge.token) == "string" then
		profile.pendingForge = saved.pendingForge
	end
	profile.version = CURRENT_VERSION
	return profile
end

local function withRetry<T>(attempts: number, callback: () -> T): (boolean, T?)
	local delaySeconds = 1
	for attempt = 1, attempts do
		local ok, result = pcall(callback)
		if ok then
			return true, result
		end
		warn(`[PlayerData] DataStore attempt {attempt}/{attempts} failed: {result}`)
		if attempt < attempts then
			task.wait(delaySeconds)
			delaySeconds = math.min(delaySeconds * 2, 8)
		end
	end
	return false, nil
end

local function keyFor(player: Player): string
	return `u_{player.UserId}`
end

--[[
	Claims the profile's lock and reads it in one UpdateAsync. Returns the profile, or nil with a
	reason when another server holds a fresh lock or the call keeps failing.
]]
local function claim(player: Player): (Profile?, string?)
	local activeStore = store
	if not activeStore then
		return nil, "no store"
	end
	local jobId = if game.JobId ~= "" then game.JobId else "studio"
	for _ = 1, LOAD_ATTEMPTS do
		local lockedByOther = false
		local loaded: Profile? = nil
		local ok = withRetry(3, function()
			activeStore:UpdateAsync(keyFor(player), function(old: Stored?)
				local stored: Stored = old or {}
				local lock = stored.lock
				local now = os.time()
				if lock and lock.job ~= jobId and now - lock.time < LOCK_STALE_SECONDS then
					lockedByOther = true
					return nil
				end
				lockedByOther = false
				local profile = reconcile(stored.data)
				loaded = profile
				return { data = profile, lock = { job = jobId, time = now } }
			end)
			return true
		end)
		if not ok then
			return nil, "failed"
		end
		if loaded and not lockedByOther then
			return loaded, nil
		end
		-- Another server is still saving this player; give it a moment to let go.
		task.wait(3)
	end
	return nil, "locked"
end

local function save(player: Player, session: Session, release: boolean)
	local activeStore = store
	if not activeStore or not session.persistent or session.released then
		return
	end
	if session.saving and not release then
		return
	end
	session.saving = true
	local jobId = if game.JobId ~= "" then game.JobId else "studio"
	local profile = session.profile
	withRetry(if release then 5 else 3, function()
		activeStore:UpdateAsync(keyFor(player), function(old: Stored?)
			local stored: Stored = old or {}
			local lock = stored.lock
			-- If another server took the lock, this one has stale data and must not write.
			if lock and lock.job ~= jobId then
				return nil
			end
			return {
				data = profile,
				lock = if release then nil else { job = jobId, time = os.time() },
			}
		end)
		return true
	end)
	session.saving = false
	if release then
		session.released = true
	end
end

local function onPlayerAdded(player: Player)
	local profile: Profile? = nil
	local persistent = true
	if store then
		local reason
		profile, reason = claim(player)
		if not profile then
			if RunService:IsStudio() then
				warn(`[PlayerData] Using a temporary profile for {player.Name} ({reason})`)
				profile = defaultProfile()
				persistent = false
			else
				player:Kick(
					if reason == "locked"
						then "Your data is still saving from another server. Please rejoin in a moment."
						else "Your data couldn't load. Please rejoin."
				)
				return
			end
		end
	else
		profile = defaultProfile()
		persistent = false
	end
	if not player.Parent then
		-- They left while loading; give the lock straight back.
		local session: Session = {
			profile = profile :: Profile,
			statsDirty = false,
			stateDirty = false,
			persistent = persistent,
			saving = false,
			released = false,
		}
		save(player, session, true)
		return
	end
	local session: Session = {
		profile = profile :: Profile,
		statsDirty = true,
		stateDirty = true,
		persistent = persistent,
		saving = false,
		released = false,
	}
	sessions[player] = session
	player:SetAttribute("Loaded", true)
	PlayerData.Loaded:Fire(player, session.profile)

	-- Stagger autosaves so players who joined together don't all save on one tick.
	task.spawn(function()
		task.wait(player.UserId % AUTOSAVE_SECONDS)
		while sessions[player] == session do
			save(player, session, false)
			task.wait(AUTOSAVE_SECONDS)
		end
	end)
end

-- Leave saves still writing; BindToClose waits for these as well as its own.
local leavingSaves = 0

local function onPlayerRemoving(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	for _, handler in beforeRelease do
		local profile = session.profile
		local ok, err = pcall(function()
			handler(player, profile)
		end)
		if not ok then
			warn(`[PlayerData] Before-release handler failed for {player.Name}: {err}`)
		end
	end
	sessions[player] = nil
	-- Counted so BindToClose waits for a leave save that started just before shutdown.
	leavingSaves += 1
	save(player, session, true)
	leavingSaves -= 1
end

------------------------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------------------------

function PlayerData.get(player: Player): Profile?
	local session = sessions[player]
	return if session then session.profile else nil
end

function PlayerData.players(): { Player }
	local list = {}
	for player in sessions do
		table.insert(list, player)
	end
	return list
end

-- Marks that the full state changed (guns, bag, upgrades) and the client needs a new copy.
function PlayerData.markState(player: Player)
	local session = sessions[player]
	if session then
		session.stateDirty = true
		session.statsDirty = true
	end
end

function PlayerData.markStats(player: Player)
	local session = sessions[player]
	if session then
		session.statsDirty = true
	end
end

function PlayerData.addPower(player: Player, amount: number)
	local profile = PlayerData.get(player)
	if profile and amount > 0 then
		profile.power += amount
		PlayerData.markStats(player)
	end
end

function PlayerData.addCoins(player: Player, amount: number)
	local profile = PlayerData.get(player)
	if profile and amount > 0 then
		profile.coins += math.floor(amount)
		PlayerData.markStats(player)
	end
end

function PlayerData.spendCoins(player: Player, amount: number): boolean
	local profile = PlayerData.get(player)
	if not profile or amount < 0 or profile.coins < amount then
		return false
	end
	profile.coins -= amount
	PlayerData.markStats(player)
	return true
end

function PlayerData.addXp(player: Player, amount: number)
	local profile = PlayerData.get(player)
	if not profile or amount <= 0 then
		return
	end
	profile.xp += amount
	local leveled = false
	-- A cap on loops per call keeps a huge reward from stalling the server.
	for _ = 1, 500 do
		local needed = Balance.xpToNext(profile.level)
		if profile.xp < needed then
			break
		end
		profile.xp -= needed
		profile.level += 1
		leveled = true
	end
	PlayerData.markStats(player)
	if leveled then
		PlayerData.LeveledUp:Fire(player, profile.level)
		PlayerData.LoadoutChanged:Fire(player)
	end
end

function PlayerData.upgradeLevel(player: Player, id: string): number
	local profile = PlayerData.get(player)
	return if profile then profile.upgrades[id] or 0 else 0
end

function PlayerData.newGunUid(profile: Profile): string
	local uid = `g{profile.nextUid}`
	profile.nextUid += 1
	return uid
end

function PlayerData.findGun(profile: Profile, uid: string): (Types.GunItem?, number?)
	for index, item in profile.guns do
		if item.uid == uid then
			return item, index
		end
	end
	return nil, nil
end

function PlayerData.equippedGun(profile: Profile): Types.GunItem
	local item = PlayerData.findGun(profile, profile.equipped)
	return item or profile.guns[1]
end

function PlayerData.bagCount(profile: Profile): number
	local total = 0
	for _, count in profile.bag do
		total += count
	end
	return total
end

------------------------------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------------------------------

function PlayerData:Init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn(`[PlayerData] DataStores unavailable, progress won't save: {result}`)
	end
end

function PlayerData:Start()
	const stateRemote = Net.event("State")
	const statsRemote = Net.event("Stats")

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	game:BindToClose(function()
		local pending = 0
		for player, session in sessions do
			pending += 1
			for _, handler in beforeRelease do
				pcall(handler, player, session.profile)
			end
			task.spawn(function()
				save(player, session, true)
				pending -= 1
			end)
		end
		-- Studio waits too, a little less, so stopping a playtest doesn't drop its last save.
		local limit = if RunService:IsStudio() then 10 else 25
		local started = os.clock()
		while (pending > 0 or leavingSaves > 0) and os.clock() - started < limit do
			task.wait(0.2)
		end
	end)

	-- Send changed state at a steady rate instead of on every change.
	task.spawn(function()
		while true do
			task.wait(SYNC_INTERVAL)
			for player, session in sessions do
				if session.stateDirty then
					session.stateDirty = false
					stateRemote:FireClient(player, session.profile)
				end
				if session.statsDirty then
					session.statsDirty = false
					local profile = session.profile
					statsRemote:FireClient(player, {
						power = profile.power,
						coins = profile.coins,
						level = profile.level,
						xp = profile.xp,
						rebirths = profile.rebirths,
					})
				end
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			for _, session in sessions do
				session.profile.playSeconds += 1
			end
		end
	end)
end

-- Ids for new guns use HttpService only when a profile's counter is unusable.
function PlayerData.fallbackUid(): string
	return HttpService:GenerateGUID(false)
end

return PlayerData
