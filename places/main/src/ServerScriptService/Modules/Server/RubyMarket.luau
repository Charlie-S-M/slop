--!nonstrict
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local Balance = require("@game/ReplicatedStorage/Shared/Balance")
local Guns = require("@game/ReplicatedStorage/Shared/Guns")
local PlayerData = require("./PlayerData")
local Plaza = require("./RubyPlaza")
local RateLimit = require("./RateLimit")
local Market = {}
local studio = RunService:IsStudio()
local orders, active, sales, wealth, rooms
local preview = studio and workspace:GetAttribute("RubyPlaytest") == true
local testOrders, testIndexes = {}, { active = {}, sales = {}, wealth = {} }
local cachedOffers, recent, leaders, prices, sold = {}, {}, {}, {}, {}
local busy, roomOf = {}, {}
local remote
local function integer(n, low, high)
	return typeof(n) == "number" and n == math.floor(n) and n >= low and n <= high
end
local function transact(id, change)
	if preview then
		testOrders[id] = change(testOrders[id])
		return testOrders[id]
	end
	return orders:UpdateAsync(id, change)
end
local function read(id)
	if preview then
		return testOrders[id]
	end
	return orders:GetAsync(id)
end
local function index(name, id, value)
	if preview then
		testIndexes[name][id] = value
		return
	end
	local db = if name == "active" then active elseif name == "sales" then sales else wealth
	if value then
		db:SetAsync(id, value)
	else
		db:RemoveAsync(id)
	end
end
local function rows(name, minimum)
	if preview then
		local result = {}
		for key, value in testIndexes[name] do
			if value >= (minimum or 0) then
				table.insert(result, { key = key, value = value })
			end
		end
		table.sort(result, function(a, b)
			return a.value > b.value
		end)
		return result
	end
	local db = if name == "active" then active elseif name == "sales" then sales else wealth
	local pages = db:GetSortedAsync(false, 100, minimum)
	local result = {}
	while true do
		for _, row in pages:GetCurrentPage() do
			table.insert(result, row)
		end
		if pages.IsFinished or name == "wealth" then
			break
		end
		pages:AdvanceToNextPageAsync()
	end
	return result
end
local function includeOffer(o)
	cachedOffers[o.id] = if o.state == "open" and o.expires > os.time() then o else nil
end
local function showStalls()
	local plaza = workspace:FindFirstChild("RubyExchange")
	if not plaza then
		return
	end
	local room = 1
	for _, number in roomOf do
		room = number
		break
	end
	local sellers, stock = {}, {}
	for _, offer in cachedOffers do
		if offer.room == room and offer.expires > os.time() then
			if not stock[offer.seller] then
				stock[offer.seller] = {}
				table.insert(sellers, offer.seller)
			end
			table.insert(stock[offer.seller], offer)
		end
	end
	table.sort(sellers)
	for _, prompt in plaza:GetDescendants() do
		if not prompt:IsA("ProximityPrompt") then
			continue
		end
		local i = tonumber((prompt:GetAttribute("Station") or ""):match("^Stall(%d+)$"))
		if not i then
			continue
		end
		local part = prompt.Parent
		local label = part:FindFirstChildWhichIsA("TextLabel", true)
		local items = stock[sellers[i]]
		local title = if items then items[1].name .. "'s stall" else "Open stall " .. i
		prompt.ObjectText = title
		if label then
			label.Text = title
		end
		local previews = part:FindFirstChild("DisplayGuns")
		if previews then
			previews:Destroy()
		end
		if not items then
			continue
		end
		previews = Instance.new("Folder")
		previews.Name = "DisplayGuns"
		previews.Parent = part
		table.sort(items, function(a, b)
			return a.price < b.price
		end)
		for slot = 1, math.min(#items, 3) do
			local offer = items[slot]
			local model =
				require(ReplicatedStorage.Shared.GunBuilder).build(assert(Guns.get(offer.gun.id)))
			local box, size = model:GetBoundingBox()
			model:ScaleTo(model:GetScale() * 3.5 / math.max(size.X, size.Y, size.Z))
			box, size = model:GetBoundingBox()
			local offset = box:ToObjectSpace(model:GetPivot())
			for _, child in model:GetDescendants() do
				if child:IsA("BasePart") then
					child.Anchored = true
					child.CanCollide = false
					child.CanTouch = false
					child.CanQuery = false
				end
			end
			model:PivotTo(
				part.CFrame
					* CFrame.new((slot - 2) * 4, 1 + size.Y * 0.5, 0)
					* CFrame.Angles(0, math.pi / 2, 0)
					* offset
			)
			model.Parent = previews
		end
	end
end
local function refresh()
	local nextOffers, history, counts, samples = {}, {}, {}, {}
	for _, row in rows("active", os.time() + 1) do
		local o = read(row.key)
		if o and o.state == "open" and o.expires > os.time() then
			nextOffers[o.id] = o
		end
	end
	for _, row in rows("sales", os.time() - 7 * 86400) do
		local o = read(row.key)
		if o and o.state == "sold" then
			counts[o.gun.id] = (counts[o.gun.id] or 0) + 1
			local set = samples[o.gun.id] or {}
			table.insert(set, o.price)
			samples[o.gun.id] = set
			if #history < 10 then
				table.insert(history, o)
			end
		end
	end
	local estimated = {}
	for id, set in samples do
		table.sort(set)
		estimated[id] = set[math.ceil(#set / 2)]
	end
	local top = {}
	for id, count in counts do
		table.insert(top, { id = id, count = count })
	end
	table.sort(top, function(a, b)
		return a.count > b.count
	end)
	cachedOffers, recent, sold, prices, leaders =
		nextOffers, history, top, estimated, rows("wealth")
	showStalls()
	local plaza = workspace:FindFirstChild("RubyExchange")
	for i, title in { "Recent Sales", "Most Net Worth", "Most Sold • 7 Days" } do
		local lines = { title }
		for j = 1, 5 do
			local line
			if i == 1 and recent[j] then
				line = recent[j].gun.id .. "   ♦ " .. recent[j].price
			elseif i == 2 and leaders[j] then
				local ok, name =
					pcall(Players.GetNameFromUserIdAsync, Players, tonumber(leaders[j].key))
				line = (if ok then name else leaders[j].key) .. "   ♦ " .. leaders[j].value
			elseif i == 3 and sold[j] then
				line = sold[j].id .. "   × " .. sold[j].count
			end
			if line then
				table.insert(lines, line)
			end
		end
		local label = plaza and plaza:FindFirstChild("BoardText" .. i, true)
		if label then
			label.Text = table.concat(lines, "\n")
		end
	end
end
local function checkpoint(player, p)
	PlayerData.markState(player)
	assert(
		PlayerData.marketCheckpoint(player) and PlayerData.get(player) == p,
		"Save pending. Try again shortly."
	)
end
-- The profile reserves the item or payment before the listing record can change.
-- Each side keeps its intent until its own save includes the delivered gun or rubies.
local function settle(player, p, key, intent)
	checkpoint(player, p)
	local o = transact(intent.id, function(old)
		if not old then
			if intent.kind == "sell" then
				return intent.offer
			end
			return nil
		end
		if old.state ~= "open" then
			return old
		end
		if os.time() >= old.expires then
			old.state = "expired"
		elseif
			intent.kind == "buy"
			and old.id == intent.id
			and old.seller ~= player.UserId
			and old.price == intent.price
		then
			old.state = "sold"
			old.buyer = player.UserId
			old.purchase = key
			old.soldAt = os.time()
		elseif intent.cancel and old.seller == player.UserId then
			old.state = "canceled"
		end
		return old
	end)
	assert(PlayerData.get(player) == p, "Player left")
	if not o and intent.kind == "sell" then
		error("Listing unavailable")
	end
	if o then
		includeOffer(o)
		if o.state == "open" then
			if not intent.indexed then
				index("active", o.id, o.expires)
				intent.indexed = true
			end
		else
			if o.state == "sold" then
				index("sales", o.id, o.soldAt)
			end
			index("active", o.id, nil)
		end
	end
	if intent.kind == "sell" and o.state == "open" then
		return
	end
	assert(PlayerData.get(player) == p, "Player left")
	local gun
	local credit = 0
	if intent.kind == "buy" then
		if o and o.purchase == key then
			gun = o.gun
		else
			credit = intent.price
		end
	elseif o.state == "sold" then
		credit = o.price
	else
		gun = o.gun
		credit = if o.state == "canceled" then Balance.listingRefund(o.fee) else 0
	end
	if gun and #p.guns >= Balance.MAX_GUNS then
		intent.pickup = true
		if credit > 0 and not intent.refunded then
			p.rubies += credit
			intent.refunded = true
		end
		checkpoint(player, p)
		return
	end
	if gun then
		local item = table.clone(gun)
		item.uid = PlayerData.newGunUid(p)
		table.insert(p.guns, item)
		p.gunIndex[item.id] = true
	end
	if not intent.refunded then
		p.rubies += credit
	end
	p.marketOrders[key] = nil
	checkpoint(player, p)
end
local function recover(player, p)
	for key, intent in p.marketOrders do
		if intent.kind == "sell" and intent.indexed and not intent.cancel and not intent.pickup then
			local o = read(intent.id)
			if o and o.state == "open" and o.expires > os.time() then
				continue
			end
		end
		settle(player, p, key, intent)
	end
end
local function stationNear(player, key)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local plaza = workspace:FindFirstChild("RubyExchange")
	if not plaza then
		return false
	end
	for _, v in plaza:GetDescendants() do
		if v:IsA("ProximityPrompt") and v:GetAttribute("Station") == key then
			return (root.Position - v.Parent.Position).Magnitude <= 22
		end
	end
	return false
end
local function nearMarket(player)
	if not roomOf[player] then
		return false
	end
	if stationNear(player, "Market") then
		return true
	end
	for i = 1, 8 do
		if stationNear(player, "Stall" .. i) then
			return true
		end
	end
	return false
end
local function worth(p)
	local total = p.rubies
	for _, item in p.guns do
		total += prices[item.id] or 0
	end
	for _, intent in p.marketOrders do
		if intent.kind == "sell" then
			total += prices[intent.offer.gun.id] or 0
		end
	end
	return total
end
local function snapshot(player, p)
	Balance.rubyQuestProgress(p, "", 0)
	local offers = {}
	for _, o in cachedOffers do
		if o.expires > os.time() and roomOf[player] then
			table.insert(offers, o)
		end
	end
	table.sort(offers, function(a, b)
		return a.price < b.price
	end)
	return {
		ok = true,
		room = roomOf[player],
		offers = offers,
		rubies = p.rubies,
		guns = p.guns,
		equipped = p.equipped,
		posts = p.marketPosts,
		orders = p.marketOrders,
		quests = p.rubyQuests,
		recent = recent,
		leaders = leaders,
		sold = sold,
	}
end
local function enter(player, room)
	roomOf[player] = room
	player:SetAttribute("RubyRoom", room)
	local char = player.Character
	if char then
		char:PivotTo(CFrame.new(Plaza.origin + Vector3.new(0, 5, 49)))
	end
end
local function request(player, action, args)
	local p = assert(PlayerData.get(player), "Profile loading")
	if
		action == "post"
		or action == "buy"
		or action == "claim"
		or action == "cancel"
		or action == "pickup"
	then
		assert(
			PlayerData.canTrade(player),
			"Trading requires a saved profile. Rejoin and try again."
		)
	end
	if action == "join" then
		assert(
			stationNear(player, "Join") and integer(args.room, 1, 8),
			"Choose a trading lobby at the gate"
		)
		if studio then
			enter(player, args.room)
		else
			local key = "room" .. args.room
			local code = rooms:GetAsync(key)
			if not code then
				local candidate = TeleportService:ReserveServerAsync(game.PlaceId)
				code = rooms:UpdateAsync(key, function(old)
					return old or candidate
				end)
			end
			checkpoint(player, p)
			local options = Instance.new("TeleportOptions")
			options.ReservedServerAccessCode = code
			options:SetTeleportData({ rubyRoom = args.room })
			TeleportService:TeleportAsync(game.PlaceId, { player }, options)
		end
	elseif action == "exit" then
		assert(stationNear(player, "Exit"), "Use the return gate")
		if studio then
			roomOf[player] = nil
			player:SetAttribute("RubyRoom", nil)
			player.Character:PivotTo(CFrame.new(Plaza.entry + Vector3.new(0, 4, 8)))
		else
			checkpoint(player, p)
			TeleportService:TeleportAsync(game.PlaceId, { player })
		end
	elseif action == "claim" then
		assert(stationNear(player, "Quests"), "Visit the contracts desk")
		Balance.rubyQuestProgress(p, "", 0)
		for kind, goal in Balance.RUBY_QUEST_GOALS do
			if p.rubyQuests[kind] >= goal and not p.rubyQuests.claimed[kind] then
				p.rubyQuests.claimed[kind] = true
				p.rubies += Balance.RUBY_QUEST_REWARDS[kind]
			end
		end
		checkpoint(player, p)
	elseif action == "post" then
		assert(stationNear(player, "Market") and roomOf[player], "Visit the listing computer")
		assert(
			integer(args.days, 1, Balance.TRADE_MAX_DAYS) and integer(args.price, 1, 1000000000),
			"Enter a valid price and duration"
		)
		local gun, slot = PlayerData.findGun(p, args.uid)
		local def = gun and Guns.get(gun.id)
		assert(
			def
				and not gun.locked
				and gun.uid ~= p.equipped
				and gun.id ~= Guns.STARTER_ID
				and not Guns.isLimited(gun.id),
			"This gun cannot be listed"
		)
		local fee = Balance.listingFee(p.marketPosts, def.rarity, args.days)
		assert(args.fee == fee and p.rubies >= fee, "Review the fee and your ruby balance")
		local id = HttpService:GenerateGUID(false)
		local offer = {
			id = id,
			gun = gun,
			price = args.price,
			fee = fee,
			seller = player.UserId,
			name = player.DisplayName,
			room = roomOf[player],
			expires = os.time() + 86400 * args.days,
			state = "open",
		}
		local intent = { kind = "sell", id = id, offer = offer }
		table.remove(p.guns, slot)
		p.rubies -= fee
		p.marketPosts += 1
		p.marketOrders[id] = intent
		settle(player, p, id, intent)
	elseif action == "buy" then
		assert(nearMarket(player), "Visit a stall or the computer")
		local o = cachedOffers[args.id]
		assert(
			o
				and (o.room == roomOf[player] or stationNear(player, "Market"))
				and o.seller ~= player.UserId
				and o.price == args.price
				and o.expires > os.time(),
			"Listing unavailable"
		)
		assert(
			p.rubies >= o.price and #p.guns < Balance.MAX_GUNS,
			"Check your rubies and inventory space"
		)
		local key = HttpService:GenerateGUID(false)
		local intent = { kind = "buy", id = o.id, price = o.price }
		p.rubies -= o.price
		p.marketOrders[key] = intent
		settle(player, p, key, intent)
	elseif action == "cancel" or action == "pickup" then
		assert(nearMarket(player), "Visit the market")
		local intent = p.marketOrders[args.id]
		assert(intent and (action == "pickup" or intent.kind == "sell"), "Listing unavailable")
		if action == "cancel" then
			intent.cancel = true
		end
		settle(player, p, args.id, intent)
	else
		assert(action == "view", "Unknown action")
	end
	return snapshot(player, p)
end
local function onPlayer(player)
	local payload = player:GetJoinData().TeleportData
	if
		game.PrivateServerId ~= ""
		and game.PrivateServerOwnerId == 0
		and typeof(payload) == "table"
		and integer(payload.rubyRoom, 1, 8)
	then
		local function arrive(char)
			if char:WaitForChild("HumanoidRootPart", 10) and player.Character == char then
				enter(player, payload.rubyRoom)
			end
		end
		player.CharacterAdded:Connect(arrive)
		if player.Character then
			task.spawn(arrive, player.Character)
		end
	end
end
local lastWorth = {}
function Market:Start()
	if not preview then
		orders = DataStoreService:GetDataStore("RubyOrders1")
		active = DataStoreService:GetOrderedDataStore("RubyListings1")
		sales = DataStoreService:GetOrderedDataStore("RubySales1")
		wealth = DataStoreService:GetOrderedDataStore("RubyWorth1")
		rooms = DataStoreService:GetDataStore("RubyRooms1")
	end
	remote = Instance.new("RemoteFunction")
	remote.Name = "RubyMarket"
	remote.OnServerInvoke = function(player, action, args)
		if busy[player] or not RateLimit.allow(player, "RubyMarket", 3, 6) then
			return { error = "Please wait a moment." }
		end
		busy[player] = true
		local ok, result =
			pcall(request, player, action, if typeof(args) == "table" then args else {})
		busy[player] = nil
		return if ok
			then result
			else {
				error = tostring(result):match(":%d+: (.+)") or "Market unavailable. Try again.",
			}
	end
	remote.Parent = ReplicatedStorage
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		roomOf[player] = nil
		lastWorth[player] = nil
	end)
	task.spawn(function()
		local lastPrices = -math.huge
		while true do
			local ok, err = true, nil
			if next(roomOf) or (#PlayerData.players() > 0 and os.clock() - lastPrices >= 180) then
				ok, err = pcall(refresh)
				if ok then
					lastPrices = os.clock()
				end
			end
			if not ok then
				warn("Ruby market refresh", err)
			end
			for _, player in PlayerData.players() do
				if busy[player] then
					continue
				end
				busy[player] = true
				local success, reason = pcall(function()
					local p = PlayerData.get(player)
					if p then
						recover(player, p)
						local value = worth(p)
						if lastWorth[player] ~= value and lastPrices > -math.huge then
							index(
								"wealth",
								tostring(player.UserId),
								if value > 0 then value else nil
							)
							lastWorth[player] = value
						end
					end
				end)
				if not success then
					warn("Ruby settlement", reason)
				end
				busy[player] = nil
			end
			task.wait(30)
		end
	end)
end
return Market
