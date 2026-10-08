--!strict
-- Background music. Plays the lobby tracks from Shared/Sounds.luau in turn (starting at a random
-- one), and switches to the event track while Award Night or a special event is on, when that
-- track has an id. Big moments (a Legend pull, a Masterpiece) dip the music for a few seconds so
-- the sting stands out. With no track ids set, this stays silent.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Events = require(ReplicatedStorage.Shared.Events)
local Sounds = require(ReplicatedStorage.Shared.Sounds)

local FADE = 1.5
local DUCK_TO = 0.25 -- share of the normal volume while ducked

local Music = {}

local group: SoundGroup? = nil
local current: Sound? = nil
local currentTrack: Sounds.Track? = nil
local lobbyIndex = 0
local eventOn = false -- Award Night
local specialOn = false -- a special event (set by the events code through Music.setEvent)
local duckUntil = 0
local playing = false -- the music is wanted (volume above 0)

local function level(): number
	local track = currentTrack
	if track == nil then
		return 0
	end
	return track.volume * (if os.clock() < duckUntil then DUCK_TO else 1)
end

local function fadeOut(sound: Sound)
	local tween = TweenService:Create(sound, TweenInfo.new(FADE), { Volume = 0 })
	tween:Play()
	tween.Completed:Once(function()
		sound:Destroy()
	end)
end

local playNext: () -> ()

local function play(track: Sounds.Track, looped: boolean)
	local musicGroup = group
	if musicGroup == nil then
		return
	end
	local old = current
	if old ~= nil then
		fadeOut(old)
	end
	local sound = Instance.new("Sound")
	sound.Name = track.name
	sound.SoundId = "rbxassetid://" .. track.id
	sound.Looped = looped
	sound.Volume = 0
	sound.SoundGroup = musicGroup
	sound.Parent = musicGroup
	current = sound
	currentTrack = track
	sound:Play()
	TweenService:Create(sound, TweenInfo.new(FADE), { Volume = level() }):Play()
	sound.Ended:Once(function()
		if current == sound then
			playNext()
		end
	end)
end

-- Picks what should be playing now and starts it if it is not already on.
playNext = function()
	if not playing then
		return
	end
	local event = Sounds.Music.event
	if (eventOn or specialOn) and event.id ~= 0 then
		if currentTrack ~= event then
			play(event, true)
		end
		return
	end
	local tracks = Sounds.lobbyTracks()
	if #tracks == 0 then
		local old = current
		if old ~= nil then
			fadeOut(old)
		end
		current, currentTrack = nil, nil
		return
	end
	lobbyIndex = if lobbyIndex == 0 then math.random(1, #tracks) else lobbyIndex % #tracks + 1
	-- A single lobby track loops; several play in turn.
	play(tracks[lobbyIndex], #tracks == 1)
end

local function refresh()
	local wasEvent = currentTrack ~= nil and currentTrack == Sounds.Music.event
	local wantEvent = (eventOn or specialOn) and Sounds.Music.event.id ~= 0
	if wasEvent ~= wantEvent or (playing and current == nil) then
		playNext()
	end
end

function Music.start()
	local musicGroup = Instance.new("SoundGroup")
	musicGroup.Name = "MovieMogulMusic"
	musicGroup.Volume = Sounds.DEFAULT_MUSIC
	musicGroup.Parent = SoundService
	group = musicGroup
	playing = musicGroup.Volume > 0
	playNext()

	-- Award Night follows the shared clock (see Shared/Events.luau).
	task.spawn(function()
		while true do
			local active = Events.awardNight(workspace:GetServerTimeNow())
			if active ~= eventOn then
				eventOn = active
				refresh()
			end
			task.wait(1)
		end
	end)
end

-- Music volume, 0..1 (the player's setting). At 0 the music stops instead of streaming silently.
function Music.setVolume(volume: number)
	local musicGroup = group
	if musicGroup == nil then
		return
	end
	musicGroup.Volume = volume
	local want = volume > 0
	if want == playing then
		return
	end
	playing = want
	if want then
		playNext()
	else
		local old = current
		if old ~= nil then
			fadeOut(old)
		end
		current, currentTrack = nil, nil
	end
end

-- For special events: true while one is on, so the event track (if set) plays.
function Music.setEvent(active: boolean)
	if specialOn ~= active then
		specialOn = active
		refresh()
	end
end

-- Dips the music for `seconds` (a big reveal), then brings it back.
function Music.duck(seconds: number)
	duckUntil = os.clock() + seconds
	local sound = current
	if sound == nil then
		return
	end
	TweenService:Create(sound, TweenInfo.new(0.2), { Volume = level() }):Play()
	task.delay(seconds, function()
		if current == sound and os.clock() >= duckUntil then
			TweenService:Create(sound, TweenInfo.new(FADE), { Volume = level() }):Play()
		end
	end)
end

return Music
