--!strict
--[[
	The impact frame a reveal plays for its rarity, before the reward card shows. Below Legendary
	there is none. Forged guns use these today; armor and attachment chests reuse them.
]]

const Rarity = require("./Rarity")

export type RevealKind = "Ember" | "Implode" | "Prism" | "Radiant"

export type RevealStyle = {
	kind: RevealKind,
	-- How long the sequence holds the reveal before the card appears.
	seconds: number,
	-- The flash frames: the item's silhouette in `silhouette` over `background`, then inverted.
	background: Color3,
	silhouette: Color3,
	-- The color of the shockwave, burst, or particles that follow.
	accent: Color3,
	-- How dark the scene gets behind the effect (0 = not at all).
	darken: number,
	-- A spinning prismatic halo that stays behind the item while the card shows.
	halo: boolean,
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

const STYLES: { [number]: RevealStyle } = {
	[5] = {
		kind = "Ember",
		seconds = 0.9,
		background = rgb(20, 12, 4),
		silhouette = rgb(255, 196, 60),
		accent = rgb(255, 130, 40),
		darken = 0,
		halo = false,
	},
	[6] = {
		kind = "Implode",
		seconds = 1.2,
		background = rgb(12, 4, 24),
		silhouette = rgb(200, 110, 255),
		accent = rgb(170, 80, 255),
		darken = 0.25,
		halo = false,
	},
	[7] = {
		kind = "Prism",
		seconds = 1.5,
		background = rgb(0, 0, 0),
		silhouette = rgb(255, 255, 255),
		accent = rgb(255, 120, 250),
		darken = 0.55,
		halo = true,
	},
	[8] = {
		kind = "Radiant",
		seconds = 1.9,
		background = rgb(255, 250, 235),
		silhouette = rgb(30, 24, 10),
		accent = rgb(255, 236, 190),
		darken = 0.55,
		halo = true,
	},
	-- Celestial, Cosmic, and Omega also play their tier cutscene (TierCutscene) before this.
	[9] = {
		kind = "Radiant",
		seconds = 1.9,
		background = rgb(235, 250, 255),
		silhouette = rgb(20, 40, 70),
		accent = rgb(150, 230, 255),
		darken = 0.55,
		halo = true,
	},
	[10] = {
		kind = "Radiant",
		seconds = 1.9,
		background = rgb(20, 15, 60),
		silhouette = rgb(230, 120, 255),
		accent = rgb(90, 110, 255),
		darken = 0.65,
		halo = true,
	},
	[11] = {
		kind = "Radiant",
		seconds = 2.1,
		background = rgb(10, 0, 5),
		silhouette = rgb(255, 60, 80),
		accent = rgb(255, 255, 255),
		darken = 0.75,
		halo = true,
	},
}

local RevealStyles = {}

function RevealStyles.forRarity(tier: number): RevealStyle?
	return STYLES[math.clamp(math.floor(tier), 1, Rarity.Count)]
end

return RevealStyles
