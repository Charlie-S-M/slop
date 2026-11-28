--!strict
--[[
	Builds a pet as a small brick creature: a body, a head with eyes, and parts by style (ears for
	cats and bunnies, wings for birds and dragons, a tail, and horns for dragons). The model faces
	-Z with its pivot at the body's center, and every part is anchored and non-colliding.
]]

const Pets = require("./Pets")
const Rarity = require("./Rarity")

local function brick(
	model: Model,
	size: Vector3,
	offset: Vector3,
	color: Color3,
	rotation: Vector3?
): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Studs
	part.Color = color
	part.Size = size
	local spin = rotation or Vector3.zero
	part.CFrame = CFrame.new(offset)
		* CFrame.Angles(math.rad(spin.X), math.rad(spin.Y), math.rad(spin.Z))
	part.Parent = model
	return part
end

local PetBuilder = {}

function PetBuilder.build(def: Pets.PetDef): Model
	local model = Instance.new("Model")
	model.Name = def.id
	local body = brick(model, Vector3.new(1.2, 1, 1.5), Vector3.zero, def.body)
	model.PrimaryPart = body
	brick(model, Vector3.new(1.1, 1, 1), Vector3.new(0, 0.6, -0.9), def.body)
	for _, side in { -1, 1 } do
		brick(
			model,
			Vector3.new(0.22, 0.26, 0.05),
			Vector3.new(side * 0.25, 0.7, -1.41),
			Color3.new(0.08, 0.08, 0.1)
		)
		brick(
			model,
			Vector3.new(0.25, 0.45, 0.25),
			Vector3.new(side * 0.4, -0.65, -0.45),
			def.accent
		)
		brick(
			model,
			Vector3.new(0.25, 0.45, 0.25),
			Vector3.new(side * 0.4, -0.65, 0.45),
			def.accent
		)
		if def.style == "Cat" then
			brick(
				model,
				Vector3.new(0.3, 0.35, 0.15),
				Vector3.new(side * 0.35, 1.25, -0.9),
				def.accent
			)
		elseif def.style == "Bunny" then
			brick(
				model,
				Vector3.new(0.22, 0.8, 0.15),
				Vector3.new(side * 0.25, 1.45, -0.85),
				def.accent
			)
		elseif def.style == "Bird" or def.style == "Dragon" then
			brick(
				model,
				Vector3.new(0.9, 0.12, 0.8),
				Vector3.new(side * 0.95, 0.25, 0.1),
				def.accent,
				Vector3.new(0, 0, side * 25)
			)
		end
		if def.style == "Dragon" then
			brick(
				model,
				Vector3.new(0.15, 0.4, 0.15),
				Vector3.new(side * 0.3, 1.25, -0.8),
				def.accent,
				Vector3.new(-20, 0, 0)
			)
		end
	end
	if def.style == "Bird" then
		brick(
			model,
			Vector3.new(0.3, 0.2, 0.35),
			Vector3.new(0, 0.5, -1.55),
			Color3.fromRGB(255, 190, 60)
		)
	else
		brick(
			model,
			Vector3.new(0.25, 0.25, 0.9),
			Vector3.new(0, 0.25, 1.1),
			def.accent,
			Vector3.new(30, 0, 0)
		)
	end
	-- Top pets glow along their accent parts.
	if def.rarity >= 5 then
		for _, part in model:GetChildren() do
			if part:IsA("BasePart") and part.Color == def.accent then
				part.Material = Enum.Material.Neon
			end
		end
	end
	model:ScaleTo(0.8 + 0.06 * def.rarity)
	return model
end

-- The rarity color, for UI around a pet.
function PetBuilder.color(def: Pets.PetDef): Color3
	return Rarity.get(def.rarity).color
end

return PetBuilder
