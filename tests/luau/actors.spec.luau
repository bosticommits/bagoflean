local H = require("./harness")
local Actors = H.require("Actors")
local test, expect, equal, near = H.test, H.expect, H.equal, H.near

local function sum(t: { [string]: number }): number
	local total = 0
	for _, v in t do
		total += v
	end
	return total
end

-- Actors v2 (docs/design/actors-v2.md): 30 actors, 5/5/5/5/4/3/3 per tier, 90 Index slots.
local TIER_SIZES: { [string]: number } = { Newcomer = 5, Rising = 5, Pro = 5, Star = 5, Superstar = 4, Legend = 3, Icon = 3 }

test("every tier has its planned actors and the Index has 90 slots", function()
	for _, tier in Actors.Tiers do
		equal(#Actors.actorsInTier(tier.id), TIER_SIZES[tier.id], `actors in {tier.id}`)
	end
	equal(#Actors.List, 30, "actors")
	equal(Actors.IndexSlots, 90, "Index slots")
end)

test("the nine Actors v2 actors are there with their planned tier, genre and name", function()
	local planned = {
		{ "WerewolfPup", "Werewolf Pup", "Newcomer", "Horror" },
		{ "CardboardAstronaut", "Cardboard Astronaut", "Newcomer", "Sci-Fi" },
		{ "RodeoRookie", "Rodeo Rookie", "Rising", "Action" },
		{ "WobblyWitch", "Wobbly Witch", "Rising", "Horror" },
		{ "LagoonMermaid", "Lagoon Mermaid", "Pro", "Romance" },
		{ "TimeTourist", "Time Tourist", "Pro", "Sci-Fi" },
		{ "CaptainKapow", "Captain Kapow", "Star", "Action" },
		{ "InspectorWhoops", "Inspector Whoops", "Star", "Comedy" },
		{ "PirateCaptain", "Captain Squawk", "Superstar", "Comedy" },
	}
	for _, row in planned do
		local actor = Actors.getActor(row[1])
		expect(actor ~= nil, `{row[1]} missing`)
		local a = actor :: Actors.Actor
		equal(a.name, row[2], `{row[1]} name`)
		equal(a.tier, row[3], `{row[1]} tier`)
		equal(a.genre, row[4], `{row[1]} genre`)
	end
end)

test("the 21 original actor ids are untouched (saved data keys them)", function()
	local original = {
		"NervousIntern", "StuntDouble", "BackgroundExtra", "SoapRegular", "AdModel", "IndieSidekick",
		"ActionVeteran", "ComedyDuo", "NightShiftVillain", "TeenHeartthrob", "MethodActor", "SpaceCaptain",
		"BoxOfficeKing", "ScreamQueen", "RomComSweetheart", "GoldenAgeDiva", "SilentEraClown", "SciFiVisionary",
		"MogulsMuse", "LastActionHero", "PhantomAuteur",
	}
	for _, id in original do
		expect(Actors.getActor(id) ~= nil, `{id} was removed or renamed`)
	end
	-- Inside a tier the old actors keep their relative order (TopStudios breaks ties by position).
	local index = {}
	for i, actor in Actors.List do
		index[actor.id] = i
	end
	for i = 2, #original do
		local prev, cur = Actors.getActor(original[i - 1]) :: Actors.Actor, Actors.getActor(original[i]) :: Actors.Actor
		if prev.tier == cur.tier then
			expect(index[prev.id] < index[cur.id], `{cur.id} moved before {prev.id}`)
		end
	end
end)

test("per-actor odds: each tier's chance splits evenly, so tier totals are unchanged and sum to 1", function()
	for _, luck in { 1, 2, 10 } do
		for _, agency in Actors.Agencies do
			local chances = Actors.tierChances(luck, agency.minTier)
			local total = 0
			for _, tier in Actors.Tiers do
				local actors = Actors.actorsInTier(tier.id)
				local each = chances[tier.id] / #actors
				total += each * #actors
			end
			near(total, 1, 1e-9, `luck {luck} {agency.id}`)
		end
	end
	-- Plan: one actor at Open Casting, Luck 1.
	local open = Actors.tierChances(1, 1)
	near(1 / (open.Star / 5), 3500, 1, "a Star actor is 1 in 3,500")
	near(1 / (open.Superstar / 4), 32000, 1, "a Superstar actor is 1 in 32,000")
end)

test("actor ids are unique and every actor has a real tier and genre", function()
	local seen = {}
	local genres = { Action = true, Comedy = true, Horror = true, Romance = true, ["Sci-Fi"] = true }
	for _, actor in Actors.List do
		expect(not seen[actor.id], `duplicate actor id {actor.id}`)
		seen[actor.id] = true
		expect(Actors.getTier(actor.tier) ~= nil, `{actor.id} has unknown tier {actor.tier}`)
		expect(genres[actor.genre], `{actor.id} has unknown genre {actor.genre}`)
		equal(Actors.getActor(actor.id), actor, "lookup by id")
	end
end)

test("tiers get rarer and stronger in order", function()
	for i = 2, #Actors.Tiers do
		local prev, tier = Actors.Tiers[i - 1], Actors.Tiers[i]
		expect(tier.oneIn > prev.oneIn, `{tier.id} should be rarer than {prev.id}`)
		expect(tier.starPower > prev.starPower, `{tier.id} should have more Star Power than {prev.id}`)
	end
end)

test("tier chances sum to 1 for every luck and agency", function()
	for _, luck in { 0, 1, 1.5, 2, 10, 1000, 1e9 } do
		for _, agency in Actors.Agencies do
			local chances = Actors.tierChances(luck, agency.minTier)
			near(sum(chances), 1, 1e-9, `luck {luck}, {agency.id}`)
			for id, chance in chances do
				expect(chance >= 0 and chance <= 1, `{id} chance {chance} out of range`)
			end
		end
	end
end)

test("rare tiers hit their exact 1 in N at Luck 1, and Luck divides N", function()
	local icon = Actors.Tiers[#Actors.Tiers]
	local base = Actors.tierChances(1)
	near(base[icon.id], 1 / icon.oneIn, 1e-12, `{icon.id} at luck 1`)
	local doubled = Actors.tierChances(2)
	near(doubled[icon.id], 2 / icon.oneIn, 1e-12, `{icon.id} at luck 2`)
	expect(doubled.Superstar > base.Superstar, "luck should raise Superstar odds")
	expect(doubled.Newcomer < base.Newcomer, "luck should lower Newcomer odds")
end)

test("luck below 1 never makes odds worse than base", function()
	local base, low = Actors.tierChances(1), Actors.tierChances(0.2)
	for id, chance in base do
		near(low[id], chance, 1e-12, id)
	end
end)

test("agencies remove the bottom tiers and make rare tiers likelier", function()
	local open = Actors.tierChances(1, 1)
	for _, agency in Actors.Agencies do
		local chances = Actors.tierChances(1, agency.minTier)
		for index, tier in Actors.Tiers do
			if index < agency.minTier then
				equal(chances[tier.id], 0, `{agency.id} should remove {tier.id}`)
			else
				expect(chances[tier.id] >= open[tier.id], `{agency.id} lowered {tier.id}`)
			end
		end
	end
end)

test("agencies cost more and need more Fame as they get better", function()
	for i = 2, #Actors.Agencies do
		local prev, agency = Actors.Agencies[i - 1], Actors.Agencies[i]
		expect(agency.cost > prev.cost, `{agency.id} cost`)
		expect(agency.fame >= prev.fame, `{agency.id} fame`)
		expect(agency.minTier >= prev.minTier, `{agency.id} minTier`)
	end
	equal(Actors.Agencies[1].fame, 0, "first agency is free to unlock")
end)

test("variant chances sum to 1 and match the plan at Luck 1", function()
	for _, luck in { 1, 2, 50, 1e6 } do
		local chances = Actors.variantChances(luck)
		near(sum(chances), 1, 1e-9, `luck {luck}`)
		for id, chance in chances do
			expect(chance >= 0, `{id} negative at luck {luck}`)
		end
	end
	local base = Actors.variantChances(1)
	local award = 1 / Actors.getVariant("Award").oneIn
	near(base.Award, award, 1e-12, "Award-Winning")
	near(base.Shiny, (1 - award) / Actors.getVariant("Shiny").oneIn, 1e-12, "Shiny")
end)

test("rolls follow the odds and respect the agency floor", function()
	local random = H.Random.new(12345)
	local rolls = 200000
	local counts: { [string]: number } = {}
	for _ = 1, rolls do
		local actor, variant = Actors.roll(random, 1, 1)
		expect(actor ~= nil and variant ~= nil, "roll returned nil")
		counts[actor.tier] = (counts[actor.tier] or 0) + 1
	end
	local chances = Actors.tierChances(1, 1)
	for _, id in { "Newcomer", "Rising", "Pro" } do
		near((counts[id] or 0) / rolls, chances[id], 0.01, `{id} share`)
	end

	local floor = Actors.Agencies[#Actors.Agencies].minTier
	for _ = 1, 20000 do
		local actor = Actors.roll(random, 1, floor)
		local tierIndex = table.find(
			(function()
				local ids = {}
				for _, tier in Actors.Tiers do
					table.insert(ids, tier.id)
				end
				return ids
			end)(),
			actor.tier
		)
		expect(tierIndex ~= nil and tierIndex >= floor, `rolled {actor.tier} below the agency floor`)
	end
end)

test("Luck divides N at every agency, not only at Open Casting", function()
	for _, agency in Actors.Agencies do
		local base = Actors.tierChances(1, agency.minTier)
		local doubled = Actors.tierChances(2, agency.minTier)
		for index = agency.minTier + 2, #Actors.Tiers do
			local id = Actors.Tiers[index].id
			-- Rare tiers double (within a hair, from the tiers above taking their share first).
			near(doubled[id] / base[id], 2, 0.01, `{agency.id} {id} at Luck 2`)
		end
	end
end)

test("the hot start guarantees climb, end with a Star, and only ever raise a roll", function()
	expect(#Actors.HotStart > 0, "the hot start has steps")
	local lastCast, lastTier = 0, 0
	for _, step in Actors.HotStart do
		local tier = Actors.getTier(step.tier)
		expect(tier ~= nil, `hot start tier {step.tier} is not a tier`)
		local tierIndex = table.find(Actors.Tiers, tier) :: number
		expect(step.cast > lastCast, "hot start casts go up")
		expect(tierIndex > lastTier, "hot start tiers go up")
		lastCast, lastTier = step.cast, tierIndex
		equal(Actors.hotStartTier(step.cast), step.tier, `cast {step.cast}`)
	end
	equal(Actors.HotStart[#Actors.HotStart].tier, "Star", "the last guarantee is a Star")
	equal(Actors.HotStartLength, lastCast, "length is the last guaranteed cast")
	equal(Actors.hotStartTier(1), nil, "the first cast is a normal roll")
	equal(Actors.nextHotStart(0), Actors.HotStart[1], "next guarantee for a new player")
	equal(Actors.nextHotStart(Actors.HotStartLength), nil, "nothing after the last guarantee")

	local random = H.Random.new(777)
	local starIndex = table.find(Actors.Tiers, Actors.getTier("Star")) :: number
	local better = 0
	for _ = 1, 20000 do
		local actor = Actors.roll(random, 200, 1, "Star")
		local tierIndex = table.find(Actors.Tiers, Actors.getTier(actor.tier)) :: number
		expect(tierIndex >= starIndex, `guaranteed Star rolled {actor.tier}`)
		if tierIndex > starIndex then
			better += 1
		end
	end
	expect(better > 0, "a luckier roll keeps its better tier")
end)
