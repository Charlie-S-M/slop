--!strict

--[[
	Everything sold for Robux: developer products (bought again and again) and game passes (owned
	for good). Each entry has the Robux price it's listed at and its id in each experience, keyed by
	universe id (game.GameId), because one product has a different id in every experience. A nil id
	means the product hasn't been created there yet, and its button says so instead of prompting.
]]

export type Kind = "product" | "pass"

export type ProductDef = {
	key: string,
	kind: Kind,
	name: string,
	description: string,
	price: number,
	-- The product's id in each experience, by universe id.
	ids: { [number]: number },
}

const PRODUCTS: { ProductDef } = {
	{
		key = "NewQuests",
		kind = "product",
		name = "New Quests",
		description = "Deal a fresh set of daily quests.",
		price = 49,
		ids = {},
	},
}

local Products = {}

Products.List = PRODUCTS

local byKey: { [string]: ProductDef } = {}
for _, def in PRODUCTS do
	byKey[def.key] = def
end

function Products.get(key: string): ProductDef?
	return byKey[key]
end

-- The product's id in this experience, or nil when it hasn't been created here.
function Products.id(def: ProductDef): number?
	return def.ids[game.GameId]
end

-- The product a purchase id belongs to in this experience.
function Products.byId(id: number): ProductDef?
	for _, def in PRODUCTS do
		if def.ids[game.GameId] == id then
			return def
		end
	end
	return nil
end

return Products
