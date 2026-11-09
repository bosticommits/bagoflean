local H = require("./harness")
local Spotlight = H.require("Spotlight")
local test, expect = H.test, H.expect

test("the four bands leave exactly the padded hole uncovered", function()
	local r = Spotlight.rects(800, 400, 100, 50, 60, 40, 8)
	local covered = 0
	for _, band in r do
		covered += band.w * band.h
	end
	expect(covered == 800 * 400 - 76 * 56, `covered {covered}`)
end)

test("a target past the edge never gives a negative band", function()
	for _, band in Spotlight.rects(800, 400, 780, -30, 100, 60, 8) do
		expect(band.w >= 0 and band.h >= 0, "negative size")
	end
end)
