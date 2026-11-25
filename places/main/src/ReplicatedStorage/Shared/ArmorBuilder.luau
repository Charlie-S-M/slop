--!strict
--[[
	Builds armor pieces from bricks in their set's colors. Each piece is a list of shapes laid out
	around the body part it covers, sized from that part, so the same layout fits a character and a
	standalone display model. Helmets cover the head, chestplates the torso, and boots each foot.
]]

const Armor = require("./Armor")
const Rarity = require("./Rarity")

-- One brick of a piece: its size and offset as fractions of the body part it sits on.
type Shape = { size: Vector3, offset: Vector3, trim: boolean }

local function shape(
	sx: number,
	sy: number,
	sz: number,
	ox: number,
	oy: number,
	oz: number,
	trim: boolean?
): Shape
	return { size = Vector3.new(sx, sy, sz), offset = Vector3.new(ox, oy, oz), trim = trim == true }
end

-- The body part names each slot covers, R15 first, then R6.
const MOUNTS: { [string]: { { string } } } = {
	Helmet = { { "Head" } },
	Chestplate = { { "UpperTorso" }, { "Torso" } },
	Boots = { { "LeftFoot", "RightFoot" }, { "Left Leg", "Right Leg" } },
}

-- Offsets are in units of the body part's size, from its center; the front of a body part is -Z.
const LAYOUTS: { [string]: { Shape } } = {
	Helmet = {
		shape(1.2, 0.6, 1.2, 0, 0.32, 0),
		shape(1.24, 0.14, 1.24, 0, 0.02, 0, true),
		shape(1.16, 0.5, 0.12, 0, -0.05, 0.58),
		shape(0.14, 0.5, 1.1, 0.6, -0.05, 0),
		shape(0.14, 0.5, 1.1, -0.6, -0.05, 0),
		shape(0.16, 0.34, 0.16, 0, 0.72, 0, true),
	},
	Chestplate = {
		shape(1.12, 0.9, 1.16, 0, 0.05, 0),
		shape(1.14, 0.12, 1.18, 0, -0.38, 0, true),
		shape(0.5, 0.4, 0.06, 0, 0.12, -0.6, true),
		shape(0.42, 0.3, 1.1, 0.68, 0.38, 0),
		shape(0.42, 0.3, 1.1, -0.68, 0.38, 0),
	},
	Boots = {
		shape(1.2, 1.1, 1.25, 0, 0.05, -0.05),
		shape(1.24, 0.2, 1.3, 0, -0.45, -0.08, true),
	},
}

-- A nominal body part size for each slot, for display models with no character.
const DISPLAY_SIZE: { [string]: Vector3 } = {
	Helmet = Vector3.new(1.2, 1.2, 1.2),
	Chestplate = Vector3.new(2, 1.6, 1),
	Boots = Vector3.new(1, 0.5, 1),
}

local function brick(def: Armor.ArmorDef, piece: Shape, bodySize: Vector3, at: CFrame): Part
	local part = Instance.new("Part")
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.Material = if piece.trim and def.rarity >= 5
		then Enum.Material.Neon
		else Enum.Material.SmoothPlastic
	part.Color = if piece.trim then def.trim else def.body
	part.TopSurface = Enum.SurfaceType.Studs
	part.Size = piece.size * bodySize
	part.CFrame = at * CFrame.new(piece.offset * bodySize)
	return part
end

local ArmorBuilder = {}

-- A standalone, anchored model of the piece, for the forge cutscene and menus.
function ArmorBuilder.build(def: Armor.ArmorDef): Model
	local model = Instance.new("Model")
	model.Name = def.id
	local bodySize = DISPLAY_SIZE[def.slot]
	local copies: { number } = if def.slot == "Boots" then { -0.6, 0.6 } else { 0 }
	for _, side in copies do
		local at = CFrame.new(side * bodySize.X, 0, 0)
		for _, piece in LAYOUTS[def.slot] do
			local part = brick(def, piece, bodySize, at)
			part.Anchored = true
			part.Parent = model
		end
	end
	local scale = Rarity.get(def.rarity).gunScale
	model:ScaleTo(1.6 * scale)
	return model
end

-- Welds the piece onto `character` under a folder named "Armor", returning the parts it made.
function ArmorBuilder.attach(character: Model, def: Armor.ArmorDef): { BasePart }
	local folder: Instance
	local existing = character:FindFirstChild("Armor")
	if existing then
		folder = existing
	else
		local created = Instance.new("Folder")
		created.Name = "Armor"
		created.Parent = character
		folder = created
	end
	local made: { BasePart } = {}
	for _, names in MOUNTS[def.slot] do
		local mounts: { BasePart } = {}
		for _, name in names do
			local found = character:FindFirstChild(name)
			if found and found:IsA("BasePart") then
				table.insert(mounts, found)
			end
		end
		if #mounts == #names then
			for _, mount in mounts do
				-- R6 legs are tall, so a boot sits on their lower quarter.
				local size = mount.Size
				local at = mount.CFrame
				if def.slot == "Boots" and string.find(mount.Name, "Leg") then
					size = Vector3.new(size.X, size.Y * 0.25, size.Z)
					at = mount.CFrame * CFrame.new(0, -mount.Size.Y * 0.375, 0)
				end
				for _, piece in LAYOUTS[def.slot] do
					local part = brick(def, piece, size, at)
					part.Name = def.slot
					local weld = Instance.new("WeldConstraint")
					weld.Part0 = mount
					weld.Part1 = part
					weld.Parent = part
					part.Parent = folder
					table.insert(made, part)
				end
			end
			break
		end
	end
	return made
end

return ArmorBuilder
