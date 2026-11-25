--!strict
--[[
	Opens a boss chest on screen. Coins pop with a coin toast. An attachment spins a reel of rarity
	cards that slows and stops on the part; Legendary and up then hit the impact frame with a model
	of the part floating in front of the camera.
]]

const Players = game:GetService("Players")
const TweenService = game:GetService("TweenService")

const Attachments = require("@game/ReplicatedStorage/Shared/Attachments")
const Format = require("@game/ReplicatedStorage/Shared/Format")
const Net = require("@game/ReplicatedStorage/Shared/Net")
const Rarity = require("@game/ReplicatedStorage/Shared/Rarity")
const ImpactFrames = require("./Cutscene/ImpactFrames")
const Effects = require("./Effects")
const Kit = require("./UI/Kit")

local ChestReveal = {}

local screen: ScreenGui
local busy = false
local queue: { any } = {}
local random = Random.new()

const CARD = 110
const GAP = 10
const CARDS = 40
-- Where the result sits in the strip; the reel stops with it under the pointer.
const RESULT_INDEX = 34

local function card(parent: Instance, rarity: number, index: number, label: string): Frame
	local def = Rarity.get(rarity)
	local frame = Kit.new("Frame", {
		Size = UDim2.fromOffset(CARD, CARD),
		Position = UDim2.fromOffset((index - 1) * (CARD + GAP), 0),
		BackgroundColor3 = Kit.Colors.Card,
		Parent = parent,
	})
	Kit.corner(12).Parent = frame
	Kit.stroke(4, def.color, Enum.ApplyStrokeMode.Border).Parent = frame
	Kit.gradient(def.color:Lerp(Kit.Colors.Card, 0.35), Kit.Colors.Card).Parent = frame
	Kit.text({
		Text = label,
		Size = UDim2.fromScale(0.9, 0.5),
		Position = UDim2.fromScale(0.05, 0.25),
		TextWrapped = true,
		Stroke = 2,
		Parent = frame,
	})
	return frame
end

-- A small brick model of the part in front of the camera, for the impact frame's silhouette.
local function partModel(rarity: number): Model
	local model = Instance.new("Model")
	local camera = workspace.CurrentCamera
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Material = Enum.Material.Neon
	part.Color = Rarity.get(rarity).color
	part.Size = Vector3.new(1.6, 1, 2.4)
	part.CFrame = camera.CFrame * CFrame.new(0, 0, -9) * CFrame.Angles(0.4, 0.6, 0)
	part.Parent = model
	model.PrimaryPart = part
	model.Parent = workspace
	return model
end

local function showPart(partId: string, rarity: number)
	local def = Attachments.get(partId)
	if not def then
		return
	end
	local holder = Kit.new("Frame", {
		Size = UDim2.new(0.8, 0, 0, CARD + 70),
		Position = UDim2.fromScale(0.5, 0.42),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Kit.Colors.Ink,
		BackgroundTransparency = 0.15,
		ClipsDescendants = true,
		Parent = screen,
	})
	Kit.corner(16).Parent = holder
	Kit.text({
		Text = "🎁 Boss chest: an attachment!",
		Size = UDim2.new(1, 0, 0, 40),
		Stroke = 2.5,
		Parent = holder,
	})
	local strip = Kit.new("Frame", {
		Size = UDim2.fromOffset(CARDS * (CARD + GAP), CARD),
		Position = UDim2.fromOffset(0, 50),
		BackgroundTransparency = 1,
		Parent = holder,
	})
	-- Filler cards follow the reel's own odds, so the strip looks like what it rolls.
	for index = 1, CARDS do
		if index == RESULT_INDEX then
			card(strip, rarity, index, def.name)
		else
			local fake = 1
			local roll = random:NextNumber()
			local running = 0
			for tier, weight in { 0.5, 0.25, 0.15, 0.05, 0.039, 0.01, 0.001 } do
				running += weight
				if roll < running then
					fake = tier
					break
				end
			end
			card(strip, fake, index, Rarity.get(fake).name)
		end
	end
	local pointer = Kit.new("Frame", {
		Size = UDim2.fromOffset(4, CARD + 20),
		Position = UDim2.new(0.5, -2, 0, 40),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 5,
		Parent = holder,
	})
	Kit.corner(2).Parent = pointer
	-- Land the result card's center under the pointer, a little off so it doesn't look scripted.
	local width = holder.AbsoluteSize.X
	local target = width / 2
		- ((RESULT_INDEX - 1) * (CARD + GAP) + CARD / 2)
		+ random:NextNumber(-30, 30)
	local spin = TweenService:Create(
		strip,
		TweenInfo.new(3.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{ Position = UDim2.fromOffset(target, 50) }
	)
	spin:Play()
	for _ = 1, 12 do
		Kit.sound(Kit.Sounds.Click, 0.25, 1.2)
		task.wait(0.12)
	end
	spin.Completed:Wait()
	local rarityDef = Rarity.get(rarity)
	if rarity >= 5 then
		local model = partModel(rarity)
		local world = Instance.new("Folder")
		world.Parent = workspace
		ImpactFrames.play(rarity, model, screen, world, function()
			return holder.Parent ~= nil
		end)
		model:Destroy()
		task.delay(2, function()
			world:Destroy()
		end)
	end
	Kit.sound(Kit.Sounds.Ding, 0.5, 1 + rarity * 0.05)
	Effects.confetti({ rarityDef.color, rarityDef.glow, Color3.new(1, 1, 1) }, 40 + rarity * 20)
	local statName = if def.stat == "power"
		then "Power"
		elseif def.stat == "speed" then "Speed"
		else "Training"
	Effects.toast(
		`{rarityDef.name} {def.name}! +{Format.percent(def.bonus)} {statName} when equipped.`,
		rarityDef.color
	)
	task.wait(2.2)
	holder:Destroy()
	-- Clear anything the impact frame left (the halo, the shade).
	for _, child in screen:GetChildren() do
		child:Destroy()
	end
end

local function open(data: any)
	if typeof(data) ~= "table" then
		return
	end
	if data.kind == "coins" and typeof(data.coins) == "number" then
		Kit.sound(Kit.Sounds.CoinRetro, 0.5)
		Effects.toast(
			`🎁 Boss chest: 💰{Format.abbreviate(data.coins)} coins!`,
			Color3.fromRGB(255, 220, 90)
		)
	elseif
		data.kind == "part"
		and typeof(data.partId) == "string"
		and typeof(data.rarity) == "number"
	then
		showPart(data.partId, data.rarity)
	end
end

function ChestReveal:Init()
	screen = Kit.new("ScreenGui", {
		Name = "ChestReveal",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 25,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
end

function ChestReveal:Start()
	Net.event("ChestOpened").OnClientEvent:Connect(function(data)
		table.insert(queue, data)
		if busy then
			return
		end
		busy = true
		while #queue > 0 do
			open(table.remove(queue, 1))
		end
		busy = false
	end)
end

return ChestReveal
