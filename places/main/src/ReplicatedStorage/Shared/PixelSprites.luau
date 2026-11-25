--!strict
--[[
	16x16 pixel-art icons for the hotbar, as rows of keys: "." clear, "k" outline, "b" body,
	"a" accent, "t" trim, "w" shine. The keys are colored from the item's own palette, so one
	sprite serves every gun of a kind, every armor piece of a slot, and every pet of a style.
]]

export type Run = { x: number, y: number, width: number, key: string }

local PixelSprites = {}

PixelSprites.SPRITES = {
	Pistol = {
		"................",
		"................",
		"................",
		"................",
		"..kkkkkkkkkkkk..",
		"..kwbbbbbbbbbak.",
		"..kbtttbbbbbbak.",
		"..kbbbbbbbbbbkk.",
		"..kkkkbbkkkkkk..",
		".....kbbk.......",
		".....kbak.......",
		"....kbbak.......",
		"....kbbbk.......",
		"....kkkkk.......",
		"................",
		"................",
	},
	SMG = {
		"................",
		"................",
		"................",
		"................",
		"..kkkkkkkkkkk...",
		".kwbbbbbbbbbakkk",
		".kbbtttttbbbaaak",
		".kbbbbbbbbbbkkkk",
		".kkkkbbkbbkkk...",
		"....kbbkbak.....",
		"....kbbkbak.....",
		"...kbbk.kak.....",
		"...kbbk.kkk.....",
		"...kkkk.........",
		"................",
		"................",
	},
	Rifle = {
		"................",
		"................",
		"................",
		"................",
		"kkkk............",
		"kbbkkkkkkkkkkk..",
		"kbbbwbbbbbbbbakk",
		"kbbbtttbbbbbbaak",
		"kkkbbbbbbbbbkkkk",
		"..kkbbkkbkkk....",
		"...kbbkkbak.....",
		"...kkkk.kak.....",
		"........kbk.....",
		"........kkk.....",
		"................",
		"................",
	},
	Shotgun = {
		"................",
		"................",
		"................",
		"kkkk............",
		"kbbkkkkkkkkkkkk.",
		"kbbbwbbbbbbbbbak",
		"kbbbbbbbbbbbbbak",
		"kbbbtttttttbbkkk",
		"kkkkbbbkkkkkkk..",
		"...kbbbk........",
		"...kbbak........",
		"..kbbbak........",
		"..kbbbbk........",
		"..kkkkkk........",
		"................",
		"................",
	},
	Heavy = {
		"................",
		"................",
		"....kkkkkk......",
		"...kbbbbbbk.....",
		"..kkbbwbbbbkkkkk",
		".kbbbbbbbbbbaaak",
		".kbtttbbbbbbaaak",
		".kbbbbbbbbbbaaak",
		".kbbbbbbbbbbkkkk",
		"..kkkbbbbkkk....",
		"....kbbbbk......",
		"....kbaabk......",
		"....kbbbbk......",
		"....kkkkkk......",
		"................",
		"................",
	},
	Helmet = {
		"................",
		"................",
		".....kkkkkk.....",
		"....kbbbbbbk....",
		"...kbwbbbbbbk...",
		"..kbbbbbbbbbbk..",
		"..kbbbbbbbbbbk..",
		"..kttttttttttk..",
		"..kbbkkkkkkbbk..",
		"..kbbkaaaakbbk..",
		"..kbbkkkkkkbbk..",
		"..kbbk....kbbk..",
		"..kbbk....kbbk..",
		"..kkkk....kkkk..",
		"................",
		"................",
	},
	Chestplate = {
		"................",
		"................",
		"..kkkk....kkkk..",
		".kbbbbkkkkbbbbk.",
		".kbwbbbbbbbbbbk.",
		".kbbbbbbbbbbbbk.",
		".kkkbbbaabbbkkk.",
		"...kbbaaaabbk...",
		"...kbbbaabbbk...",
		"...kttttttttk...",
		"...kbbbbbbbbk...",
		"...kbbbbbbbbk...",
		"...kbbbbbbbbk...",
		"...kkkkkkkkkk...",
		"................",
		"................",
	},
	Boots = {
		"................",
		"................",
		"................",
		"..kkkk....kkkk..",
		"..kbbk....kbbk..",
		"..kwbk....kwbk..",
		"..kbbk....kbbk..",
		"..kttk....kttk..",
		"..kbbk....kbbk..",
		"..kbbkk...kbbkk.",
		".kbbbbbk.kbbbbbk",
		".kaaaaak.kaaaaak",
		".kkkkkkk.kkkkkkk",
		"................",
		"................",
		"................",
	},
	Critter = {
		"................",
		"................",
		"....kk....kk....",
		"...kak...kak....",
		"...kbkkkkkbk....",
		"..kbbbbbbbbbk...",
		"..kbwkbbbkwbk...",
		"..kbbkbbbkbbk...",
		"..kbbbbaabbbkk..",
		"..kkbbbbbbbbbak.",
		"...kbbbbbbbbkak.",
		"...kbbbbbbbbkk..",
		"...kbkkbbkkbk...",
		"...kak.kk.kak...",
		"...kkk....kkk...",
		"................",
	},
	Winged = {
		"................",
		"................",
		"......kkkk......",
		".....kbbbbk.....",
		"....kbwkkwbk....",
		"....kbbbbbbkk...",
		".kk.kbbbbbbtk...",
		"kaakkbbbbbbkk.kk",
		"kaaaabbbbbbbkaak",
		".kaaabbbbbbbaaak",
		"..kkkbbbbbbbkkk.",
		"....kbbbbbbk....",
		"....kbkkkkbk....",
		"....kak..kak....",
		"....kkk..kkk....",
		"................",
	},
} :: { [string]: { string } }

const GUN_SPRITES: { [string]: string } = {
	Pistol = "Pistol",
	SMG = "SMG",
	Burst = "SMG",
	Rifle = "Rifle",
	Sniper = "Rifle",
	Shotgun = "Shotgun",
	Minigun = "Heavy",
	Launcher = "Heavy",
}

function PixelSprites.forGun(kind: string): string
	return GUN_SPRITES[kind] or "Pistol"
end

function PixelSprites.forArmor(slot: string): string
	return if PixelSprites.SPRITES[slot] then slot else "Chestplate"
end

function PixelSprites.forPet(style: string): string
	return if style == "Bird" or style == "Dragon" then "Winged" else "Critter"
end

-- Each row's stretches of one key, so an icon draws as a few frames instead of 256 pixels.
function PixelSprites.runs(rows: { string }): { Run }
	local found: { Run } = {}
	for y, row in rows do
		local x = 1
		while x <= #row do
			local key = string.sub(row, x, x)
			local width = 1
			while x + width <= #row and string.sub(row, x + width, x + width) == key do
				width += 1
			end
			if key ~= "." then
				table.insert(found, { x = x - 1, y = y - 1, width = width, key = key })
			end
			x += width
		end
	end
	return found
end

return PixelSprites
