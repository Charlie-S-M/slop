--!strict

--[[
	Everything sold for Robux: developer products (bought again and again) and game passes (owned
	for good). Each entry has its Robux price, how the shop shows it, and its id in each experience,
	keyed by universe id (game.GameId), because one product has a different id in every experience.
	A nil id means it hasn't been created there yet, and its button says so instead of prompting.

	What a purchase grants lives on the server (Modules/Server/Shop.luau); what a pass does lives
	in Modules/Server/Boosts.luau.
]]

export type Kind = "product" | "pass"
export type Section = "Featured" | "ServerLuck" | "Passes" | "Power" | "Coins" | "Eggs" | "Potions"

export type ProductDef = {
	key: string,
	kind: Kind,
	section: Section?,
	name: string,
	description: string,
	glyph: string,
	color: Color3,
	price: number,
	-- The product's id in each experience, by universe id.
	ids: { [number]: number },
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function item(
	key: string,
	kind: Kind,
	section: Section?,
	name: string,
	description: string,
	glyph: string,
	color: Color3,
	price: number
): ProductDef
	return {
		key = key,
		kind = kind,
		section = section,
		name = name,
		description = description,
		glyph = glyph,
		color = color,
		price = price,
		ids = {},
	}
end

const GOLD = rgb(255, 196, 60)
const GREEN = rgb(80, 205, 95)
const RED = rgb(240, 85, 70)
const BLUE = rgb(70, 150, 245)
const PURPLE = rgb(165, 95, 245)
const PINK = rgb(250, 120, 190)
const TEAL = rgb(40, 200, 190)

const PRODUCTS: { ProductDef } = {
	-- Featured: one starter pack per player, and the limited guns.
	item(
		"StarterPack",
		"product",
		"Featured",
		"Starter Pack",
		"Coins, 3 Luck Potions, and a Lucky Forge. Once per player!",
		"🎁",
		PINK,
		29
	),
	item(
		"NovaReaper",
		"product",
		"Featured",
		"Nova Reaper",
		"Limited Eternal rifle, 1.6× stronger than your best gun.",
		"🔫",
		PURPLE,
		499
	),
	item(
		"DragonheartCannon",
		"product",
		"Featured",
		"Dragonheart Cannon",
		"Limited Eternal launcher, 1.6× stronger than your best gun.",
		"🐉",
		RED,
		799
	),
	-- Server-wide and next-forge luck.
	item(
		"ServerLuck",
		"product",
		"ServerLuck",
		"Server Luck",
		"2× forge luck for everyone in the server, 15 minutes. Stacks!",
		"🍀",
		GREEN,
		49
	),
	item(
		"LuckyForge",
		"product",
		"ServerLuck",
		"Lucky Forge",
		"3× luck on your next forge.",
		"🔨",
		GOLD,
		9
	),
	item(
		"LuckyForge5",
		"product",
		"ServerLuck",
		"Lucky Forge ×5",
		"3× luck on your next five forges.",
		"🔨",
		GOLD,
		39
	),
	-- Game passes.
	item("VIP", "pass", "Passes", "VIP", "+25% Power and coins, forever.", "👑", GOLD, 399),
	item(
		"DoubleCoins",
		"pass",
		"Passes",
		"2× Coins",
		"Double coins from monsters and chests.",
		"💰",
		GREEN,
		249
	),
	item(
		"ForgeSkip",
		"pass",
		"Passes",
		"Forge Skip",
		"Skip the melt and pour scenes.",
		"▶",
		BLUE,
		99
	),
	item(
		"AutoPerfectForge",
		"pass",
		"Passes",
		"Auto Perfect Forge",
		"Automatically land perfect forge strikes.",
		"★",
		GOLD,
		299
	),
	item("SpeedBoost", "pass", "Passes", "Speed Boost", "Walk 50% faster.", "👟", BLUE, 149),
	item("ExtraLuck", "pass", "Passes", "Extra Luck", "+25% forge luck.", "🍀", GREEN, 99),
	item("SuperLuck", "pass", "Passes", "Super Luck", "+60% forge luck.", "🌟", TEAL, 349),
	item(
		"AutoCollect",
		"pass",
		"Passes",
		"Auto Collect",
		"Ores fly to you from anywhere in the stage.",
		"🧲",
		BLUE,
		199
	),
	item(
		"KeepOres",
		"pass",
		"Passes",
		"Keep Ores",
		"Keep your ore bag when you fall in a stage.",
		"🎒",
		rgb(230, 140, 60),
		149
	),
	item(
		"DoubleBossLoot",
		"pass",
		"Passes",
		"2× Boss Loot",
		"Double coins from boss chests.",
		"👹",
		RED,
		199
	),
	item(
		"AutoRebirth",
		"pass",
		"Passes",
		"Auto Rebirth",
		"Rebirths by itself as soon as you can.",
		"🔄",
		PURPLE,
		299
	),
	item(
		"PetStorage30",
		"pass",
		"Passes",
		"+30 Pet Storage",
		"Keep 30 more pets.",
		"🐾",
		PINK,
		99
	),
	item(
		"PetStorage60",
		"pass",
		"Passes",
		"+60 Pet Storage",
		"Keep 60 more pets.",
		"🐾",
		PINK,
		249
	),
	-- Power packs, scaled to the next rebirth.
	item("Power1", "product", "Power", "Power Pack", "Instant Power.", "⚡", RED, 19),
	item("Power2", "product", "Power", "Power Crate", "Lots of Power.", "⚡", RED, 79),
	item("Power3", "product", "Power", "Power Chest", "A chest of Power.", "⚡", RED, 239),
	item("Power4", "product", "Power", "Power Vault", "A vault of Power.", "⚡", RED, 639),
	-- Coin packs, scaled to your best stage.
	item("Coins1", "product", "Coins", "Coin Pouch", "Instant coins.", "💰", GREEN, 29),
	item("Coins2", "product", "Coins", "Coin Stack", "Lots of coins.", "💰", GREEN, 79),
	item("Coins3", "product", "Coins", "Coin Bag", "A bag of coins.", "💰", GREEN, 239),
	item("Coins4", "product", "Coins", "Coin Vault", "A vault of coins.", "💰", GREEN, 639),
	-- Free hatches from your best unlocked egg.
	item("Eggs3", "product", "Eggs", "3 Eggs", "Hatch your best egg 3 times.", "🥚", PINK, 79),
	item(
		"Eggs10",
		"product",
		"Eggs",
		"10 Eggs",
		"Hatch your best egg 10 times.",
		"🥚",
		PINK,
		239
	),
	-- Potions: timed boosts, used whenever you like from the shop.
	item(
		"LuckPotion",
		"product",
		"Potions",
		"Luck Potion",
		"+30% forge luck for 15 minutes.",
		"🧪",
		GREEN,
		19
	),
	item(
		"LuckPotion5",
		"product",
		"Potions",
		"Luck Potion ×5",
		"Five Luck Potions.",
		"🧪",
		GREEN,
		76
	),
	item(
		"PowerPotion",
		"product",
		"Potions",
		"Power Potion",
		"2× training Power for 15 minutes.",
		"🧪",
		RED,
		19
	),
	item(
		"PowerPotion5",
		"product",
		"Potions",
		"Power Potion ×5",
		"Five Power Potions.",
		"🧪",
		RED,
		76
	),
	item(
		"CoinPotion",
		"product",
		"Potions",
		"Coin Potion",
		"2× coins for 15 minutes.",
		"🧪",
		GOLD,
		19
	),
	item(
		"CoinPotion5",
		"product",
		"Potions",
		"Coin Potion ×5",
		"Five Coin Potions.",
		"🧪",
		GOLD,
		76
	),
	-- Sold from the Lucky Wheel.
	item(
		"WheelSpin1",
		"product",
		nil,
		"1 Wheel Spin",
		"One spin of the Lucky Wheel.",
		"🎡",
		GOLD,
		24
	),
	item(
		"WheelSpin3",
		"product",
		nil,
		"3 Wheel Spins",
		"Three Lucky Wheel spins.",
		"🎡",
		GOLD,
		105
	),
	item(
		"WheelSpin10",
		"product",
		nil,
		"10 Wheel Spins",
		"Ten Lucky Wheel spins.",
		"🎡",
		GOLD,
		319
	),
	-- Sold from the Quests menu.
	item(
		"NewQuests",
		"product",
		nil,
		"New Quests",
		"Deal a fresh set of daily quests.",
		"🔁",
		GREEN,
		49
	),
}

-- Each experience's ids, by universe id and then product key. Created with Open Cloud.
const IDS: { [number]: { [string]: number } } = {
	-- 2D Gun Exponential! (ALPHA), owned by FarSource Development.
	[10779068698] = {
		VIP = 2098626200,
		DoubleCoins = 2098656216,
		SpeedBoost = 2099928165,
		ExtraLuck = 2102099382,
		SuperLuck = 2101931412,
		AutoCollect = 2099124220,
		KeepOres = 2098620154,
		DoubleBossLoot = 2098614236,
		AutoRebirth = 2098476155,
		PetStorage30 = 2099550185,
		PetStorage60 = 2098380207,
		StarterPack = 3736383457,
		NovaReaper = 3736383461,
		DragonheartCannon = 3736383465,
		ServerLuck = 3736383471,
		LuckyForge = 3736383474,
		LuckyForge5 = 3736383481,
		Power1 = 3736383483,
		Power2 = 3736383488,
		Power3 = 3736383490,
		Power4 = 3736383493,
		Coins1 = 3736383497,
		Coins2 = 3736383503,
		Coins3 = 3736383507,
		Coins4 = 3736383510,
		Eggs3 = 3736383626,
		Eggs10 = 3736383629,
		LuckPotion = 3736383630,
		LuckPotion5 = 3736383634,
		PowerPotion = 3736383637,
		PowerPotion5 = 3736383639,
		CoinPotion = 3736383640,
		CoinPotion5 = 3736383642,
		WheelSpin1 = 3736383644,
		WheelSpin3 = 3736383646,
		WheelSpin10 = 3736383649,
		NewQuests = 3736383651,
	},
}
for universe, ids in IDS do
	for _, def in PRODUCTS do
		def.ids[universe] = ids[def.key]
	end
end

local Products = {}

Products.List = PRODUCTS
-- The shop's tabs, in order, with their labels.
Products.SECTIONS = {
	{ key = "Featured", label = "Featured", glyph = "⭐", color = RED },
	{ key = "ServerLuck", label = "Server Luck", glyph = "🍀", color = GOLD },
	{ key = "Passes", label = "Passes", glyph = "🎫", color = BLUE },
	{ key = "Power", label = "Power", glyph = "⚡", color = rgb(245, 120, 50) },
	{ key = "Coins", label = "Coins", glyph = "💰", color = GREEN },
	{ key = "Eggs", label = "Eggs", glyph = "🥚", color = PINK },
	{ key = "Potions", label = "Potions", glyph = "🧪", color = PURPLE },
}
-- Potions by the boost they start, and how long one lasts.
Products.POTIONS = { LuckPotion = "Luck", PowerPotion = "Power", CoinPotion = "Coins" }
Products.POTION_SECONDS = 15 * 60
-- The limited guns' sale ends at this time (UTC), shown as a countdown.
Products.LIMITED_ENDS = 1797465600

Products.PENDING_PASSES = { ForgeSkip = true, AutoPerfectForge = true } :: { [string]: boolean }

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
function Products.byId(kind: Kind, id: number): ProductDef?
	for _, def in PRODUCTS do
		if def.kind == kind and def.ids[game.GameId] == id then
			return def
		end
	end
	return nil
end

return Products
