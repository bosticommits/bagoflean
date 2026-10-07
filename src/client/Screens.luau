--!strict
-- Lets things in the world open a screen (the store stands on the map, see Stands.luau) without
-- knowing how each screen is built. Each screen registers how to open itself when it starts.
-- Names: Shop, Daily, Requests, Codes, Upgrades, Odds, Actors, Studio.
local Screens = {}

local openers: { [string]: () -> () } = {}

function Screens.register(name: string, open: () -> ())
	openers[name] = open
end

-- Open screen `name` (left open if it already is). Returns false for a screen that isn't there.
function Screens.open(name: string): boolean
	local open = openers[name]
	if open == nil then
		return false
	end
	open()
	return true
end

return Screens
