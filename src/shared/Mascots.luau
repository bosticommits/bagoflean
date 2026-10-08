--!strict
-- Studio mascots: little companions that follow their owner round town. They are cosmetic only:
-- no Cash, Luck or speed. Each one is earned by a milestone the save already records (premieres,
-- the Index, Fame, a rebirth, a Masterpiece), so nothing new is counted and nothing is sold.
-- The models are Blender designs (art/blender/mascots.py); the server checks unlocks with this
-- file and the Mascots screen shows the same rules.
local Actors = require(script.Parent.Actors)

local Mascots = {}

export type Mascot = {
	id: string, -- stable; saved as the equipped mascot and used as the Blender mesh's name
	name: string,
	tier: string, -- an Actors tier id: the card and glow use its color
	blurb: string,
	unlock: string, -- how to earn it, as the screen says it
	stat: string, -- what is measured, see Mascots.progress
	target: number,
	hover: boolean?, -- floats instead of hopping
}

local talentFame = 0
for _, agency in Actors.Agencies do
	if agency.id == "Talent" then
		talentFame = agency.fame
	end
end

-- Easiest first; the rarity colors rise with them.
Mascots.List = {
	{ id = "PopcornPup", name = "Popcorn Pup", tier = "Newcomer", blurb = "Never misses a screening.", unlock = "Every studio's first mascot", stat = "free", target = 0 },
	{ id = "ClapperCroc", name = "Clapper Croc", tier = "Rising", blurb = "Snaps for every take.", unlock = "Premiere 10 movies", stat = "premiere", target = 10 },
	{ id = "ReelKitty", name = "Reel Kitty", tier = "Pro", blurb = "Hears every reel spin.", unlock = "Discover 15 actors in the Index", stat = "index", target = 15 },
	{ id = "CameraBot", name = "Camera Bot", tier = "Star", blurb = "Always rolling.", unlock = "Open the Talent Agency", stat = "fame", target = talentFame, hover = true },
	{ id = "SpotlightOwl", name = "Spotlight Owl", tier = "Superstar", blurb = "Lights up the night.", unlock = "Make a Sequel (rebirth)", stat = "rebirths", target = 1 },
	{ id = "PremiereDragon", name = "Premiere Dragon", tier = "Legend", blurb = "Guards the red carpet.", unlock = "Make a Masterpiece", stat = "masterpiece", target = 1 },
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

return Mascots
