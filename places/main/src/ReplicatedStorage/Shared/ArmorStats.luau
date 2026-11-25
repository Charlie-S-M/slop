--!strict
-- Armor numbers both sides need: a forged piece's defense and how much of a hit the worn set blocks.

const Armor = require("./Armor")
const Balance = require("./Balance")
const Types = require("./Types")

local ArmorStats = {}

-- The share of each hit a freshly forged piece blocks.
function ArmorStats.roll(def: Armor.ArmorDef, grade: Types.Grade, roll: number): number
	return Balance.ARMOR_SLOT_SHARE[def.slot]
		* Balance.ARMOR_RARITY_DEFENSE[def.rarity]
		* Balance.ARMOR_GRADE_MULTIPLIER[grade]
		* roll
end

-- The owned piece a finished armor forge makes. Defense is kept to four decimals for saves and UI.
function ArmorStats.makeItem(
	uid: string,
	def: Armor.ArmorDef,
	grade: Types.Grade,
	roll: number
): Types.ArmorItem
	local defense = math.floor(ArmorStats.roll(def, grade, roll) * 10000 + 0.5) / 10000
	return { uid = uid, id = def.id, defense = defense, grade = grade, locked = false }
end

-- The equipped piece in `slot`, if the uid there names an owned piece made for that slot.
function ArmorStats.equippedIn(
	armor: { Types.ArmorItem },
	equipped: { [string]: string },
	slot: Types.ArmorSlot
): Types.ArmorItem?
	local uid = equipped[slot]
	if not uid then
		return nil
	end
	for _, item in armor do
		if item.uid == uid then
			local def = Armor.get(item.id)
			return if def and def.slot == slot then item else nil
		end
	end
	return nil
end

-- The share of each hit the worn pieces block together, capped at ARMOR_MAX_BLOCK.
function ArmorStats.blocked(armor: { Types.ArmorItem }, equipped: { [string]: string }): number
	local total = 0
	for _, slot: Types.ArmorSlot in Armor.SLOTS do
		local item = ArmorStats.equippedIn(armor, equipped, slot)
		if item then
			total += item.defense
		end
	end
	return math.min(total, Balance.ARMOR_MAX_BLOCK)
end

return ArmorStats
