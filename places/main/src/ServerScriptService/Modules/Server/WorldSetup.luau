--!strict

-- Makes sure the lobby exists and sets the world's lighting, sky, and settings before players
-- arrive, so the look lives in code rather than only in the place file.

const Balance = require("@game/ReplicatedStorage/Shared/Balance")
const Lighting = game:GetService("Lighting")
const Players = game:GetService("Players")

const LobbyBuilder = require("./World/LobbyBuilder")

-- A bright cartoon skybox from the Creator Store (asset 528506487).
const SKY_FACES = {
	SkyboxBk = "rbxassetid://528480826",
	SkyboxDn = "rbxassetid://528481890",
	SkyboxFt = "rbxassetid://528481964",
	SkyboxLf = "rbxassetid://528482047",
	SkyboxRt = "rbxassetid://528482365",
	SkyboxUp = "rbxassetid://528484371",
}

local WorldSetup = {}

local function child<T>(className: string, name: string): T
	local existing = Lighting:FindFirstChildOfClass(className :: any)
	if existing then
		return existing :: any
	end
	local created = Instance.new(className :: any)
	created.Name = name
	created.Parent = Lighting
	return created :: any
end

local function applyLighting()
	Lighting.Brightness = 2.3
	Lighting.ExposureCompensation = -0.15
	Lighting.Ambient = Color3.fromRGB(95, 95, 110)
	Lighting.OutdoorAmbient = Color3.fromRGB(125, 128, 145)
	Lighting.ClockTime = 14.2
	Lighting.GeographicLatitude = 35
	Lighting.EnvironmentDiffuseScale = 0.8
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.3

	local sky = child("Sky", "Sky") :: Sky
	for face, id in SKY_FACES do
		(sky :: any)[face] = id
	end
	sky.CelestialBodiesShown = false

	local atmosphere = child("Atmosphere", "Atmosphere") :: Atmosphere
	atmosphere.Density = 0.26
	atmosphere.Offset = 0.12
	atmosphere.Color = Color3.fromRGB(190, 220, 255)
	atmosphere.Decay = Color3.fromRGB(110, 150, 220)
	atmosphere.Glare = 0.1
	atmosphere.Haze = 0.8

	local correction = child("ColorCorrectionEffect", "ColorCorrection") :: ColorCorrectionEffect
	correction.Saturation = 0.22
	correction.Contrast = 0.1
	correction.Brightness = -0.02
	correction.TintColor = Color3.new(1, 1, 1)

	local bloom = child("BloomEffect", "Bloom") :: BloomEffect
	bloom.Intensity = 0.55
	bloom.Size = 24
	bloom.Threshold = 1.7

	local rays = child("SunRaysEffect", "SunRays") :: SunRaysEffect
	rays.Intensity = 0.05

	local depth = Lighting:FindFirstChildOfClass("DepthOfFieldEffect")
	if depth then
		depth.Enabled = false
	end
end

function WorldSetup:Init()
	-- The lobby is normally baked into the place. A place without one builds it from code.
	if not workspace:FindFirstChild("Lobby") then
		LobbyBuilder.build(workspace)
	end
	applyLighting()
	Players.RespawnTime = 3
	workspace.Gravity = 160
end

function WorldSetup:Start()
	task.spawn(function()
		local epoch = workspace:GetServerTimeNow()
		while true do
			local elapsed = (workspace:GetServerTimeNow() - epoch)
				% (Balance.DAY_SECONDS + Balance.NIGHT_SECONDS)
			local progress = if elapsed < Balance.DAY_SECONDS
				then elapsed / Balance.DAY_SECONDS
				else 1 + (elapsed - Balance.DAY_SECONDS) / Balance.NIGHT_SECONDS
			Lighting.ClockTime = (6 + progress * 12) % 24
			task.wait(1)
		end
	end)
end

return WorldSetup
