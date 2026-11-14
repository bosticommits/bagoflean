local H = require("./harness")
local Achievements = H.require("Achievements")
local ShowMe = H.require("ShowMe")
local test, expect, equal = H.test, H.expect, H.equal

local SCREENS = { Upgrades = true, Studio = true }

test("every start goal has a Show me target", function()
	for _, a in Achievements.List do
		if a.group == "start" then
			local t = ShowMe.TARGETS[a.id]
			expect(t ~= nil, `{a.id} has no target`)
			expect(t.ui ~= nil or t.world ~= nil, `{a.id} points at nothing`)
			expect(t.screen == nil or SCREENS[t.screen], `{a.id} opens an unknown screen`)
			expect((t.screen == nil) == (t.focus == nil), `{a.id} screen and focus go together`)
		end
	end
end)

test("metres round studs x 0.28 and never read 0", function()
	equal(ShowMe.metres(100), 28)
	equal(ShowMe.metres(86), 24)
	equal(ShowMe.metres(1), 1)
end)
