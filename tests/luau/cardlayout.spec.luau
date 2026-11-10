local H = require("./harness")
local CardLayout = H.require("CardLayout")
local test, expect = H.test, H.expect

-- Overlay heights: the iPhone 14 landscape viewport (331) and a tall desktop window (653).
for _, viewH in { 331, 653 } do
	test(`{viewH} px: buttons stay 44 px and the stats keep 20 px clear of the halo`, function()
		local cardH = math.min(CardLayout.cardScale(viewH) * viewH, 600)
		local l = CardLayout.compute(cardH)
		local buttonTop = (l.buttonBottom - l.buttonH) * cardH
		local statsBottom = (l.statsY + l.statsH) * cardH
		expect(l.buttonH * cardH >= 44, "tap height")
		expect(buttonTop - CardLayout.HALO - statsBottom >= 20 - 1e-6, "clear of the halo")
		expect(l.artY < l.nameY and l.nameY + l.nameH <= l.ribbonY + 1e-6, "art, name, ribbon in order")
		expect(l.ribbonY + l.ribbonH <= l.statsY, "ribbon above the stats")
		expect(l.artH * cardH >= 50, "the actor keeps room")
	end)
end

test("the measured phone card (238 px) clears the buttons", function()
	local l = CardLayout.compute(238)
	expect((l.buttonBottom - l.buttonH - l.statsY - l.statsH) * 238 >= 28 - 1e-6, "was 1-3 px")
end)
