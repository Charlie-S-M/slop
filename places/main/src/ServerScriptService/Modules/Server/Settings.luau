--!strict

--[[
	Saves the Settings menu's choices and redeems codes. Codes live only here on the server, so
	the client never sees what each one gives. Each code works once per player.

	"dev_everything" is a testing code: the best ores, three of every pet, and a quadrillion coins.
	It only works in Studio or for the experience owner (rank 255 in the owning group).
]]

const GroupService = game:GetService("GroupService")
const RunService = game:GetService("RunService")

const Net = require("@game/ReplicatedStorage/Shared/Net")
const Ores = require("@game/ReplicatedStorage/Shared/Ores")
const Pets = require("@game/ReplicatedStorage/Shared/Pets")
const Types = require("@game/ReplicatedStorage/Shared/Types")
const PlayerData = require("./PlayerData")
const RateLimit = require("./RateLimit")

local Settings = {}

type Code = { coins: number?, power: number?, everything: boolean?, message: string }

const CODES: { [string]: Code } = {
	release = { coins = 5000, message = "Thanks for playing! +5,000 coins" },
	update_0 = { coins = 10000, power = 250, message = "Update 0! +10,000 coins and +250 Power" },
	pewpew = { coins = 2500, message = "Pew pew! +2,500 coins" },
	forgefire = { power = 500, message = "The forge burns bright! +500 Power" },
	thankyou = { coins = 1000, message = "You're awesome! +1,000 coins" },
	dev_everything = { everything = true, message = "Testing kit: best ores, every pet, 1Qd coins" },
}

-- How many of each of the best ores the testing code gives.
const DEV_ORE_COUNT = 10
const DEV_BEST_ORES = 3
const DEV_PETS_EACH = 3
const DEV_COINS = 1e15

local notifyRemote: RemoteEvent

local function isOwner(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	end
	local ok, groups = pcall(function()
		return GroupService:GetGroupsAsync(player.UserId)
	end)
	if not ok or typeof(groups) ~= "table" then
		return false
	end
	for _, group in groups do
		if group.Id == game.CreatorId then
			return group.Rank == 255
		end
	end
	return false
end

local function grantEverything(player: Player, profile: Types.Profile)
	const best = table.clone(Ores.List)
	table.sort(best, function(a, b)
		return a.index > b.index
	end)
	for index = 1, math.min(DEV_BEST_ORES, #best) do
		const ore = best[index]
		profile.bag[ore.id] = (profile.bag[ore.id] or 0) + DEV_ORE_COUNT
		profile.oreIndex[ore.id] = true
	end
	for _, pet in Pets.List do
		for _ = 1, DEV_PETS_EACH do
			table.insert(
				profile.pets,
				{ uid = PlayerData.newGunUid(profile), id = pet.id, locked = false }
			)
		end
	end
	PlayerData.addCoins(player, DEV_COINS)
end

local function onSaveSetting(player: Player, key: unknown, value: unknown)
	if not RateLimit.allow(player, "SaveSetting", 6, 12) then
		return
	end
	const profile = PlayerData.get(player)
	if not profile or typeof(key) ~= "string" then
		return
	end
	if key == "autoMode" or key == "autoSkip" or key == "autoRebirth" then
		if typeof(value) == "boolean" then
			(profile.settings :: any)[key] = value
		end
	elseif key == "sfx" or key == "music" then
		if typeof(value) == "number" and value == value then
			(profile.settings :: any)[key] = math.clamp(math.floor(value * 100 + 0.5) / 100, 0, 1)
		end
	end
end

local function onRedeem(player: Player, raw: unknown)
	if not RateLimit.allow(player, "RedeemCode", 1, 3) then
		return
	end
	const profile = PlayerData.get(player)
	if not profile or typeof(raw) ~= "string" or #raw > 40 then
		return
	end
	const name = string.lower((raw:gsub("^%s+", ""):gsub("%s+$", "")))
	const code = CODES[name]
	if not code or (code.everything and not isOwner(player)) then
		notifyRemote:FireClient(player, "That code doesn't exist.", Color3.fromRGB(255, 120, 120))
		return
	end
	if profile.redeemedCodes[name] then
		notifyRemote:FireClient(player, "You already used that code!", Color3.fromRGB(255, 200, 60))
		return
	end
	profile.redeemedCodes[name] = true
	if code.everything then
		grantEverything(player, profile)
		-- Testing codes can be used again, for a fresh kit after a wipe.
		profile.redeemedCodes[name] = nil
	end
	if code.coins then
		PlayerData.addCoins(player, code.coins)
	end
	if code.power then
		PlayerData.addPower(player, code.power)
	end
	PlayerData.markState(player)
	notifyRemote:FireClient(player, code.message, Color3.fromRGB(140, 255, 120))
end

function Settings:Init()
	notifyRemote = Net.event("Notify")
end

function Settings:Start()
	Net.event("SaveSetting").OnServerEvent:Connect(onSaveSetting)
	Net.event("RedeemCode").OnServerEvent:Connect(onRedeem)
end

return Settings
