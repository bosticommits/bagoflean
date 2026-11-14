local H = require("./harness")
local R = H.require("RectOverlap")
local test, expect = H.test, H.expect

local panel = { x = 100, y = 50, w = 400, h = 300 }

test("a rect inside, or crossing an edge, overlaps", function()
	expect(R.overlaps({ x = 150, y = 100, w = 20, h = 20 }, panel), "inside")
	expect(R.overlaps({ x = 80, y = 100, w = 40, h = 20 }, panel), "crossing the left edge")
end)

test("a rect beside or only touching does not overlap", function()
	expect(not R.overlaps({ x = 10, y = 100, w = 40, h = 40 }, panel), "beside")
	expect(not R.overlaps({ x = 60, y = 100, w = 40, h = 40 }, panel), "touching the edge")
end)

test("inflate grows every side, so a near miss becomes an overlap", function()
	local near = { x = 60, y = 100, w = 30, h = 30 }
	expect(not R.overlaps(near, panel), "near miss")
	expect(R.overlaps(R.inflate(near, 20), panel), "inflated")
end)

test("overlapsAny checks the whole list and an empty list never overlaps", function()
	local far = { x = 900, y = 900, w = 10, h = 10 }
	expect(R.overlapsAny({ x = 120, y = 60, w = 5, h = 5 }, { far, panel }), "second rect")
	expect(not R.overlapsAny({ x = 120, y = 60, w = 5, h = 5 }, {}), "empty")
end)
