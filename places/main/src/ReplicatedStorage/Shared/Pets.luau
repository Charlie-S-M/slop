--!strict
--[[
	The pet catalog and eggs. Each egg unlocks at a best stage, costs that stage's enemy coins times
	its multiplier, and hatches one of four pets, one per rarity, by weight. A pet boosts one thing:
	ore drop chance, training power, or shot damage.
]]

const Balance = require("./Balance")

export type PetKind = "Ores" | "Training" | "Damage"
export type PetStyle = "Bunny" | "Cat" | "Bird" | "Dragon"

export type PetDef = {
	id: string,
	name: string,
	rarity: number,
	kind: PetKind,
	-- The extra share this pet adds, e.g. 0.2 for +20%.
	bonus: number,
	style: PetStyle,
	body: Color3,
	accent: Color3,
}

export type EggDef = {
	id: string,
	name: string,
	unlockStage: number,
	costMultiplier: number,
	color: Color3,
	pets: { { petId: string, weight: number } },
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- The bonus a pet of each rarity gives.
const RARITY_BONUS = { 0.05, 0.1, 0.2, 0.35, 0.6, 1, 1.75 }

const LIST: { PetDef } = {}
const BY_ID: { [string]: PetDef } = {}

local function pet(
	id: string,
	name: string,
	rarity: number,
	kind: PetKind,
	style: PetStyle,
	body: Color3,
	accent: Color3
): string
	local def: PetDef = {
		id = id,
		name = name,
		rarity = rarity,
		kind = kind,
		bonus = RARITY_BONUS[rarity],
		style = style,
		body = body,
		accent = accent,
	}
	table.insert(LIST, def)
	BY_ID[id] = def
	return id
end

const EGGS: { EggDef } = {
	{
		id = "MeadowEgg",
		name = "Meadow Egg",
		unlockStage = 1,
		costMultiplier = 200,
		color = rgb(120, 200, 90),
		pets = {
			{
				petId = pet(
					"Pebblepup",
					"Pebblepup",
					1,
					"Training",
					"Cat",
					rgb(170, 170, 160),
					rgb(90, 90, 85)
				),
				weight = 60,
			},
			{
				petId = pet(
					"Clovercat",
					"Clovercat",
					2,
					"Ores",
					"Cat",
					rgb(110, 200, 90),
					rgb(240, 250, 200)
				),
				weight = 30,
			},
			{
				petId = pet(
					"Bricklet",
					"Bricklet",
					3,
					"Damage",
					"Bunny",
					rgb(220, 70, 60),
					rgb(255, 220, 120)
				),
				weight = 9,
			},
			{
				petId = pet(
					"Sproutling",
					"Sproutling",
					4,
					"Training",
					"Bird",
					rgb(150, 90, 220),
					rgb(140, 255, 160)
				),
				weight = 1,
			},
		},
	},
	{
		id = "EmberEgg",
		name = "Ember Egg",
		unlockStage = 31,
		costMultiplier = 400,
		color = rgb(255, 120, 50),
		pets = {
			{
				petId = pet(
					"Cinderfox",
					"Cinderfox",
					2,
					"Damage",
					"Cat",
					rgb(230, 110, 40),
					rgb(255, 230, 170)
				),
				weight = 45,
			},
			{
				petId = pet(
					"Ashwing",
					"Ashwing",
					3,
					"Ores",
					"Bird",
					rgb(90, 80, 80),
					rgb(255, 140, 40)
				),
				weight = 35,
			},
			{
				petId = pet(
					"Magmaroo",
					"Magmaroo",
					4,
					"Training",
					"Bunny",
					rgb(150, 40, 30),
					rgb(255, 170, 40)
				),
				weight = 16,
			},
			{
				petId = pet(
					"Blazewyrm",
					"Blazewyrm",
					5,
					"Damage",
					"Dragon",
					rgb(255, 170, 30),
					rgb(255, 250, 200)
				),
				weight = 4,
			},
		},
	},
	{
		id = "PrismEgg",
		name = "Prism Egg",
		unlockStage = 61,
		costMultiplier = 800,
		color = rgb(170, 220, 255),
		pets = {
			{
				petId = pet(
					"Glimmerkit",
					"Glimmerkit",
					4,
					"Ores",
					"Cat",
					rgb(200, 150, 255),
					rgb(240, 240, 255)
				),
				weight = 50,
			},
			{
				petId = pet(
					"Shardhawk",
					"Shardhawk",
					5,
					"Training",
					"Bird",
					rgb(120, 220, 255),
					rgb(255, 255, 255)
				),
				weight = 35,
			},
			{
				petId = pet(
					"Voidbun",
					"Voidbun",
					6,
					"Ores",
					"Bunny",
					rgb(40, 20, 70),
					rgb(255, 70, 160)
				),
				weight = 13,
			},
			{
				petId = pet(
					"Prismadrake",
					"Prismadrake",
					7,
					"Damage",
					"Dragon",
					rgb(230, 250, 255),
					rgb(255, 120, 250)
				),
				weight = 2,
			},
		},
	},
}

const EGG_BY_ID: { [string]: EggDef } = {}
for _, egg in EGGS do
	EGG_BY_ID[egg.id] = egg
end

local Pets = {}

Pets.List = LIST
Pets.EGGS = EGGS

function Pets.get(id: string): PetDef?
	return BY_ID[id]
end

function Pets.egg(id: string): EggDef?
	return EGG_BY_ID[id]
end

-- The pet an egg hatches for a roll in [0, 1).
function Pets.roll(egg: EggDef, roll: number): PetDef
	local total = 0
	for _, entry in egg.pets do
		total += entry.weight
	end
	local running = 0
	for _, entry in egg.pets do
		running += entry.weight / total
		if roll < running then
			return BY_ID[entry.petId]
		end
	end
	return BY_ID[egg.pets[#egg.pets].petId]
end

function Pets.price(egg: EggDef): number
	return Balance.enemyCoins(egg.unlockStage) * egg.costMultiplier
end

return Pets
