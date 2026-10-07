--!strict
-- Script, genre and premiere definitions plus the payout math. Shared so the UI can preview
-- numbers, but only the server ever applies them.
local Actors = require(script.Parent.Actors)

export type Length = {
	id: string,
	name: string,
	seconds: number,
	base: number, -- script base earnings
	cost: number,
	fame: number, -- Fame needed to buy this script length
}

export type Result = {
	id: string,
	name: string,
	chance: number, -- base chance at Luck 1
	multiplier: number,
	color: Color3,
}

local Movies = {}

Movies.SpecialtyBonus = 1.5 -- actor cast in their specialty genre (plan section 2)

Movies.Genres = { "Action", "Comedy", "Horror", "Romance", "Sci-Fi" }

-- Plan section 2: Short Film 2 min, Indie 10 min, Feature 45 min, Epic 3 h. Base earnings per
-- second fall slightly with length, so Shorts (with clapping) are best while playing and long
-- scripts are for time away. Tuned with tools/economy_sim.py (see ECONOMY.md).
Movies.Lengths = {
	{ id = "Short", name = "Short Film", seconds = 2 * 60, base = 12, cost = 15, fame = 0 },
	{ id = "Indie", name = "Indie", seconds = 10 * 60, base = 55, cost = 60, fame = 0 },
	{ id = "Feature", name = "Feature", seconds = 45 * 60, base = 220, cost = 250, fame = 1800},
	{ id = "Epic", name = "Epic", seconds = 3 * 60 * 60, base = 780, cost = 900, fame = 16000},
} :: { Length }

-- Fame needed before a genre's scripts can be bought (plan section 6: Fame unlocks genres).
Movies.GenreFame = {
	Action = 0,
	Comedy = 0,
	Horror = 100,
	Romance = 100,
	["Sci-Fi"] = 2000,
} :: { [string]: number }

-- Ordered worst to best.
Movies.Results = {
	{ id = "Flop", name = "Flop", chance = 0.20, multiplier = 0.5, color = Color3.fromRGB(150, 150, 160) },
	{ id = "Hit", name = "Hit", chance = 0.5525, multiplier = 1, color = Color3.fromRGB(90, 200, 120) },
	{ id = "Blockbuster", name = "Blockbuster", chance = 0.20, multiplier = 3, color = Color3.fromRGB(80, 160, 255) },
	{ id = "Cult", name = "Cult Classic", chance = 0.045, multiplier = 6, color = Color3.fromRGB(180, 100, 255) },
	{ id = "Masterpiece", name = "Masterpiece", chance = 0.0025, multiplier = 20, color = Color3.fromRGB(255, 215, 0) },
} :: { Result }

local TITLES: { [string]: { string } } = {
	Action = { "Final Showdown", "Dust and Thunder", "The Last Chase", "Iron Dawn" },
	Comedy = { "Oops, I Did It Again", "The Wrong Wedding", "Mild Disaster", "Awkward Silence" },
	Horror = { "Don't Open It", "The Quiet House", "Midnight Cellar", "Hollow Eyes" },
	Romance = { "Paris, Maybe", "Letters at Dawn", "The Long Goodbye", "Second Summer" },
	["Sci-Fi"] = { "Orbit Zero", "The Last Signal", "Neon Frontier", "Echoes of Mars" },
}

local lengthById: { [string]: Length } = {}
for _, length in Movies.Lengths do
	lengthById[length.id] = length
end
local resultById: { [string]: Result } = {}
for _, result in Movies.Results do
	resultById[result.id] = result
end
local genreSet: { [string]: boolean } = {}
for _, genre in Movies.Genres do
	genreSet[genre] = true
end

function Movies.getLength(id: string): Length?
	return lengthById[id]
end

function Movies.getResult(id: string): Result?
	return resultById[id]
end

function Movies.isGenre(genre: string): boolean
	return genreSet[genre] == true
end

function Movies.scriptKey(genre: string, lengthId: string): string
	return genre .. ":" .. lengthId
end

function Movies.randomTitle(random: Random, genre: string): string
	local pool = TITLES[genre]
	return pool[random:NextInteger(1, #pool)]
end

-- Star Power one actor-variant contributes to a movie of `genre`.
function Movies.actorPower(actorKey: string, genre: string): number
	local parts = string.split(actorKey, ":")
	local actor = Actors.getActor(parts[1] or "")
	local variant = Actors.getVariant(parts[2] or "")
	if actor == nil or variant == nil then
		return 0
	end
	local tier = Actors.getTier(actor.tier)
	if tier == nil then
		return 0
	end
	local bonus = if actor.genre == genre then Movies.SpecialtyBonus else 1
	return tier.starPower * variant.multiplier * bonus
end

function Movies.castPower(castKeys: { string }, genre: string): number
	local total = 0
	for _, key in castKeys do
		total += Movies.actorPower(key, genre)
	end
	return total
end

-- Chance of each result (sums to 1). Luck multiplies the three best results' chances; the extra
-- comes out of Flop first, then Hit. At Luck 1 this is exactly the plan's table.
function Movies.premiereChances(luck: number): { [string]: number }
	local safeLuck = math.max(luck, 1)
	local chances: { [string]: number } = {}
	for _, result in Movies.Results do
		chances[result.id] = result.chance
	end
	local extra = 0
	for _, id in { "Blockbuster", "Cult", "Masterpiece" } do
		local add = chances[id] * (safeLuck - 1)
		chances[id] += add
		extra += add
	end
	for _, id in { "Flop", "Hit" } do
		local take = math.min(chances[id], extra)
		chances[id] -= take
		extra -= take
	end
	local total = 0
	for _, value in chances do
		total += value
	end
	for id, value in chances do
		chances[id] = value / total
	end
	return chances
end

function Movies.rollResult(random: Random, luck: number): Result
	local chances = Movies.premiereChances(luck)
	local pick = random:NextNumber()
	local running = 0
	local chosen = Movies.Results[1]
	for _, result in Movies.Results do
		running += chances[result.id]
		chosen = result
		if pick < running then
			break
		end
	end
	return chosen
end

-- Plan section 2: script base x total Star Power x genre bonus x premiere result. The genre bonus
-- comes from completing a genre's Index set (1 when not earned).
function Movies.payout(length: Length, power: number, result: Result, genreBonus: number?): number
	return math.max(1, math.floor(length.base * power * (genreBonus or 1) * result.multiplier))
end

-- Fame never resets and is never spent; the unlock thresholds are set from this curve (ECONOMY.md).
function Movies.fame(payout: number): number
	return math.max(1, math.floor(math.sqrt(payout)))
end

return Movies
