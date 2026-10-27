--!strict
-- Client sound effects. Which sound each moment plays lives in Shared/Sounds.luau (named slots), so
-- sounds can be swapped there without touching game code. Everything plays through one SFX
-- SoundGroup, whose volume is the player's Effects setting. Sounds play locally: instant feedback,
-- no server latency.
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Sounds = require(ReplicatedStorage.Shared.Sounds)

local group: SoundGroup? = nil
local templates: { [number]: Sound? } = {} -- by asset id, shared by every slot that uses it
local lastPlayed: { [string]: number } = {}

-- The same slot again within this many seconds is skipped, so a burst (a row of rewards, many
-- coins at once) sounds like one hit instead of a wall of noise.
local REPEAT_GAP = 0.05

local Sfx = {}

local function template(id: number): Sound?
	local existing = templates[id]
	if existing ~= nil then
		return existing
	end
	local sfxGroup = group
	if sfxGroup == nil then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = tostring(id)
	sound.SoundId = "rbxassetid://" .. id
	sound.SoundGroup = sfxGroup
	sound.Parent = sfxGroup
	templates[id] = sound
	return sound
end

function Sfx.start()
	local sfxGroup = Instance.new("SoundGroup")
	sfxGroup.Name = "MovieMogulSfx"
	sfxGroup.Volume = Sounds.DEFAULT_SFX
	sfxGroup.Parent = SoundService
	group = sfxGroup
	local list = {}
	for name in Sounds.Slots do
		local id = Sounds.resolve(name)
		local sound = if id ~= nil and templates[id] == nil then template(id) else nil
		if sound ~= nil then
			table.insert(list, sound)
		end
	end
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(list)
		end)
	end)
end

-- Effects volume, 0..1 (the player's setting).
function Sfx.setVolume(volume: number)
	local sfxGroup = group
	if sfxGroup ~= nil then
		sfxGroup.Volume = volume
	end
end

-- Plays slot `name` (see Sounds.Slots) as a one-shot copy, so overlapping plays never cut each
-- other off. `pitch` multiplies the slot's own pitch, for a little variety. With `at`, the sound
-- comes from that spot in the world (3D, fading out by `range` studs); `length` cuts a long sound
-- short with a quick fade.
local function playSlot(name: string, pitch: number?, at: Vector3?, range: number?, length: number?)
	local id, volume, slotPitch = Sounds.resolve(name)
	if id == nil then
		warn(`[Sfx] unknown sound slot "{name}"`)
		return
	end
	local now = os.clock()
	if now - (lastPlayed[name] or -1) < REPEAT_GAP then
		return
	end
	lastPlayed[name] = now
	local base = template(id)
	local sfxGroup = group
	if base == nil or sfxGroup == nil or sfxGroup.Volume <= 0 then
		return
	end
	local sound = base:Clone()
	sound.Volume = volume
	sound.PlaybackSpeed = slotPitch * (pitch or 1)
	local holder: Instance = sfxGroup
	if at ~= nil then
		local attachment = Instance.new("Attachment")
		attachment.Name = "SfxAt"
		attachment.WorldPosition = at
		attachment.Parent = workspace.Terrain
		holder = attachment
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMinDistance = 12
		sound.RollOffMaxDistance = range or 140
	end
	sound.Parent = holder
	sound:Play()
	local function done()
		if sound.Parent ~= nil then
			sound:Destroy()
		end
		if holder ~= sfxGroup and holder.Parent ~= nil then
			holder:Destroy()
		end
	end
	sound.Ended:Once(done)
	if length ~= nil then
		task.delay(length, function()
			if sound.Parent ~= nil then
				TweenService:Create(sound, TweenInfo.new(0.6), { Volume = 0 }):Play()
				task.delay(0.6, done)
			end
		end)
	end
	-- Safety net if Ended never fires (asset failed to load).
	task.delay(math.max(8, (length or 0) + 1), done)
end

function Sfx.play(name: string, pitch: number?)
	playSlot(name, pitch)
end

-- Plays slot `name` from `at` in the world (see playSlot).
function Sfx.playAt(name: string, at: Vector3, range: number?, length: number?)
	playSlot(name, nil, at, range, length)
end

-- A looping 3D sound for `parent` (an Attachment or part), through the Effects volume: asset
-- `id` at `volume`, fading out by `range` studs. Not playing yet; the caller plays and stops it.
function Sfx.loop(id: number, volume: number, parent: Instance, range: number): Sound?
	local sfxGroup = group
	if sfxGroup == nil or id <= 0 then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://" .. id
	sound.Volume = volume
	sound.Looped = true
	sound.SoundGroup = sfxGroup
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = math.min(20, range / 3)
	sound.RollOffMaxDistance = range
	sound.Parent = parent
	return sound
end

return Sfx
