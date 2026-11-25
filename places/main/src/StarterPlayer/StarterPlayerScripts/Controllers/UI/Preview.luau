--!strict

const Armor = require("@game/ReplicatedStorage/Shared/Armor")
const Guns = require("@game/ReplicatedStorage/Shared/Guns")
const Ores = require("@game/ReplicatedStorage/Shared/Ores")
const Pets = require("@game/ReplicatedStorage/Shared/Pets")

const PixelSprites = require("@game/ReplicatedStorage/Shared/PixelSprites")
local Preview = {}

local function show(
	viewport: Frame,
	key: string,
	id: string,
	body: Color3,
	accent: Color3,
	trim: Color3?
)
	if viewport:FindFirstChild(id) then
		return
	end
	viewport:ClearAllChildren()
	local icon = Instance.new("Frame")
	icon.Name = id
	icon.BackgroundTransparency = 1
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromScale(1, 1)
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.Parent = icon
	icon.Parent = viewport
	PixelSprites.draw(icon, key, body, accent, trim)
end

function Preview.gun(viewport: Frame, id: string, _spin: number?)
	local def = Guns.get(id)
	if not def then
		viewport:ClearAllChildren()
		return
	end
	show(viewport, PixelSprites.forGun(def.kind), id, def.body, def.accent, def.trim)
end

function Preview.armor(viewport: Frame, id: string, _spin: number?)
	local def = Armor.get(id)
	if not def then
		viewport:ClearAllChildren()
		return
	end
	show(viewport, PixelSprites.forArmor(def.slot), id, def.body, def.trim, nil)
end

function Preview.pet(viewport: Frame, id: string, _spin: number?)
	local def = Pets.get(id)
	if not def then
		viewport:ClearAllChildren()
		return
	end
	show(viewport, PixelSprites.forPet(def.style), id, def.body, def.accent, nil)
end

function Preview.ore(viewport: Frame, id: string, _spin: number?)
	local def = Ores.get(id)
	if not def then
		viewport:ClearAllChildren()
		return
	end
	show(viewport, PixelSprites.forOre(def.style), id, def.color, def.color, nil)
end

function Preview.viewport(props: { [string]: any }): Frame
	local viewport = Instance.new("Frame")
	viewport.BackgroundTransparency = 1
	viewport.Size = UDim2.fromScale(1, 1)
	for key, value in props do
		(viewport :: any)[key] = value
	end
	return viewport
end

return Preview
