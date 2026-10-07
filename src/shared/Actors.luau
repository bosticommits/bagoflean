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

-- Ordered common to rare.
Actors.Tiers = {
	{ id = "Newcomer", name = "Newcomer", oneIn = 2, starPower = 1, color = Color3.fromRGB(170, 170, 180) },
	{ id = "Rising", name = "Rising", oneIn = 6, starPower = 4, color = Color3.fromRGB(90, 200, 120) },
	{ id = "Pro", name = "Pro", oneIn = 30, starPower = 15, color = Color3.fromRGB(80, 160, 255) },
	{ id = "Star", name = "Star", oneIn = 200, starPower = 70, color = Color3.fromRGB(180, 100, 255) },
	{ id = "Superstar", name = "Superstar", oneIn = 1500, starPower = 400, color = Color3.fromRGB(255, 150, 60) },
	{ id = "Legend", name = "Legend", oneIn = 15000, starPower = 2500, color = Color3.fromRGB(255, 80, 80) },
	{ id = "Icon", name = "Icon", oneIn = 150000, starPower = 20000, color = Color3.fromRGB(255, 215, 0) },
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
	{ id = "Award", name = "Award-Winning", oneIn = 800, multiplier = 5, color = Color3.fromRGB(255, 215, 0) },
} :: { Variant }

Actors.IndexSlots = #Actors.List * #Actors.Variants

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
-- "1 in N" with whatever probability is left, so Icon is exactly 1 in 150,000 and the rare tiers
-- match the plan. Luck divides N (Luck x2 turns 1 in 1,500 into 1 in 750). Newcomer gets the rest.
function Actors.tierChances(luck: number): { [string]: number }
	local chances: { [string]: number } = {}
	local remaining = 1
	for index = #Actors.Tiers, 2, -1 do
		local tier = Actors.Tiers[index]
		local chance = remaining * math.min(1, math.max(luck, 1) / tier.oneIn)
		chances[tier.id] = chance
		remaining -= chance
	end
	chances[Actors.Tiers[1].id] = remaining
	return chances
end

-- Chance of each variant (sums to 1). Award-Winning is rolled first, then Shiny.
function Actors.variantChances(luck: number): { [string]: number }
	local safeLuck = math.max(luck, 1)
	local award = math.min(1, safeLuck / 800)
	local shiny = (1 - award) * math.min(1, safeLuck / 40)
	return { Normal = 1 - award - shiny, Shiny = shiny, Award = award }
end

-- `random` is a Random object so the server owns the seed.
function Actors.roll(random: Random, luck: number): (Actor, Variant)
	local chances = Actors.tierChances(luck)
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
