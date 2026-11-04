local H = require("./harness")
local Movies = H.require("Movies")
local PremiereNight = H.require("PremiereNight")
local IconModels = H.require("Models/IconModels")
local test, expect, equal = H.test, H.expect, H.equal

test("every premiere result has a premiere night style with a real icon", function()
	for _, result in Movies.Results do
		local style = PremiereNight.Styles[result.id]
		expect(style ~= nil, `{result.id} has a style`)
		expect(table.find(IconModels.Ids, style.icon) ~= nil, `{result.id} icon {style.icon} exists`)
		expect(style.flashes >= 0 and style.flashes <= 30, `{result.id} flash count stays light for phones`)
	end
	equal(PremiereNight.style("NoSuchResult"), PremiereNight.Styles.Hit)
end)

test("rarer results get at least as big a moment", function()
	local last = -1
	for _, result in Movies.Results do
		local flashes = PremiereNight.Styles[result.id].flashes
		expect(flashes >= last, `{result.id} has no fewer flashes than the result before it`)
		last = flashes
	end
	equal(PremiereNight.Styles.Flop.beams, "down")
	expect(PremiereNight.Styles.Masterpiece.rainbow, "Masterpiece gets the rainbow stamp")
end)

test("poster and result text", function()
	equal(PremiereNight.stampText("Cult"), "CULT CLASSIC!")
	equal(PremiereNight.stampText("Hit"), "HIT!")
	equal(PremiereNight.lengthLine("Short"), "SHORT FILM  -  NOW SHOWING")
	equal(PremiereNight.billing({}), "")
	equal(PremiereNight.billing({ "Ad Model", "Indie Sidekick" }), "STARRING  Ad Model, Indie Sidekick")
	equal(PremiereNight.bonusLine(nil, nil, nil), "")
	equal(PremiereNight.bonusLine(1, nil, 1), "")
	equal(PremiereNight.bonusLine(1.5, 2, nil), "Award Night x2  -  genre set x1.5")
	expect(PremiereNight.DRUMROLL_SECONDS <= 3, "the build-up stays under 3 seconds (ART_STYLE.md)")

test("bonus line lists every stacked bonus in order and ignores bad numbers", function()
	equal(PremiereNight.bonusLine(1.5, 2, 3), "Award Night x2  -  genre set x1.5  -  rebirth x3")
	equal(PremiereNight.bonusLine(0 / 0, nil, nil), "", "NaN bonus is not shown")
	equal(PremiereNight.bonusLine(0, 0, 0), "", "zero bonuses are not shown")
	equal(PremiereNight.billing({ "Solo" }), "STARRING  Solo")
end)

test("unknown ids fall back safely", function()
	equal(PremiereNight.stampText("Mystery"), "MYSTERY!")
	equal(PremiereNight.lengthLine("Mini"), "MINI  -  NOW SHOWING")
end)

end)

test("the theatre show builds up longer for rarer results, inside the time budget", function()
	local lastReveal, lastCard = -1, -1
	for _, result in Movies.Results do
		local show = PremiereNight.Shows[result.id]
		expect(show ~= nil, `{result.id} has a show`)
		local reveal, card = PremiereNight.beats(result.id)
		expect(reveal >= lastReveal and card >= lastCard, `{result.id} builds up at least as long`)
		lastReveal, lastCard = reveal, card
		expect(#show.critic >= 1, `{result.id} has a critic line`)
		expect(show.stars[1] >= 1 and show.stars[2] <= 5 and show.stars[1] <= show.stars[2], `{result.id} stars`)
	end
	-- Drumroll to Continue (the longest glide, the card, then ~1.2 s of count-up): 4-6 s for a Hit,
	-- a Masterpiece may run longer.
	local _, hitCard = PremiereNight.beats("Hit")
	expect(1.1 + hitCard + 1.2 <= 6, "a Hit reaches Continue within 6 s")
	equal(PremiereNight.Shows.Hit.hush, 0)
	expect(PremiereNight.Shows.Masterpiece.hush > PremiereNight.Shows.Blockbuster.hush, "the hush grows")
end)

test("the critic's stars stay in each result's range", function()
	for _, result in Movies.Results do
		local show = PremiereNight.show(result.id)
		for _, roll in { 0, 0.3, 0.5, 0.99 } do
			local stars, line = PremiereNight.review(result.id, roll)
			expect(stars >= show.stars[1] and stars <= show.stars[2], `{result.id} stars at {roll}`)
			expect(table.find(show.critic, line) ~= nil, `{result.id} line at {roll}`)
		end
	end
	equal(PremiereNight.review("Flop", 0), 1)
	equal(PremiereNight.review("Flop", 0.99), 2)
end)

test("far players get a cut, near ones a glide", function()
	equal(PremiereNight.glideSeconds(10), 0.6)
	equal(PremiereNight.glideSeconds(1000), nil)
	local mid = PremiereNight.glideSeconds(200)
	expect(mid ~= nil and mid > 0.6 and mid <= 1.1, "mid glide")
end)

test("PREMIERE ALL: masterpieces get their own show, otherwise the biggest result; the rest go worst to best", function()
	local function film(result: string, payout: number, extra: any?)
		local r = { result = result, payout = payout, fame = if type(payout) == "number" then payout // 10 else 0, title = result .. payout }
		for k, v in extra or {} do
			r[k] = v
		end
		return r
	end
	local a, b, c, d = film("Hit", 1200), film("Flop", 300), film("Blockbuster", 900), film("Hit", 800)
	local full, rest = PremiereNight.plan({ a, b, c, d })
	equal(#full, 1)
	equal(full[1], c, "the rarest result gets the show, not the richest")
	equal(rest[1], b)
	equal(rest[2], d)
	equal(rest[3], a)
	local m1, m2 = film("Masterpiece", 20000), film("Masterpiece", 5000)
	full, rest = PremiereNight.plan({ a, m1, b, m2 })
	equal(#full, 2, "every masterpiece gets a show")
	equal(full[1], m1)
	equal(rest[1], b)
	equal(#rest, 2)
	full, rest = PremiereNight.plan({ film("Hit", 500), film("Hit", 900) })
	equal(full[1].payout, 900, "the richer of equals")
	equal(rest[1].payout, 500)
	local payout, fame, awards = PremiereNight.total({ a, film("Hit", 100, { awardNight = true }), film("Hit", "x") })
	equal(payout, 1300)
	equal(fame, 130)
	equal(awards, 1)
end)
