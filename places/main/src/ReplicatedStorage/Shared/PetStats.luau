--!strict
-- What equipped pets add up to. The server applies these numbers and the Pets menu shows the same ones.

const Balance = require("./Balance")
const Pets = require("./Pets")
const Types = require("./Types")

export type OwnedPet = Types.PetItem

local PetStats = {}

-- The equipped pets that exist, at most PET_SLOTS of them, in equip order.
function PetStats.equipped(pets: { OwnedPet }, equipped: { string }): { Pets.PetDef }
	local byUid: { [string]: OwnedPet } = {}
	for _, owned in pets do
		byUid[owned.uid] = owned
	end
	local found = {}
	local seen: { [string]: boolean } = {}
	for _, uid in equipped do
		local owned = byUid[uid]
		local def = owned and Pets.get(owned.id)
		if def and not seen[uid] then
			seen[uid] = true
			table.insert(found, def)
			if #found >= Balance.PET_SLOTS then
				break
			end
		end
	end
	return found
end

-- The multiplier equipped pets give `kind`: 1 plus every matching pet's bonus.
function PetStats.multiplier(pets: { OwnedPet }, equipped: { string }, kind: Pets.PetKind): number
	local total = 1
	for _, def in PetStats.equipped(pets, equipped) do
		if def.kind == kind then
			total += def.bonus
		end
	end
	return total
end

return PetStats
