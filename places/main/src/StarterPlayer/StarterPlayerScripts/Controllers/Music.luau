--!strict

-- Background music: a looping playlist of licensed Roblox library tracks. It plays through the
-- music sound group, whose volume the Settings menu sets.

const SoundService = game:GetService("SoundService")
const TweenService = game:GetService("TweenService")

const ClientState = require("./ClientState")
const Kit = require("./UI/Kit")

-- Roblox's licensed music library: lobby tracks, then the Gauntlet track.
const LOBBY_TRACKS = {
	"rbxassetid://1836333502",
	"rbxassetid://1848344860",
}
const GAUNTLET_TRACK = "rbxassetid://1837581633"
const BOSS_TRACK = "rbxassetid://1843463175"
const VOLUME = 0.22

local Music = {}

local ambience: SoundGroup
local forging = false
local sound: Sound
local bossSound: Sound
local regularMix: SoundGroup
local trackIndex = 1
local inGauntlet = false
local eliteActive = false
local musicVersion = 0
local towerMusic = false
local rhythmVersion = 0

local function setTowerMusic(active: boolean)
	if towerMusic == active then
		return
	end
	towerMusic = active
	rhythmVersion += 1
	local version = rhythmVersion
	if not active then
		return
	end
	task.spawn(function()
		local beat = 0
		while rhythmVersion == version do
			-- The beat is part of the music, so it follows the music volume.
			local volume = Kit.MusicGroup.Volume
			if volume > 0.01 and not forging then
				if beat % 4 == 0 then
					Kit.sound(Kit.Sounds.Boom, 0.12 * volume, 1.8)
				elseif beat % 4 == 2 then
					Kit.sound(Kit.Sounds.Pump, 0.075 * volume, 1.5)
				else
					Kit.sound(Kit.Sounds.Toggle, 0.035 * volume, 2.2)
				end
			end
			beat += 1
			task.wait(60 / 150 / 2)
		end
	end)
end

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
	forging = active
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
	sound.Ended:Connect(function()
		if inGauntlet then
			sound:Play()
		else
			nextLobbyTrack()
		end
	end)
	ClientState.RunChanged:Connect(function(run)
		local active = run.active == true
		local elite = active and run.elite == true
		setTowerMusic(active and run.tower == true and not elite)
		sound.PlaybackSpeed = if active and run.tower then 1.24 else 1
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
		if active ~= inGauntlet then
			inGauntlet = active
			task.spawn(play, if active then GAUNTLET_TRACK else LOBBY_TRACKS[trackIndex])
		end
	end)
	task.spawn(play, LOBBY_TRACKS[trackIndex])
end

return Music
