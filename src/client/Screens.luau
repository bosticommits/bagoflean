--!strict
-- Lets things in the world open a screen (the store stands on the map, see Stands.luau) without
-- knowing how each screen is built. Each screen registers how to open itself when it starts.
-- Names: Shop, Daily, Requests, Codes, Upgrades, Odds, Actors, Studio, Rebirth, Goals, Quests.
local Screens = {}

local openers: { [string]: (focus: string?) -> () } = {}

function Screens.register(name: string, open: (focus: string?) -> ())
	openers[name] = open
end

-- Open screen `name` (left open if it already is). `focus` picks what to show inside it (Upgrades:
-- an upgrade id, Studio: a tab). Returns false for a screen that isn't there.
function Screens.open(name: string, focus: string?): boolean
	local open = openers[name]
	if open == nil then
		return false
	end
	open(focus)
	return true
end

return Screens
