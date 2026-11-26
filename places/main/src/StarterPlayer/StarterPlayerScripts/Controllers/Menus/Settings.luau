--!strict

--[[
	Settings: auto mode on joining and leaving a stage, auto skip between waves, effect and music
	volume, and a box for codes. Choices save to the profile; volumes apply to the Sfx and music
	sound groups as soon as the profile arrives, and live while a slider is dragged.
]]

const UserInputService = game:GetService("UserInputService")

const Net = require("@game/ReplicatedStorage/Shared/Net")
const Types = require("@game/ReplicatedStorage/Shared/Types")
const ClientState = require("../ClientState")
const Kit = require("../UI/Kit")
const Menus = require("../Menus")

local SettingsMenu = {}

type Toggle = { key: string, button: TextButton }
type Slider = { key: string, fill: Frame, knob: Frame, value: TextLabel }

local toggles: { Toggle } = {}
local sliders: { Slider } = {}
local dragging: Slider? = nil
local codeBox: TextBox
local built = false

local function settings(): Types.Settings?
	local profile = ClientState.profile
	return profile and profile.settings
end

local function applyVolumes()
	local current = settings()
	if current then
		Kit.SfxGroup.Volume = current.sfx
		Kit.MusicGroup.Volume = current.music
	end
end

local function paintToggle(toggle: Toggle, on: boolean)
	if on then
		Kit.setButtonColor(toggle.button, Kit.Colors.Green, Kit.Colors.GreenDark)
		Kit.setButtonText(toggle.button, "ON")
	else
		Kit.setButtonColor(toggle.button, Kit.Colors.Grey, Kit.Colors.GreyDark)
		Kit.setButtonText(toggle.button, "OFF")
	end
end

local function paintSlider(slider: Slider, value: number)
	slider.fill.Size = UDim2.fromScale(value, 1)
	slider.knob.Position = UDim2.fromScale(value, 0.5)
	slider.value.Text = `{math.floor(value * 100 + 0.5)}%`
end

local function refresh()
	local current = settings() :: any
	if not built or not current then
		return
	end
	for _, toggle in toggles do
		paintToggle(toggle, current[toggle.key] == true)
	end
	for _, slider in sliders do
		if slider ~= dragging then
			paintSlider(slider, current[slider.key] or 1)
		end
	end
end

local function row(content: Frame, order: number, title: string, hint: string): Frame
	local frame = Kit.new("Frame", {
		BackgroundColor3 = Kit.Colors.Card,
		Position = UDim2.fromScale(0.03, 0.02 + (order - 1) * 0.155),
		Size = UDim2.fromScale(0.94, 0.135),
		Parent = content,
	})
	Kit.corner(12).Parent = frame
	Kit.stroke(2, Kit.Colors.Ink, Enum.ApplyStrokeMode.Border).Parent = frame
	Kit.text({
		Text = title,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromScale(0.04, 0.1),
		Size = UDim2.fromScale(0.55, 0.45),
		Parent = frame,
	})
	Kit.text({
		Text = hint,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(190, 205, 225),
		Position = UDim2.fromScale(0.04, 0.56),
		Size = UDim2.fromScale(0.58, 0.32),
		Stroke = 1.5,
		Gradient = false,
		Parent = frame,
	})
	return frame
end

local function addToggle(content: Frame, order: number, key: string, title: string, hint: string)
	local frame = row(content, order, title, hint)
	local toggle: Toggle
	local button = Kit.button({
		name = key,
		color = Kit.Colors.Grey,
		dark = Kit.Colors.GreyDark,
		size = UDim2.fromScale(0.22, 0.62),
		position = UDim2.fromScale(0.74, 0.19),
		text = "OFF",
		parent = frame,
		onClick = function()
			local current = settings() :: any
			if not current then
				return
			end
			current[key] = not current[key]
			paintToggle(toggle, current[key])
			Net.event("SaveSetting"):FireServer(key, current[key])
		end,
	})
	toggle = { key = key, button = button }
	table.insert(toggles, toggle)
end

local function addSlider(content: Frame, order: number, key: string, title: string, hint: string)
	local frame = row(content, order, title, hint)
	local track = Kit.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(30, 34, 50),
		Position = UDim2.fromScale(0.6, 0.42),
		Size = UDim2.fromScale(0.26, 0.18),
		Active = true,
		Parent = frame,
	})
	Kit.cornerScale(0.5).Parent = track
	local fill = Kit.new("Frame", {
		BackgroundColor3 = Kit.Colors.Blue,
		Size = UDim2.fromScale(1, 1),
		Parent = track,
	})
	Kit.cornerScale(0.5).Parent = fill
	local knob = Kit.new("Frame", {
		BackgroundColor3 = Kit.Colors.White,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromScale(2.2, 2.2),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		Parent = track,
	})
	Kit.cornerScale(0.5).Parent = knob
	Kit.stroke(2, Kit.Colors.Ink, Enum.ApplyStrokeMode.Border).Parent = knob
	local value = Kit.text({
		Text = "100%",
		Position = UDim2.fromScale(0.88, 0.25),
		Size = UDim2.fromScale(0.1, 0.5),
		Stroke = 1.5,
		Parent = frame,
	})
	local slider: Slider = { key = key, fill = fill, knob = knob, value = value }
	table.insert(sliders, slider)

	local function setFrom(x: number)
		local share = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		share = math.floor(share * 100 + 0.5) / 100
		paintSlider(slider, share)
		local current = settings() :: any
		if current then
			current[key] = share
			applyVolumes()
		end
	end
	track.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = slider
			setFrom(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if
			dragging == slider
			and (
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			setFrom(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if
			dragging == slider
			and (
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			dragging = nil
			local current = settings() :: any
			if current then
				Net.event("SaveSetting"):FireServer(key, current[key])
			end
		end
	end)
end

local function build(content: Frame)
	built = true
	addToggle(
		content,
		1,
		"autoMode",
		"🤖 Auto Auto Mode",
		"Turn auto mode on when a stage starts, off when you leave"
	)
	addToggle(
		content,
		2,
		"autoSkip",
		"⏩ Auto Skip Wave",
		"Skip the wait between stages and waves right away"
	)
	addSlider(content, 3, "sfx", "🔊 Sound Effects", "Shots, hits, and menu sounds")
	addSlider(content, 4, "music", "🎵 Music", "Lobby and Gauntlet tracks")
	local frame = row(content, 5, "🎟️ Codes", "Type a code and press Redeem")
	codeBox = Kit.new("TextBox", {
		Text = "",
		PlaceholderText = "Enter code",
		ClearTextOnFocus = false,
		FontFace = Kit.FONT,
		TextScaled = true,
		TextColor3 = Kit.Colors.White,
		PlaceholderColor3 = Color3.fromRGB(140, 150, 170),
		BackgroundColor3 = Color3.fromRGB(30, 34, 50),
		Position = UDim2.fromScale(0.42, 0.2),
		Size = UDim2.fromScale(0.32, 0.6),
		Parent = frame,
	})
	Kit.corner(8).Parent = codeBox
	Kit.paddingScale(0.08).Parent = codeBox
	Kit.button({
		name = "Redeem",
		color = Kit.Colors.Gold,
		dark = Kit.Colors.GoldDark,
		size = UDim2.fromScale(0.2, 0.6),
		position = UDim2.fromScale(0.77, 0.2),
		text = "Redeem",
		parent = frame,
		onClick = function()
			if codeBox.Text ~= "" then
				Net.event("RedeemCode"):FireServer(codeBox.Text)
				codeBox.Text = ""
			end
		end,
	})
	refresh()
end

function SettingsMenu:Init()
	Menus.register({
		name = "Settings",
		title = "⚙️ Settings",
		color = Kit.Colors.Grey,
		size = Vector2.new(0.46, 0.66),
		build = build,
		onOpen = refresh,
	})
end

function SettingsMenu:Start()
	ClientState.ProfileChanged:Connect(function()
		applyVolumes()
		if Menus.isOpen("Settings") then
			refresh()
		end
	end)
	applyVolumes()
end

return SettingsMenu
