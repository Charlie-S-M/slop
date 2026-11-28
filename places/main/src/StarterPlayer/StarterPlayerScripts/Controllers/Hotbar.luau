--!strict
--[[
	The loadout hotbar: a dark rounded bar along the bottom of the screen showing what's equipped as
	pixel-art icons. Slot 1 is the gun (lit, since it's in hand), 2-4 the helmet, chestplate, and
	boots, and 5-7 the pets. It replaces Roblox's own backpack bar, which only ever held the gun.
	Phones get it at half size, and a button beside it hides or shows it.
]]

const Players = game:GetService("Players")
const TweenService = game:GetService("TweenService")
const StarterGui = game:GetService("StarterGui")

const Armor = require("@game/ReplicatedStorage/Shared/Armor")
const ArmorStats = require("@game/ReplicatedStorage/Shared/ArmorStats")
const Balance = require("@game/ReplicatedStorage/Shared/Balance")
const Guns = require("@game/ReplicatedStorage/Shared/Guns")
const Pets = require("@game/ReplicatedStorage/Shared/Pets")
const PixelSprites = require("@game/ReplicatedStorage/Shared/PixelSprites")
const Rarity = require("@game/ReplicatedStorage/Shared/Rarity")
const Types = require("@game/ReplicatedStorage/Shared/Types")
const ClientState = require("./ClientState")
const Kit = require("./UI/Kit")
const Net = require("@game/ReplicatedStorage/Shared/Net")

local Hotbar = {}

-- The bar's size on phones, as a share of its full size.
const COMPACT_SCALE = 0.5
-- Shows or hides the bar; set once it's built.
local apply: ((boolean) -> ())? = nil

-- The player's choice, from the bar's own button or the Settings menu.
function Hotbar.show(shown: boolean)
	if apply then
		apply(shown)
	end
end

type Palette = { b: Color3, a: Color3, t: Color3, k: Color3, w: Color3 }
type Slot = { frame: Frame, icon: Frame, stroke: UIStroke, drawn: string }

local slots: { Slot } = {}

const SLOT_COUNT = 4 + Balance.PET_SLOTS

local function palette(body: Color3, accent: Color3, trim: Color3): Palette
	return {
		b = body,
		a = accent,
		t = trim,
		k = body:Lerp(Color3.new(0, 0, 0), 0.75),
		w = body:Lerp(Color3.new(1, 1, 1), 0.7),
	}
end

-- Draws a sprite into `icon` as merged pixel runs, only when what's shown actually changed.
local function draw(slot: Slot, key: string, sprite: string?, colors: Palette?, rarity: number?)
	if slot.drawn == key then
		return
	end
	slot.drawn = key
	slot.icon:ClearAllChildren()
	slot.stroke.Color = if rarity then Rarity.get(rarity).color else Color3.fromRGB(70, 80, 100)
	if not sprite or not colors then
		return
	end
	local rows = PixelSprites.SPRITES[sprite]
	for _, run in PixelSprites.runs(rows) do
		Kit.new("Frame", {
			Size = UDim2.fromScale(run.width / 16, 1 / 16),
			Position = UDim2.fromScale(run.x / 16, run.y / 16),
			BackgroundColor3 = (colors :: any)[run.key],
			BorderSizePixel = 0,
			Parent = slot.icon,
		})
	end
end

local function refresh()
	local profile = ClientState.profile
	if not profile or #slots == 0 then
		return
	end
	-- 1: the gun in hand.
	local gun: Types.GunItem? = nil
	for _, item in profile.guns do
		if item.uid == profile.equipped then
			gun = item
		end
	end
	local gunDef = gun and Guns.get(gun.id)
	if gunDef then
		draw(
			slots[1],
			`gun:{gunDef.id}`,
			PixelSprites.forGun(gunDef.kind),
			palette(gunDef.body, gunDef.accent, gunDef.trim),
			gunDef.rarity
		)
	else
		draw(slots[1], "gun:none")
	end
	-- 2-4: armor.
	for index, slot: Types.ArmorSlot in Armor.SLOTS do
		local worn = ArmorStats.equippedIn(profile.armor, profile.equippedArmor, slot)
		local def = worn and Armor.get(worn.id)
		if def then
			draw(
				slots[1 + index],
				`armor:{def.id}`,
				PixelSprites.forArmor(slot),
				palette(def.body, def.trim, def.trim),
				def.rarity
			)
		else
			draw(slots[1 + index], `armor:none:{slot}`)
		end
	end
	-- 5+: pets.
	for index = 1, Balance.PET_SLOTS do
		local uid = profile.equippedPets[index]
		local def = nil
		for _, pet in profile.pets do
			if pet.uid == uid then
				def = Pets.get(pet.id)
			end
		end
		if def then
			draw(
				slots[4 + index],
				`pet:{def.id}`,
				PixelSprites.forPet(def.style),
				palette(def.body, def.accent, def.accent),
				def.rarity
			)
		else
			draw(slots[4 + index], `pet:none:{index}`)
		end
	end
end

local function build()
	local screen = Kit.new("ScreenGui", {
		Name = "Hotbar",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 5,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	local bar = Kit.new("CanvasGroup", {
		Size = UDim2.fromOffset(SLOT_COUNT * 58 + 24, 96),
		Position = UDim2.new(0.5, 0, 1, -150),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = Color3.fromRGB(22, 26, 34),
		BackgroundTransparency = 0.12,
		Parent = screen,
	})
	local scale = Kit.new("UIScale", { Scale = 1, Parent = bar }) :: UIScale
	local compact = false
	local wanted = true
	local toggle: TextButton
	local transition: Tween? = nil
	-- Where the bar and its button sit for the screen's size and the player's choice.
	local function place(instant: boolean?)
		const size = if compact then COMPACT_SCALE else 1
		-- On phones it rests just above the health bar.
		const rest = if compact then UDim2.fromScale(0.5, 0.775) else UDim2.new(0.5, 0, 1, -150)
		const hidden = Players.LocalPlayer:GetAttribute("ForgeCamera") == true
		const visible = wanted and not hidden
		scale.Scale = size
		if transition then
			transition:Cancel()
		end
		if visible then
			bar.Visible = true
		end
		const goal = {
			GroupTransparency = if visible then 0 else 1,
			-- It slides down a little as it goes.
			Position = if visible then rest else rest + UDim2.fromOffset(0, 18),
		}
		const tween = TweenService:Create(bar, TweenInfo.new(if instant then 0 else 0.22), goal)
		transition = tween
		tween.Completed:Once(function(state)
			if state == Enum.PlaybackState.Completed and not visible then
				bar.Visible = false
			end
		end)
		tween:Play()
		toggle.Visible = not hidden
		toggle.Text = if wanted then "▼" else "▲ Loadout"
		toggle.Size = if wanted then UDim2.fromOffset(28, 28) else UDim2.fromOffset(104, 28)
		-- Beside the bar's right end while it's up; in its place, centered, once it's away.
		const side = (SLOT_COUNT * 58 + 24) * size / 2 + 6
		toggle.AnchorPoint = Vector2.new(if wanted then 0 else 0.5, 1)
		-- On a big screen the lone button lifts clear of the damage readout.
		const lone = if compact then rest else rest - UDim2.fromOffset(0, 28)
		toggle.Position = if wanted then rest + UDim2.fromOffset(side, 0) else lone
	end
	toggle = Kit.new("TextButton", {
		Name = "LoadoutToggle",
		FontFace = Kit.FONT,
		TextSize = 15,
		TextColor3 = Color3.fromRGB(190, 205, 225),
		BackgroundColor3 = Color3.fromRGB(22, 26, 34),
		BackgroundTransparency = 0.12,
		AutoButtonColor = false,
		Parent = screen,
	}) :: TextButton
	Kit.corner(10).Parent = toggle
	Kit.new("UIStroke", {
		Color = Color3.fromRGB(70, 150, 220),
		Thickness = 2,
		Transparency = 0.35,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = toggle,
	})
	toggle.Activated:Connect(function()
		wanted = not wanted
		Kit.sound(Kit.Sounds.Click, 0.3)
		const profile = ClientState.profile
		if profile then
			profile.settings.showLoadout = wanted
		end
		Net.event("SaveSetting"):FireServer("showLoadout", wanted)
		place()
	end)
	function apply(shown: boolean)
		if shown ~= wanted then
			wanted = shown
			place()
		end
	end
	local function follow()
		const profile = ClientState.profile
		if profile then
			Hotbar.show(profile.settings.showLoadout)
		end
	end
	ClientState.ProfileChanged:Connect(follow)
	Players.LocalPlayer:GetAttributeChangedSignal("ForgeCamera"):Connect(function()
		place()
	end)
	Kit.onCompact(function(small)
		compact = small
		place(true)
	end)
	follow()
	Kit.new("UICorner", { CornerRadius = UDim.new(0, 22), Parent = bar })
	Kit.new(
		"UIStroke",
		{ Color = Color3.fromRGB(70, 150, 220), Thickness = 2, Transparency = 0.35, Parent = bar }
	)
	Kit.text({
		Text = "LOADOUT",
		Size = UDim2.fromOffset(120, 18),
		Position = UDim2.fromOffset(16, 6),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(190, 205, 225),
		Stroke = 0,
		Parent = bar,
	})
	for index = 1, SLOT_COUNT do
		local frame = Kit.new("Frame", {
			Size = UDim2.fromOffset(48, 48),
			Position = UDim2.fromOffset(16 + (index - 1) * 58, 26),
			BackgroundColor3 = Color3.fromRGB(34, 40, 52),
			Parent = bar,
		})
		Kit.new("UICorner", { CornerRadius = UDim.new(0, 10), Parent = frame })
		local stroke = Kit.new(
			"UIStroke",
			{ Color = Color3.fromRGB(70, 80, 100), Thickness = 2, Parent = frame }
		)
		local icon = Kit.new("Frame", {
			Size = UDim2.fromScale(0.8, 0.8),
			Position = UDim2.fromScale(0.1, 0.1),
			BackgroundTransparency = 1,
			Parent = frame,
		})
		Kit.text({
			Text = tostring(index),
			Size = UDim2.fromOffset(48, 14),
			Position = UDim2.new(0, 0, 1, 2),
			TextColor3 = Color3.fromRGB(150, 165, 190),
			Stroke = 0,
			Parent = frame,
		})
		table.insert(slots, { frame = frame, icon = icon, stroke = stroke, drawn = "" })
	end
	-- The gun is the item in hand, so its slot glows like a selected hotbar slot.
	local glow = slots[1].stroke
	glow.Thickness = 3
	Kit.new("UIStroke", {
		Color = Color3.fromRGB(90, 200, 255),
		Thickness = 6,
		Transparency = 0.7,
		Parent = Kit.new("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Parent = slots[1].frame,
		}),
	})
end

function Hotbar:Start()
	-- Our bar shows the gun; Roblox's own tool bar would only duplicate it.
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)
	build()
	refresh()
	ClientState.ProfileChanged:Connect(refresh)
end

return Hotbar
