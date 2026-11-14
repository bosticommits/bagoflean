local H = require("./harness")
local PL = H.require("PickerLayout")
local test, expect, equal = H.test, H.expect, H.equal

-- The three viewports from the spec (main-gui area after the safe insets, and the HUD's MenuRight).
local devices = {
	{ name = "PC 1336x653", w = 1336, h = 595, menu = 210, compact = false },
	{ name = "iPhone 7 667x375", w = 667, h = 320, menu = 110, compact = true },
	{ name = "iPhone 14 844x390", w = 750, h = 311, menu = 115, compact = true },
}

for _, d in devices do
	test(`{d.name}: the panel clears every edge and the HUD by the gutter`, function()
		local r = PL.panelRect(d.w, d.h, d.menu, d.compact, nil, PL.MAX_W, PL.MAX_H)
		local g = PL.gutter(d.compact)
		expect(r.x - PL.STROKE >= 0 and r.y - PL.STROKE >= 0, "outline on screen")
		expect(r.x - PL.iconLeft(d.compact) >= d.menu + g - 1, "clapper clears the HUD column")
		expect(r.y - PL.iconTop(d.compact) >= g - 1, "clapper clears the top")
		expect(d.w - (r.x + r.w) - PL.STROKE >= g - 1, "right gutter")
		expect(d.h - (r.y + r.h) - PL.STROKE >= g - 1, "bottom gutter")
		expect(r.w <= PL.MAX_W and r.h <= PL.MAX_H, "max size")
	end)
end

test("spec rects: PC 760x542 centred, iPhone 7 518x277 at x 132", function()
	local pc = PL.panelRect(1336, 595, 210, false, nil, PL.MAX_W, PL.MAX_H)
	equal(pc.w, 760) equal(pc.h, 542) equal(pc.x, 288) equal(pc.y, 32)
	local ph = PL.panelRect(667, 320, 110, true, nil, PL.MAX_W, PL.MAX_H)
	equal(ph.w, 518) equal(ph.h, 277) equal(ph.x, 132) equal(ph.y, 26)
end)

test("a tutorial bubble reserve moves the top down but never up", function()
	local free = PL.panelRect(1336, 595, 210, false, nil, PL.MAX_W, PL.MAX_H)
	local held = PL.panelRect(1336, 595, 210, false, 133, PL.MAX_W, PL.MAX_H)
	expect(held.y - PL.iconTop(false) >= 133, "clapper below the bubble")
	expect(held.h < free.h, "shorter")
	local small = PL.panelRect(1336, 595, 210, false, 5, PL.MAX_W, PL.MAX_H)
	equal(small.y, free.y)
end)

for _, d in devices do
	test(`{d.name}: footer slots, text and buttons never overlap and fit the panel`, function()
		local r = PL.panelRect(d.w, d.h, d.menu, d.compact, nil, PL.MAX_W, PL.MAX_H)
		local f = PL.footer(r.w, d.compact, 3)
		equal(#f.slotCentres, 3)
		local pad = PL.padding(d.compact)
		local last = f.slotCentres[3]
		expect(last.x + f.slotSize / 2 <= f.text.x, "slots end before the text")
		if not f.twoRow then
			expect(f.text.x + f.text.w <= f.clear.x, "text ends before Clear")
			expect(f.text.w >= (if d.compact then 110 else 150), "text block wide enough")
			expect(f.clear.x + f.clear.w <= f.go.x, "Clear before Start")
		else
			expect(f.clear.x + f.clear.w <= f.go.x, "two-row: Clear before Start")
			expect(f.clear.y >= f.slotCentres[1].y + f.slotSize / 2, "two-row: buttons under the slots")
		end
		expect(f.go.x + f.go.w <= r.w - pad + 0.5, "Start inside the right padding")
		expect(f.go.y >= 0 and f.go.y + f.go.h <= f.height, "Start inside the footer")
		expect(f.clear.y >= 0 and f.clear.y + f.clear.h <= f.height, "Clear inside the footer")
		expect(f.text.y >= 0 and f.text.y + f.text.h <= f.height, "text inside the footer")
	end)
end

test("spec footer numbers: PC slot centres 40/104/168, iPhone 7 text x150 and Start x382", function()
	local pc = PL.footer(760, false, 3)
	equal(pc.height, 84)
	equal(pc.slotCentres[1].x, 40) equal(pc.slotCentres[2].x, 104) equal(pc.slotCentres[3].x, 168)
	equal(pc.slotCentres[1].y, 42)
	equal(pc.text.x, 212) equal(pc.text.w, 172) equal(pc.clear.x, 398) equal(pc.go.x, 538)
	local ph = PL.footer(518, true, 3)
	equal(ph.height, 60)
	equal(ph.text.x, 150) equal(ph.clear.x, 290) equal(ph.go.x, 382) equal(ph.go.w, 128)
	local ph14 = PL.footer(596, true, 3)
	equal(ph14.go.x, 460) equal(ph14.clear.x, 368) equal(ph14.text.w, 208)
end)

test("a narrow panel falls back to a taller two-row footer", function()
	local f = PL.footer(420, true, 3)
	expect(f.twoRow, "two rows")
	equal(f.height, 96)
	local pc = PL.footer(520, false, 3)
	expect(pc.twoRow, "PC two rows")
	equal(pc.height, 132)
	expect(pc.go.w > pc.clear.w, "Start is the wider button")
end)

for _, d in devices do
	test(`{d.name}: the two panes fit inside the body and the footer`, function()
		local r = PL.panelRect(d.w, d.h, d.menu, d.compact, nil, PL.MAX_W, PL.MAX_H)
		local f = PL.footer(r.w, d.compact, 3)
		local b = PL.body(r.w, r.h, d.compact, f.height)
		local pad = PL.padding(d.compact)
		expect(b.scripts.x == pad, "scripts at the left padding")
		expect(b.scripts.x + b.scripts.w < b.cast.x, "gap between panes")
		expect(b.cast.x + b.cast.w <= r.w - pad, "cast pane inside the right padding")
		expect(b.scripts.y >= PL.titleHeight(d.compact), "below the title bar")
		expect(b.scripts.y + b.scripts.h <= r.h - f.height, "above the footer")
		expect(b.scripts.w >= 140 and b.scripts.w <= 220, "scripts width clamp")
		equal(b.headingH, if d.compact then 0 else 24)
	end)
end

test("spec panes: PC 220 | 504, iPhone 7 151 | 343", function()
	local b = PL.body(760, 542, false, 84)
	equal(b.scripts.w, 220) equal(b.cast.w, 504) equal(b.scripts.y, 96) equal(b.scripts.h, 350)
	local p = PL.body(518, 277, true, 60)
	equal(p.scripts.w, 151) equal(p.cast.w, 343) equal(p.scripts.y, 48) equal(p.scripts.h, 161)
end)

test("grid: 3 columns on every spec viewport, no wasted column, cards stay inside the window", function()
	for _, case in { { 498, false, 3 }, { 337, true, 3 }, { 392, true, 3 } } do
		local windowW, compact, cols = case[1], case[2], case[3]
		local g = PL.grid(windowW, compact)
		equal(g.cols, cols)
		local used = g.cols * g.cellW + (g.cols - 1) * g.gap
		expect(used <= windowW - 6, "cards fit")
		expect(windowW - 6 - used < g.cellW + g.gap, "right slack under one card")
	end
end)

test("grid: at least two columns even in a very narrow pane, and wide panes add columns", function()
	equal(PL.grid(120, true).cols, 2)
	expect(PL.grid(900, false).cols > 3, "wide pane, more columns")
end)

test("grid cell height follows the width", function()
	local g = PL.grid(498, false)
	equal(g.cellH, math.floor(g.cellW * 0.62 + 0.5) + 52)
end)
