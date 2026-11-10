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

local sparse = { hud[1], hud[5] } -- coins and the CAST bar

local function input(over: { [string]: any }?): any
	local i = {
		areaW = area.w,
		areaH = area.h,
		hud = sparse,
		panels = {},
		target = nil,
		bust = bust,
		text = "Tap the green Cast button to meet your first actor",
		maxWidth = 260,
		margin = 8,
		previous = nil,
	}
	for k, v in over or {} do
		i[k] = v
	end
	return i
end

test("place: picks a clean spot clear of the HUD", function()
	local p = Placer.place(input())
	expect(p.clean, "clean")
	expect(p.width == 260 and p.textSize == 16, "full size first")
end)

test("place: a blocked spot falls to a narrower tier or the next spot", function()
	local first = Placer.place(input())
	-- a panel-free obstacle sitting on the first pick's card
	local blocker = { x = first.cardRight - first.width, y = first.cardY + 70, w = first.width, h = 30 }
	local hudPlus = table.clone(sparse)
	table.insert(hudPlus, blocker)
	local p = Placer.place(input({ hud = hudPlus }))
	expect(p.clean, "still clean")
	expect(p.cardY ~= first.cardY or p.cardRight ~= first.cardRight or p.width ~= first.width, "moved")
end)

test("place: hysteresis keeps a clean previous pick", function()
	local prev = Placer.place(input())
	-- a small toast elsewhere that does not touch it must not move the bubble
	local hudPlus = table.clone(sparse)
	table.insert(hudPlus, { x = 20, y = 250, w = 40, h = 20 })
	local p = Placer.place(input({ hud = hudPlus, previous = prev }))
	expect(p == prev, "same pick returned")
end)

test("place: previous pick is dropped once it overlaps", function()
	local prev = Placer.place(input())
	local hudPlus = table.clone(sparse)
	table.insert(hudPlus, { x = prev.cardRight - prev.width, y = prev.cardY + 70, w = prev.width, h = 30 })
	local p = Placer.place(input({ hud = hudPlus, previous = prev }))
	expect(p ~= prev, "new pick")
	expect(p.clean, "clean")
end)

test("place: an unclean previous pick is not kept when a clean one exists", function()
	local stale = { bustRight = 300, bustY = 300, cardRight = 300, cardY = 300, width = 260, textSize = 16, clean = false }
	expect(Placer.place(input({ previous = stale })).clean, "clean")
end)

test("place: the target is never covered when something else fits", function()
	local first = Placer.place(input())
	local t = { x = first.cardRight - first.width + 10, y = first.cardY + 5, w = 40, h = 30 }
	local p = Placer.place(input({ target = t }))
	local x0, y0 = p.cardRight - p.width, p.cardY
	local hit = Placer.overlapArea({ x = x0, y = y0, w = p.width, h = 60 }, t, 0) > 0
	expect(not hit, "target clear")
end)

test("place: a panel rect is avoided like the HUD", function()
	local first = Placer.place(input())
	local panel = { x = first.cardRight - first.width, y = first.cardY, w = first.width, h = 90 }
	local p = Placer.place(input({ panels = { panel } }))
	expect(Placer.overlapArea({ x = p.cardRight - p.width, y = p.cardY, w = p.width, h = 60 }, panel, 0) == 0, "panel clear")
end)

test("spots: five candidates, all on screen horizontally", function()
	local s = Placer.spots(area.w, area.h, hud, 8, bust, 260, 16, 95)
	expect(#s == 5, "five")
	for _, p in s do
		expect(p.cardRight - p.width >= 0 and p.cardRight <= area.w, "inside")
	end
end)
