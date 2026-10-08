--!strict
-- Every sound in the game, in one place. To change a sound, paste a Roblox audio id into its slot.
--
-- Library: sounds known to work. They are Roblox's own UI sound pack (creator: Roblox, verified),
-- so they are free to use and will not be taken down.
--
-- Slots: each moment in the game that makes a sound. A slot with `id = 0` plays its `fallback`
-- library sound instead (at `pitch`), so the game always has sound; paste an audio id to give the
-- moment its own sound. Pasted ids must be audio you own or that is public on the Creator Store.
--
-- Music: background tracks. A track with `id = 0` is skipped; with no tracks set, there is no music.
-- "lobby" tracks play in turn the whole time; "event" plays during Award Night (and special events)
-- if it has an id, otherwise the lobby tracks keep playing.
local Sounds = {}

export type LibrarySound = { id: number, volume: number }
export type Slot = { id: number, volume: number, fallback: string, pitch: number? }
export type Track = { id: number, name: string, volume: number }

Sounds.Library = {
	click = { id = 15675032796, volume = 0.45 }, -- Roblox_UI_Small_Click
	clap = { id = 15675059323, volume = 0.6 }, -- Roblox_UI_Bright_Click
	whoosh = { id = 15675024286, volume = 0.5 }, -- Roblox_UI_Whoosh_01
	pop = { id = 15675055424, volume = 0.6 }, -- Roblox_UI_Cute_Pop
	stinger = { id = 15675043410, volume = 0.7 }, -- Roblox_UI_Tonal_Stinger
	jingle = { id = 15675016548, volume = 0.7 }, -- Roblox_UI_Piano_Hello
	sweep = { id = 15675046931, volume = 0.5 }, -- Roblox_UI_Sweep
	low = { id = 15675062723, volume = 0.6 }, -- Roblox_UI_Whistle_Low
	indicator = { id = 15675085146, volume = 0.45 }, -- Roblox_UI_Indicator
} :: { [string]: LibrarySound }

local function slot(fallback: string, pitch: number?): Slot
	local library = Sounds.Library[fallback]
	return { id = 0, volume = if library ~= nil then library.volume else 0.5, fallback = fallback, pitch = pitch }
end

Sounds.Slots = {
	-- Menus
	click = slot("click"), -- every button
	panelOpen = slot("sweep", 1.3), -- a menu slides open
	notify = slot("indicator"), -- tutorial step, small heads-up
	error = slot("low", 1.2), -- not enough Cash, wrong code

	-- Money
	cashCollect = slot("sweep"), -- box office collected
	coin = slot("pop", 1.5), -- the coin "ding" layered on a collect
	spend = slot("clap", 1.25), -- Cash spent on an upgrade, script or stage

	-- Casting
	castRoll = slot("whoosh"), -- the casting roll starts
	revealCommon = slot("pop"), -- Newcomer, Rising
	revealRare = slot("stinger"), -- Pro, Star
	revealEpic = slot("stinger", 0.9), -- Superstar and up: a deeper sting
	revealLegend = slot("jingle"), -- Legend and Icon, on top of the deeper sting (music dips under it)
	revealShiny = slot("stinger", 1.25), -- Shiny and Award variants, on top of the tier sound

	-- Filming and premieres
	clap = slot("clap"), -- the clapperboard speed-up
	premiereDrumroll = slot("whoosh", 0.8), -- "The reviews are in..."
	premiereFlop = slot("low"),
	premiereHit = slot("pop"),
	premiereBig = slot("stinger"), -- Blockbuster and Cult Classic
	premiereMasterpiece = slot("jingle"), -- the music dips under it

	-- Rewards
	reward = slot("stinger"), -- a reward or code claimed
	welcome = slot("jingle"), -- welcome back, daily reward ready, tutorial done
	gift = slot("pop"), -- the stay gift pops up

	-- Server events
	awardNight = slot("jingle", 0.9), -- Award Night starts
	eventStart = slot("stinger", 0.85), -- a special event starts (banner)
	eventPickup = slot("pop", 1.3), -- picking up a Cash Rain coin or crate
	eventEnd = slot("sweep", 0.8), -- a special event ends
} :: { [string]: Slot }

-- Track ids below were checked in Studio on 2026-10-08: uploaded by Roblox (its licensed music
-- library, free to use) and they load. Names are from the library listing.
Sounds.Music = {
	lobby = {
		{ id = 15675069601, name = "Lobby 1", volume = 0.35 }, -- calm, 1:35
		{ id = 130053244401794, name = "Lobby 2", volume = 0.35 }, -- calm, 4:21
		{ id = 15930255433, name = "Lobby 3", volume = 0.35 }, -- light, 1:47
	} :: { Track },
	event = { id = 17422163655, name = "Cloud Blitz", volume = 0.4 } :: Track, -- energetic, 2:18
}

-- Player volume settings: 0..1 in steps of 1/STEPS. Saved with the player's data.
Sounds.STEPS = 10
Sounds.DEFAULT_MUSIC = 0.6
Sounds.DEFAULT_SFX = 1

-- Snaps any value to a valid volume (bad input becomes `default`).
function Sounds.cleanVolume(value: any, default: number): number
	if type(value) ~= "number" or value ~= value then
		return default
	end
	return math.clamp(math.floor(value * Sounds.STEPS + 0.5) / Sounds.STEPS, 0, 1)
end

-- The sound a slot actually plays: (asset id, volume, pitch), or nil for an unknown slot.
function Sounds.resolve(name: string): (number?, number, number)
	local s = Sounds.Slots[name]
	if s == nil then
		return nil, 0, 1
	end
	if s.id ~= 0 then
		return s.id, s.volume, 1
	end
	local library = Sounds.Library[s.fallback]
	if library == nil then
		return nil, 0, 1
	end
	return library.id, s.volume, s.pitch or 1
end

-- Tracks with an id, in order.
function Sounds.lobbyTracks(): { Track }
	local list = {}
	for _, track in Sounds.Music.lobby do
		if track.id ~= 0 then
			table.insert(list, track)
		end
	end
	return list
end

return Sounds
