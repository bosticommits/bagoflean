local H = require("./harness")
local Actors = H.require("Actors")
local test, expect, equal = H.test, H.expect, H.equal

local function sum(map: { [string]: number }): number
	local total = 0
	for _, value in map do
		total += value
	end
	return total
end

local function near(a: number, b: number, tolerance: number, message: string)
	expect(math.abs(a - b) <= tolerance, `{message}: {a} vs {b}`)
end

test("percent: at least 4 decimals below the first non-zero digit, 0 reads 0%", function()
	equal(Actors.percent(0), "0%", "zero")
	equal(Actors.percent(-1), "0%", "negative is zero")
	equal(Actors.percent(0.5), "50.000%", "half")
	equal(Actors.percent(1 / 40), "2.5000%", "1 in 40")
	equal(Actors.percent(1 / 5000000), "0.000020000%", "Icon at Open Casting")
	equal(Actors.percent(1), "100%", "certain")
	for _, chance in { 0.37, 0.0123, 1 / 8000, 1 / 220000, 3.3e-7 } do
		local text = Actors.percent(chance)
		local digits = string.gsub(string.gsub(text, "%%", ""), "%.", "")
		local significant = #string.gsub(digits, "^0+", "")
		expect(significant >= 5, `{text} keeps 4 places after the first non-zero digit`)
		near(tonumber(string.sub(text, 1, -2)) :: number, chance * 100, chance * 100 * 0.001, `{text} is the chance`)
	end
end)

test("oneIn: a rounded 1 in N with thousands separators", function()
	equal(Actors.oneIn(0), "never", "zero")
	equal(Actors.oneIn(1 / 5000000), "1 in 5,000,000", "Icon")
	equal(Actors.oneIn(1 / 40), "1 in 40", "small")
	equal(Actors.oneIn(1 / 1234), "1 in 1,234", "thousands")
end)

test("castOdds: the tiers always add up to 100%, with or without a floor and a limited actor", function()
	local limited = Actors.Limited[1]
	for _, agency in Actors.Agencies do
		for _, luck in { 1, 2.5, 40 } do
			for _, floor in { false, "Rising", "Pro", "Star", "Superstar" } do
				for _, withLimited in { false, true } do
					local odds = Actors.castOdds(luck, agency.minTier, if floor then floor else nil, if withLimited then limited else nil)
					near(sum(odds.tiers), 1, 1e-9, `{agency.id} luck {luck} floor {floor} limited {withLimited}`)
					for id, chance in odds.tiers do
						expect(chance >= 0, `{id} not negative`)
					end
					-- The actors of every tier (and the limited one) add up to their tier's row.
					local actors = odds.limited
					for _, tier in Actors.Tiers do
						actors += odds.actor[tier.id] * #Actors.actorsInTier(tier.id)
					end
					near(actors, 1, 1e-9, "every actor adds up too")
				end
			end
		end
	end
end)

test("castOdds: a floor merges the tiers below it; the limited actor comes out of the first tier", function()
	local plain = Actors.castOdds(1, 1, nil, nil)
	local floored = Actors.castOdds(1, 1, "Star", nil)
	equal(floored.tiers.Newcomer, 0, "no Newcomer under a Star floor")
	equal(floored.tiers.Pro, 0, "no Pro under a Star floor")
	near(floored.tiers.Star, plain.tiers.Newcomer + plain.tiers.Rising + plain.tiers.Pro + plain.tiers.Star, 1e-12, "Star takes the lower tiers")
	equal(floored.tiers.Legend, plain.tiers.Legend, "higher tiers keep theirs")

	local limited = Actors.Limited[1] -- a Star
	local with = Actors.castOdds(1, 1, nil, limited)
	near(with.limited, plain.tiers.Star / 3, 1e-12, "as likely as one everyday Star actor")
	near(with.tiers.Newcomer, plain.tiers.Newcomer - with.limited, 1e-12, "taken from the commonest tier")
	near(with.tiers.Star, plain.tiers.Star + with.limited, 1e-12, "counted in its own tier")
	near(with.actor.Star, plain.actor.Star, 1e-12, "everyday Star actors keep their chance")

	local over = Actors.castOdds(1, 1, "Superstar", limited)
	equal(over.limited, 0, "a floor above its tier leaves no room for it")
	local at = Actors.castOdds(1, 1, "Star", limited)
	expect(at.limited > 0, "a floor at its tier still allows it")
end)

test("castOdds matches what Actors.roll rolls", function()
	local random = H.Random.new(20261118)
	local limited = Actors.Limited[2]
	local cases = { { 1, 1, nil }, { 3, 2, "Rising" }, { 1, 1, "Star" }, { 12, 3, nil } }
	for _, case in cases do
		local luck, minTier, floor = case[1] :: number, case[2] :: number, case[3] :: string?
		local odds = Actors.castOdds(luck, minTier, floor, limited)
		local runs = 60000
		local tiers, limitedSeen = {}, 0
		for _ = 1, runs do
			local actor = Actors.roll(random, luck, minTier, floor, limited)
			tiers[actor.tier] = (tiers[actor.tier] or 0) + 1
			if actor.season ~= nil then
				limitedSeen += 1
			end
		end
		for _, tier in Actors.Tiers do
			if odds.tiers[tier.id] > 0.02 then
				near((tiers[tier.id] or 0) / runs, odds.tiers[tier.id], 0.01, `luck {luck} floor {floor} {tier.id}`)
			elseif odds.tiers[tier.id] == 0 then
				equal(tiers[tier.id] or 0, 0, `{tier.id} cannot happen`)
			end
		end
		near(limitedSeen / runs, odds.limited, 0.01, "the limited actor's share")
	end
end)

test("pullChance is the chance of one exact pull, variants included", function()
	local total = 0
	local limited = Actors.Limited[1]
	for _, actor in Actors.List do
		for _, variant in Actors.Variants do
			total += Actors.pullChance(2, 2, "Rising", limited, actor.id, variant.id)
		end
	end
	for _, variant in Actors.Variants do
		total += Actors.pullChance(2, 2, "Rising", limited, limited.id, variant.id)
	end
	near(total, 1, 1e-9, "every pull adds up to 1")
	local normal = Actors.pullChance(1, 1, nil, nil, "MogulsMuse", "Normal")
	local shiny = Actors.pullChance(1, 1, nil, nil, "MogulsMuse", "Shiny")
	expect(shiny < normal and shiny > 0, "Shiny is rarer")
	near(Actors.pullChance(1, 1, nil, nil, "MogulsMuse", "Normal") + Actors.pullChance(1, 1, nil, nil, "MogulsMuse", "Shiny") + Actors.pullChance(1, 1, nil, nil, "MogulsMuse", "Award"), 1 / 5000000 / 3, 1e-12, "an Icon is 1 in 15,000,000 per actor, any variant")
	equal(Actors.pullChance(1, 3, nil, nil, "NervousIntern", "Normal"), 0, "an agency without that tier never casts it")
	local guaranteed = Actors.pullChance(1, 1, "Superstar", nil, "BoxOfficeKing", "Normal")
	expect(guaranteed > 0.2, "a guaranteed Superstar cast is a third of the Superstar-or-better chance, not 1 in 8,000")
end)
