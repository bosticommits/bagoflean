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
end)
