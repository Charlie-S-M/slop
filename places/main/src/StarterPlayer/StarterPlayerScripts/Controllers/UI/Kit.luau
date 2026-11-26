--!strict

--[[
	The UI kit: chunky outlined text, glossy gradient buttons with press pops, dark rounded panels,
	and small animation helpers. Every screen builds from these so the whole game shares one look.
]]

const SoundService = game:GetService("SoundService")
const TweenService = game:GetService("TweenService")

local Kit = {}

Kit.FONT = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold)
Kit.FONT_BODY = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)

Kit.Colors = {
	Ink = Color3.fromRGB(22, 22, 34),
	Panel = Color3.fromRGB(40, 44, 66),
	PanelLight = Color3.fromRGB(58, 64, 94),
	Card = Color3.fromRGB(52, 57, 84),
	White = Color3.fromRGB(255, 255, 255),
	Green = Color3.fromRGB(70, 210, 80),
	GreenDark = Color3.fromRGB(40, 150, 50),
	Red = Color3.fromRGB(235, 60, 70),
	RedDark = Color3.fromRGB(170, 30, 45),
	Blue = Color3.fromRGB(60, 160, 255),
	BlueDark = Color3.fromRGB(30, 100, 210),
	Gold = Color3.fromRGB(255, 200, 40),
	GoldDark = Color3.fromRGB(220, 140, 20),
	Purple = Color3.fromRGB(170, 90, 255),
	PurpleDark = Color3.fromRGB(110, 50, 200),
	Orange = Color3.fromRGB(255, 140, 40),
	OrangeDark = Color3.fromRGB(210, 90, 20),
	Grey = Color3.fromRGB(120, 125, 140),
	GreyDark = Color3.fromRGB(80, 84, 98),
	Pink = Color3.fromRGB(255, 90, 190),
	PinkDark = Color3.fromRGB(200, 40, 140),
	Teal = Color3.fromRGB(40, 220, 210),
	TealDark = Color3.fromRGB(20, 150, 160),
}

Kit.FAST = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
Kit.BOUNCY = TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
Kit.SMOOTH = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

export type Props = { [string]: any }

-- Creates an instance, sets its properties, and parents its children.
function Kit.new(className: string, props: Props?, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function Kit.corner(radius: number?): UICorner
	return Kit.new("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

function Kit.cornerScale(scale: number): UICorner
	return Kit.new("UICorner", { CornerRadius = UDim.new(scale, 0) })
end

function Kit.stroke(thickness: number?, color: Color3?, mode: Enum.ApplyStrokeMode?): UIStroke
	return Kit.new("UIStroke", {
		Thickness = thickness or 3,
		Color = color or Kit.Colors.Ink,
		ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Contextual,
		LineJoinMode = Enum.LineJoinMode.Round,
	})
end

function Kit.gradient(top: Color3, bottom: Color3, rotation: number?): UIGradient
	return Kit.new("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = rotation or 90,
	})
end

function Kit.padding(pixels: number): UIPadding
	local amount = UDim.new(0, pixels)
	return Kit.new(
		"UIPadding",
		{ PaddingTop = amount, PaddingBottom = amount, PaddingLeft = amount, PaddingRight = amount }
	)
end

function Kit.paddingScale(scale: number): UIPadding
	local amount = UDim.new(scale, 0)
	return Kit.new(
		"UIPadding",
		{ PaddingTop = amount, PaddingBottom = amount, PaddingLeft = amount, PaddingRight = amount }
	)
end

function Kit.aspect(ratio: number): UIAspectRatioConstraint
	return Kit.new("UIAspectRatioConstraint", { AspectRatio = ratio })
end

--[[
	Chunky game text: Fredoka with a thick dark outline and a soft top-to-bottom gradient. The
	outline scales with the label so small and large text read the same.
]]
function Kit.text(props: Props): TextLabel
	local label = Kit.new("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = Kit.FONT,
		TextScaled = true,
		TextColor3 = Kit.Colors.White,
		Size = UDim2.fromScale(1, 1),
		Text = "",
	})
	local strokeThickness = props.Stroke or 2.5
	local gradientOn = props.Gradient ~= false
	local maxSize = props.MaxTextSize
	for key, value in props do
		if
			key ~= "Stroke"
			and key ~= "StrokeColor"
			and key ~= "Gradient"
			and key ~= "MaxTextSize"
			and key ~= "Parent"
		then
			(label :: any)[key] = value
		end
	end
	if strokeThickness > 0 then
		Kit.stroke(strokeThickness, props.StrokeColor or Kit.Colors.Ink).Parent = label
	end
	if gradientOn then
		Kit.gradient(Color3.new(1, 1, 1), Color3.fromRGB(205, 210, 225)).Parent = label
	end
	if maxSize then
		Kit.new("UITextSizeConstraint", { MaxTextSize = maxSize, Parent = label })
	end
	if props.Parent then
		label.Parent = props.Parent
	end
	return label
end

-- Every effect sound plays through these groups, so the Settings menu's sliders set their volume.
local function soundGroup(name: string): SoundGroup
	local existing = SoundService:FindFirstChild(name)
	if existing and existing:IsA("SoundGroup") then
		return existing
	end
	local group = Instance.new("SoundGroup")
	group.Name = name
	group.Parent = SoundService
	return group
end
Kit.SfxGroup = soundGroup("Sfx")
Kit.MusicGroup = soundGroup("MusicGroup")

local function playSound(id: string, volume: number?, speed: number?)
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume or 0.5
	sound.PlaybackSpeed = (speed or 1) * (0.95 + math.random() * 0.1)
	sound.SoundGroup = Kit.SfxGroup
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	task.delay(6, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

Kit.Sounds = require("./Sounds")

function Kit.sound(id: string, volume: number?, speed: number?)
	playSound(id, volume, speed)
end

-- Scales an element up and back, the basic "juice" for presses and rewards.
function Kit.pop(target: GuiObject, amount: number?)
	local scale = target:FindFirstChild("PopScale") :: UIScale?
	if not scale then
		scale = Kit.new("UIScale", { Name = "PopScale", Parent = target })
	end
	local s = scale :: UIScale
	s.Scale = amount or 1.15
	TweenService:Create(s, Kit.BOUNCY, { Scale = 1 }):Play()
end

--[[
	A glossy button: a colored body with a darker base edge, a light top sheen, a thick outline,
	and a press animation. Returns the button; put labels and icons inside "Face".
]]
function Kit.button(props: {
	color: Color3,
	dark: Color3,
	size: UDim2,
	position: UDim2?,
	anchor: Vector2?,
	text: string?,
	textSize: number?,
	radius: number?,
	parent: Instance?,
	name: string?,
	onClick: (() -> ())?,
}): TextButton
	local button = Kit.new("TextButton", {
		Name = props.name or "Button",
		Size = props.size,
		Position = props.position or UDim2.new(),
		AnchorPoint = props.anchor or Vector2.zero,
		BackgroundColor3 = props.dark,
		Text = "",
		AutoButtonColor = false,
	}) :: TextButton
	Kit.corner(props.radius or 12).Parent = button
	Kit.stroke(3, Kit.Colors.Ink, Enum.ApplyStrokeMode.Border).Parent = button

	local face = Kit.new("Frame", {
		Name = "Face",
		Size = UDim2.new(1, 0, 1, -5),
		BackgroundColor3 = props.color,
		BorderSizePixel = 0,
		Parent = button,
	})
	Kit.corner(props.radius or 12).Parent = face
	Kit.gradient(props.color:Lerp(Color3.new(1, 1, 1), 0.25), props.color).Parent = face
	-- A glossy sheen across the top half.
	local sheen = Kit.new("Frame", {
		Name = "Sheen",
		Size = UDim2.new(1, -8, 0.42, 0),
		Position = UDim2.fromOffset(4, 3),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.78,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = face,
	})
	Kit.corner((props.radius or 12) - 3).Parent = sheen

	if props.text then
		Kit.text({
			Name = "Label",
			Text = props.text,
			Size = UDim2.fromScale(0.86, 0.72),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			ZIndex = 3,
			MaxTextSize = props.textSize,
			Parent = face,
		})
	end

	local scale = Kit.new("UIScale", { Parent = button }) :: UIScale
	button.MouseEnter:Connect(function()
		TweenService:Create(scale, Kit.FAST, { Scale = 1.05 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, Kit.FAST, { Scale = 1 }):Play()
	end)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, Kit.FAST, { Scale = 0.92 }):Play()
	end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(scale, Kit.BOUNCY, { Scale = 1.05 }):Play()
	end)
	if props.onClick then
		local onClick = props.onClick
		button.Activated:Connect(function()
			Kit.sound(Kit.Sounds.Click, 0.4)
			onClick()
		end)
	end
	if props.parent then
		button.Parent = props.parent
	end
	return button
end

-- Recolors a button made by Kit.button, for enabled and disabled states.
function Kit.setButtonColor(button: TextButton, color: Color3, dark: Color3)
	button.BackgroundColor3 = dark
	local face = button:FindFirstChild("Face") :: Frame?
	if face then
		face.BackgroundColor3 = color
		local gradient = face:FindFirstChildOfClass("UIGradient")
		if gradient then
			gradient.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.25), color)
		end
	end
end

function Kit.setButtonText(button: TextButton, text: string)
	local face = button:FindFirstChild("Face")
	local label = face and face:FindFirstChild("Label") :: TextLabel?
	if label then
		label.Text = text
	end
end

--[[
	A dark rounded panel with a thick outline and an inner lighter edge, the frame for every menu.
]]
function Kit.panel(props: Props): Frame
	local frame = Kit.new("Frame", {
		BackgroundColor3 = Kit.Colors.Panel,
		BorderSizePixel = 0,
	})
	for key, value in props do
		if key ~= "Parent" and key ~= "Radius" then
			(frame :: any)[key] = value
		end
	end
	Kit.corner(props.Radius or 18).Parent = frame
	Kit.stroke(4, Kit.Colors.Ink, Enum.ApplyStrokeMode.Border).Parent = frame
	Kit.gradient(Kit.Colors.PanelLight, Kit.Colors.Panel).Parent = frame
	if props.Parent then
		frame.Parent = props.Parent
	end
	return frame
end

--[[
	An icon tile: a rounded colored square with a big emoji glyph, a glossy sheen, and an outline.
	Used for menu buttons, upgrade cards, and currency badges.
]]
function Kit.iconTile(glyph: string, color: Color3, size: UDim2, parent: Instance?): Frame
	local tile = Kit.new("Frame", {
		Name = "Icon",
		Size = size,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
	})
	Kit.corner(10).Parent = tile
	Kit.stroke(2.5, Kit.Colors.Ink, Enum.ApplyStrokeMode.Border).Parent = tile
	Kit.gradient(color:Lerp(Color3.new(1, 1, 1), 0.3), color:Lerp(Color3.new(0, 0, 0), 0.15)).Parent =
		tile
	Kit.text({
		Name = "Glyph",
		Text = glyph,
		Size = UDim2.fromScale(0.78, 0.78),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Stroke = 0,
		Gradient = false,
		FontFace = Kit.FONT_BODY,
		Parent = tile,
	})
	if parent then
		tile.Parent = parent
	end
	return tile
end

--[[
	Animates a number label from its current value to a target. Keeps one tween per label so rapid
	updates retarget smoothly instead of fighting.
]]
local counters: { [TextLabel]: { value: NumberValue, tween: Tween?, format: (number) -> string } } =
	{}

function Kit.countTo(
	label: TextLabel,
	target: number,
	format: (number) -> string,
	duration: number?
)
	local entry = counters[label]
	if not entry then
		local value = Instance.new("NumberValue")
		value.Value = target
		local created = { value = value, tween = nil, format = format }
		entry = created
		counters[label] = created
		value.Changed:Connect(function(current)
			label.Text = created.format(current)
		end)
		label.Destroying:Connect(function()
			counters[label] = nil
			value:Destroy()
		end)
		label.Text = format(target)
		return
	end
	entry.format = format
	if entry.tween then
		entry.tween:Cancel()
	end
	-- Huge jumps snap; a count-up over orders of magnitude reads as noise.
	if target > entry.value.Value * 50 or target < entry.value.Value then
		entry.value.Value = target
		label.Text = format(target)
		return
	end
	local tween = TweenService:Create(
		entry.value,
		TweenInfo.new(duration or 0.35, Enum.EasingStyle.Quad),
		{ Value = target }
	)
	entry.tween = tween
	tween:Play()
end

-- Rarity-colored rainbow shimmer for Mythic and Celestial labels.
function Kit.shimmer(gradient: UIGradient, speed: number?)
	task.spawn(function()
		local rate = speed or 0.4
		while gradient.Parent do
			gradient.Offset = Vector2.new(((os.clock() * rate) % 2) - 1, 0)
			task.wait()
		end
	end)
end

return Kit
