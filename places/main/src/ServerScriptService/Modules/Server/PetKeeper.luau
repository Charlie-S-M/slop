--!strict

--[[
	Pets on the server: hatching eggs for coins, equipping up to PET_SLOTS, and releasing pets for a
	small refund. The equipped pet ids go in the player's "Pets" attribute so every client can draw
	them following their owner. Bonuses are applied where they act (Combat and Arena) through
	PetStats.multiplier.
]]

const Balance = require("@game/ReplicatedStorage/Shared/Balance")
const Net = require("@game/ReplicatedStorage/Shared/Net")
const Pets = require("@game/ReplicatedStorage/Shared/Pets")
const PetStats = require("@game/ReplicatedStorage/Shared/PetStats")
const Types = require("@game/ReplicatedStorage/Shared/Types")
const PlayerData = require("./PlayerData")
const RateLimit = require("./RateLimit")

local PetKeeper = {}

local random = Random.new()
local notifyRemote: RemoteEvent
local hatchedRemote: RemoteEvent
local rewardRemote: RemoteEvent

-- A released pet refunds this share of its egg's price.
const RELEASE_REFUND = 0.1

local function isUid(value: unknown): boolean
	return typeof(value) == "string" and #value > 0 and #value <= 40
end

local function findPet(profile: Types.Profile, uid: string): (Types.PetItem?, number?)
	for index, pet in profile.pets do
		if pet.uid == uid then
			return pet, index
		end
	end
	return nil, nil
end

local function eggOf(petId: string): Pets.EggDef?
	for _, egg in Pets.EGGS do
		for _, entry in egg.pets do
			if entry.petId == petId then
				return egg
			end
		end
	end
	return nil
end

-- Publishes the equipped pet ids, in order, for every client to draw.
function PetKeeper.publish(player: Player)
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	local ids = {}
	for _, def in PetStats.equipped(profile.pets, profile.equippedPets) do
		table.insert(ids, def.id)
	end
	player:SetAttribute("Pets", table.concat(ids, ","))
end

local function onHatch(player: Player, eggId: unknown)
	if not RateLimit.allow(player, "HatchEgg", 1, 2) or typeof(eggId) ~= "string" then
		return
	end
	local egg = Pets.egg(eggId)
	local profile = PlayerData.get(player)
	if not egg or not profile then
		return
	end
	if profile.bestStage + 1 < egg.unlockStage then
		notifyRemote:FireClient(player, `Reach stage {egg.unlockStage} to open the {egg.name}!`)
		return
	end
	if #profile.pets >= Balance.MAX_PETS then
		notifyRemote:FireClient(player, "Your pet pen is full. Release a few first!")
		return
	end
	if not PlayerData.spendCoins(player, Pets.price(egg)) then
		notifyRemote:FireClient(player, "Not enough coins for that egg!")
		return
	end
	local def = Pets.roll(egg, random:NextNumber())
	local pet: Types.PetItem = { uid = PlayerData.newGunUid(profile), id = def.id, locked = false }
	table.insert(profile.pets, pet)
	PlayerData.markState(player)
	hatchedRemote:FireClient(player, { pet = pet, eggId = egg.id })
end

local function onEquip(player: Player, uid: unknown)
	if not RateLimit.allow(player, "EquipPet", 4, 5) or not isUid(uid) then
		return
	end
	local profile = PlayerData.get(player)
	if not profile or not findPet(profile, uid :: string) then
		return
	end
	if table.find(profile.equippedPets, uid :: string) then
		return
	end
	if #profile.equippedPets >= Balance.PET_SLOTS then
		notifyRemote:FireClient(player, `You can bring {Balance.PET_SLOTS} pets at once.`)
		return
	end
	table.insert(profile.equippedPets, uid :: string)
	PlayerData.markState(player)
	PetKeeper.publish(player)
end

local function onUnequip(player: Player, uid: unknown)
	if not RateLimit.allow(player, "EquipPet", 4, 5) or not isUid(uid) then
		return
	end
	local profile = PlayerData.get(player)
	local index = profile and table.find(profile.equippedPets, uid :: string)
	if not profile or not index then
		return
	end
	table.remove(profile.equippedPets, index)
	PlayerData.markState(player)
	PetKeeper.publish(player)
end

local function onRelease(player: Player, uid: unknown)
	if not RateLimit.allow(player, "ReleasePet", 4, 5) or not isUid(uid) then
		return
	end
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	local pet, index = findPet(profile, uid :: string)
	if not pet or not index or pet.locked or table.find(profile.equippedPets, pet.uid) then
		return
	end
	local egg = eggOf(pet.id)
	local refund = if egg then math.floor(Pets.price(egg) * RELEASE_REFUND) else 0
	table.remove(profile.pets, index)
	if refund > 0 then
		PlayerData.addCoins(player, refund)
		rewardRemote:FireClient(player, { kind = "coins", coins = refund })
	end
	PlayerData.markState(player)
end

local function onLock(player: Player, uid: unknown)
	if not RateLimit.allow(player, "ToggleLock", 5, 6) or not isUid(uid) then
		return
	end
	local profile = PlayerData.get(player)
	local pet = profile and findPet(profile, uid :: string)
	if pet then
		pet.locked = not pet.locked
		PlayerData.markState(player)
	end
end

function PetKeeper:Start()
	notifyRemote = Net.event("Notify")
	hatchedRemote = Net.event("Hatched")
	rewardRemote = Net.event("Reward")
	Net.event("HatchEgg").OnServerEvent:Connect(onHatch)
	Net.event("EquipPet").OnServerEvent:Connect(onEquip)
	Net.event("UnequipPet").OnServerEvent:Connect(onUnequip)
	Net.event("ReleasePet").OnServerEvent:Connect(onRelease)
	Net.event("LockPet").OnServerEvent:Connect(onLock)
	PlayerData.Loaded:Connect(function(player)
		PetKeeper.publish(player)
	end)
	for _, player in PlayerData.players() do
		PetKeeper.publish(player)
	end
end

return PetKeeper
