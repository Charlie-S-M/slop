--!strict
--[[
	The armor catalog. Every rarity has one set, and every set has a helmet, a chestplate, and
	boots, so the forge picks the piece for the slot the player chose and the rarity it rolled.
]]

const Types = require("./Types")

export type ArmorDef = {
	id: string,
	name: string,
	slot: Types.ArmorSlot,
	rarity: number,
	set: string,
	body: Color3,
	trim: Color3,
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- Set name, body color, and trim color, by rarity.
const SETS: { { name: string, body: Color3, trim: Color3 } } = {
	{ name = "Scrap", body = rgb(130, 120, 110), trim = rgb(170, 110, 70) },
	{ name = "Copperplate", body = rgb(190, 110, 60), trim = rgb(90, 200, 120) },
	{ name = "Steelguard", body = rgb(150, 165, 185), trim = rgb(60, 140, 255) },
	{ name = "Amethyst", body = rgb(110, 60, 160), trim = rgb(230, 150, 255) },
	{ name = "Sunforged", body = rgb(255, 190, 50), trim = rgb(255, 245, 190) },
	{ name = "Bloodmoon", body = rgb(120, 20, 40), trim = rgb(255, 90, 90) },
	{ name = "Prismatic", body = rgb(230, 250, 255), trim = rgb(255, 120, 250) },
	{ name = "Dawnlight", body = rgb(255, 248, 230), trim = rgb(170, 210, 255) },
}

const SLOTS: { Types.ArmorSlot } = { "Helmet", "Chestplate", "Boots" }

const LIST: { ArmorDef } = {}
const BY_ID: { [string]: ArmorDef } = {}
const BY_SLOT: { [string]: { [number]: ArmorDef } } = {}

for rarity, set in SETS do
	for _, slot in SLOTS do
		local def: ArmorDef = {
			id = set.name .. slot,
			name = `{set.name} {slot}`,
			slot = slot,
			rarity = rarity,
			set = set.name,
			body = set.body,
			trim = set.trim,
		}
		table.insert(LIST, def)
		BY_ID[def.id] = def
		BY_SLOT[slot] = BY_SLOT[slot] or {}
		BY_SLOT[slot][rarity] = def
	end
end

local Armor = {}

Armor.SLOTS = SLOTS
Armor.List = LIST

function Armor.get(id: string): ArmorDef?
	return BY_ID[id]
end

function Armor.isSlot(value: unknown): boolean
	return typeof(value) == "string" and BY_SLOT[value] ~= nil
end

-- The piece for `slot` at `rarity`, clamped to the rarities that have a set.
function Armor.forSlot(slot: Types.ArmorSlot, rarity: number): ArmorDef
	return BY_SLOT[slot][math.clamp(math.floor(rarity), 1, #SETS)]
end

return Armor
