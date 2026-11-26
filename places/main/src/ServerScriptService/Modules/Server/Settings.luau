--!strict

--[[
	Saves the Settings menu's choices and redeems codes. Codes live only here on the server, so
	the client never sees what each one gives. Each code works once per player.
]]

const Net = require("@game/ReplicatedStorage/Shared/Net")
const PlayerData = require("./PlayerData")
const RateLimit = require("./RateLimit")

local Settings = {}

type Code = { coins: number?, power: number?, message: string }

const CODES: { [string]: Code } = {
	release = { coins = 5000, message = "Thanks for playing! +5,000 coins" },
	update_0 = { coins = 10000, power = 250, message = "Update 0! +10,000 coins and +250 Power" },
	pewpew = { coins = 2500, message = "Pew pew! +2,500 coins" },
	forgefire = { power = 500, message = "The forge burns bright! +500 Power" },
	thankyou = { coins = 1000, message = "You're awesome! +1,000 coins" },
}

local notifyRemote: RemoteEvent

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
	if not code then
		notifyRemote:FireClient(player, "That code doesn't exist.", Color3.fromRGB(255, 120, 120))
		return
	end
	if profile.redeemedCodes[name] then
		notifyRemote:FireClient(player, "You already used that code!", Color3.fromRGB(255, 200, 60))
		return
	end
	profile.redeemedCodes[name] = true
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
