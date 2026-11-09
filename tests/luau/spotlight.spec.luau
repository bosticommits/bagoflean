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

test("bands tile with no gap or overlap for fractional targets", function()
	for _, c in { { 748, 380, 295.48, 100.2, 73.6, 80.88 }, { 654, 330, 12.7, 3.3, 200.1, 50.9 }, { 800, 400, 0.4, 0.6, 5.5, 5.5 } } do
		local r = Spotlight.rects(c[1], c[2], c[3], c[4], c[5], c[6], 8)
		local covered = 0
		for _, b in r do
			expect(b.x == math.floor(b.x) and b.y == math.floor(b.y) and b.w == math.floor(b.w) and b.h == math.floor(b.h), "fractional band")
			covered += b.w * b.h
		end
		expect(r[1].y + r[1].h == r[3].y and r[3].y == r[4].y, "top band meets the side bands")
		expect(r[3].y + r[3].h == r[2].y and r[4].y + r[4].h == r[2].y, "side bands meet the bottom band")
		expect(r[4].x + r[4].w == c[1] and r[2].y + r[2].h == c[2], "right and bottom reach the screen edge")
		local hole = (r[4].x - r[3].w) * r[3].h
		expect(covered + hole == c[1] * c[2], `{covered} + {hole} ~= area`)
	end
end)
