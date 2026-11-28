--!strict

-- Background music: a looping playlist of licensed Roblox library tracks. It plays through the
-- music sound group, whose volume the Settings menu sets.

const SoundService = game:GetService("SoundService")
const TweenService = game:GetService("TweenService")

const ClientState = require("./ClientState")
const Kit = require("./UI/Kit")

-- Roblox's licensed music library: the regular playlist continues through ordinary encounters.
const LOBBY_TRACKS = {
	"rbxassetid://1836333502",
	"rbxassetid://1848344860",
}
const BOSS_TRACK = "rbxassetid://1843463175"
const VOLUME = 0.22

local Music = {}

local ambience: SoundGroup
local sound: Sound
local bossSound: Sound
local regularMix: SoundGroup
local trackIndex = 1
local eliteActive = false
local musicVersion = 0
local function play(id: string)
	musicVersion += 1
	local version = musicVersion
	local fadeOut = TweenService:Create(sound, TweenInfo.new(0.6), { Volume = 0 })
	fadeOut:Play()
	fadeOut.Completed:Wait()
	if version ~= musicVersion then
		return
	end
	sound.SoundId = id
	sound.TimePosition = 0
	sound:Play()
	TweenService:Create(sound, TweenInfo.new(1.2), { Volume = VOLUME }):Play()
end

local function nextLobbyTrack()
	trackIndex = trackIndex % #LOBBY_TRACKS + 1
	task.spawn(play, LOBBY_TRACKS[trackIndex])
end

function Music.forgeMix(active: boolean)
	TweenService:Create(
		ambience,
		TweenInfo.new(if active then 0.55 else 0.85),
		{ Volume = if active then 0 else 1 }
	):Play()
end

function Music:Init()
	ambience = Instance.new("SoundGroup")
	ambience.Name = "Ambience"
	ambience.Volume = 1
	ambience.Parent = Kit.MusicGroup
	sound = Instance.new("Sound")
	sound.Name = "Music"
	sound.Volume = 0
	regularMix = Instance.new("SoundGroup")
	regularMix.Name = "RegularMusicMix"
	regularMix.Volume = 1
	regularMix.Parent = ambience
	sound.SoundGroup = regularMix
	sound.Parent = SoundService

	bossSound = Instance.new("Sound")
	bossSound.Name = "BossMusic"
	bossSound.SoundId = BOSS_TRACK
	bossSound.Volume = 0
	bossSound.Looped = true
	bossSound.SoundGroup = ambience
	bossSound.Parent = SoundService
	task.spawn(function()
		game:GetService("ContentProvider"):PreloadAsync({ bossSound })
	end)
end

local function celebrationNote(pitch: number, fade: number)
	local cue = Instance.new("Sound")
	cue.SoundId = Kit.Sounds.Ding
	cue.SoundGroup = Kit.MusicGroup
	cue.Volume = 0.18
	cue.PlaybackSpeed = pitch
	cue.Parent = SoundService
	cue:Play()
	TweenService:Create(cue, TweenInfo.new(fade), { Volume = 0 }):Play()
	task.delay(fade + 0.1, function()
		cue:Destroy()
	end)
end

local function celebrate()
	celebrationNote(1, 0.55)
	task.delay(0.16, celebrationNote, 1.2599, 0.65)
	task.delay(0.34, celebrationNote, 1.4983, 1.15)
end

function Music:Start()
	sound.Ended:Connect(nextLobbyTrack)
	ClientState.RunChanged:Connect(function(run)
		local active = run.active == true
		local elite = active and run.elite == true
		if elite ~= eliteActive then
			eliteActive = elite
			local fade = TweenInfo.new(if elite then 0.28 else 0.55)
			TweenService:Create(regularMix, fade, { Volume = if elite then 0 else 1 }):Play()
			if elite and not bossSound.IsPlaying then
				bossSound:Play()
			end
			local bossFade =
				TweenService:Create(bossSound, fade, { Volume = if elite then 0.42 else 0 })
			bossFade:Play()
			if not elite then
				if active then
					celebrate()
				end
				bossFade.Completed:Once(function(state)
					if state == Enum.PlaybackState.Completed and not eliteActive then
						bossSound:Stop()
					end
				end)
			end
		end
	end)
	task.spawn(play, LOBBY_TRACKS[trackIndex])
end

return Music
