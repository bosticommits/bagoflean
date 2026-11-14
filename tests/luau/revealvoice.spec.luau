local H = require("./harness")
local RevealVoice = H.require("RevealVoice")
local Reveal = H.require("Reveal")
local test, expect, equal = H.test, H.expect, H.equal

local function has(slots: { string }, name: string): boolean
	return table.find(slots, name) ~= nil
end

test("Pro and below get no Lucien line", function()
	local state = RevealVoice.new()
	for rank = 1, 3 do
		equal(#RevealVoice.pick(state, rank, true, 1000, 0), 0, `rank {rank} silent`)
	end
end)

test("the first Star+ of the session speaks, then the 180 s rest applies", function()
	local state = RevealVoice.new()
	expect(has(RevealVoice.pick(state, 4, false, 10, 0.99), "lucienRarePull"), "first Star+")
	expect(not has(RevealVoice.pick(state, 5, true, 100, 0), "lucienRarePull"), "inside the cooldown, even NEW")
	expect(not has(RevealVoice.pick(state, 4, false, 200, 0.99), "lucienRarePull"), "after rest, not new, bad roll")
	expect(has(RevealVoice.pick(state, 4, true, 200, 0.99), "lucienRarePull"), "after rest and NEW")
	expect(has(RevealVoice.pick(state, 5, false, 400, 0.1), "lucienRarePull"), "after rest and 25% roll")
	expect(not has(RevealVoice.pick(state, 5, false, 600, 0.25), "lucienRarePull"), "roll 0.25 is not below 25%")
end)

test("a rest-less first Star+ at the very start still counts as the session's first", function()
	local state = RevealVoice.new()
	RevealVoice.pick(state, 4, false, 5, 0.99)
	state.lastLine = -math.huge
	expect(not has(RevealVoice.pick(state, 4, false, 1000, 0.99), "lucienRarePull"), "no longer the first")
end)

test("Icon always speaks and restarts the cooldown; Legend only has the announcer", function()
	local state = RevealVoice.new()
	RevealVoice.pick(state, 4, true, 0, 0)
	local icon = RevealVoice.pick(state, 7, false, 1, 0.99)
	expect(has(icon, "lucienLegendPull") and has(icon, "voiceIcon"), "icon lines")
	local legend = RevealVoice.pick(state, 6, true, 2, 0)
	equal(#legend, 1, "legend announcer only")
	equal(legend[1], "voiceLegend", "legend slot")
	expect(not has(RevealVoice.pick(state, 5, true, 100, 0), "lucienRarePull"), "icon restarted the rest")
end)

test("the announcer calls Star and up only", function()
	local state = RevealVoice.new()
	equal(RevealVoice.pick(state, 3, true, 0, 0)[1], nil, "no Pro call")
	equal(RevealVoice.pick(state, 5, false, 0, 1)[1], "voiceSuperstar", "Superstar call")
end)

test("card or toast", function()
	local done, early = { tutorialDone = true }, { tutorialDone = false }
	expect(not Reveal.useCard(3, { variantId = "Normal" }, done), "Pro is a toast")
	expect(not Reveal.useCard(1, { variantId = "Shiny" }, done), "Shiny is a toast")
	expect(Reveal.useCard(4, { variantId = "Normal" }, done), "Star is a card")
	expect(Reveal.useCard(2, { variantId = "Award" }, done), "Award is a card")
	expect(Reveal.useCard(2, { variantId = "Normal", guarantee = "hotStart" }, done), "guarantee is a card")
	expect(Reveal.useCard(1, { variantId = "Normal" }, early), "tutorial cast is a card")
end)

test("input guard after the flip grows with rank and spares small cards", function()
	equal(Reveal.guardSeconds(1), 0, "Newcomer card")
	equal(Reveal.guardSeconds(3), 0, "Pro card")
	equal(Reveal.guardSeconds(4), 0.6, "Star")
	equal(Reveal.guardSeconds(6), 1.2, "Legend")
	equal(Reveal.guardSeconds(7), 1.2, "Icon")
	for rank = 4, 6 do
		expect(Reveal.guardSeconds(rank) < Reveal.guardSeconds(rank + 1) or rank == 6, "never shrinks")
	end
end)
