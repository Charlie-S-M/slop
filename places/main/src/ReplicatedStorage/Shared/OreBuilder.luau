--!strict

-- Builds the small crystal or nugget clusters used for ore pickups and ore icons.

const Ores = require("./Ores")
const Rarity = require("./Rarity")

local OreBuilder = {}

local function chunk(
	model: Model,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material
)
	local part = Instance.new("Part")
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

--[[
	Returns an anchored model about 1.6 studs across, centered on its pivot. Rocks and metals are
	chunky nuggets; crystals, gems, and cores are glowing shards.
]]
function OreBuilder.build(def: Ores.OreDef): Model
	local model = Instance.new("Model")
	model.Name = def.id
	local rarity = Rarity.get(def.rarity)
	local dark = def.color:Lerp(Color3.new(0, 0, 0), 0.35)

	-- A rock base under every ore.
	local base = chunk(
		model,
		Vector3.new(1.3, 0.5, 1.1),
		CFrame.new(0, -0.45, 0),
		Color3.fromRGB(110, 105, 110),
		Enum.Material.Slate
	)
	model.PrimaryPart = base

	if def.style == "Rock" or def.style == "Metal" then
		local material = if def.style == "Metal" then Enum.Material.Metal else Enum.Material.Slate
		chunk(
			model,
			Vector3.new(0.8, 0.7, 0.8),
			CFrame.new(-0.2, 0, 0.1) * CFrame.Angles(0.3, 0.4, 0.2),
			def.color,
			material
		)
		chunk(
			model,
			Vector3.new(0.6, 0.55, 0.6),
			CFrame.new(0.35, -0.05, -0.15) * CFrame.Angles(-0.2, 0.9, 0.1),
			dark,
			material
		)
		chunk(
			model,
			Vector3.new(0.45, 0.4, 0.45),
			CFrame.new(0.1, 0.35, -0.1) * CFrame.Angles(0.5, 0.2, 0.6),
			def.color,
			material
		)
	else
		local material = if def.rarity >= 3 then Enum.Material.Neon else Enum.Material.Glass
		local shards = {
			{
				size = Vector3.new(0.42, 1.3, 0.42),
				cframe = CFrame.new(0, 0.25, 0) * CFrame.Angles(0, 0.6, 0.1),
			},
			{
				size = Vector3.new(0.32, 0.9, 0.32),
				cframe = CFrame.new(0.35, 0.05, 0.1) * CFrame.Angles(0, 0.3, -0.5),
			},
			{
				size = Vector3.new(0.3, 0.8, 0.3),
				cframe = CFrame.new(-0.35, 0.0, -0.1) * CFrame.Angles(0.2, 0.2, 0.55),
			},
			{
				size = Vector3.new(0.26, 0.6, 0.26),
				cframe = CFrame.new(0.05, -0.05, 0.38) * CFrame.Angles(0.6, 0, 0.1),
			},
		}
		for index, shard in shards do
			local part = chunk(
				model,
				shard.size,
				shard.cframe,
				if index % 2 == 0 then def.color else def.color:Lerp(Color3.new(1, 1, 1), 0.2),
				material
			)
			part.Transparency = if material == Enum.Material.Glass then 0.15 else 0
		end
		if def.style == "Core" then
			local core = chunk(
				model,
				Vector3.new(0.6, 0.6, 0.6),
				CFrame.new(0, 0.2, 0),
				rarity.glow,
				Enum.Material.Neon
			)
			core.Shape = Enum.PartType.Ball
		end
	end

	return model
end

return OreBuilder
