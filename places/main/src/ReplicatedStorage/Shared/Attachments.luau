--!strict
--[[
	The attachment catalog: a part for each of five slots at each of seven rarities. A part raises
	one gun stat by its bonus: barrels and scopes raise Power, grips and magazines raise Speed, and
	keychains raise Training. Scopes and magazines give half the bonus of the main part in their stat.
]]

export type AttachSlot = "Scope" | "Grip" | "Barrel" | "Magazine" | "Keychain"
export type PartStat = "power" | "speed" | "train"

export type PartDef = {
	id: string,
	name: string,
	slot: AttachSlot,
	rarity: number,
	stat: PartStat,
	-- The share the stat rises by, e.g. 0.07 for +7%.
	bonus: number,
}

const SLOTS: { AttachSlot } = { "Scope", "Grip", "Barrel", "Magazine", "Keychain" }
const PREFIXES = { "Rusty", "Sturdy", "Tuned", "Arcane", "Gilded", "Crimson", "Prismatic" }
const BONUS = { 0.02, 0.04, 0.07, 0.11, 0.16, 0.24, 0.35 }
const SLOT_STAT: { [string]: { stat: PartStat, share: number } } = {
	Barrel = { stat = "power", share = 1 },
	Scope = { stat = "power", share = 0.5 },
	Grip = { stat = "speed", share = 1 },
	Magazine = { stat = "speed", share = 0.5 },
	Keychain = { stat = "train", share = 1 },
}

const LIST: { PartDef } = {}
const BY_ID: { [string]: PartDef } = {}
const BY_SLOT: { [string]: { [number]: PartDef } } = {}

for rarity, prefix in PREFIXES do
	for _, slot: AttachSlot in SLOTS do
		local info = SLOT_STAT[slot]
		local def: PartDef = {
			id = prefix .. slot,
			name = `{prefix} {slot}`,
			slot = slot,
			rarity = rarity,
			stat = info.stat,
			bonus = BONUS[rarity] * info.share,
		}
		table.insert(LIST, def)
		BY_ID[def.id] = def
		BY_SLOT[slot] = BY_SLOT[slot] or {}
		BY_SLOT[slot][rarity] = def
	end
end

local Attachments = {}

Attachments.SLOTS = SLOTS
Attachments.List = LIST
Attachments.RARITIES = #PREFIXES

function Attachments.get(id: string): PartDef?
	return BY_ID[id]
end

function Attachments.isSlot(value: unknown): boolean
	return typeof(value) == "string" and BY_SLOT[value] ~= nil
end

function Attachments.forSlot(slot: AttachSlot, rarity: number): PartDef
	return BY_SLOT[slot][math.clamp(math.floor(rarity), 1, #PREFIXES)]
end

-- Every part of a rarity, for picking a chest's reward.
function Attachments.ofRarity(rarity: number): { PartDef }
	local found = {}
	for _, def in LIST do
		if def.rarity == rarity then
			table.insert(found, def)
		end
	end
	return found
end

return Attachments
