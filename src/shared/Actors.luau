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
	{ id = "BackgroundExtra", name = "Background Extra", tier = "Newcomer", genre = "Romance" },

	{ id = "SoapRegular", name = "Soap Opera Regular", tier = "Rising", genre = "Romance" },
	{ id = "AdModel", name = "Ad Model", tier = "Rising", genre = "Comedy" },
	{ id = "IndieSidekick", name = "Indie Sidekick", tier = "Rising", genre = "Sci-Fi" },

	{ id = "ActionVeteran", name = "Action Veteran", tier = "Pro", genre = "Action" },
	{ id = "ComedyDuo", name = "Comedy Duo", tier = "Pro", genre = "Comedy" },
	{ id = "NightShiftVillain", name = "Night Shift Villain", tier = "Pro", genre = "Horror" },

	{ id = "TeenHeartthrob", name = "Teen Heartthrob", tier = "Star", genre = "Romance" },
	{ id = "MethodActor", name = "Method Actor", tier = "Star", genre = "Horror" },
	{ id = "SpaceCaptain", name = "Space Opera Captain", tier = "Star", genre = "Sci-Fi" },

	{ id = "BoxOfficeKing", name = "Box Office King", tier = "Superstar", genre = "Action" },
	{ id = "ScreamQueen", name = "Scream Queen", tier = "Superstar", genre = "Horror" },
	{ id = "RomComSweetheart", name = "Rom-Com Sweetheart", tier = "Superstar", genre = "Romance" },

	{ id = "GoldenAgeDiva", name = "Golden Age Diva", tier = "Legend", genre = "Romance" },
	{ id = "SilentEraClown", name = "Silent Era Clown", tier = "Legend", genre = "Comedy" },
	{ id = "SciFiVisionary", name = "Sci-Fi Visionary", tier = "Legend", genre = "Sci-Fi" },

	{ id = "MogulsMuse", name = "The Mogul's Muse", tier = "Icon", genre = "Romance" },
	{ id = "LastActionHero", name = "The Last Action Hero", tier = "Icon", genre = "Action" },
	{ id = "PhantomAuteur", name = "The Phantom Auteur", tier = "Icon", genre = "Horror" },
} :: { Actor }

-- Ordered normal, then rarer. Award-Winning is checked first when rolling.
Actors.Variants = {
	{ id = "Normal", name = "Normal", oneIn = nil, multiplier = 1, color = Color3.fromRGB(230, 230, 235) },
	{ id = "Shiny", name = "Shiny", oneIn = 40, multiplier = 2, color = Color3.fromRGB(120, 230, 255) },
	{ id = "Award", name = "Award-Winning", oneIn = 800, multiplier = 5, color = Color3.fromRGB(245, 184, 46) },
} :: { Variant }

Actors.IndexSlots = #Actors.List * #Actors.Variants

export type Agency = {
	id: string,
	name: string,
	cost: number,
	fame: number, -- Fame needed to use it
	minTier: number, -- tiers below this index are removed from the pool
}

-- Plan section 3: better agencies cost more per roll and remove the bottom tier(s).
-- Talent Agency's Fame gate sets when it opens (about 30 minutes of play, see ECONOMY.md): Fame,
-- not its $1,000 price, is what holds it back, so tune the gate to move it.
Actors.Agencies = {
	{ id = "Open", name = "Open Casting", cost = 10, fame = 0, minTier = 1 },
	{ id = "Talent", name = "Talent Agency", cost = 1000, fame = 1400, minTier = 2 },
	{ id = "Hollywood", name = "Hollywood Casting", cost = 100000, fame = 50000, minTier = 3 },
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

function Actors.actorsInTier(tierId: string): { Actor }
	return actorsByTier[tierId] or {}
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
-- raises a lower roll to that tier; the variant is rolled as usual.
function Actors.roll(random: Random, luck: number, minTier: number?, floorTier: string?): (Actor, Variant)
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

return Actors
