--!strict

--[[
	Runs each player's quest book: deals dailies at the UTC day change, counts progress from the
	rest of the game through QuestKeeper.record, and handles claiming, swapping, and the daily
	chest. Quests.luau holds the rules; this module applies them to live profiles.
]]

const Net = require("@game/ReplicatedStorage/Shared/Net")
const Quests = require("@game/ReplicatedStorage/Shared/Quests")
const PlayerData = require("./PlayerData")
const RateLimit = require("./RateLimit")

local QuestKeeper = {}

const random = Random.new()
local notifyRemote: RemoteEvent

local function refresh(player: Player): boolean
	local profile = PlayerData.get(player)
	if not profile then
		return false
	end
	local changed = Quests.refresh(profile.quests, os.time(), profile.towerBest, random)
	if changed then
		PlayerData.markState(player)
	end
	return changed
end

-- Counts progress toward every unclaimed quest of `kind` (Kills, Bosses, Ores, Stages, Floors,
-- Forges, or Hatches).
function QuestKeeper.record(player: Player, kind: string, amount: number)
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	Quests.record(profile.quests, kind, amount)
	PlayerData.markState(player)
end

-- Deals a fresh set of dailies; the New Quests purchase calls this.
function QuestKeeper.reroll(player: Player)
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	Quests.reroll(profile.quests, profile.towerBest, random)
	PlayerData.markState(player)
end

local function claim(player: Player, list: { Quests.Quest }, index: number, daily: boolean): boolean
	local profile = PlayerData.get(player)
	local quest = list[index]
	if not profile or not quest or quest.claimed or not Quests.done(quest) then
		return false
	end
	quest.claimed = true
	local before = Quests.rank(profile.quests.stars).rank
	profile.quests.stars += quest.stars
	if daily then
		profile.quests.chestPips = math.min(Quests.CHEST_PIPS, profile.quests.chestPips + 1)
	end
	PlayerData.addCoins(player, Quests.coins(quest, profile.bestStage))
	local after = Quests.rank(profile.quests.stars)
	if after.rank > before then
		notifyRemote:FireClient(
			player,
			`Quest rank up! You're now a {after.name}.`,
			Color3.fromRGB(255, 215, 90)
		)
	end
	return true
end

local function onClaim(player: Player, scope: unknown, index: unknown)
	if not RateLimit.allow(player, "QuestClaim", 4, 8) then
		return
	end
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	refresh(player)
	local claimedAny = false
	if scope == "all" then
		for at in profile.quests.daily do
			claimedAny = claim(player, profile.quests.daily, at, true) or claimedAny
		end
		for at in profile.quests.challenge do
			claimedAny = claim(player, profile.quests.challenge, at, false) or claimedAny
		end
	elseif
		(scope == "daily" or scope == "challenge")
		and typeof(index) == "number"
		and index == math.floor(index)
	then
		local list = if scope == "daily" then profile.quests.daily else profile.quests.challenge
		claimedAny = claim(player, list, index, scope == "daily")
	end
	if not claimedAny then
		return
	end
	-- A claimed challenge makes room for a new one.
	local kept = {}
	for _, quest in profile.quests.challenge do
		if not quest.claimed then
			table.insert(kept, quest)
		end
	end
	profile.quests.challenge = kept
	refresh(player)
	PlayerData.markState(player)
end

local function onSwap(player: Player, index: unknown)
	if not RateLimit.allow(player, "QuestSwap", 2, 4) then
		return
	end
	local profile = PlayerData.get(player)
	if not profile or typeof(index) ~= "number" or index ~= math.floor(index) then
		return
	end
	refresh(player)
	if Quests.swap(profile.quests, index, profile.towerBest, random) then
		PlayerData.markState(player)
	else
		notifyRemote:FireClient(player, "Each daily quest can only be swapped once.")
	end
end

local function onChest(player: Player)
	if not RateLimit.allow(player, "QuestChest", 1, 2) then
		return
	end
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	refresh(player)
	local book = profile.quests
	if book.chestOpened or book.chestPips < Quests.CHEST_PIPS then
		return
	end
	book.chestOpened = true
	local coins = Quests.chestCoins(profile.bestStage)
	PlayerData.addCoins(player, coins)
	PlayerData.markState(player)
	notifyRemote:FireClient(player, "Daily chest opened! 💰", Color3.fromRGB(140, 255, 120))
end

function QuestKeeper:Init()
	notifyRemote = Net.event("Notify")
end

function QuestKeeper:Start()
	Net.event("QuestClaim").OnServerEvent:Connect(onClaim)
	Net.event("QuestSwap").OnServerEvent:Connect(onSwap)
	Net.event("QuestChest").OnServerEvent:Connect(onChest)
	PlayerData.Loaded:Connect(function(player)
		refresh(player)
	end)
	for _, player in PlayerData.players() do
		refresh(player)
	end
	-- Dailies turn over at the UTC day change even for players who stay online.
	task.spawn(function()
		while true do
			task.wait(30)
			for _, player in PlayerData.players() do
				refresh(player)
			end
		end
	end)
end

return QuestKeeper
