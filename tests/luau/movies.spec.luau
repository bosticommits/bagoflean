local H = require("./harness")
local Actors = H.require("Actors")
local Movies = H.require("Movies")
local test, expect, equal, near = H.test, H.expect, H.equal, H.near

local function sum(t: { [string]: number }): number
	local total = 0
	for _, v in t do
		total += v
	end
	return total
end

test("premiere chances match the plan at Luck 1", function()
	local chances = Movies.premiereChances(1)
	for _, result in Movies.Results do
		near(chances[result.id], result.chance, 1e-12, result.id)
	end
	near(sum(chances), 1, 1e-9, "sum")
end)

test("premiere chances sum to 1 and stay valid at any luck", function()
	for _, luck in { 0, 1, 1.25, 2, 5, 20, 1000 } do
		local chances = Movies.premiereChances(luck)
		near(sum(chances), 1, 1e-9, `luck {luck}`)
		for id, chance in chances do
			expect(chance >= 0 and chance <= 1, `{id} = {chance} at luck {luck}`)
		end
	end
end)

-- Past Luck 4 Flop and Hit are used up and the best results level off, so compare with a little
-- slack for floating point.
test("more luck never lowers the chance of the best results", function()
	local previous = Movies.premiereChances(1)
	for _, luck in { 1.5, 2, 3, 5, 10 } do
		local chances = Movies.premiereChances(luck)
		expect(chances.Masterpiece >= previous.Masterpiece - 1e-12, `Masterpiece at luck {luck}`)
		expect(chances.Flop <= previous.Flop + 1e-12, `Flop at luck {luck}`)
		previous = chances
	end
end)

test("results are ordered worst to best", function()
	for i = 2, #Movies.Results do
		expect(Movies.Results[i].multiplier > Movies.Results[i - 1].multiplier, Movies.Results[i].id)
	end
end)

test("rolled premieres follow the odds", function()
	local random = H.Random.new(777)
	local rolls = 200000
	local counts: { [string]: number } = {}
	for _ = 1, rolls do
		local result = Movies.rollResult(random, 1)
		counts[result.id] = (counts[result.id] or 0) + 1
	end
	for _, result in Movies.Results do
		near((counts[result.id] or 0) / rolls, result.chance, 0.01, result.id)
	end
end)

test("longer scripts take longer, cost more, earn more and never unlock earlier", function()
	for i = 2, #Movies.Lengths do
		local prev, length = Movies.Lengths[i - 1], Movies.Lengths[i]
		expect(length.seconds > prev.seconds, `{length.id} seconds`)
		expect(length.cost > prev.cost, `{length.id} cost`)
		expect(length.base > prev.base, `{length.id} base`)
		expect(length.fame >= prev.fame, `{length.id} fame`)
	end
	equal(Movies.Lengths[1].fame, 0, "the first script is available from the start")
end)

test("every genre has a Fame gate, titles, and starting genres exist", function()
	local free = 0
	for _, genre in Movies.Genres do
		expect(Movies.GenreFame[genre] ~= nil, `{genre} has no Fame gate`)
		expect(Movies.isGenre(genre), genre)
		local title = Movies.randomTitle(H.Random.new(1), genre)
		expect(type(title) == "string" and #title > 0, `{genre} has no titles`)
		if Movies.GenreFame[genre] == 0 then
			free += 1
		end
	end
	expect(free > 0, "at least one genre must be open at Fame 0")
	expect(not Movies.isGenre("Western"), "unknown genre accepted")
end)

test("specialty genre gives the Star Power bonus", function()
	local actor = Actors.List[1]
	local tier = Actors.getTier(actor.tier)
	local key = Actors.key(actor.id, "Normal")
	near(Movies.actorPower(key, actor.genre), tier.starPower * Movies.SpecialtyBonus, 1e-9, "specialty")
	local other = if actor.genre == "Action" then "Comedy" else "Action"
	near(Movies.actorPower(key, other), tier.starPower, 1e-9, "off-genre")
	local award = Actors.getVariant("Award")
	near(Movies.actorPower(Actors.key(actor.id, award.id), other), tier.starPower * award.multiplier, 1e-9, "Award-Winning")
end)

test("bad cast keys are worth nothing", function()
	equal(Movies.actorPower("Nobody:Normal", "Action"), 0, "unknown actor")
	equal(Movies.actorPower(Actors.List[1].id .. ":Gold", "Action"), 0, "unknown variant")
	equal(Movies.actorPower("", "Action"), 0, "empty key")
	equal(Movies.castPower({}, "Action"), 0, "empty cast")
end)

test("payout follows the plan formula and is never below 1", function()
	local short = Movies.getLength("Short")
	local hit = Movies.getResult("Hit")
	local flop = Movies.getResult("Flop")
	equal(Movies.payout(short, 10, hit), math.max(1, math.floor(short.base * 10 * hit.multiplier)), "base x power x result")
	equal(Movies.payout(short, 10, hit, 1.15), math.max(1, math.floor(short.base * 10 * 1.15 * hit.multiplier)), "genre bonus")
	equal(Movies.payout(short, 0, flop), 1, "minimum payout")
	expect(Movies.fame(1) >= 1, "minimum Fame")
	expect(Movies.fame(10000) > Movies.fame(100), "Fame grows with payout")
end)
