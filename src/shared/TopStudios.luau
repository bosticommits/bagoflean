--!strict
-- Rules for showing off: which of a player's actors are their rarest (the Rare Wall on their lot
-- and the star pedestal), how the Top Studios board in the plaza ranks studios by Fame, and the
-- short numbers it prints. Pure functions, so tests/luau can check them outside Roblox.
local Actors = require(script.Parent.Actors)

local TopStudios = {}

TopStudios.BoardSize = 10 -- rows on the plaza board
TopStudios.WallSize = 5 -- figures on a Rare Wall

export type Owned = { actor: Actors.Actor, variant: Actors.Variant, key: string }
export type Entry = { userId: number, fame: number }

local tierRank: { [string]: number } = {}
for rank, tier in Actors.Tiers do
	tierRank[tier.id] = rank
end
local variantRank: { [string]: number } = {}
for rank, variant in Actors.Variants do
	variantRank[variant.id] = rank
end
local listOrder: { [string]: number } = {}
for i, actor in Actors.List do
	listOrder[actor.id] = i
end

-- The `count` rarest copies in a roster ("actorId:variantId" -> copies): highest tier first, then
-- the best variant, then the rarer actor in the list. Each actor-and-variant shows once.
function TopStudios.rarest(roster: { [string]: number }, count: number): { Owned }
	local owned: { Owned } = {}
	for key, copies in roster do
		if type(copies) == "number" and copies > 0 then
			local parts = string.split(key, ":")
			local actor = Actors.getActor(parts[1] or "")
			local variant = Actors.getVariant(parts[2] or "")
			if actor ~= nil and variant ~= nil and tierRank[actor.tier] ~= nil then
				table.insert(owned, { actor = actor, variant = variant, key = key })
			end
		end
	end
	table.sort(owned, function(a, b)
		local ta, tb = tierRank[a.actor.tier], tierRank[b.actor.tier]
		if ta ~= tb then
			return ta > tb
		end
		local va, vb = variantRank[a.variant.id], variantRank[b.variant.id]
		if va ~= vb then
			return va > vb
		end
		return listOrder[a.actor.id] > listOrder[b.actor.id]
	end)
	while #owned > count do
		table.remove(owned)
	end
	return owned
end

-- The board's rows: the saved top list from every server merged with the players here right now
-- (their Fame is fresher than the last save), one row per player at their highest Fame, best
-- first. Players with no Fame yet are left off.
function TopStudios.merge(saved: { Entry }, live: { Entry }, limit: number): { Entry }
	local best: { [number]: number } = {}
	for _, list in { saved, live } do
		for _, entry in list do
			if entry.fame > 0 and entry.fame > (best[entry.userId] or 0) then
				best[entry.userId] = entry.fame
			end
		end
	end
	local rows: { Entry } = {}
	for userId, fame in best do
		table.insert(rows, { userId = userId, fame = fame })
	end
	table.sort(rows, function(a, b)
		if a.fame ~= b.fame then
			return a.fame > b.fame
		end
		return a.userId < b.userId
	end)
	while #rows > limit do
		table.remove(rows)
	end
	return rows
end

-- 950, 12.5K, 3.4M, 1.2B: short enough for a board seen from across the plaza.
local SUFFIXES: { { size: number, letter: string } } = {
	{ size = 1e12, letter = "T" },
	{ size = 1e9, letter = "B" },
	{ size = 1e6, letter = "M" },
	{ size = 1e3, letter = "K" },
}
function TopStudios.short(n: number): string
	n = math.max(0, math.floor(n))
	for _, step in SUFFIXES do
		local size, letter = step.size, step.letter
		if n >= size then
			local value = n / size
			local text = if value >= 100 then tostring(math.floor(value)) else string.format("%.1f", math.floor(value * 10) / 10)
			return (string.gsub(text, "%.0$", "")) .. letter
		end
	end
	return tostring(n)
end

return TopStudios
