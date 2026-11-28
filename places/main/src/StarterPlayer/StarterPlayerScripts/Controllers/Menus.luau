--!strict

--[[
	Opens and closes the game's menu windows, one at a time. Each menu module registers a builder in
	its Init; the HUD and world prompts call Menus.open(name). Windows share one frame style: a title
	badge over the top-left corner, a red close button, and a bouncy open animation.
]]

const Lighting = game:GetService("Lighting")
const Players = game:GetService("Players")
const TweenService = game:GetService("TweenService")
const UserInputService = game:GetService("UserInputService")

const Kit = require("./UI/Kit")
const Signal = require("@game/ReplicatedStorage/Shared/Signal")

export type MenuSpec = {
	name: string,
	title: string,
	color: Color3,
	-- Window size as a share of the screen; the window keeps this aspect ratio.
	size: Vector2,
	build: (content: Frame) -> (),
	onOpen: (() -> ())?,
	onClose: (() -> ())?,
}

type Window = { spec: MenuSpec, root: Frame, scale: UIScale, built: boolean, content: Frame }

local Menus = {}

Menus.Opened = Signal.new() :: Signal.Signal<string?>

local screen: ScreenGui
local windows: { [string]: Window } = {}
local current: string? = nil
local blur: BlurEffect

local function makeWindow(spec: MenuSpec): Window
	local root = Kit.new("Frame", {
		Name = spec.name,
		Size = UDim2.fromScale(spec.size.X, spec.size.Y),
		Position = UDim2.fromScale(0.5, 0.52),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = screen,
	}) :: Frame
	Kit.new("UISizeConstraint", { MaxSize = Vector2.new(1100, 760), Parent = root })
	local scale = Kit.new("UIScale", { Parent = root }) :: UIScale

	local panel = Kit.panel({
		Name = "Panel",
		Size = UDim2.fromScale(1, 1),
		Parent = root,
	})
	-- A colored strip along the top edge in the menu's color.
	local strip = Kit.new("Frame", {
		Name = "Strip",
		Size = UDim2.new(1, -16, 0, 8),
		Position = UDim2.fromOffset(8, 8),
		BackgroundColor3 = spec.color,
		BorderSizePixel = 0,
		Parent = panel,
	})
	Kit.corner(4).Parent = strip

	local content = Kit.new("Frame", {
		Name = "Content",
		Size = UDim2.new(1, -36, 1, -46),
		Position = UDim2.fromOffset(18, 30),
		BackgroundTransparency = 1,
		Parent = panel,
	}) :: Frame

	-- The title badge sits over the top-left corner, tilted a touch.
	Kit.text({
		Name = "Title",
		Text = spec.title,
		Size = UDim2.new(0.42, 0, 0, 64),
		Position = UDim2.fromOffset(6, -50),
		TextXAlignment = Enum.TextXAlignment.Left,
		Stroke = 4,
		Rotation = -2,
		ZIndex = 5,
		Parent = root,
	})

	local close = Kit.button({
		name = "Close",
		color = Kit.Colors.Red,
		dark = Kit.Colors.RedDark,
		size = UDim2.fromOffset(58, 58),
		position = UDim2.new(1, 14, 0, -18),
		anchor = Vector2.new(1, 0),
		text = "X",
		textSize = 40,
		parent = root,
		onClick = function()
			Menus.close()
		end,
	})
	close.ZIndex = 6

	return { spec = spec, root = root, scale = scale, built = false, content = content }
end

function Menus.register(spec: MenuSpec)
	windows[spec.name] = makeWindow(spec)
end

function Menus.isOpen(name: string?): boolean
	if name then
		return current == name
	end
	return current ~= nil
end

function Menus.close()
	local name = current
	if not name then
		return
	end
	current = nil
	local window = windows[name]
	TweenService:Create(blur, Kit.FAST, { Size = 0 }):Play()
	local tween = TweenService:Create(
		window.scale,
		TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Scale = 0.6 }
	)
	tween:Play()
	tween.Completed:Once(function()
		if current ~= name then
			window.root.Visible = false
		end
	end)
	if window.spec.onClose then
		window.spec.onClose()
	end
	Menus.Opened:Fire(nil)
end

function Menus.open(name: string)
	local window = windows[name]
	if not window then
		return
	end
	if current == name then
		return
	end
	if current then
		local previous = windows[current]
		previous.root.Visible = false
		if previous.spec.onClose then
			previous.spec.onClose()
		end
	end
	current = name
	if not window.built then
		window.built = true
		window.spec.build(window.content)
	end
	window.root.Visible = true
	window.scale.Scale = 0.7
	TweenService:Create(window.scale, Kit.BOUNCY, { Scale = 1 }):Play()
	TweenService:Create(blur, Kit.SMOOTH, { Size = 10 }):Play()
	Kit.sound(Kit.Sounds.Whoosh, 0.25, 1.4)
	if window.spec.onOpen then
		window.spec.onOpen()
	end
	Menus.Opened:Fire(name)
end

function Menus.toggle(name: string)
	if current == name then
		Menus.close()
	else
		Menus.open(name)
	end
end

function Menus:Init()
	local player = Players.LocalPlayer
	screen = Kit.new("ScreenGui", {
		Name = "Menus",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 10,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	blur = Instance.new("BlurEffect")
	blur.Name = "MenuBlur"
	blur.Size = 0
	blur.Parent = Lighting
end

function Menus:Start()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
			Menus.close()
		end
	end)
end

function Menus.screen(): ScreenGui
	return screen
end

return Menus
