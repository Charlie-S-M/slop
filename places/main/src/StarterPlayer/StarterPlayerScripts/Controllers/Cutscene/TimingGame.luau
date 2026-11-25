--!strict
local Input = game:GetService("UserInputService")
local Run = game:GetService("RunService")
local Balance = require("@game/ReplicatedStorage/Shared/Balance")
local GunStats = require("@game/ReplicatedStorage/Shared/GunStats")
local TimingGame = {}
function TimingGame.strike(
	screen: ScreenGui,
	index: number,
	at: Vector2,
	alive: () -> boolean,
	record: (number) -> ()
): number
	task.wait(0.25 + math.random() * 0.35)
	if not alive() then
		return 0
	end
	local panel = Instance.new("Frame")
	panel.Name = "StrikeTarget"
	panel.BackgroundTransparency = 1
	panel.Size = UDim2.fromOffset(0, 0)
	panel.Position = UDim2.fromOffset(at.X, at.Y)
	panel.Parent = screen
	local function ring(color: Color3): Frame
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Size = UDim2.fromOffset(64, 64)
		f.BackgroundTransparency = 1
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = f
		local edge = Instance.new("UIStroke")
		edge.Color = color
		edge.Thickness = 4
		edge.Parent = f
		f.Parent = panel
		return f
	end
	ring(Color3.new(1, 1, 1))
	local moving = ring(Color3.fromRGB(255, 172, 58))
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.fromOffset(0, 51)
	label.Size = UDim2.fromOffset(360, 38)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.12
	label.Font = Enum.Font.GothamBold
	label.TextSize = 19
	label.Text = ("Strike %d/%d  •  Tap when the rings meet"):format(index, Balance.STRIKES)
	label.Parent = panel
	local started = os.clock()
	local score: number? = nil
	local input = Input.InputBegan:Connect(function(key)
		if
			score == nil
			and (
				key.UserInputType == Enum.UserInputType.MouseButton1
				or key.UserInputType == Enum.UserInputType.Touch
				or key.KeyCode == Enum.KeyCode.ButtonA
			)
		then
			score = GunStats.strikeAccuracy((os.clock() - started) / Balance.RING_SECONDS - 1)
		end
	end)
	while score == nil and alive() do
		local elapsed = (os.clock() - started) / Balance.RING_SECONDS
		local diameter = math.max(14, 64 + 100 * (1 - elapsed))
		moving.Size = UDim2.fromOffset(diameter, diameter)
		if elapsed >= 1.32 then
			break
		end
		Run.RenderStepped:Wait()
	end
	input:Disconnect()
	local accuracy = score or 0
	if alive() then
		record(accuracy)
	end
	if panel.Parent and alive() then
		label.Text = GunStats.strikeLabel(accuracy)
		label.TextColor3 = if accuracy >= 0.75
			then Color3.fromRGB(122, 255, 173)
			else Color3.fromRGB(255, 180, 98)
		task.wait(0.25)
	end
	panel:Destroy()
	return accuracy
end
return TimingGame
