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
-- `voice`: a spoken line (one at a time, ducks the other sounds; slots named "lucien..." are voices
-- too). `delay`: seconds to wait before it starts, e.g. so a voice follows the sting's hit.
export type Slot = { id: number, volume: number, fallback: string, pitch: number?, voice: boolean?, delay: number? }
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

local function slot(fallback: string, pitch: number?, delay: number?): Slot
	local library = Sounds.Library[fallback]
	return { id = 0, volume = if library ~= nil then library.volume else 0.5, fallback = fallback, pitch = pitch, delay = delay }
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
	-- The reveal build-up (CastingUi): drumroll ticks speed up, a tone each time the glow climbs a
	-- tier (pitched up per tier), and a burst when a fake-out jumps to the real tier.
	drumroll = slot("clap", 0.6),
	drumrollLow = slot("click", 0.5), -- the second drum layer for Superstar+ and the near miss
	revealStep = slot("indicator"),
	revealBurst = slot("stinger", 1.2),
	-- The announcer on the flip (Fish Audio voice "Energetic Male", uploaded 2026-10-26).
	voiceStar = { id = 115516541869843, volume = 0.8, fallback = "pop", pitch = 1.2, voice = true }, -- "Star!"
	voiceSuperstar = { id = 123249610913912, volume = 0.85, fallback = "pop", pitch = 1.1, voice = true }, -- "SUPERSTAR!"
	voiceLegend = { id = 100766374127319, volume = 0.9, fallback = "pop", pitch = 1, voice = true }, -- "LEGEND!"
	voiceIcon = { id = 120481667577201, volume = 0.9, fallback = "pop", pitch = 0.9, voice = true }, -- "ICON!"
	-- "Ooh, so close!": the near-miss tease lands on a lower tier.
	voiceSoClose = { id = 81149535231196, volume = 0.8, fallback = "low", pitch = 1.1, voice = true },

	-- Filming and premieres
	clap = slot("clap"), -- the clapperboard speed-up
	premiereDrumroll = slot("whoosh", 0.8), -- "The reviews are in..."
	-- The result stings (premiere audio picked 2026-11-04: Roblox's licensed APM and Pro Sound
	-- Effects libraries, plus one public sad trombone). Each is 8 s or less: Sfx cuts longer ones.
	premiereFlop = { id = 190705984, volume = 0.6, fallback = "low" }, -- "Sad-Trombone": wah-wah-wahhh
	premiereHit = { id = 1839997962, volume = 0.6, fallback = "pop" }, -- "Right Answer" (Juice Music, GAME SHOW TOOLKIT)
	premiereBig = { id = 1839997821, volume = 0.65, fallback = "stinger" }, -- Blockbuster: "Rising Bumper 2" (GAME SHOW TOOLKIT)
	premiereCult = { id = 1846887865, volume = 0.6, fallback = "stinger", pitch = 0.9 }, -- "Mystery Sting 10": eerie choir (Sonoton)
	premiereMasterpiece = { id = 1845298676, volume = 0.75, fallback = "jingle" }, -- "1812 Fanfare" horn calls (Soho FANFARES); music dips under it
	premiereFlash = { id = 9113678227, volume = 0.45, fallback = "clap", pitch = 1.1 }, -- camera flashes: "Camera Shutter 1" (PSE)
	premiereStamp = slot("clap", 0.6), -- the result stamp lands on the poster
	-- The red-carpet show at the Grand Premiere Theatre (PremiereShow). Long ones are loops or
	-- beds the show cuts to length.
	showDrumroll = { id = 1842251033, volume = 0.55, fallback = "clap", pitch = 0.6 }, -- "Snare Drum Roll" (KPM): the build-up
	showHeartbeat = { id = 1839998022, volume = 0.7, fallback = "low", pitch = 0.6 }, -- "Heartbeat" (GAME SHOW TOOLKIT): the hush
	showCheer = { id = 9113138035, volume = 0.5, fallback = "clap", pitch = 1.1 }, -- applause (PSE "Applause Tight 4")
	showCheerWild = { id = 9112766203, volume = 0.55, fallback = "clap" }, -- cheers, whistles, chanting (PSE "Crowd Cheer And Applause 2")
	-- The crowd's friendly "awww" on a Flop: four Fish Audio voices layered (uploaded 2026-11-04).
	showAww = { id = 99187295696445, volume = 0.7, fallback = "low", pitch = 0.8 },
	showRain = { id = 9112852671, volume = 0.45, fallback = "sweep", pitch = 0.6 }, -- Flop drizzle (PSE "Rain Continuous Drizzle 2")
	showFireworks = { id = 9112780898, volume = 0.6, fallback = "pop", pitch = 0.7 }, -- pops and whistles (PSE "Fireworks Sparse 2")
	showCoins = { id = 9113849445, volume = 0.5, fallback = "pop", pitch = 1.5 }, -- the coin burst (PSE "Coins Or Keys Jingle 5")
	showTotal = { id = 1839997894, volume = 0.6, fallback = "jingle" }, -- tonight's total: "Organ Ta Da" (GAME SHOW TOOLKIT)
	showFlip = slot("whoosh", 1.4), -- the marquee board flips over
	showGlide = slot("whoosh", 0.7), -- the camera glides to the theatre and back
	showStar = slot("indicator", 1.2), -- each critic star fills (the show raises the pitch per star)
	-- Direct the scene (TakeUi): the TAKE! card pops up, then the verdict on CUT!
	takePop = slot("pop", 1.1),
	takePerfect = slot("stinger", 1.15),
	takeGood = slot("clap", 1.05),
	takeMiss = slot("low", 0.9),
	-- The film crews on the film sets (FilmSetWorld), heard from where it happens. The voice lines
	-- were still in moderation review when added; the fallbacks play only if an id is cleared.
	FilmClapper = { id = 9120916820, volume = 0.7, fallback = "clap", pitch = 0.8 }, -- the clapperboard snaps shut (PSE "Wood Impacts 13")
	FilmAction = { id = 123389177574608, volume = 0.8, fallback = "low", pitch = 1.35 }, -- the director's "Action!"
	FilmCut = { id = 133550941117464, volume = 0.8, fallback = "low", pitch = 0.85 }, -- the director's "Cut!"
	FilmPlaces = { id = 109213125841224, volume = 0.8, fallback = "indicator" }, -- "Places everyone!" when the owner walks in
	FilmApplause = { id = 9113138035, volume = 0.5, fallback = "clap", pitch = 1.1 }, -- a clean take (PSE "Applause Tight 4"; FilmSetWorld plays ~3 s of it)

	-- Rewards
	reward = slot("stinger"), -- a reward or code claimed
	welcome = slot("jingle"), -- welcome back, daily reward ready, tutorial done
	gift = slot("pop"), -- the stay gift pops up
	giftOpen = slot("stinger", 1.3), -- a playtime gift present pops open
	goal = slot("jingle", 1.1), -- an achievement goal reached (Goals screen)

	-- Server events
	awardNight = slot("jingle", 0.9), -- Award Night starts
	eventTeaser = slot("indicator"), -- "SPECIAL EVENT IN 10" ticks down
	eventStart = slot("stinger", 0.85), -- a special event starts (banner)
	eventWhoosh = slot("whoosh", 0.8), -- the banner slam; the Lucky Star falling and flying off
	eventImpact = slot("stinger", 0.75), -- the Lucky Star hits the ground
	eventSweep = slot("sweep"), -- the Spotlight switching on, the Golden Hour sunset
	eventPickup = slot("pop", 1.3), -- picking up a Cash Rain coin or crate
	eventEnd = slot("sweep", 0.8), -- a special event ends
	frightSting = slot("stinger", 0.6), -- the Pumpkin Patch starts (Fright Night): a spooky sting
	-- Then the announcer: "Fright Night has begun! Grab the pumpkins!" (Fish Audio, uploaded 2026-10-26).
	frightVoice = { id = 116173500034235, volume = 0.8, fallback = "whoosh", pitch = 0.6, voice = true },

	-- Lucien Vale, the game show host (Fish Audio voice "Adrian", uploaded 2026-11-04). All "lucien"
	-- slots are voices; `delay` lets the sting that starts with them land first.
	lucienWelcome = { id = 119403867472276, volume = 0.9, fallback = "jingle" }, -- "Welcome to Hollywood RNG!"
	lucienFirstCast = { id = 125664057757278, volume = 0.9, fallback = "whoosh" }, -- "Time to roll your first cast!"
	lucienRarePull = { id = 94106934856816, volume = 0.9, fallback = "stinger", delay = 0.8 }, -- "Ooh! Now THAT is a rare face!"
	lucienLegendPull = { id = 76266690163201, volume = 0.9, fallback = "jingle", delay = 1 }, -- "A LEGEND!"
	lucienAction = { id = 78920949726178, volume = 0.9, fallback = "clap" }, -- "Lights... camera... ACTION!"
	lucienPremiere = { id = 105795421068430, volume = 0.9, fallback = "whoosh", delay = 0.4 }, -- "Let's see what the critics say..."
	lucienFlop = { id = 98265469775608, volume = 0.9, fallback = "low", delay = 0.9 }, -- "Oof... a flop!"
	lucienBlockbuster = { id = 127361279847230, volume = 0.9, fallback = "stinger", delay = 0.9 }, -- "BLOCKBUSTER!"
	lucienHit = { id = 102072339047901, volume = 0.9, fallback = "pop", delay = 0.8 }, -- "A hit! The audience loves it!"
	lucienCult = { id = 80231962225282, volume = 0.9, fallback = "stinger", delay = 1 }, -- "A cult classic... they'll be quoting this one for years!"
	lucienMasterpiece = { id = 113254789405013, volume = 0.9, fallback = "jingle", delay = 1 }, -- "A MASTERPIECE! Hollywood will never forget tonight!"
	lucienTotal = { id = 134834345543231, volume = 0.9, fallback = "jingle" }, -- "What a night at the box office!"
	lucienRebirth = { id = 94420324004466, volume = 0.9, fallback = "jingle", delay = 1.2 }, -- "A fresh start!"
	lucienEventStart = { id = 110851102217227, volume = 0.9, fallback = "stinger", delay = 0.9 }, -- "Heads up, Hollywood! A special event just started!"
	lucienFestivalWin = { id = 110138148663833, volume = 0.9, fallback = "jingle" }, -- "And the Festival Laurel goes to... YOU!" (matched by name, check it)

	-- Studio visits
	visitJump = slot("whoosh", 1.2), -- the Visit menu jumps you to a studio
	applause = slot("clap", 1.1), -- someone applauds a studio near you (each clap)
	applauseGot = slot("stinger", 1.2), -- your studio's applause counted

	-- Rebirth
	rebirthSting = slot("stinger", 0.8), -- the rebirth reveal opens
	rebirth = slot("jingle", 0.95, 0.5), -- follows the sting half a second later (the music dips under it)
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
	-- The Pumpkin Patch event's track (Fright Night); with id 0 it plays the event track. Roblox's
	-- licensed music library (APMOfficial, verified, free), checked 2026-10-26.
	fright = { id = 1836009584, name = "Bouncing Halloween", volume = 0.4 } :: Track, -- playful spooky, 1:29
}

-- Film set ambience: a quiet loop heard only up close on each set (FilmSetWorld), by set id. A
-- set with no entry, or an id of 0, stays silent; adding a set is one line here.
Sounds.Ambience = {
	Gulch = { id = 9112832297, volume = 0.25 }, -- placeholder: audio pass (PSE "Mountain Birds 2" stands in for wind; creaking wood still missing)
	MoonBase = { id = 9114330786, volume = 0.25 }, -- placeholder: audio pass (PSE "Energy Field Constant" hum with beeps)
	Jungle = { id = 9112805601, volume = 0.25 }, -- placeholder: audio pass (PSE "Jungle Birds Ambience 2", birds; distant drums still missing)
} :: { [string]: LibrarySound }

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

-- True for spoken lines, which the Sfx voice channel plays one at a time (see VoiceQueue).
function Sounds.isVoice(name: string): boolean
	local s = Sounds.Slots[name]
	return s ~= nil and (s.voice == true or string.sub(name, 1, 6) == "lucien")
end

-- Seconds a slot waits before it starts (0 for most).
function Sounds.delayOf(name: string): number
	local s = Sounds.Slots[name]
	return if s ~= nil and s.delay ~= nil then s.delay else 0
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
