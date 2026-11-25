--!strict

-- Background music: a looping playlist of licensed Roblox library tracks, with a mute button that
-- remembers the choice for the session.

const SoundService = game:GetService("SoundService")
const TweenService = game:GetService("TweenService")

const ClientState = require("./ClientState")
const Hud = require("./Hud")
const Kit = require("./UI/Kit")

-- Roblox's licensed music library: lobby tracks, then the Gauntlet track.
const LOBBY_TRACKS = {
	"rbxassetid://1836333502",
	"rbxassetid://1848344860",
}
const GAUNTLET_TRACK = "rbxassetid://1837581633"
const VOLUME = 0.22

local Music = {}

local sound: Sound
local muted = false
local trackIndex = 1
local inGauntlet = false
local muteButton: TextButton

local function play(id: string)
	if sound.SoundId == id and sound.IsPlaying then
		return
	end
	local fadeOut = TweenService:Create(sound, TweenInfo.new(0.6), { Volume = 0 })
	fadeOut:Play()
	fadeOut.Completed:Wait()
	sound.SoundId = id
	sound.TimePosition = 0
	sound:Play()
	TweenService:Create(sound, TweenInfo.new(1.2), { Volume = if muted then 0 else VOLUME }):Play()
end

local function nextLobbyTrack()
	trackIndex = trackIndex % #LOBBY_TRACKS + 1
	task.spawn(play, LOBBY_TRACKS[trackIndex])
end

local function setMuted(value: boolean)
	muted = value
	sound.Volume = if muted then 0 else VOLUME
	Kit.setButtonText(muteButton, if muted then "🔇" else "🔊")
end

function Music:Init()
	sound = Instance.new("Sound")
	sound.Name = "Music"
	sound.Volume = 0
	sound.Parent = SoundService
end

function Music:Start()
	muteButton = Kit.button({
		name = "Mute",
		color = Kit.Colors.Blue,
		dark = Kit.Colors.BlueDark,
		size = UDim2.fromOffset(52, 52),
		position = UDim2.new(1, -14, 0, 14),
		anchor = Vector2.new(1, 0),
		text = "🔊",
		parent = Hud.screen(),
		onClick = function()
			setMuted(not muted)
		end,
	})
	sound.Ended:Connect(function()
		if inGauntlet then
			sound:Play()
		else
			nextLobbyTrack()
		end
	end)
	ClientState.RunChanged:Connect(function(run)
		local active = run.active == true
		if active ~= inGauntlet then
			inGauntlet = active
			task.spawn(play, if active then GAUNTLET_TRACK else LOBBY_TRACKS[trackIndex])
		end
	end)
	task.spawn(play, LOBBY_TRACKS[trackIndex])
end

return Music
