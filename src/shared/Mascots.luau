--!strict
-- Studio mascots: little companions that follow their owner round town. Each one is earned by a
-- milestone the save already records (premieres, the Index, Fame, a rebirth, a Masterpiece), so
-- nothing new is counted and nothing is sold. The models are Blender designs
-- (art/blender/mascots.py); the server checks unlocks with this file and the Mascots screen shows
-- the same rules.
--
-- Buffs (plan: plans/MASCOT_BUFFS.md in the project files). Each mascot gives one small buff, and
-- only the mascot a player has out counts, so buffs never stack. Every kind has a hard cap
-- (Mascots.Caps, checked by tests) kept well under the Robux pass that does the same job, and a
-- buff only switches on WarmUp seconds after equipping, so swapping mascots between a cast and a
-- premiere cannot collect two buffs. The server applies them:
--   cash       movie Cash, after Fame is worked out (MovieService), like the rebirth bonus
--   luck       casting Luck (CastingService.castLuck), like the 2x Luck pass; not premieres
--   speed      films take this much less time (MovieService), on top of Faster Filming
--   boxOffice  cinema royalties, also while away (EconomyService.rate)
local Actors = require(script.Parent.Actors)

local Mascots = {}

export type BuffKind = "cash" | "luck" | "speed" | "boxOffice"

export type Buff = {
	kind: BuffKind,
	amount: number, -- 0.2 is +20% Cash, x1.2 Luck, 20% faster films or +20% box office
}

export type Mascot = {
	id: string, -- stable; saved as the equipped mascot and used as the Blender mesh's name
	name: string,
	tier: string, -- an Actors tier id: the card and glow use its color
	blurb: string,
	unlock: string, -- how to earn it, as the screen says it
	stat: string, -- what is measured, see Mascots.progress
	target: number,
	hover: boolean?, -- floats instead of hopping
	buff: Buff,
}

-- The most any mascot may give, per kind. The 2x Luck pass is x2 and Faster Filming is 25%.
Mascots.Caps = table.freeze({
	cash = 0.2,
	luck = 0.2,
	speed = 0.1,
	boxOffice = 0.15,
}) :: { [BuffKind]: number }

Mascots.WarmUp = 30 -- seconds after equipping before the buff works

local talentFame = 0
for _, agency in Actors.Agencies do
	if agency.id == "Talent" then
		talentFame = agency.fame
	end
end

-- Easiest first; the rarity colors rise with them.
Mascots.List = {
	{ id = "PopcornPup", name = "Popcorn Pup", tier = "Newcomer", blurb = "Never misses a screening.", unlock = "Every studio's first mascot", stat = "free", target = 0, buff = { kind = "cash", amount = 0.05 } },
	{ id = "ClapperCroc", name = "Clapper Croc", tier = "Rising", blurb = "Snaps for every take.", unlock = "Premiere 10 movies", stat = "premiere", target = 10, buff = { kind = "speed", amount = 0.1 } },
	{ id = "ReelKitty", name = "Reel Kitty", tier = "Pro", blurb = "Hears every reel spin.", unlock = "Discover 15 actors in the Index", stat = "index", target = 15, buff = { kind = "luck", amount = 0.1 } },
	{ id = "CameraBot", name = "Camera Bot", tier = "Star", blurb = "Always rolling.", unlock = "Open the Talent Agency", stat = "fame", target = talentFame, hover = true, buff = { kind = "boxOffice", amount = 0.15 } },
	{ id = "SpotlightOwl", name = "Spotlight Owl", tier = "Superstar", blurb = "Lights up the night.", unlock = "Make a Sequel (rebirth)", stat = "rebirths", target = 1, buff = { kind = "luck", amount = 0.2 } },
	{ id = "PremiereDragon", name = "Premiere Dragon", tier = "Legend", blurb = "Guards the red carpet.", unlock = "Make a Masterpiece", stat = "masterpiece", target = 1, buff = { kind = "cash", amount = 0.2 } },
} :: { Mascot }

Mascots.Default = "PopcornPup"

local byId: { [string]: Mascot } = {}
for _, mascot in Mascots.List do
	byId[mascot.id] = mascot
end

function Mascots.get(id: string): Mascot?
	return byId[id]
end

-- How far a player is towards a mascot, from their save (or the client's synced copy of it):
-- the fields used are stats.premiere, index, fame, rebirths and trophies.
function Mascots.progress(mascot: Mascot, data: any): number
	if mascot.stat == "free" then
		return 0
	elseif mascot.stat == "premiere" then
		local stats = if type(data.stats) == "table" then data.stats else {}
		return if type(stats.premiere) == "number" then stats.premiere else 0
	elseif mascot.stat == "index" then
		local count = 0
		if type(data.index) == "table" then
			for _, found in data.index do
				if found == true then
					count += 1
				end
			end
		end
		return count
	elseif mascot.stat == "fame" then
		return if type(data.fame) == "number" then data.fame else 0
	elseif mascot.stat == "rebirths" then
		return if type(data.rebirths) == "number" then data.rebirths else 0
	elseif mascot.stat == "masterpiece" then
		return if type(data.trophies) == "number" then data.trophies else 0
	end
	return 0
end

function Mascots.isUnlocked(mascot: Mascot, data: any): boolean
	return Mascots.progress(mascot, data) >= mascot.target
end

-- Ids of every mascot the player has earned, in list order.
function Mascots.unlocked(data: any): { string }
	local ids = {}
	for _, mascot in Mascots.List do
		if Mascots.isUnlocked(mascot, data) then
			table.insert(ids, mascot.id)
		end
	end
	return ids
end

-- The mascot a save shows: its choice if that is still earned, none if it chose none, else the
-- default. A missing or broken choice (an older save) gets the Popcorn Pup.
function Mascots.equipped(data: any): string
	local choice = data.mascot
	if choice == "" then
		return ""
	end
	if type(choice) == "string" then
		local mascot = byId[choice]
		if mascot ~= nil and Mascots.isUnlocked(mascot, data) then
			return choice
		end
	end
	return Mascots.Default
end


-- The buff as the Mascots screen says it.
function Mascots.describe(buff: Buff): string
	local percent = math.floor(buff.amount * 100 + 0.5)
	if buff.kind == "cash" then
		return `+{percent}% movie Cash`
	elseif buff.kind == "luck" then
		return `x{1 + buff.amount} casting Luck`
	elseif buff.kind == "speed" then
		return `Movies film {percent}% faster`
	end
	return `+{percent}% box office`
end

-- Seconds until the equipped mascot's buff works (0 once it does). `data.mascotSince` is when the
-- mascot was last changed (os.time()); older saves without it count as long ago.
function Mascots.warmUpLeft(data: any, now: number): number
	local since = if type(data.mascotSince) == "number" then data.mascotSince else 0
	return math.max(0, since + Mascots.WarmUp - now)
end

-- How much of `kind` the player's mascot gives right now: 0 when it gives another kind, is hidden
-- or is still warming up. Never above the kind's cap.
function Mascots.boost(data: any, kind: BuffKind, now: number): number
	local mascot = byId[Mascots.equipped(data)]
	if mascot == nil or mascot.buff.kind ~= kind or Mascots.warmUpLeft(data, now) > 0 then
		return 0
	end
	return math.clamp(mascot.buff.amount, 0, Mascots.Caps[kind])
end

return Mascots
