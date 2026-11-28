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

function PetStats.best(pets: { OwnedPet }, equipped: { string }, kind: Pets.PetKind): { string }
	local ranked = table.clone(pets)
	local function score(pet: OwnedPet): number
		local def = Pets.get(pet.id)
		return if def and def.kind == kind then def.bonus else 0
	end
	table.sort(ranked, function(a, b)
		local sa, sb = score(a), score(b)
		if sa ~= sb then
			return sa > sb
		end
		local ea, eb = table.find(equipped, a.uid), table.find(equipped, b.uid)
		if ea or eb then
			return (ea or math.huge) < (eb or math.huge)
		end
		return a.uid < b.uid
	end)
	local chosen = {}
	for i = 1, math.min(#ranked, Balance.PET_SLOTS) do
		table.insert(chosen, ranked[i].uid)
	end
	return chosen
end

return PetStats
