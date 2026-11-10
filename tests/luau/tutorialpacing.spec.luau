local H = require("./harness")
local Pacing = H.require("TutorialPacing")
local test, expect = H.test, H.expect

-- The 8 voiced lines that were cut short: clip length, characters at 60 chars/s.
local clips = { intro1 = 4.53, resultCult = 3.55, resultFlop = 3.50, resultMasterpiece = 3.49, scriptBuy = 3.29, shoot = 3.18, joy = 3.08, studio = 2.85 }

test("a voiced line stays until its clip has ended plus the gap", function()
	for name, clip in clips do
		local typing = 60 / 60 -- a 60-character line
		local total = typing + Pacing.hold(60, clip, typing)
		expect(total >= clip + 0.6 - 1e-6, `{name} is cut short`)
		expect(total <= clip + 0.8 + 1e-6 or total == typing + Pacing.MIN_HOLD, `{name} lingers`)
	end
end)

test("a short clip still holds the minimum reading time", function()
	expect(Pacing.hold(10, 1, 0.2) == 2.2, "min")
end)

test("no clip length falls back to the old formula", function()
	expect(Pacing.hold(100, nil, 1.6) == 4, "capped at 4")
	expect(Pacing.hold(20, 0, 0.3) == 2.2, "floored at 2.2")
	expect(math.abs(Pacing.hold(60, nil, 1) - 2.7) < 1e-9, "chars * 0.045")
end)

test("a tap waits for the clip", function()
	expect(not Pacing.canAdvance(10, 12), "still talking")
	expect(Pacing.canAdvance(12, 12), "clip ended")
end)
