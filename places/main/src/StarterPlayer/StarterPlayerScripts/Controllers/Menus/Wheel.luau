--!strict

--[[
	The Lucky Wheel, opened at the wheel stand west of the spawn. Spin uses the daily free spin
	first, then paid spins. The server picks the prize; the wheel spins five turns and eases out
	onto it, then the prize is announced. Paid spins come in packs of 1, 3, and 10.
]]

const RunService = game:GetService("RunService")
const TweenService = game:GetService("TweenService")

const Format = require("@game/ReplicatedStorage/Shared/Format")
const Net = require("@game/ReplicatedStorage/Shared/Net")
const Products = require("@game/ReplicatedStorage/Shared/Products")
const Wheel = require("@game/ReplicatedStorage/Shared/Wheel")
const ClientState = require("../ClientState")
const Effects = require("../Effects")
const Kit = require("../UI/Kit")
const Purchases = require("../UI/Purchases")
const Menus = require("../Menus")

local WheelMenu = {}

const SLICE = 360 / #Wheel.PRIZES
const RED = Color3.fromRGB(225, 50, 60)
const CREAM = Color3.fromRGB(250, 235, 205)
const SPIN_TIME = 4.5

local built = false
-- Each prize tile and its slice's angle, to keep the tiles upright as the wheel turns.
local tiles: { { frame: Frame, angle: number } } = {}
local spinning = false
local wheel: Frame
local spinButton: TextButton
local pityLabel: TextLabel

local function refresh()
	local profile = ClientState.profile
	if not built or not profile then
		return
	end
	local free = Wheel.freeReady(profile.lastWheel, os.time())
	if spinning then
		Kit.setButtonText(spinButton, "Spinning...")
	elseif free then
		Kit.setButtonText(spinButton, "Free Spin!")
	elseif profile.wheelSpins > 0 then
		Kit.setButtonText(spinButton, `Spin ({profile.wheelSpins})`)
	else
		local wait = Wheel.FREE_COOLDOWN - (os.time() - profile.lastWheel)
		Kit.setButtonText(spinButton, `Free in {Format.duration(wait)}`)
	end
	local ready = not spinning and (free or profile.wheelSpins > 0)
	if ready then
		Kit.setButtonColor(spinButton, Kit.Colors.Green, Kit.Colors.GreenDark)
	else
		Kit.setButtonColor(spinButton, Kit.Colors.Grey, Kit.Colors.GreyDark)
	end
	pityLabel.Text = `Exclusive in {Wheel.PITY - profile.wheelPity}`
end

local function slice(index: number)
	local prize = Wheel.PRIZES[index]
	local angle = (index - 1) * SLICE
	-- Frames turn around their own middle, so each slice is drawn in a frame the size of the
	-- wheel and turned by its angle: the spoke and the prize sit along its top half.
	local function turned(rotation: number): Frame
		return Kit.new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Rotation = rotation,
			Parent = wheel,
		})
	end
	-- A spoke between this slice and the next.
	Kit.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(200, 150, 40),
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.02),
		Size = UDim2.fromScale(0.012, 0.48),
		Parent = turned(angle + SLICE / 2),
	})
	-- The slice's prize, read from the rim inward.
	-- Square tiles out near the rim, small enough that neighbors never touch. Each one is turned
	-- back against the wheel every frame, so its text always reads right side up.
	local tile = Kit.new("Frame", {
		BackgroundColor3 = if index % 2 == 1 then RED else CREAM,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.155),
		Size = UDim2.fromScale(0.2, 0.2),
		SizeConstraint = Enum.SizeConstraint.RelativeXX,
		Parent = turned(angle),
	})
	table.insert(tiles, { frame = tile, angle = angle })
	Kit.corner(14).Parent = tile
	Kit.stroke(2, Color3.fromRGB(150, 100, 30), Enum.ApplyStrokeMode.Border).Parent = tile
	local text = if index % 2 == 1 then Kit.Colors.White else Color3.fromRGB(110, 40, 40)
	Kit.text({
		Text = prize.glyph,
		Size = UDim2.fromScale(0.8, 0.42),
		Position = UDim2.fromScale(0.1, 0.04),
		Stroke = 0,
		Gradient = false,
		FontFace = Kit.FONT_BODY,
		Parent = tile,
	})
	Kit.text({
		Text = prize.label,
		Size = UDim2.fromScale(0.92, 0.24),
		Position = UDim2.fromScale(0.04, 0.46),
		TextColor3 = text,
		Stroke = if index % 2 == 1 then 2 else 0,
		Gradient = false,
		Parent = tile,
	})
	Kit.text({
		Text = `{prize.weight}%`,
		Size = UDim2.fromScale(0.7, 0.22),
		Position = UDim2.fromScale(0.15, 0.72),
		TextColor3 = text,
		Stroke = if index % 2 == 1 then 2 else 0,
		Gradient = false,
		Parent = tile,
	})
end

local function build(content: Frame)
	built = true
	local face = Kit.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(240, 190, 60),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.06),
		Size = UDim2.fromScale(0.7, 0.7),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		Parent = content,
	})
	Kit.cornerScale(0.5).Parent = face
	Kit.stroke(5, Color3.fromRGB(140, 90, 20), Enum.ApplyStrokeMode.Border).Parent = face
	wheel = Kit.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(255, 245, 225),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.92, 0.92),
		Parent = face,
	})
	Kit.cornerScale(0.5).Parent = wheel
	for index in Wheel.PRIZES do
		slice(index)
	end
	local hub = Kit.new("Frame", {
		BackgroundColor3 = RED,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.16, 0.16),
		Parent = face,
	})
	Kit.cornerScale(0.5).Parent = hub
	Kit.stroke(5, Color3.fromRGB(240, 190, 60), Enum.ApplyStrokeMode.Border).Parent = hub
	-- The pointer at the top that marks the prize.
	Kit.text({
		Text = "▼",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.02),
		Size = UDim2.fromScale(0.12, 0.12),
		TextColor3 = RED,
		Stroke = 3,
		Gradient = false,
		ZIndex = 5,
		Parent = face,
	})
	pityLabel = Kit.text({
		Text = "",
		Position = UDim2.fromScale(0.02, 0.02),
		Size = UDim2.fromScale(0.3, 0.07),
		TextColor3 = Color3.fromRGB(255, 120, 200),
		Stroke = 3,
		Parent = content,
	})
	local packs = { "WheelSpin1", "WheelSpin3", "", "WheelSpin10" }
	for index, key in packs do
		local position = UDim2.fromScale(0.02 + (index - 1) * 0.245, 0.83)
		if key == "" then
			spinButton = Kit.button({
				name = "Spin",
				color = Kit.Colors.Green,
				dark = Kit.Colors.GreenDark,
				size = UDim2.fromScale(0.23, 0.14),
				position = position,
				text = "Spin",
				parent = content,
				onClick = function()
					if not spinning then
						Net.event("SpinWheel"):FireServer()
					end
				end,
			})
		else
			local def = Products.get(key)
			Kit.button({
				name = key,
				color = Kit.Colors.Gold,
				dark = Kit.Colors.GoldDark,
				size = UDim2.fromScale(0.23, 0.14),
				position = position,
				text = if def then `R$ {def.price}  ·  {def.name}` else key,
				parent = content,
				onClick = function()
					Purchases.prompt(key)
				end,
			})
		end
	end
	refresh()
	RunService.RenderStepped:Connect(function()
		if Menus.isOpen("Wheel") then
			for _, tile in tiles do
				tile.frame.Rotation = -(tile.angle + wheel.Rotation)
			end
		end
	end)
	task.spawn(function()
		while content.Parent do
			if Menus.isOpen("Wheel") then
				refresh()
			end
			task.wait(1)
		end
	end)
end

-- Spins five turns and eases out with the prize under the pointer, then announces it.
local function land(index: number)
	if not built then
		return
	end
	spinning = true
	refresh()
	local angle = (index - 1) * SLICE
	local start = wheel.Rotation
	local base = start + 360 * 5
	local target = base - ((base + angle) % 360)
	local tween = TweenService:Create(
		wheel,
		TweenInfo.new(SPIN_TIME, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{ Rotation = target }
	)
	tween.Completed:Once(function()
		wheel.Rotation = target % 360
		spinning = false
		refresh()
		local prize = Wheel.PRIZES[index]
		Kit.sound(Kit.Sounds.Coin, 0.6)
		if index == Wheel.EXCLUSIVE then
			Effects.banner(
				"🎰 JACKPOT!",
				Color3.fromRGB(255, 120, 200),
				Color3.fromRGB(255, 210, 60),
				"Jackpot Blaster is yours!"
			)
		else
			Effects.toast(
				`🎡 You won: {prize.glyph} {prize.label}!`,
				Color3.fromRGB(255, 215, 80)
			)
		end
	end)
	tween:Play()
end

function WheelMenu:Init()
	Menus.register({
		name = "Wheel",
		title = "🎡 Lucky Wheel",
		color = Kit.Colors.Red,
		size = Vector2.new(0.6, 0.86),
		build = build,
		onOpen = refresh,
	})
end

function WheelMenu:Start()
	Net.event("WheelResult").OnClientEvent:Connect(function(index: number)
		if typeof(index) == "number" and Wheel.PRIZES[index] then
			land(index)
		end
	end)
	ClientState.ProfileChanged:Connect(function()
		if Menus.isOpen("Wheel") then
			refresh()
		end
	end)
end

return WheelMenu
