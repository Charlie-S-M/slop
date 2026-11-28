--!strict

--[[
	The prestige shop: bought with prestige tokens, one per prestige (doubled by 2x Prestige
	Coins). The 2x items can be bought again and again, each level doubling the effect again and
	costing double the level before. The Save items are bought once and keep part of a profile
	through every prestige after.
]]

export type ItemId =
	"Coins"
	| "FireRate"
	| "ForgeLuck"
	| "Tokens"
	| "RubyChance"
	| "PartLuck"
	| "SavePets"
	| "SaveUpgrades"
	| "SaveGuns"

export type ItemDef = {
	id: ItemId,
	name: string,
	detail: string,
	glyph: string,
	-- What the first level costs, in tokens.
	cost: number,
	-- Bought once, instead of levelling up.
	once: boolean,
}

const ITEMS: { ItemDef } = {
	{
		id = "RubyChance",
		name = "Mobs Drop Rubies",
		detail = "Gives mobs a .01% chance to drop 1 ruby! Each further level doubles the chance.",
		glyph = "♦",
		cost = 1,
		once = false,
	},
	{
		id = "Coins",
		name = "2x Coins",
		detail = "Doubles coins from every source, again each level.",
		glyph = "💰",
		cost = 1,
		once = false,
	},
	{
		id = "FireRate",
		name = "2x Firing Speed",
		detail = "Every gun fires twice as fast, again each level.",
		glyph = "🔥",
		cost = 1,
		once = false,
	},
	{
		id = "ForgeLuck",
		name = "2x Forging Luck",
		detail = "Doubles forge luck and the Eternal chance, again each level.",
		glyph = "🍀",
		cost = 1,
		once = false,
	},
	{
		id = "Tokens",
		name = "2x Prestige Coins",
		detail = "Doubles the tokens each prestige gives, again each level.",
		glyph = "⭐",
		cost = 1,
		once = false,
	},
	{
		id = "PartLuck",
		name = "2x Part Luck",
		detail = "Doubles boss chest part luck, again each level.",
		glyph = "🧰",
		cost = 1,
		once = false,
	},
	{
		id = "SavePets",
		name = "Save Pets",
		detail = "Keep your pets through every prestige.",
		glyph = "🐾",
		cost = 3,
		once = true,
	},
	{
		id = "SaveUpgrades",
		name = "Save Upgrades",
		detail = "Keep your coin upgrades through every prestige.",
		glyph = "⬆️",
		cost = 3,
		once = true,
	},
	{
		id = "SaveGuns",
		name = "Save Guns",
		detail = "Keep your guns through every prestige.",
		glyph = "🔫",
		cost = 10,
		once = true,
	},
}

const BY_ID: { [string]: ItemDef } = {}
for _, def in ITEMS do
	BY_ID[def.id] = def
end

-- The firing speed multiplier stops here, so shots never outrun the server's rate check.
const MAX_FIRE_RATE = 8

local PrestigeShop = {}

PrestigeShop.ITEMS = ITEMS
PrestigeShop.MAX_FIRE_RATE = MAX_FIRE_RATE

function PrestigeShop.get(id: string): ItemDef?
	return BY_ID[id]
end

function PrestigeShop.level(levels: { [string]: number }?, id: ItemId): number
	return if levels then math.max(levels[id] or 0, 0) else 0
end

-- Tokens for the next level, or nil once a one-time item is owned.
function PrestigeShop.cost(def: ItemDef, level: number): number?
	if def.once then
		return if level >= 1 then nil else def.cost
	end
	return def.cost * 2 ^ level
end

-- The effect of a 2x item: 2, 4, 8... at levels 1, 2, 3.
function PrestigeShop.multiplier(levels: { [string]: number }?, id: ItemId): number
	const value = 2 ^ PrestigeShop.level(levels, id)
	return if id == "FireRate" then math.min(value, MAX_FIRE_RATE) else value
end

-- Firing speed past MAX_FIRE_RATE turns into damage instead, so every level still doubles output.
function PrestigeShop.fireRateDamage(levels: { [string]: number }?): number
	return 2 ^ PrestigeShop.level(levels, "FireRate") / PrestigeShop.multiplier(levels, "FireRate")
end

function PrestigeShop.owns(levels: { [string]: number }?, id: ItemId): boolean
	return PrestigeShop.level(levels, id) >= 1
end

-- Tokens one prestige gives.
function PrestigeShop.tokensPerPrestige(levels: { [string]: number }?): number
	return PrestigeShop.multiplier(levels, "Tokens")
end

return PrestigeShop
