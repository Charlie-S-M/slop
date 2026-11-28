--!strict

-- After every few forges, once the cutscene has handed the screen back, suggests the Auto Perfect
-- Forge pass to players who don't own it.

const Players = game:GetService("Players")

const Balance = require("@game/ReplicatedStorage/Shared/Balance")
const Net = require("@game/ReplicatedStorage/Shared/Net")
const Products = require("@game/ReplicatedStorage/Shared/Products")
const ClientState = require("./ClientState")
const Kit = require("./UI/Kit")
const Menus = require("./Menus")
const Purchases = require("./UI/Purchases")

const PASS = "AutoPerfectForge"
const MENU = "ForgeOffer"

local ForgeOffer = {}

-- The forge count the last suggestion was for, so one forge never raises it twice.
local offeredAt = 0

local function owned(): boolean
	return Players.LocalPlayer:GetAttribute(`Pass_{PASS}`) == true
end

local function build(content: Frame)
	const def = Products.get(PASS)
	if not def then
		return
	end
	local art = Kit.new("ImageLabel", {
		Name = "HammerArt",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.01),
		Size = UDim2.fromScale(0.94, 0.46),
		Image = "rbxassetid://121386565174730",
		ScaleType = Enum.ScaleType.Crop,
		BackgroundColor3 = Color3.fromRGB(53, 21, 79),
		Parent = content,
	})
	Kit.aspect(1).Parent = art
	Kit.corner(10).Parent = art
	Kit.stroke(2, Kit.Colors.Gold).Parent = art
	Kit.text({
		Text = "Auto Perfect Forge",
		Position = UDim2.fromScale(0.03, 0.47),
		Size = UDim2.fromScale(0.94, 0.15),
		Stroke = 2.5,
		Parent = content,
	})
	Kit.text({
		Text = "Automatically land a perfect strike on every forge.",
		Position = UDim2.fromScale(0.06, 0.63),
		Size = UDim2.fromScale(0.88, 0.1),
		TextColor3 = Color3.fromRGB(190, 205, 225),
		Stroke = 1.5,
		Gradient = false,
		Parent = content,
	})
	Kit.button({
		name = "Buy",
		color = Kit.Colors.Green,
		dark = Kit.Colors.GreenDark,
		size = UDim2.fromScale(0.46, 0.2),
		position = UDim2.fromScale(0.5, 0.78),
		text = `R$ {def.price}`,
		parent = content,
		onClick = function()
			Menus.close()
			Purchases.prompt(PASS)
		end,
	})
	Kit.button({
		name = "NotNow",
		color = Kit.Colors.Grey,
		dark = Kit.Colors.GreyDark,
		size = UDim2.fromScale(0.36, 0.2),
		position = UDim2.fromScale(0.08, 0.78),
		text = "Not now",
		parent = content,
		onClick = function()
			Menus.close()
		end,
	})
end

local function suggestWhenFree()
	-- The cutscene holds the camera until the player takes the reveal.
	while Players.LocalPlayer:GetAttribute("ForgeCamera") do
		task.wait(0.2)
	end
	task.wait(0.35)
	const profile = ClientState.profile
	if
		not profile
		or profile.forges == offeredAt
		or not Balance.recommendsAutoPerfect(profile.forges, owned())
		or Players.LocalPlayer:GetAttribute("InRun")
		or Players.LocalPlayer:GetAttribute("ForgeCamera")
	then
		return
	end
	offeredAt = profile.forges
	Menus.open(MENU)
end

function ForgeOffer:Init()
	Menus.register({
		name = MENU,
		title = "\u{2B50} Forge Tip",
		color = Kit.Colors.Gold,
		size = Vector2.new(0.42, 0.58),
		build = build,
	})
end

function ForgeOffer:Start()
	Net.event("ForgeResult").OnClientEvent:Connect(function()
		task.spawn(suggestWhenFree)
	end)
end

return ForgeOffer
