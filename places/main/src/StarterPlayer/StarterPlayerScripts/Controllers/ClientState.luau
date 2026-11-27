--!strict

-- The client's copy of its profile, stats, and run, kept current from server remotes. UI code
-- reads from here and listens to the signals; it never changes the values itself.

const Balance = require("@game/ReplicatedStorage/Shared/Balance")
const GunStats = require("@game/ReplicatedStorage/Shared/GunStats")
const Guns = require("@game/ReplicatedStorage/Shared/Guns")
const PetStats = require("@game/ReplicatedStorage/Shared/PetStats")
const Net = require("@game/ReplicatedStorage/Shared/Net")
const Signal = require("@game/ReplicatedStorage/Shared/Signal")
const Types = require("@game/ReplicatedStorage/Shared/Types")
const Upgrades = require("@game/ReplicatedStorage/Shared/Upgrades")

local ClientState = {}

ClientState.profile = nil :: Types.Profile?
ClientState.run = { active = false, stage = 0 } :: any

ClientState.ProfileChanged = Signal.new() :: Signal.Signal<Types.Profile>
ClientState.StatsChanged = Signal.new() :: Signal.Signal<Types.Profile>
ClientState.RunChanged = Signal.new() :: Signal.Signal<any>
ClientState.LeveledUp = Signal.new() :: Signal.Signal<number>

function ClientState.equipped(): (Types.GunItem?, Guns.GunDef?)
	local profile = ClientState.profile
	if not profile then
		return nil, nil
	end
	for _, item in profile.guns do
		if item.uid == profile.equipped then
			return GunStats.effective(item), Guns.get(item.id)
		end
	end
	local first = profile.guns[1]
	return if first then GunStats.effective(first) else nil,
		if first then Guns.get(first.id) else nil
end

-- Damage of one full trigger pull with the equipped gun, as the server would compute it.
function ClientState.shotDamage(): number
	local profile = ClientState.profile
	local item, def = ClientState.equipped()
	if not profile or not item or not def then
		return 0
	end
	return Balance.playerPelletDamage(
		profile,
		item.power,
		def,
		PetStats.multiplier(profile.pets, profile.equippedPets, "Damage")
	) * Guns.kindStats(def.kind).pellets
end

function ClientState.bagCount(): number
	local profile = ClientState.profile
	local total = 0
	if profile then
		for _, count in profile.bag do
			total += count
		end
	end
	return total
end

function ClientState.bagCapacity(): number
	local profile = ClientState.profile
	return Upgrades.value("BagSize", if profile then profile.upgrades.BagSize or 0 else 0)
end

function ClientState.upgradeLevel(id: string): number
	local profile = ClientState.profile
	return if profile then profile.upgrades[id] or 0 else 0
end

function ClientState:Start()
	Net.event("State").OnClientEvent:Connect(function(profile: Types.Profile)
		ClientState.profile = profile
		ClientState.ProfileChanged:Fire(profile)
		ClientState.StatsChanged:Fire(profile)
	end)
	Net.event("Stats").OnClientEvent:Connect(function(stats: Types.Stats)
		local profile = ClientState.profile
		if not profile then
			return
		end
		local oldLevel = profile.level
		profile.power = stats.power
		profile.coins = stats.coins
		profile.level = stats.level
		profile.xp = stats.xp
		profile.rebirths = stats.rebirths
		ClientState.StatsChanged:Fire(profile)
		if stats.level > oldLevel then
			ClientState.LeveledUp:Fire(stats.level)
		end
	end)
	Net.event("Run").OnClientEvent:Connect(function(run)
		ClientState.run = run
		ClientState.RunChanged:Fire(run)
	end)
end

return ClientState
