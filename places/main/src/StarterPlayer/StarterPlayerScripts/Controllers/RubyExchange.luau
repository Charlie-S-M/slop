--!nonstrict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Prompts = game:GetService("ProximityPromptService")
local Kit = require("./UI/Kit")
local Balance = require("@game/ReplicatedStorage/Shared/Balance")
local Guns = require("@game/ReplicatedStorage/Shared/Guns")
local Rarity = require("@game/ReplicatedStorage/Shared/Rarity")
local player = Players.LocalPlayer
local RubyExchange = {}
local gui, panel, header, body, tabs, message, remote
local state, page, station, selected, days, priceText, query
local busy = false
local transition
local function loading(room)
	local overlay = Instance.new("ScreenGui")
	overlay.Name = "RubyCrossing"
	overlay.IgnoreGuiInset = true
	overlay.DisplayOrder = 180
	overlay.ResetOnSpawn = false
	local field = Instance.new("Frame")
	field.Size = UDim2.fromScale(1, 1)
	field.BackgroundColor3 = Color3.new(1, 1, 1)
	field.Parent = overlay
	Kit.gradient(Color3.fromRGB(121, 29, 76), Color3.fromRGB(30, 19, 46), 65).Parent = field
	local track = Kit.new("Frame", {
		Size = UDim2.fromScale(0.54, 0.024),
		Position = UDim2.fromScale(0.23, 0.745),
		BackgroundColor3 = Color3.fromRGB(38, 22, 48),
		BorderSizePixel = 0,
		Parent = field,
	})
	Kit.cornerScale(0.5).Parent = track
	local glint = Kit.new("Frame", {
		Size = UDim2.fromScale(0.26, 1),
		BackgroundColor3 = Color3.fromRGB(255, 193, 107),
		BorderSizePixel = 0,
		Parent = track,
	})
	Kit.cornerScale(0.5).Parent = glint
	game:GetService("TweenService")
		:Create(
			glint,
			TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Position = UDim2.fromScale(0.74, 0) }
		)
		:Play()
	local function caption(value, y, h, color)
		return Kit.text({
			Text = value,
			TextColor3 = color,
			Size = UDim2.fromScale(0.8, h),
			Position = UDim2.fromScale(0.1, y),
			Stroke = 3,
			Parent = field,
		})
	end
	caption("♦", 0.12, 0.34, Color3.fromRGB(255, 74, 115))
	caption("Ruby Exchange", 0.48, 0.12, Color3.fromRGB(255, 229, 178))
	caption("Joining trading lobby " .. room .. "…", 0.66, 0.06, Color3.fromRGB(235, 219, 247))
	caption("Your first two listings are free.", 0.81, 0.05, Color3.fromRGB(226, 194, 217))
	game:GetService("TeleportService"):SetTeleportGui(overlay)
	overlay.Parent = player.PlayerGui
	return overlay
end
local ruby = Color3.fromRGB(207, 41, 85)
local plum = Color3.fromRGB(68, 48, 83)
local cream = Color3.fromRGB(255, 230, 192)
local function new(class, props)
	return Kit.new(class, props)
end
local function round(frame)
	Kit.corner(10).Parent = frame
end
local function text(parent, value, size)
	return Kit.text({ Text = value, Size = size, Stroke = 1.8, MaxTextSize = 20, Parent = parent })
end
local function button(parent, value, fn, color)
	local b = new("TextButton", {
		Size = UDim2.new(1, -8, 0, 48),
		BackgroundColor3 = color or plum,
		Font = Enum.Font.FredokaOne,
		TextSize = 17,
		TextWrapped = true,
		TextColor3 = cream,
		Text = value,
		Parent = parent,
	})
	round(b)
	b.Activated:Connect(fn)
	return b
end
local function clear(frame)
	for _, v in frame:GetChildren() do
		if v:IsA("GuiObject") then
			v:Destroy()
		end
	end
end
local function box(parent, value, placeholder)
	local b = new("TextBox", {
		Size = UDim2.new(1, -8, 0, 44),
		Text = value,
		PlaceholderText = placeholder,
		ClearTextOnFocus = false,
		Font = Enum.Font.FredokaOne,
		TextSize = 17,
		TextColor3 = cream,
		BackgroundColor3 = plum,
		Parent = parent,
	})
	round(b)
	return b
end
local function line(value)
	local t = text(body, value, UDim2.new(1, -8, 0, 44))
	t.TextWrapped = true
	return t
end
local function call(action, args)
	if busy then
		return false
	end
	busy = true
	local ok, data = pcall(remote.InvokeServer, remote, action, args or {})
	busy = false
	if not ok or not data or data.error then
		message.Text = if ok and data then data.error else "Market unavailable. Try again."
		return false
	end
	state = data
	return true
end
local function details(g)
	local def = Guns.get(g.id)
	local parts = {}
	for slot, id in g.parts or {} do
		table.insert(parts, slot .. " • " .. id)
	end
	table.sort(parts)
	return def.name
		.. "  ·  "
		.. Rarity.get(def.rarity).name
		.. "  ·  Grade "
		.. g.grade
		.. "\nPower "
		.. string.format("%.3g", g.power)
		.. "   Speed "
		.. string.format("%.3g", g.speed)
		.. "   Training "
		.. string.format("%.3g", g.train)
		.. (if #parts > 0 then "\n" .. table.concat(parts, ", ") else "")
end
local render
local function perform(action, args, nextPage)
	if call(action, args) then
		page = nextPage or page
		selected = nil
		render()
	end
end
local function switch(nextPage)
	page = nextPage
	selected = nil
	render()
end
local function tab(value, dest)
	local b = button(tabs, value, function()
		switch(dest)
	end, if page == dest then ruby else plum)
	b.Size = UDim2.fromScale(0.24, 1)
end
local function remaining(expires)
	return math.max(0, math.ceil((expires - os.time()) / 3600)) .. "h left"
end
render = function()
	clear(body)
	clear(tabs)
	body.CanvasPosition = Vector2.zero
	message.Text = ""
	header.Text = "Ruby Exchange   ♦ " .. state.rubies
	if station == "Market" or station:match("^Stall") then
		tab("Browse", "Browse")
		tab("List a gun", "Sell")
		tab("My listings", "Mine")
		tab("Refresh", "Refresh")
	end
	if page == "Refresh" then
		page = "Browse"
		if call("view") then
			render()
		end
	elseif page == "Join" then
		header.Text = "Trading lobbies"
		line("Choose the same lobby as a friend to browse together.")
		for i = 1, 8 do
			button(body, "Join trading lobby " .. i, function()
				transition = loading(i)
				clear(body)
				header.Text = "Ruby Exchange"
				local gem = line("♦")
				gem.TextColor3 = Color3.fromRGB(255, 70, 115)
				line("Opening the trading lobby…")
				if call("join", { room = i }) then
					gui.Enabled = false
					if game:GetService("RunService"):IsStudio() then
						task.wait(0.6)
						transition:Destroy()
						transition = nil
					end
				else
					transition:Destroy()
					transition = nil
					local reason = message.Text
					render()
					message.Text = reason
				end
			end)
		end
	elseif page == "Exit" then
		button(body, "Return to the forge", function()
			if call("exit") then
				gui.Enabled = false
			end
		end)
	elseif page == "Browse" then
		local search = box(body, query, "Search by gun or seller")
		search.FocusLost:Connect(function()
			query = search.Text
			render()
		end)
		local count = 0
		local sellers = {}
		for _, o in state.offers do
			if o.room == state.room and not table.find(sellers, o.seller) then
				table.insert(sellers, o.seller)
			end
		end
		table.sort(sellers)
		local stall = tonumber(station:match("^Stall(%d+)"))
		for _, o in state.offers do
			local def = Guns.get(o.gun.id)
			if stall and o.room ~= state.room then
				continue
			end
			if stall and (((table.find(sellers, o.seller) or 1) - 1) % 8 + 1) ~= stall then
				continue
			end
			if not (def.name .. " " .. o.name):lower():find(query:lower(), 1, true) then
				continue
			end
			count += 1
			button(body, def.name .. "  ·  " .. o.name .. "  ·  ♦ " .. o.price, function()
				selected = o
				page = "Buy"
				render()
			end)
		end
		if count == 0 then
			line("No matching listings here yet.")
		end
	elseif page == "Buy" then
		line(details(selected.gun)).Size = UDim2.new(1, -8, 0, 86)
		line("Seller: " .. selected.name .. "   ·   " .. remaining(selected.expires))
		button(body, "Buy for ♦ " .. selected.price, function()
			perform("buy", { id = selected.id, price = selected.price }, "Browse")
		end, ruby)
	elseif page == "Sell" then
		if station ~= "Market" then
			line("Visit the market computer to post a gun.")
			return
		end
		line("Choose a gun to list.")
		for _, g in state.guns do
			if
				g.locked
				or g.uid == state.equipped
				or g.id == Guns.STARTER_ID
				or Guns.isLimited(g.id)
			then
				continue
			end
			button(body, assert(Guns.get(g.id)).name .. "  ·  Grade " .. g.grade, function()
				selected = g
				days = 1
				priceText = ""
				page = "Price"
				render()
			end)
		end
	elseif page == "Price" then
		line(details(selected)).Size = UDim2.new(1, -8, 0, 80)
		local input = box(body, priceText, "Asking price in rubies")
		input:GetPropertyChangedSignal("Text"):Connect(function()
			priceText = input.Text
		end)
		button(body, "Duration: " .. days .. " day(s)   ›", function()
			days = days % Balance.TRADE_MAX_DAYS + 1
			render()
		end)
		local fee = Balance.listingFee(state.posts, assert(Guns.get(selected.id)).rarity, days)
		line(
			if state.posts < 2
				then "Free lifetime listing " .. (state.posts + 1) .. " of 2. Used when posted."
				else "Prepaid fee: ♦ "
					.. fee
					.. " for "
					.. days
					.. " day(s). Cancel early for ♦ "
					.. Balance.listingRefund(fee)
					.. "."
		)
		button(body, "List for ♦ " .. fee, function()
			local price = tonumber(input.Text)
			if not price or price < 1 or price % 1 ~= 0 then
				message.Text = "Enter a positive whole-ruby price."
				return
			end
			perform("post", { uid = selected.uid, days = days, price = price, fee = fee }, "Mine")
		end, ruby)
	elseif page == "Mine" then
		local count = 0
		for key, intent in state.orders do
			count += 1
			if intent.pickup then
				button(body, "Collect returned or purchased gun", function()
					perform("pickup", { id = key }, "Mine")
				end)
			elseif intent.kind == "sell" then
				local o = intent.offer
				button(
					body,
					assert(Guns.get(o.gun.id)).name
						.. "   ♦ "
						.. o.price
						.. "   "
						.. remaining(o.expires),
					function()
						selected = intent
						page = "Cancel"
						render()
					end
				)
			else
				line("Purchase settling…")
			end
		end
		if count == 0 then
			line("You have no active listings or pickups.")
		end
	elseif page == "Cancel" then
		local o = selected.offer
		line(details(o.gun))
		line(
			"Paid ♦ "
				.. o.fee
				.. " for the full listing. Canceling returns the gun and half the fee."
		)
		button(
			body,
			"Cancel listing · Get ♦ " .. Balance.listingRefund(o.fee) .. " back",
			function()
				perform("cancel", { id = o.id }, "Mine")
			end,
			ruby
		)
	elseif page == "Quests" then
		header.Text = "Daily ruby contracts   ♦ " .. state.rubies
		for kind, title in
			{
				bosses = "Defeat bosses",
				forges = "Forge equipment",
				veterans = "Defeat mobs at stage " .. Balance.RUBY_VETERAN_STAGE .. "+",
			}
		do
			line(
				title
					.. "   "
					.. state.quests[kind]
					.. "/"
					.. Balance.RUBY_QUEST_GOALS[kind]
					.. "   ·   "
					.. (
						if state.quests.claimed[kind]
							then "Claimed"
							else "♦ " .. Balance.RUBY_QUEST_REWARDS[kind]
					)
			)
		end
		button(body, "Claim completed contracts", function()
			perform("claim", {}, "Quests")
		end, ruby)
	elseif page:match("^Board") then
		local label = workspace.RubyExchange:FindFirstChild("BoardText" .. page:sub(-1), true)
		if label then
			line(label.Text).Size = UDim2.new(1, -8, 0, 240)
		end
	end
end
function RubyExchange:Start()
	game:GetService("TeleportService").TeleportInitFailed:Connect(function(who)
		if who == player and transition then
			transition:Destroy()
			transition = nil
			gui.Enabled = true
			message.Text = "Lobby unavailable. Choose another lobby or retry."
		end
	end)
	remote = ReplicatedStorage:WaitForChild("RubyMarket")
	gui = new("ScreenGui", {
		Name = "RubyExchange",
		Enabled = false,
		ResetOnSpawn = false,
		DisplayOrder = 35,
		Parent = player.PlayerGui,
	})
	panel = Kit.panel({
		Size = UDim2.fromScale(0.78, 0.78),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Parent = gui,
	})
	new("UISizeConstraint", { MaxSize = Vector2.new(720, 580), Parent = panel })
	header = text(panel, "Ruby Exchange", UDim2.fromScale(0.82, 0.12))
	header.TextColor3 = cream
	local close = button(panel, "×", function()
		gui.Enabled = false
	end, ruby)
	close.Position = UDim2.fromScale(0.9, 0.02)
	close.Size = UDim2.fromScale(0.08, 0.09)
	tabs = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(0.94, 0.095),
		Position = UDim2.fromScale(0.03, 0.13),
		Parent = panel,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0.01, 0),
		Parent = tabs,
	})
	body = new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0.94, 0.66),
		Position = UDim2.fromScale(0.03, 0.25),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		Parent = panel,
	})
	new(
		"UIListLayout",
		{ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 7), Parent = body }
	)
	message = text(panel, "", UDim2.fromScale(0.94, 0.08))
	message.Position = UDim2.fromScale(0.03, 0.91)
	Prompts.PromptTriggered:Connect(function(prompt)
		if prompt.Name ~= "RubyStation" then
			return
		end
		station = prompt:GetAttribute("Station")
		query = ""
		selected = nil
		gui.Enabled = true
		if call("view") then
			page = if station == "Market" or station:match("^Stall") then "Browse" else station
			render()
		end
	end)
end
return RubyExchange
