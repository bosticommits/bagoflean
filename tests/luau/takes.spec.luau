local H = require("./harness")
local Movies = H.require("Movies")
local PremiereNight = H.require("PremiereNight")
local Takes = H.require("Takes")
local test, expect, equal = H.test, H.expect, H.equal

test("take Luck is small and capped", function()
	equal(Takes.MaxLuck, Takes.PerFilm * Takes.Luck.Perfect)
	equal(Takes.luck(nil), 0)
	equal(Takes.luck({}), 0)
	equal(Takes.luck({ "Miss", "Miss", "Miss" }), 0)
	expect(math.abs(Takes.luck({ "Good", "Perfect" }) - 0.12) < 1e-9, "a good and a perfect take add 0.12")
	-- A doctored save cannot add more takes, unknown verdicts or more than the cap.
	equal(Takes.luck({ "Perfect", "Perfect", "Perfect", "Perfect", "Perfect" }), Takes.MaxLuck)
	equal(Takes.luck({ "Legendary", 5, true }), 0)
	equal(Takes.luck("Perfect"), 0)
	equal(Takes.count({ "Good", "Good", "Good", "Good" }), Takes.PerFilm)
	-- Perfect directing at Luck 1 lifts the average premiere by under 15% (ECONOMY.md stays true).
	local function average(luck: number): number
		local total = 0
		for id, chance in Movies.premiereChances(luck) do
			total += chance * (Movies.getResult(id) :: any).multiplier
		end
		return total
	end
	local lift = average(1 + Takes.MaxLuck) / average(1)
	expect(lift > 1 and lift < 1.15, `best-case lift {lift}`)
end)

test("takes open at each quarter of the shoot, and never after it wraps", function()
	equal(Takes.opened(0, 120, 0), 0)
	equal(Takes.opened(0, 120, 29), 0)
	equal(Takes.opened(0, 120, 30), 1)
	equal(Takes.opened(0, 120, 60), 2)
	equal(Takes.opened(0, 120, 119), 3)
	equal(Takes.opened(0, 120, 120), 0) -- wrapped: offline films get no takes
	equal(Takes.opened(0, 120, 5000), 0)
	equal(Takes.waiting({ "Good" }, 0, 120, 61), 1)
	equal(Takes.waiting({ "Good", "Miss" }, 0, 120, 61), 0)
	equal(Takes.waiting(nil, 0, 120, 100), 3)
end)

test("the marker sweeps and bounces, and the zones judge it", function()
	for index = 1, Takes.PerFilm do
		local sweep = Takes.SweepSeconds[index]
		equal(Takes.marker(0, index), 0)
		expect(math.abs(Takes.marker(sweep, index) - 1) < 1e-9, "reaches the right edge after one sweep")
		expect(math.abs(Takes.marker(sweep * 1.5, index) - 0.5) < 1e-9, "comes back to the middle")
		local target = Takes.target(1000, 1, index)
		expect(target >= 0.22 and target <= 0.78, "the zone sits fully inside the bar")
		equal(Takes.judge(target * sweep, target, index), "Perfect")
		equal(Takes.judge((target + Takes.GoodHalfWidth * 0.9) * sweep, target, index), "Good")
		equal(Takes.judge((target - Takes.GoodHalfWidth - 0.05) * sweep, target, index), "Miss")
	end
	expect(Takes.SweepSeconds[1] >= Takes.SweepSeconds[3], "later takes are no slower")
	-- Different takes of one film put the zone in different places.
	expect(Takes.target(1000, 1, 1) ~= Takes.target(1000, 1, 2), "the zone moves between takes")
	-- Nobody can sit still for a perfect take: the gold window is a small slice of each pass.
	expect(Takes.PerfectHalfWidth * 2 * Takes.SweepSeconds[1] < 0.15, "gold is under 0.15 s wide")
end)

test("the premiere card names the takes bonus", function()
	equal(PremiereNight.bonusLine(nil, nil, nil, 0), "")
	equal(PremiereNight.bonusLine(nil, nil, nil, 0.12), "takes +0.12 Luck")
	equal(PremiereNight.bonusLine(1.5, 2, nil, 0.04), "takes +0.04 Luck  -  Award Night x2  -  genre set x1.5")
	equal(Takes.verdictText("Perfect"), "PERFECT TAKE!")
	equal(Takes.verdictText("Miss"), "MISSED IT!")
end)
