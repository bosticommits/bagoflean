local H = require("./harness")
local TP = H.require("TutorialPill")
local test, expect, equal = H.test, H.expect, H.equal

-- panel width, bar height, close size, close margin, header text width + x, compact
local cases = {
	{ name = "PC picker", panelW = 760, bar = 54, close = 40, margin = 10, headerRight = 16 + 120, compact = false },
	{ name = "phone 518 picker", panelW = 518, bar = 40, close = 32, margin = 10, headerRight = 16 + 80, compact = true },
	{ name = "phone 596 picker", panelW = 596, bar = 40, close = 32, margin = 10, headerRight = 16 + 80, compact = true },
}

for _, c in cases do
	test(`{c.name}: pill parts fit the slot and Skip stays 12 px from the X`, function()
		local s = TP.slot(c.headerRight, c.bar, c.close, c.margin)
		local slotW = c.panelW - s.x - s.rightInset
		expect(TP.fits(slotW), "slot wide enough")
		local p = TP.pill(slotW, s.h, c.compact)
		expect(p.pillW > 100, "pill has room")
		equal(p.skipX + p.skipW, slotW)
		-- close X left edge = panelW - margin - close; Skip right edge (panel-local) = s.x + slotW
		local closeLeft = c.panelW - c.margin - c.close
		expect(closeLeft - (s.x + p.skipX + p.skipW) >= 12, "12 px from the X")
		expect(s.x >= c.headerRight + 12, "12 px from the title")
		expect(p.bustX + p.bust <= p.pillX and p.pillX + p.pillW <= p.skipX, "no overlap")
		expect(p.bust <= s.h and p.skipH <= s.h, "fits the bar height")
	end)
end

test("a narrow slot falls back to the corner bubble", function()
	expect(not TP.fits(219), "219 too narrow")
	expect(TP.fits(220), "220 ok")
end)
