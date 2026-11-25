--!strict
--[[
	A training dummy beside the forge for comparing builds. It's built on this client only: shooting
	it shows each hit's damage, from the same formula the server uses (gun, Power, rebirths, level,
	and pets), and a rolling five-second DPS above its head. It trains nothing and drops nothing.
]]

const TweenService = game:GetService("TweenService")

const Format = require("@game/ReplicatedStorage/Shared/Format")
const Kit = require("./UI/Kit")

local TrainingDummy = {}

const WINDOW = 5

local model: Model? = nil
local dpsLabel: TextLabel
local hits: { { at: number, amount: number } } = {}

local function brick(
	parent: Instance,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	name: string?
): Part
	local part = Instance.new("Part")
	part.Name = name or "Part"
	part.Anchored = true
	part.CanCollide = true
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Studs
	part.Color = color
	part.Size = size
	part.CFrame = cframe
	part.Parent = parent
	return part
end

local function build()
	local lobby = workspace:WaitForChild("Lobby", 30)
	local forge = lobby and lobby:WaitForChild("Forge", 30)
	local anvil = forge and forge:WaitForChild("Anvil", 30)
	if not anvil or not anvil:IsA("BasePart") then
		return
	end
	local dummy = Instance.new("Model")
	dummy.Name = "TrainingDummy"
	-- Just past the forge building's front corner, clear of its doorway, facing the plaza.
	local box, size = (forge :: Model):GetBoundingBox()
	local floorY = anvil.Position.Y - anvil.Size.Y / 2
	local base = CFrame.new(
		box.Position.X - size.X / 2 - 6,
		floorY,
		box.Position.Z + size.Z / 2 + 6
	) * CFrame.Angles(0, math.rad(-90), 0)
	local wood = Color3.fromRGB(150, 105, 65)
	local straw = Color3.fromRGB(235, 200, 110)
	brick(dummy, Vector3.new(4, 0.6, 4), base * CFrame.new(0, 0.3, 0), wood)
	brick(dummy, Vector3.new(0.8, 3, 0.8), base * CFrame.new(0, 2.1, 0), wood)
	local body =
		brick(dummy, Vector3.new(2.6, 2.8, 1.6), base * CFrame.new(0, 4.6, 0), straw, "Body")
	brick(dummy, Vector3.new(1.8, 1.8, 1.8), base * CFrame.new(0, 6.9, 0), straw, "Head")
	brick(dummy, Vector3.new(4.6, 0.6, 0.6), base * CFrame.new(0, 5.3, 0), wood)
	brick(
		dummy,
		Vector3.new(1.4, 1.4, 0.1),
		base * CFrame.new(0, 4.8, -0.85),
		Color3.fromRGB(230, 60, 60)
	)
	dummy.PrimaryPart = body
	local gui = Kit.new("BillboardGui", {
		Size = UDim2.fromOffset(220, 70),
		StudsOffset = Vector3.new(0, 5.5, 0),
		MaxDistance = 120,
		AlwaysOnTop = true,
		Parent = body,
	})
	Kit.text({
		Text = "🎯 Training Dummy",
		Size = UDim2.fromScale(1, 0.45),
		Stroke = 2,
		Parent = gui,
	})
	dpsLabel = Kit.text({
		Text = "Shoot me to see your DPS",
		Size = UDim2.fromScale(1, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		TextColor3 = Color3.fromRGB(255, 220, 100),
		Stroke = 2,
		Parent = gui,
	})
	dummy.Parent = workspace
	model = dummy
end

-- True when a raycast hit belongs to the dummy.
function TrainingDummy.isDummy(part: Instance): boolean
	return model ~= nil and part:IsDescendantOf(model)
end

-- Records a hit of `amount` damage at `position`, shows the number, and updates the DPS.
function TrainingDummy.hit(amount: number, position: Vector3)
	local now = os.clock()
	table.insert(hits, { at = now, amount = amount })
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.Transparency = 1
	holder.Size = Vector3.one * 0.2
	holder.Position = position
	holder.Parent = workspace
	local gui = Kit.new("BillboardGui", {
		Size = UDim2.fromOffset(120, 40),
		AlwaysOnTop = true,
		Parent = holder,
	})
	local label = Kit.text({
		Text = Format.abbreviate(amount),
		Size = UDim2.fromScale(1, 1),
		TextColor3 = Color3.fromRGB(255, 240, 200),
		Stroke = 2,
		Parent = gui,
	})
	TweenService:Create(gui, TweenInfo.new(0.7), { StudsOffset = Vector3.new(0, 2.5, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(0.7), { TextTransparency = 1 }):Play()
	task.delay(0.75, function()
		holder:Destroy()
	end)
end

function TrainingDummy:Start()
	task.spawn(build)
	task.spawn(function()
		while true do
			task.wait(0.25)
			if dpsLabel then
				local now = os.clock()
				local total = 0
				for index = #hits, 1, -1 do
					if now - hits[index].at > WINDOW then
						table.remove(hits, index)
					else
						total += hits[index].amount
					end
				end
				dpsLabel.Text = if #hits > 0
					then `{Format.abbreviate(total / WINDOW)} DPS`
					else "Shoot me to see your DPS"
			end
		end
	end)
end

return TrainingDummy
