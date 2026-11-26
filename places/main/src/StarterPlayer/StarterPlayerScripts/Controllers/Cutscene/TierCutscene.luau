--!strict

--[[
	The cutscene for forging past Eternal (Celestial, Cosmic, Omega), played before the impact
	frame. It builds tension the way a big roll should feel:
	1. The screen darkens and a ring of glowing gems, one per tier in its color, orbits the anvil
	   faster and faster while three lines written for the tier appear.
	2. A white flash and a fake-out: the tier below lands big, as if that were the result.
	3. "wait..."
	4. The real tier opens inside spinning sacred-geometry rings, spelled out letter by letter.
	Every beat checks `alive`, so an aborted forge stops the cutscene at once.
]]

const RunService = game:GetService("RunService")
const TweenService = game:GetService("TweenService")

const Rarity = require("@game/ReplicatedStorage/Shared/Rarity")
const Kit = require("../UI/Kit")

local TierCutscene = {}

-- Three lines per tier, shown while the ring spins up.
const LINES: { [number]: { string } } = {
	[9] = { "The forge hums...", "The sky opens up...", "Starlight pours into the metal..." },
	[10] = {
		"The forge goes silent...",
		"Gravity bends around the anvil...",
		"Galaxies swirl in the steel...",
	},
	[11] = { "The forge trembles...", "Reality itself bends...", "Time stops." },
}
const GEMS = 14

local function fade(target: Instance, info: TweenInfo, goal: { [string]: any })
	TweenService:Create(target, info, goal):Play()
end

local function ring(parent: Instance, size: number, color: Color3, thickness: number): Frame
	local frame = Kit.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(size, size),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		Parent = parent,
	})
	Kit.cornerScale(0.5).Parent = frame
	Kit.new(
		"UIStroke",
		{ Color = color, Thickness = thickness, Transparency = 0.15, Parent = frame }
	)
	return frame
end

-- Waits `seconds`; false when the cutscene should stop.
local function hold(seconds: number, alive: () -> boolean): boolean
	local untilTime = os.clock() + seconds
	while os.clock() < untilTime do
		if not alive() then
			return false
		end
		task.wait()
	end
	return alive()
end

function TierCutscene.play(tier: number, screen: ScreenGui, alive: () -> boolean)
	local lines = LINES[tier]
	if not lines then
		return
	end
	local rarity = Rarity.get(tier)
	local below = Rarity.get(tier - 1)
	local root = Kit.new("CanvasGroup", {
		Name = "TierCutscene",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		-- The lowest layer, so under global layering every beat draws above the dark backdrop.
		ZIndex = 1,
		Parent = screen,
	})
	local connections: { RBXScriptConnection } = {}
	local function finish()
		for _, connection in connections do
			connection:Disconnect()
		end
		root:Destroy()
	end
	fade(root, TweenInfo.new(0.4), { BackgroundTransparency = 0.05 })

	-- 1. The gem ring around the anvil, speeding up while the lines appear.
	local orbit = Kit.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(0.5, 0.5),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		Parent = root,
	})
	local gems: { Frame } = {}
	for index = 1, GEMS do
		local color = Rarity.get((index - 1) % tier + 1).color
		local gem = Kit.new("Frame", {
			BackgroundColor3 = color,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromScale(0.11, 0.11),
			Parent = orbit,
		})
		Kit.cornerScale(0.5).Parent = gem
		Kit.new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, Parent = gem })
		table.insert(gems, gem)
	end
	Kit.text({
		Text = "⚒️",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.3, 0.3),
		Stroke = 0,
		Gradient = false,
		FontFace = Kit.FONT_BODY,
		Parent = orbit,
	})
	local spinStart = os.clock()
	local angle = 0
	table.insert(
		connections,
		RunService.RenderStepped:Connect(function(dt: number)
			local t = os.clock() - spinStart
			angle += dt * (1.2 + t * t * 1.4)
			for index, gem in gems do
				local a = angle + (index - 1) * 2 * math.pi / GEMS
				gem.Position = UDim2.fromScale(0.5 + 0.42 * math.cos(a), 0.5 + 0.42 * math.sin(a))
			end
		end)
	)
	local caption = Kit.text({
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.8),
		Size = UDim2.fromScale(0.7, 0.07),
		TextColor3 = rarity.glow,
		Stroke = 3,
		Parent = root,
	})
	for _, line in lines do
		caption.Text = line
		caption.TextTransparency = 1
		fade(caption, TweenInfo.new(0.35), { TextTransparency = 0 })
		Kit.sound(Kit.Sounds.Ding, 0.35, 0.6 + tier * 0.03)
		if not hold(1.15, alive) then
			finish()
			return
		end
	end

	-- 2. A flash, and the tier below lands as if it were the result.
	local flash = Kit.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 60,
		Parent = root,
	})
	fade(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 })
	orbit.Visible = false
	caption.Text = ""
	Kit.sound(Kit.Sounds.Boom, 0.5, 1)
	local fake = Kit.text({
		Text = string.upper(below.name),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(0.7, 0.16),
		TextColor3 = below.color,
		Stroke = 5,
		Parent = root,
	})
	if not hold(1.1, alive) then
		finish()
		return
	end

	-- 3. "wait..."
	fade(fake, TweenInfo.new(0.3), { TextTransparency = 1 })
	local stroke = fake:FindFirstChildOfClass("UIStroke")
	if stroke then
		fade(stroke, TweenInfo.new(0.3), { Transparency = 1 })
	end
	local wait = Kit.text({
		Text = "wait...",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.3, 0.08),
		TextColor3 = Color3.fromRGB(230, 230, 240),
		Stroke = 2,
		Gradient = false,
		Parent = root,
	})
	wait.TextTransparency = 1
	fade(wait, TweenInfo.new(0.4), { TextTransparency = 0 })
	if not hold(1.2, alive) then
		finish()
		return
	end
	wait:Destroy()

	-- 4. The real tier inside spinning sacred-geometry rings, spelled out.
	local geometry = Kit.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(0.8, 0.8),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		Parent = root,
	})
	local outer = ring(geometry, 1, rarity.color, 3)
	local middle = ring(geometry, 0.72, rarity.glow, 2)
	ring(geometry, 0.46, rarity.color, 4)
	-- Two squares turned 45 degrees apart make an eight-pointed star.
	local squares: { Frame } = {}
	for index = 1, 2 do
		local square = Kit.new("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.62, 0.62),
			Rotation = (index - 1) * 45,
			Parent = geometry,
		})
		Kit.new("UIStroke", { Color = rarity.glow, Thickness = 2, Parent = square })
		table.insert(squares, square)
	end
	local turned = 0
	table.insert(
		connections,
		RunService.RenderStepped:Connect(function(dt: number)
			turned += dt * 20
			outer.Rotation = turned
			middle.Rotation = -turned * 1.5
			for index, square in squares do
				square.Rotation = (index - 1) * 45 - turned * 0.6
			end
		end)
	)
	geometry.Size = UDim2.fromScale(0.2, 0.2)
	fade(
		geometry,
		TweenInfo.new(0.7, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.fromScale(0.8, 0.8) }
	)
	local flash2 = Kit.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = rarity.glow,
		ZIndex = 60,
		Parent = root,
	})
	fade(flash2, TweenInfo.new(0.7), { BackgroundTransparency = 1 })
	Kit.sound(Kit.Sounds.Boom, 0.6, 0.7)
	local spaced = string.upper(rarity.name):gsub(".", "%0 "):sub(1, -2)
	local title = Kit.text({
		Text = spaced,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(0.8, 0.14),
		TextColor3 = rarity.color,
		Stroke = 5,
		StrokeColor = Color3.new(1, 1, 1),
		Gradient = false,
		ZIndex = 55,
		Parent = root,
	})
	Kit.gradient(rarity.glow, rarity.color).Parent = title
	Kit.text({
		Text = `{if string.find(rarity.name, "^[AEIOU]") then "An" else "A"} {rarity.name} forge!`,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.82),
		Size = UDim2.fromScale(0.5, 0.06),
		TextColor3 = Color3.fromRGB(240, 240, 250),
		Stroke = 3,
		ZIndex = 55,
		Parent = root,
	})
	if not hold(2, alive) then
		finish()
		return
	end
	fade(root, TweenInfo.new(0.4), { GroupTransparency = 1 })
	hold(0.4, alive)
	finish()
end

return TierCutscene
