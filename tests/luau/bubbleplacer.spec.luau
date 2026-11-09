local H = require("./harness")
local Placer = H.require("BubblePlacer")
local test, expect = H.test, H.expect

-- Phone: 654x388 inside the safe area. The real HUD parts the recheck reported.
local area = { x = 0, y = 0, w = 654, h = 388 }
local hud = {
	{ x = 314, y = 4, w = 160, h = 37 }, -- coins, Fame and the + button
	{ x = 500, y = 8, w = 146, h = 90 }, -- box office / claim tracker
	{ x = 504, y = 149, w = 140, h = 34 }, -- Events
	{ x = 10, y = 8, w = 90, h = 230 }, -- left button dock
	{ x = 157, y = 300, w = 279, h = 72 }, -- CAST bar
}
local target = { x = 520, y = 30, w = 60, h = 40 }
local bust, w = 76, 260

local function spots(h)
	return {
		{ { x = 570, y = 110, w = bust, h = bust }, { x = 310, y = 110, w = w, h = h } }, -- on the HUD
		{ { x = 570, y = 200, w = bust, h = bust }, { x = 300, y = 195, w = w, h = h } }, -- clear
	}
end

test("overlap counts the margin", function()
	local a = { x = 0, y = 0, w = 10, h = 10 }
	expect(Placer.overlapArea(a, { x = 12, y = 0, w = 5, h = 10 }, 0) == 0, "apart")
	expect(Placer.overlapArea(a, { x = 12, y = 0, w = 5, h = 10 }, 8) > 0, "inside the margin")
end)

test("the first spot with no overlap wins, HUD spots are skipped", function()
	local obstacles = table.clone(hud)
	table.insert(obstacles, target)
	expect(Placer.firstFree(spots(95), obstacles, area, 8) == 2, "second spot")
end)

test("a spot outside the screen never fits", function()
	expect(Placer.firstFree({ { { x = 600, y = 300, w = 76, h = 76 } } }, {}, area, 8) == nil, "off the right edge")
end)

test("no clean spot: least overlap that leaves the target alone", function()
	local blocked = {
		{ { x = 300, y = 0, w = 300, h = 100 } }, -- touches the target
		{ { x = 20, y = 100, w = 250, h = 100 } }, -- overlaps the dock a lot
		{ { x = 160, y = 250, w = 100, h = 100 } }, -- overlaps the CAST bar a little
	}
	expect(Placer.firstFree(blocked, hud, area, 8) == nil, "none fits")
	expect(Placer.leastOverlap(blocked, hud, target, area, 8) == 3, "third")
end)

test("card height grows with the text and shrinks with a wider card", function()
	local line = "Tap the green Cast button to meet your first actor"
	expect(Placer.cardHeight(line, 220, 15) > Placer.cardHeight(line, 260, 16) - 60, "sane")
	expect(Placer.cardHeight(line, 200, 16) > Placer.cardHeight(line, 400, 16), "narrower is taller")
	expect(Placer.cardHeight("", 260, 16) > 0, "empty text")
end)
