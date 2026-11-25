--!strict

-- 3D previews in the UI: a gun or ore model framed in a ViewportFrame, optionally spinning.

const RunService = game:GetService("RunService")

const Armor = require("@game/ReplicatedStorage/Shared/Armor")
const ArmorBuilder = require("@game/ReplicatedStorage/Shared/ArmorBuilder")
const GunBuilder = require("@game/ReplicatedStorage/Shared/GunBuilder")
const Guns = require("@game/ReplicatedStorage/Shared/Guns")
const OreBuilder = require("@game/ReplicatedStorage/Shared/OreBuilder")
const Ores = require("@game/ReplicatedStorage/Shared/Ores")
const PetBuilder = require("@game/ReplicatedStorage/Shared/PetBuilder")
const Pets = require("@game/ReplicatedStorage/Shared/Pets")

local Preview = {}

local spinning: { [ViewportFrame]: { model: Model, base: CFrame, speed: number } } = {}
local loopStarted = false

local function startLoop()
	if loopStarted then
		return
	end
	loopStarted = true
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for viewport, info in spinning do
			if not viewport.Parent then
				spinning[viewport] = nil
			elseif viewport.Visible then
				info.model:PivotTo(info.base * CFrame.Angles(0, t * info.speed, 0))
			end
		end
	end)
end

local function frame(viewport: ViewportFrame, model: Model, angle: CFrame, spin: number?)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
		elseif part:IsA("ParticleEmitter") or part:IsA("PointLight") then
			part:Destroy()
		end
	end
	-- Center the model on the origin so spinning turns it in place.
	local boxCFrame, boxSize = model:GetBoundingBox()
	model:PivotTo(angle * boxCFrame:ToObjectSpace(model:GetPivot()))
	model.Parent = viewport
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	local radius = boxSize.Magnitude / 2
	-- Long guns fit their box tightly; the bounding sphere alone leaves them tiny.
	local distance = radius / math.tan(math.rad(camera.FieldOfView / 2)) * 0.82
	camera.CFrame = CFrame.lookAt(Vector3.new(0, radius * 0.25, distance), Vector3.zero)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	viewport.LightDirection = Vector3.new(-1, -1.5, -1)
	viewport.Ambient = Color3.fromRGB(170, 170, 185)
	viewport.LightColor = Color3.fromRGB(255, 255, 255)
	if spin then
		spinning[viewport] = { model = model, base = model:GetPivot(), speed = spin }
		startLoop()
	end
end

function Preview.gun(viewport: ViewportFrame, gunId: string, spin: number?)
	viewport:ClearAllChildren()
	spinning[viewport] = nil
	local def = Guns.get(gunId)
	if not def then
		return
	end
	local model = GunBuilder.build(def)
	-- Side view: barrel pointing left, tilted slightly toward the camera.
	frame(
		viewport,
		model,
		CFrame.Angles(0, math.rad(-90), 0) * CFrame.Angles(math.rad(-8), 0, math.rad(12)),
		spin
	)
end

function Preview.armor(viewport: ViewportFrame, armorId: string, spin: number?)
	viewport:ClearAllChildren()
	spinning[viewport] = nil
	local def = Armor.get(armorId)
	if not def then
		return
	end
	frame(viewport, ArmorBuilder.build(def), CFrame.Angles(math.rad(12), math.rad(200), 0), spin)
end

function Preview.pet(viewport: ViewportFrame, petId: string, spin: number?)
	viewport:ClearAllChildren()
	spinning[viewport] = nil
	local def = Pets.get(petId)
	if not def then
		return
	end
	frame(viewport, PetBuilder.build(def), CFrame.Angles(math.rad(8), math.rad(150), 0), spin)
end

function Preview.ore(viewport: ViewportFrame, oreId: string, spin: number?)
	viewport:ClearAllChildren()
	spinning[viewport] = nil
	local def = Ores.get(oreId)
	if not def then
		return
	end
	frame(viewport, OreBuilder.build(def), CFrame.Angles(math.rad(10), math.rad(30), 0), spin)
end

function Preview.viewport(props: { [string]: any }): ViewportFrame
	local viewport = Instance.new("ViewportFrame")
	viewport.BackgroundTransparency = 1
	viewport.Size = UDim2.fromScale(1, 1)
	for key, value in props do
		(viewport :: any)[key] = value
	end
	return viewport
end

return Preview
