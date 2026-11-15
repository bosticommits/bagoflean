local H = require("./harness")
local TP = H.require("TutorialPill")
local test, expect, equal = H.test, H.expect, H.equal

-- Title widths are pessimistic (phone ~14 px a char, PC ~20) and are the SHORT titles used while the
-- tutorial runs: "Stage N", "Studio", "Collection". Panel widths are the picker's real ones.
local devices = {
	{ name = "PC", panelW = 760, bar = 54, close = 40, margin = 10, perChar = 20, compact = false },
	{ name = "phone 518", panelW = 518, bar = 40, close = 32, margin = 10, perChar = 14, compact = true },
	{ name = "phone 596", panelW = 596, bar = 40, close = 32, margin = 10, perChar = 14, compact = true },
}
local titles = { "Stage 2", "Studio", "Collection", "Shop" }

for _, d in devices do
	for _, title in titles do
		test(`{d.name} / "{title}": pill parts fit and Skip stays 12 px from the X`, function()
			local s = TP.slot(16 + #title * d.perChar, d.bar, d.close, d.margin)
			local slotW = d.panelW - s.x - s.rightInset
			expect(TP.fits(slotW, d.compact), `slot {slotW} wide enough`)
			local p = TP.pill(slotW, s.h, d.compact)
			expect(p.pillW >= 150, "pill has room")
			equal(p.skipX + p.skipW, slotW)
			local closeLeft = d.panelW - d.margin - d.close
			expect(closeLeft - (s.x + p.skipX + p.skipW) >= 12, "12 px from the X")
			expect(s.x >= 16 + #title * d.perChar + 12, "12 px from the title")
			expect(p.bustX + p.bust <= p.pillX and p.pillX + p.pillW <= p.skipX, "no overlap")
			expect(p.bust <= s.h and p.skipH <= s.h and p.pillH < s.h, "fits inside the bar, off its edges")
		end)
	end
end

test("the long live titles never fit, so they cannot flap into pill mode as Fame grows", function()
	-- "Studio  -  Fame 12,345" (22 chars) and "Collection  -  Index 12/345" (27 chars)
	for _, d in devices do
		for _, chars in { 22, 27 } do
			local s = TP.slot(16 + chars * d.perChar, d.bar, d.close, d.margin)
			expect(not TP.fits(d.panelW - s.x - s.rightInset, d.compact), `{d.name} {chars} chars keeps the corner bubble`)
		end
	end
end)

test("thresholds: 280 on a phone, 330 on PC", function()
	expect(not TP.fits(279, true) and TP.fits(280, true), "phone")
	expect(not TP.fits(329, false) and TP.fits(330, false), "pc")
end)

test("phone Skip draws 32 px tall but its tap target is 44 px; PC keeps 30", function()
	local p = TP.pill(300, 32, true)
	equal(p.skipH, 32)
	equal(p.hitH, 44)
	expect(p.skipW >= 44, "wide enough")
	equal(TP.pill(300, 32, false).hitH, 30)
end)
