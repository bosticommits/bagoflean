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

test("every tier has 3 actors and the Index has 63 slots", function()
	for _, tier in Actors.Tiers do
		equal(#Actors.actorsInTier(tier.id), 3, `actors in {tier.id}`)
	end
	equal(Actors.IndexSlots, 63, "Index slots")
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
