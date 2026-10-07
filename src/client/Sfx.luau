--!strict
-- Client sound effects. All sounds are Roblox's own UI library (creator: Roblox, user 1, verified),
-- so they are safe to use and will not be taken down. One SFX SoundGroup so a volume setting can
-- be added later. Sounds play locally: instant feedback, no server latency.
local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")

local SOUNDS: { [string]: { id: number, volume: number } } = {
	click = { id = 15675032796, volume = 0.45 }, -- Roblox_UI_Small_Click
	clap = { id = 15675059323, volume = 0.6 }, -- Roblox_UI_Bright_Click
	whoosh = { id = 15675024286, volume = 0.5 }, -- Roblox_UI_Whoosh_01
	pop = { id = 15675055424, volume = 0.6 }, -- Roblox_UI_Cute_Pop
	stinger = { id = 15675043410, volume = 0.7 }, -- Roblox_UI_Tonal_Stinger
	jingle = { id = 15675016548, volume = 0.7 }, -- Roblox_UI_Piano_Hello
	sweep = { id = 15675046931, volume = 0.5 }, -- Roblox_UI_Sweep
	low = { id = 15675062723, volume = 0.6 }, -- Roblox_UI_Whistle_Low
	indicator = { id = 15675085146, volume = 0.45 }, -- Roblox_UI_Indicator
}

local group: SoundGroup? = nil
local templates: { [string]: Sound } = {}

local Sfx = {}

function Sfx.start()
	local sfxGroup = Instance.new("SoundGroup")
	sfxGroup.Name = "MovieMogulSfx"
	sfxGroup.Volume = 1
	sfxGroup.Parent = SoundService
	group = sfxGroup
	local list = {}
	for name, info in SOUNDS do
		local sound = Instance.new("Sound")
		sound.Name = name
		sound.SoundId = "rbxassetid://" .. info.id
		sound.Volume = info.volume
		sound.SoundGroup = sfxGroup
		sound.Parent = sfxGroup
		templates[name] = sound
		table.insert(list, sound)
	end
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(list)
		end)
	end)
end

-- Plays a one-shot copy, so overlapping plays never cut each other off. `pitch` defaults to 1.
function Sfx.play(name: string, pitch: number?)
	local template = templates[name]
	if template == nil or group == nil then
		return
	end
	local sound = template:Clone()
	sound.PlaybackSpeed = pitch or 1
	sound.Parent = group
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	-- Safety net if Ended never fires (asset failed to load).
	task.delay(8, function()
		if sound.Parent ~= nil then
			sound:Destroy()
		end
	end)
end

return Sfx
