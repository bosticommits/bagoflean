--!strict
-- Actor definitions and casting odds. Shared so the odds panel shows exactly what the server rolls.
-- All actors are original fictional characters (no real people).
export type Genre = "Action" | "Comedy" | "Horror" | "Romance" | "Sci-Fi"

export type Tier = {
	id: string,
	name: string,
	oneIn: number, -- base "1 in N" (plan section 3)
	starPower: number,
	color: Color3,
}

export type Actor = {
	id: string,
	name: string,
	tier: string,
	genre: Genre,
	season: string?, -- a limited actor's season (SpecialEvents.Seasons id); nil for everyone else
}

export type Variant = {
	id: string,
	name: string,
	oneIn: number?, -- nil for the normal variant
	multiplier: number,
	color: Color3,
}

local Actors = {}

-- Ordered common to rare. Colors are the rarity colors in ART_STYLE.md section 4. Icon is prismatic:
-- the UI draws it as a rainbow (UiKit.RAINBOW) and uses this pink where one color is needed.
Actors.Tiers = {
	{ id = "Newcomer", name = "Newcomer", oneIn = 2, starPower = 1, color = Color3.fromRGB(167, 169, 172) },
	{ id = "Rising", name = "Rising", oneIn = 6, starPower = 3, color = Color3.fromRGB(76, 199, 100) },
	{ id = "Pro", name = "Pro", oneIn = 40, starPower = 8, color = Color3.fromRGB(58, 141, 255) },
	{ id = "Star", name = "Star", oneIn = 700, starPower = 20, color = Color3.fromRGB(160, 77, 255) },
	{ id = "Superstar", name = "Superstar", oneIn = 8000, starPower = 50, color = Color3.fromRGB(255, 194, 26) },
	{ id = "Legend", name = "Legend", oneIn = 220000, starPower = 120, color = Color3.fromRGB(255, 90, 46) },
	{ id = "Icon", name = "Icon", oneIn = 5000000, starPower = 300, color = Color3.fromRGB(255, 95, 210) },
} :: { Tier }

Actors.List = {
	{ id = "NervousIntern", name = "Nervous Intern", tier = "Newcomer", genre = "Comedy" },
	{ id = "StuntDouble", name = "Stunt Double", tier = "Newcomer", genre = "Action" },
	{ id = "BackgroundExtra", name = "Zombie Extra", tier = "Newcomer", genre = "Romance" },

	{ id = "SoapRegular", name = "Soap Opera Star", tier = "Rising", genre = "Romance" },
	{ id = "AdModel", name = "Hot Dog Mascot", tier = "Rising", genre = "Comedy" },
	{ id = "IndieSidekick", name = "Robot Sidekick", tier = "Rising", genre = "Sci-Fi" },

	{ id = "ActionVeteran", name = "Commando", tier = "Pro", genre = "Action" },
	{ id = "ComedyDuo", name = "Ventriloquist", tier = "Pro", genre = "Comedy" },
	{ id = "NightShiftVillain", name = "Night Shift Villain", tier = "Pro", genre = "Horror" },

	{ id = "TeenHeartthrob", name = "Teen Heartthrob", tier = "Star", genre = "Romance" },
	{ id = "MethodActor", name = "Method Knight", tier = "Star", genre = "Horror" },
	{ id = "SpaceCaptain", name = "Alien Captain", tier = "Star", genre = "Sci-Fi" },

	{ id = "BoxOfficeKing", name = "Box Office King", tier = "Superstar", genre = "Action" },
	{ id = "ScreamQueen", name = "Scream Queen", tier = "Superstar", genre = "Horror" },
	{ id = "RomComSweetheart", name = "Cupid", tier = "Superstar", genre = "Romance" },

	{ id = "GoldenAgeDiva", name = "Showgirl Diva", tier = "Legend", genre = "Romance" },
	{ id = "SilentEraClown", name = "Silent Film Clown", tier = "Legend", genre = "Comedy" },
	{ id = "SciFiVisionary", name = "Brain in a Jar", tier = "Legend", genre = "Sci-Fi" },

	{ id = "MogulsMuse", name = "Golden Muse", tier = "Icon", genre = "Romance" },
	{ id = "LastActionHero", name = "Mech Hero", tier = "Icon", genre = "Action" },
	{ id = "PhantomAuteur", name = "The Phantom Auteur", tier = "Icon", genre = "Horror" },
} :: { Actor }

-- Ordered normal, then rarer. Award-Winning is checked first when rolling.
Actors.Variants = {
	{ id = "Normal", name = "Normal", oneIn = nil, multiplier = 1, color = Color3.fromRGB(230, 230, 235) },
	{ id = "Shiny", name = "Shiny", oneIn = 40, multiplier = 2, color = Color3.fromRGB(120, 230, 255) },
	{ id = "Award", name = "Award-Winning", oneIn = 800, multiplier = 5, color = Color3.fromRGB(245, 184, 46) },
} :: { Variant }

Actors.IndexSlots = #Actors.List * #Actors.Variants

-- Limited seasonal actors: one per seasonal Film Festival (SpecialEvents.Seasons). While its season
-- runs, a limited actor can be cast exactly as often as any one everyday actor of its tier (a Star
-- is 1 in 700 at Open Casting, so each Star actor is 1 in 2,100), and winning that festival gives
-- a copy. Its chance comes out of the agency's commonest tier, so every other actor keeps its odds
-- and the Star row is no slower to finish in season. Out of season nobody can cast it; copies
-- already owned stay and work like any actor of their tier. They are kept out of Actors.List on
-- purpose: the Index tier rows, the
-- genre sets, Actors.IndexSlots and the "all 21 actors" goal only count actors anyone can find on
-- any day, so a player who missed a season can still finish every one of them. The Collection
-- shows them in their own Limited group. Designs: art/blender/seasonal_actors.py.
Actors.Limited = {
	{ id = "PumpkinPhantom", name = "The Pumpkin Phantom", tier = "Star", genre = "Horror", season = "FrightNight" },
	{ id = "JingleJester", name = "Jingle Jester", tier = "Star", genre = "Comedy", season = "HolidayLights" },
	{ id = "CupidCrooner", name = "Cupid Crooner", tier = "Star", genre = "Romance", season = "LoveStory" },
	{ id = "HeatwaveHero", name = "Heatwave Hero", tier = "Star", genre = "Action", season = "SummerBlockbuster" },
} :: { Actor }

export type Agency = {
	id: string,
	name: string,
	cost: number,
	fame: number, -- Fame needed to use it
	minTier: number, -- tiers below this index are removed from the pool
	pity: string, -- the tier its pity meter guarantees (Actors.PityEvery)
}

-- Plan section 3: better agencies cost more per roll and remove the bottom tier(s).
-- Talent Agency's Fame gate sets when it opens (about 30 minutes of play, see ECONOMY.md): Fame,
-- not its $1,000 price, is what holds it back, so tune the gate to move it.
Actors.Agencies = {
	{ id = "Open", name = "Open Casting", cost = 10, fame = 0, minTier = 1, pity = "Star" },
	{ id = "Talent", name = "Talent Agency", cost = 1000, fame = 1400, minTier = 2, pity = "Superstar" },
	{ id = "Hollywood", name = "Hollywood Casting", cost = 100000, fame = 50000, minTier = 3, pity = "Superstar" },
} :: { Agency }

-- "Discovered!" hot start: a brand-new player's first casts carry guaranteed pulls, so the first
-- Star lands in the first session (about minute 7 in the economy sim) instead of around minute 17.
-- Each row says the lowest tier that cast can be; a luckier roll keeps its better tier. Counted per
-- account (crate casts too) and never again after the last row, so later play is unchanged.
export type HotStartStep = { cast: number, tier: string }

Actors.HotStart = {
	{ cast = 3, tier = "Rising" },
	{ cast = 10, tier = "Pro" },
	{ cast = 25, tier = "Star" },
} :: { HotStartStep }
Actors.HotStartLength = Actors.HotStart[#Actors.HotStart].cast

-- The tier guaranteed on the player's `castNumber`-th cast (1 = their first), or nil.
function Actors.hotStartTier(castNumber: number): string?
	for _, step in Actors.HotStart do
		if step.cast == castNumber then
			return step.tier
		end
	end
	return nil
end

-- The next guarantee after `castsDone` casts, or nil once the hot start is over.
function Actors.nextHotStart(castsDone: number): HotStartStep?
	for _, step in Actors.HotStart do
		if step.cast > castsDone then
			return step
		end
	end
	return nil
end

local agencyById: { [string]: Agency } = {}
for _, agency in Actors.Agencies do
	agencyById[agency.id] = agency
end

function Actors.getAgency(id: string): Agency?
	return agencyById[id]
end

local tierById: { [string]: Tier } = {}
for _, tier in Actors.Tiers do
	tierById[tier.id] = tier
end
local actorById: { [string]: Actor } = {}
local actorsByTier: { [string]: { Actor } } = {}
for _, actor in Actors.List do
	actorById[actor.id] = actor
	actorsByTier[actor.tier] = actorsByTier[actor.tier] or {}
	table.insert(actorsByTier[actor.tier], actor)
end
-- Limited actors can be looked up (rosters, movies, lots) but are in no tier's everyday pool.
local limitedBySeason: { [string]: Actor } = {}
for _, actor in Actors.Limited do
	actorById[actor.id] = actor
	limitedBySeason[actor.season :: string] = actor
end
local variantById: { [string]: Variant } = {}
for _, variant in Actors.Variants do
	variantById[variant.id] = variant
end

function Actors.getTier(id: string): Tier?
	return tierById[id]
end

function Actors.getActor(id: string): Actor?
	return actorById[id]
end

function Actors.getVariant(id: string): Variant?
	return variantById[id]
end

-- The everyday actors of a tier (no limited ones).
function Actors.actorsInTier(tierId: string): { Actor }
	return actorsByTier[tierId] or {}
end

function Actors.isLimited(actorId: string): boolean
	local actor = actorById[actorId]
	return actor ~= nil and actor.season ~= nil
end

-- The limited actor of season `seasonId` (SpecialEvents.Seasons), if it has one.
function Actors.limitedFor(seasonId: string?): Actor?
	return if seasonId ~= nil then limitedBySeason[seasonId] else nil
end

-- The chance a cast is `limited` (the limited actor in season), given the cast's tier chances
-- (Actors.tierChances): the same as one everyday actor of its tier, never more than the commonest
-- tier in the pool holds (that is where it comes from).
function Actors.limitedChance(chances: { [string]: number }, limited: Actor?): number
	if limited == nil then
		return 0
	end
	local share = (chances[limited.tier] or 0) / math.max(#Actors.actorsInTier(limited.tier), 1)
	for _, tier in Actors.Tiers do
		if (chances[tier.id] or 0) > 0 then
			return math.min(share, chances[tier.id])
		end
	end
	return 0
end

function Actors.key(actorId: string, variantId: string): string
	return actorId .. ":" .. variantId
end

-- Chance of each tier as a fraction (sums to 1). Tiers are tried rarest first: each hits its
-- "1 in N" (`oneIn` in Actors.Tiers) with whatever probability is left, so at Luck 1 at Open
-- Casting Icon is exactly its oneIn (1 in 5,000,000) and the other rare tiers are within a hair
-- of theirs. An agency's `minTier` removes the tiers below it from the pool: their share is dropped
-- and the rest is scaled back up to 1, so the rare tiers get proportionally more likely.
-- Luck divides N at every agency (Luck x2 turns the Talent Agency's Legend 1 in ~41,500 into 1 in
-- ~20,800). It is applied after the agency's floor, so the floor tier takes what Luck moves up;
-- before, Luck mostly turned Newcomers into Risings, which the better agencies remove anyway.
function Actors.tierChances(luck: number, minTier: number?): { [string]: number }
	local floorIndex = math.clamp(minTier or 1, 1, #Actors.Tiers)
	local safeLuck = if luck ~= luck then 1 else math.max(luck, 1)

	-- The agency's pool at Luck 1: the "1 in N" chain, bottom tiers dropped, rest scaled up.
	local base: { [string]: number } = {}
	local remaining = 1
	for index = #Actors.Tiers, 2, -1 do
		local tier = Actors.Tiers[index]
		local chance = remaining / tier.oneIn
		base[tier.id] = chance
		remaining -= chance
	end
	base[Actors.Tiers[1].id] = remaining
	local removed = 0
	for index = 1, floorIndex - 1 do
		removed += base[Actors.Tiers[index].id]
	end

	-- The same chain over the agency's pool, with Luck dividing each tier's "1 in N" in it.
	local chances: { [string]: number } = {}
	local baseLeft, left = 1, 1
	for index = #Actors.Tiers, floorIndex + 1, -1 do
		local id = Actors.Tiers[index].id
		local pooled = base[id] / (1 - removed)
		local chance = left * math.min(1, safeLuck * pooled / baseLeft)
		chances[id] = chance
		baseLeft -= pooled
		left -= chance
	end
	chances[Actors.Tiers[floorIndex].id] = left
	for index = 1, floorIndex - 1 do
		chances[Actors.Tiers[index].id] = 0
	end
	return chances
end

-- Chance of each variant (sums to 1). Award-Winning is rolled first, then Shiny.
function Actors.variantChances(luck: number): { [string]: number }
	local safeLuck = math.max(luck, 1)
	local award = math.min(1, safeLuck / 800)
	local shiny = (1 - award) * math.min(1, safeLuck / 40)
	return { Normal = 1 - award - shiny, Shiny = shiny, Award = award }
end

-- `random` is a Random object so the server owns the seed. `floorTier` (a hot start guarantee)
-- raises a lower roll to that tier; the variant is rolled as usual. `limited` is the limited actor
-- in season (Actors.limitedChance): the bottom of the roll is its, and the tiers are laid out above
-- it as usual, so only the commonest tier's share shrinks.
function Actors.roll(random: Random, luck: number, minTier: number?, floorTier: string?, limited: Actor?): (Actor, Variant)
	local chances = Actors.tierChances(luck, minTier)
	local pick = random:NextNumber()
	local chosenTier = Actors.Tiers[1]
	local running = 0
	for _, tier in Actors.Tiers do
		running += chances[tier.id]
		chosenTier = tier
		if pick < running then
			break
		end
	end
	local floor = if floorTier ~= nil then tierById[floorTier] else nil
	if floor ~= nil and (table.find(Actors.Tiers, chosenTier) :: number) < (table.find(Actors.Tiers, floor) :: number) then
		chosenTier = floor
	end

	local pool = Actors.actorsInTier(chosenTier.id)
	local actor = pool[random:NextInteger(1, #pool)]
	-- The limited actor's slice sits at the bottom of the roll, inside the commonest tier's share
	-- (a hot start guarantee above its tier keeps the guarantee instead).
	local limitedTier = if limited ~= nil then tierById[limited.tier] else nil
	if limited ~= nil and limitedTier ~= nil and pick < Actors.limitedChance(chances, limited) then
		if floor == nil or (table.find(Actors.Tiers, floor) :: number) <= (table.find(Actors.Tiers, limitedTier) :: number) then
			actor = limited
		end
	end

	local variantPick = random:NextNumber()
	local variantChance = Actors.variantChances(luck)
	local variant = variantById.Normal
	if variantPick < variantChance.Award then
		variant = variantById.Award
	elseif variantPick < variantChance.Award + variantChance.Shiny then
		variant = variantById.Shiny
	end
	return actor, variant
end

-- Pity meter: each agency counts the casts since its last pull of its `pity` tier or better, and
-- the PityEvery-th one is guaranteed that tier. Per agency, so cheap Open Casting casts cannot
-- fill up the Talent Agency's meter. Tuned in ECONOMY.md ("Pity meter").
Actors.PityEvery = 400

-- One early pull for a brand-new account, by seconds of play (counted on the server): one
-- guaranteed Superstar. `early` in the save: 0 = not yet, 2 (Actors.EarlyDone) = done (old saves
-- start done; 1 was the removed near-miss tease and counts as not yet). A natural Superstar or
-- better first also counts as done.
Actors.FirstSuperstarAfter = 12 * 60 -- the first cast after this is a guaranteed Superstar
Actors.EarlyDone = 2

export type CastSave = { hotStart: number, pity: { [string]: number }, early: number, played: number }

local function rank(tierId: string): number
	return table.find(Actors.Tiers, tierById[tierId]) or 0
end

-- Position of a tier in Actors.Tiers (1 = Newcomer); 0 for an unknown id.
Actors.tierRank = rank

-- The tier the agency's NEXT cast is guaranteed at least, and why ("hotStart" | "pity" |
-- "firstSuperstar"), or nil, nil. Pure: it changes nothing. castWithGuarantees rolls with it, and
-- the server mirrors it to the odds panel (NextFloor<agency>), so what is shown is what is rolled.
function Actors.nextFloor(save: CastSave, agency: Agency, noFirstSuperstar: boolean?): (string?, string?)
	local floor: string?, guarantee: string? = nil, nil
	local function offer(tierId: string?, why: string)
		if tierId ~= nil and (floor == nil or rank(tierId) > rank(floor :: string)) then
			floor, guarantee = tierId, why
		end
	end
	if save.hotStart < Actors.HotStartLength then
		offer(Actors.hotStartTier(save.hotStart + 1), "hotStart")
	end
	if (save.pity[agency.id] or 0) + 1 >= Actors.PityEvery then
		offer(agency.pity, "pity")
	end
	if not noFirstSuperstar and save.early < Actors.EarlyDone and save.played >= Actors.FirstSuperstarAfter then
		offer("Superstar", "firstSuperstar")
	end
	return floor, guarantee
end

-- One cast with every guarantee applied (Actors.nextFloor): the hot start, the agency's pity meter
-- and the first Superstar. `roll(floorTier)` does the real roll (Actors.roll) with the best floor
-- in force, so a luckier roll always keeps its tier. Updates `save` and returns the actor, the
-- variant, which guarantee covered this cast ("hotStart" | "pity" | "firstSuperstar" | nil) and
-- the floor tier it rolled with.
function Actors.castWithGuarantees(save: CastSave, agency: Agency, roll: (string?) -> (Actor, Variant), noFirstSuperstar: boolean?): (Actor, Variant, string?, string?)
	local floor, guarantee = Actors.nextFloor(save, agency, noFirstSuperstar)
	if save.hotStart < Actors.HotStartLength then
		save.hotStart += 1
	end
	local pityCount = (save.pity[agency.id] or 0) + 1

	local actor, variant = roll(floor)
	local got = rank(actor.tier)
	save.pity[agency.id] = if got >= rank(agency.pity) then 0 else pityCount
	if save.early < Actors.EarlyDone and got >= rank("Superstar") then
		save.early = Actors.EarlyDone
	end
	return actor, variant, guarantee, floor
end

-- Moves the chance of the tiers below `floorTier` into it: a guaranteed cast rolls at least that
-- tier, so those tiers cannot happen. nil changes nothing.
function Actors.floorChances(chances: { [string]: number }, floorTier: string?): { [string]: number }
	local merged = table.clone(chances)
	if floorTier ~= nil then
		for index = 1, rank(floorTier) - 1 do
			local id = Actors.Tiers[index].id
			merged[floorTier] += merged[id]
			merged[id] = 0
		end
	end
	return merged
end

export type CastOdds = {
	tiers: { [string]: number }, -- chance the cast is each tier (sums to 1; a limited actor counts in its own tier)
	actor: { [string]: number }, -- chance of any ONE everyday actor of each tier
	limited: number, -- chance of the limited actor (0 when none, or a floor above its tier covers the cast)
}

-- Everything a single cast can be, as Actors.roll rolls it: `floorTier` is the guarantee in force
-- (Actors.nextFloor), `limited` the limited actor in season. The limited actor's slice comes out of
-- the first tier that has any chance (it sits at the bottom of the roll) and is counted in its own
-- tier, so the tiers still sum to 1. Variants are rolled on top (Actors.variantChances).
function Actors.castOdds(luck: number, minTier: number?, floorTier: string?, limited: Actor?): CastOdds
	local base = Actors.tierChances(luck, minTier)
	local merged = Actors.floorChances(base, floorTier)
	local share = 0
	if limited ~= nil and (floorTier == nil or rank(floorTier) <= rank(limited.tier)) then
		share = Actors.limitedChance(base, limited)
	end
	local tiers: { [string]: number } = {}
	local actor: { [string]: number } = {}
	local firstTaken = false
	for _, tier in Actors.Tiers do
		local chance = merged[tier.id]
		if not firstTaken and chance > 0 then
			firstTaken = true
			chance = math.max(chance - share, 0)
		end
		actor[tier.id] = chance / math.max(#Actors.actorsInTier(tier.id), 1)
		tiers[tier.id] = chance
	end
	if limited ~= nil then
		tiers[limited.tier] += share
	end
	return { tiers = tiers, actor = actor, limited = share }
end

-- The chance of this exact pull (tier, then the actor in it, then the variant) for a cast rolled
-- with these arguments. Used for the reveal card, so the number is the cast's real one.
function Actors.pullChance(luck: number, minTier: number?, floorTier: string?, limited: Actor?, actorId: string, variantId: string): number
	local actor = actorById[actorId]
	if actor == nil then
		return 0
	end
	local odds = Actors.castOdds(luck, minTier, floorTier, limited)
	local ofActor = if actor.season ~= nil then odds.limited else odds.actor[actor.tier] or 0
	return ofActor * (Actors.variantChances(luck)[variantId] or 0)
end

-- A chance (0..1) as a percentage for the odds screens: at least 4 decimals below the first
-- non-zero digit (so a 1 in 5,000,000 Icon reads 0.000020000%). 0 reads "0%".
function Actors.percent(chance: number): string
	if chance <= 0 then
		return "0%"
	end
	local pct = chance * 100
	if pct >= 100 then
		return "100%"
	end
	local text = string.format("%." .. math.max(0, 4 - math.floor(math.log10(pct))) .. "f%%", pct)
	-- Less than certain never reads as certain.
	return if string.sub(text, 1, 3) == "100" then "99.999%" else text
end

-- A short chance for the reveal card, where space is tight: 2 significant figures down to 1%
-- ("37%", "4.2%"), "1 in N" below that. The odds panel keeps the full Actors.percent.
function Actors.brief(chance: number): string
	if chance <= 0 then
		return "0%"
	end
	local pct = chance * 100
	if pct >= 100 then
		return "100%"
	elseif pct >= 10 then
		return string.format("%.0f%%", math.min(pct, 99.4))
	elseif pct >= 1 then
		return string.format("%.1f%%", pct)
	end
	return Actors.oneIn(chance)
end

-- "1 in 8,000" style secondary text for a chance (0..1), or "never".
function Actors.oneIn(chance: number): string
	if chance <= 0 then
		return "never"
	end
	local text = tostring(math.floor(1 / chance + 0.5))
	while true do
		local replaced, count = string.gsub(text, "^(-?%d+)(%d%d%d)", "%1,%2")
		text = replaced
		if count == 0 then
			break
		end
	end
	return "1 in " .. text
end

return Actors
