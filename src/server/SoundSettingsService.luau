--!strict
-- Saves each player's Music and Effects volume with their data, so the settings follow them to
-- any server. The server only stores them: the client plays all sound. Volumes reach the client as
-- the MusicVolume and SfxVolume attributes once the player's data has loaded.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Sounds = require(ReplicatedStorage.Shared.Sounds)
local DataService = require(script.Parent.DataService)
local Remotes = require(script.Parent.Remotes)

local MIN_GAP = 0.25 -- seconds between saves per player; the client already batches changes

local SoundSettingsService = {}

local lastChange: { [Player]: number } = {}

-- Stored under `soundSettings` in the profile. It is not in DataService's template on purpose, so
-- this feature stays in its own file: ProfileStore saves extra keys, and anything missing or
-- malformed reads back as the defaults.
local function read(player: Player): (number?, number)
	local data: any = DataService.getData(player)
	if data == nil then
		return nil, 0
	end
	local saved = if type(data.soundSettings) == "table" then data.soundSettings else {}
	return Sounds.cleanVolume(saved.music, Sounds.DEFAULT_MUSIC), Sounds.cleanVolume(saved.sfx, Sounds.DEFAULT_SFX)
end

local function publish(player: Player)
	local music, sfx = read(player)
	if music ~= nil then
		player:SetAttribute("MusicVolume", music)
		player:SetAttribute("SfxVolume", sfx)
	end
end

function SoundSettingsService.start()
	Remotes.get("SoundSettings").OnServerEvent:Connect(function(player: Player, music: any, sfx: any)
		local now = os.clock()
		if now - (lastChange[player] or -math.huge) < MIN_GAP then
			return
		end
		lastChange[player] = now
		local data: any = DataService.getData(player)
		if data == nil then
			return
		end
		data.soundSettings = {
			music = Sounds.cleanVolume(music, Sounds.DEFAULT_MUSIC),
			sfx = Sounds.cleanVolume(sfx, Sounds.DEFAULT_SFX),
		}
		publish(player)
	end)

	local function watch(player: Player)
		player:GetAttributeChangedSignal("DataLoaded"):Connect(function()
			if player:GetAttribute("DataLoaded") then
				publish(player)
			end
		end)
		if player:GetAttribute("DataLoaded") then
			publish(player)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastChange[player] = nil
	end)
end

return SoundSettingsService
