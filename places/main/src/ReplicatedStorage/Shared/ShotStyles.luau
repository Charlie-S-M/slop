--!strict
--[[
	How a gun's shots look, by rarity. Below Legendary every gun shares the basic tracer; each top
	tier gets its own. GunController draws from this, so the look of a tier is data, not code.
]]

const Rarity = require("./Rarity")

export type Trail = "None" | "Embers" | "Twin" | "Prism" | "Beam"
export type Impact = "Puff" | "Sparks" | "Ring" | "Halo" | "Nova"

export type ShotStyle = {
	name: string,
	-- Tracer color. Nil means the gun's own accent mixed with its rarity glow.
	coreColor: Color3?,
	-- A wider, fainter tracer drawn around the core. Nil draws none.
	sheathColor: Color3?,
	-- Multiplies the tracer width.
	widthScale: number,
	trail: Trail,
	impact: Impact,
	-- Most extra parts one shot adds beyond its tracer, impact, and flash.
	extraParts: number,
	-- A short column of light rising from the muzzle.
	pillar: boolean,
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

const BASIC: ShotStyle = {
	name = "Basic",
	coreColor = nil,
	sheathColor = nil,
	widthScale = 1,
	trail = "None",
	impact = "Puff",
	extraParts = 0,
	pillar = false,
}

const TOP: { [number]: ShotStyle } = {
	[5] = {
		name = "Legendary",
		coreColor = rgb(255, 214, 90),
		sheathColor = nil,
		widthScale = 1.15,
		trail = "Embers",
		impact = "Sparks",
		extraParts = 4,
		pillar = false,
	},
	[6] = {
		name = "Mythic",
		coreColor = rgb(255, 70, 90),
		sheathColor = rgb(170, 80, 255),
		widthScale = 1.2,
		trail = "Twin",
		impact = "Ring",
		extraParts = 2,
		pillar = false,
	},
	[7] = {
		name = "Godly",
		coreColor = nil,
		sheathColor = rgb(255, 120, 250),
		widthScale = 1.3,
		trail = "Prism",
		impact = "Halo",
		extraParts = 3,
		pillar = false,
	},
	[8] = {
		name = "Eternal",
		coreColor = rgb(255, 252, 240),
		sheathColor = rgb(170, 210, 255),
		widthScale = 1.5,
		trail = "Beam",
		impact = "Nova",
		extraParts = 6,
		pillar = true,
	},
}

local ShotStyles = {}

-- The prism tracer cycles through these colors, one per shot.
ShotStyles.PRISM = {
	rgb(255, 90, 120),
	rgb(255, 200, 80),
	rgb(120, 255, 160),
	rgb(80, 220, 255),
	rgb(200, 120, 255),
}

function ShotStyles.forRarity(tier: number): ShotStyle
	local clamped = math.clamp(math.floor(tier), 1, Rarity.Count)
	return TOP[clamped] or BASIC
end

return ShotStyles
