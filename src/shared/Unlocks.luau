--!strict
-- Everything Fame opens (plan section 6): script genres and lengths, casting agencies and the
-- Fame-gated upgrade levels. A premiere uses it to say what its Fame just unlocked, so a player
-- notices the Talent Agency opening instead of finding it by chance. The gates themselves live
-- in Movies, Actors and Upgrades; this only reads them.
local Actors = require(script.Parent.Actors)
local Config = require(script.Parent.Config)
local Movies = require(script.Parent.Movies)
local Upgrades = require(script.Parent.Upgrades)

export type Unlock = {
	name: string, -- what the player sees, e.g. "Talent Agency"
	fame: number,
}

local Unlocks = {}

local list: { Unlock } = {}
for genre, fame in Movies.GenreFame do
	if fame > 0 then
		table.insert(list, { name = `{genre} scripts`, fame = fame })
	end
end
for _, length in Movies.Lengths do
	if length.fame > 0 then
		table.insert(list, { name = `{length.name} scripts`, fame = length.fame })
	end
end
for _, agency in Actors.Agencies do
	if agency.fame > 0 then
		table.insert(list, { name = agency.name, fame = agency.fame })
	end
end
for _, upgrade in Upgrades.List do
	for level, fame in upgrade.fame do
		if fame > 0 then
			local name = if upgrade.id == "Stages"
				then `Sound stage {Config.StartingStages + level}`
				else `{upgrade.name} level {level}`
			table.insert(list, { name = name, fame = fame })
		end
	end
end
-- Lowest Fame first; equal gates by name, so the order never depends on table iteration.
table.sort(list, function(a, b)
	if a.fame ~= b.fame then
		return a.fame < b.fame
	end
	return a.name < b.name
end)

Unlocks.List = list

-- Names of everything a Fame change from `before` to `after` opens, lowest gate first.
function Unlocks.crossed(before: number, after: number): { string }
	local names = {}
	for _, unlock in list do
		if before < unlock.fame and after >= unlock.fame then
			table.insert(names, unlock.name)
		end
	end
	return names
end

return Unlocks
