--!strict
-- Film sets: big outdoor sets past the town hedge where a film crew shoots scenes all day. Each one
-- is bought once with in-game Cash at its gate and kept for good (a rebirth resets Cash, never film
-- sets). They are never sold for Robux. Owning a set gives two things:
--   luck       casting Luck, always (CastingService.castLuck). Only the best set counts, so the
--              boosts never stack.
--   boxOffice  while the owner stands inside the set, their box office pays this much again on
--              top (1 = double), straight into Cash (FilmSetService). It stops when they leave.
-- Anyone can watch the crew from outside the gate; only owners can walk in. The map places the
-- gate and the set's area (MapModels.FilmSets); the crew and their scenes are FilmScenes.
local TopStudios = require(script.Parent.TopStudios)

local FilmSets = {}

export type FilmSet = {
	id: string, -- stable; saved in `data.filmSetsOwned`
	name: string,
	price: number, -- Cash, bought once
	luck: number, -- 0.05 is x1.05 casting Luck
	boxOffice: number, -- extra box office while inside: 1 = double
}

-- The most any set may give. The 2x Luck pass is x2; mascots give up to x1.2 Luck.
FilmSets.Caps = table.freeze({
	luck = 0.15,
	boxOffice = 1,
})

-- How often the box office bonus pays out while inside (seconds).
FilmSets.PayEvery = 5

-- Dusty Gulch first; the space station and the jungle temple come later, priced along the typical
-- player's Cash curve (ECONOMY_SUMMARY.md): the Gulch during the first day, the others as goals for
-- later days.
FilmSets.List = {
	{ id = "Gulch", name = "Dusty Gulch", price = 25000, luck = 0.05, boxOffice = 1 },
} :: { FilmSet }

local byId: { [string]: FilmSet } = {}
for _, set in FilmSets.List do
	byId[set.id] = set
end

function FilmSets.get(id: string): FilmSet?
	return byId[id]
end

-- Whether the save owns `set` (`data.filmSetsOwned`, a set of ids kept outside the save template).
function FilmSets.owns(set: FilmSet, data: any): boolean
	local owned = data.filmSetsOwned
	return type(owned) == "table" and owned[set.id] == true
end

-- Ids of every set the player owns, in list order.
function FilmSets.owned(data: any): { string }
	local ids = {}
	for _, set in FilmSets.List do
		if FilmSets.owns(set, data) then
			table.insert(ids, set.id)
		end
	end
	return ids
end

-- The casting Luck the player's sets give: the best owned set's, never above the cap.
function FilmSets.luck(data: any): number
	local best = 0
	for _, set in FilmSets.List do
		if FilmSets.owns(set, data) then
			best = math.max(best, set.luck)
		end
	end
	return math.clamp(best, 0, FilmSets.Caps.luck)
end

-- The Cash one payout gives a player standing inside `set`, earning `rate` box office a second.
function FilmSets.payout(set: FilmSet, rate: number): number
	local share = math.clamp(set.boxOffice, 0, FilmSets.Caps.boxOffice)
	return math.floor(math.max(rate, 0) * share * FilmSets.PayEvery)
end

-- The price as the gate's board shows it ("$25K").
function FilmSets.priceText(set: FilmSet): string
	return "$" .. TopStudios.short(set.price)
end

-- The two lines on the gate's price board and in the buy prompt.
function FilmSets.describe(set: FilmSet): string
	return `x{1 + set.luck} casting Luck\n{if set.boxOffice >= 1 then "Double" else `+{math.floor(set.boxOffice * 100 + 0.5)}%`} box office inside`
end

return FilmSets
