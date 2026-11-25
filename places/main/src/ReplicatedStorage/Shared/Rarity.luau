--!strict

export type RarityDef = {
	tier: number,
	name: string,
	color: Color3,
	-- A second color for gradients on cards, text, and gun accents.
	glow: Color3,
	-- How much a forged gun's power is multiplied for landing this rarity.
	powerMultiplier: number,
	-- How much bigger a gun of this rarity is than a Common one.
	gunScale: number,
}

const LIST: { RarityDef } = {
	{
		tier = 1,
		name = "Common",
		color = Color3.fromRGB(176, 186, 197),
		glow = Color3.fromRGB(235, 240, 245),
		powerMultiplier = 1,
		gunScale = 1,
	},
	{
		tier = 2,
		name = "Uncommon",
		color = Color3.fromRGB(85, 214, 84),
		glow = Color3.fromRGB(190, 255, 150),
		powerMultiplier = 2.5,
		gunScale = 1.1,
	},
	{
		tier = 3,
		name = "Rare",
		color = Color3.fromRGB(56, 156, 255),
		glow = Color3.fromRGB(140, 225, 255),
		powerMultiplier = 6,
		gunScale = 1.22,
	},
	{
		tier = 4,
		name = "Epic",
		color = Color3.fromRGB(170, 85, 255),
		glow = Color3.fromRGB(240, 150, 255),
		powerMultiplier = 15,
		gunScale = 1.36,
	},
	{
		tier = 5,
		name = "Legendary",
		color = Color3.fromRGB(255, 176, 32),
		glow = Color3.fromRGB(255, 240, 120),
		powerMultiplier = 40,
		gunScale = 1.52,
	},
	{
		tier = 6,
		name = "Mythic",
		color = Color3.fromRGB(255, 56, 96),
		glow = Color3.fromRGB(255, 160, 80),
		powerMultiplier = 110,
		gunScale = 1.7,
	},
	{
		tier = 7,
		name = "Celestial",
		color = Color3.fromRGB(64, 240, 230),
		glow = Color3.fromRGB(255, 120, 250),
		powerMultiplier = 300,
		gunScale = 1.9,
	},
}

local Rarity = {}

Rarity.List = LIST
Rarity.Count = #LIST

function Rarity.get(tier: number): RarityDef
	return LIST[math.clamp(math.floor(tier), 1, #LIST)]
end

return Rarity
