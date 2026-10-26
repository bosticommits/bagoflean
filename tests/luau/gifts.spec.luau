local H = require("./harness")
local PlaytimeGifts = H.require("PlaytimeGifts")
local Rewards = H.require("Rewards")
local test, expect, equal = H.test, H.expect, H.equal

local DAY = 20000 * 86400 -- some UTC day, at midnight

test("the ladder opens at 2, 5, 10, 15, 25, 40 and 60 minutes, and grows", function()
	local minutes = {}
	for _, gift in PlaytimeGifts.Ladder do
		table.insert(minutes, gift.minutes)
	end
	equal(table.concat(minutes, ","), "2,5,10,15,25,40,60", "unlock times")
	-- Early Cash stays tiny (ECONOMY.md: the first minutes are sensitive) and floors only grow.
	local last = 0
	for k, gift in PlaytimeGifts.Ladder do
		local floor = Rewards.cashAmount(gift.reward, 0)
		expect(floor >= last or floor == 0, `gift {k} floor does not shrink`)
		last = math.max(last, floor)
		expect(gift.minutes > 15 or floor <= 100, `gift {k} (first 15 minutes) gives at most $100`)
		expect(Rewards.describe(gift.reward, 1) ~= "", `gift {k} gives something`)
	end
	expect((PlaytimeGifts.Ladder[7].reward.luckMinutes or 0) >= 10, "the last gift is a real Lucky Casting boost")
end)

test("a gift opens only once its time is played, once, and only for a real index", function()
	local state = PlaytimeGifts.fresh(nil)
	expect(PlaytimeGifts.begin(state, DAY + 100), "a first join starts a ladder")
	PlaytimeGifts.tick(state, DAY + 100 + 119)
	expect(not PlaytimeGifts.check(state, 1), "not at 1:59")
	PlaytimeGifts.tick(state, DAY + 100 + 120)
	expect(PlaytimeGifts.check(state, 1), "gift 1 at 2:00")
	expect(not PlaytimeGifts.check(state, 2), "gift 2 not yet")
	PlaytimeGifts.claim(state, 1)
	local ok, why = PlaytimeGifts.check(state, 1)
	expect(not ok and why == "Already opened", "gift 1 opens once")
	for _, bad in { 0, 8, 1.5, "1", nil, math.huge, -1 } do
		expect(not PlaytimeGifts.check(state, bad), `rejects {tostring(bad)}`)
	end
	PlaytimeGifts.tick(state, DAY + 100 + 3600)
	for k = 2, 7 do
		expect(PlaytimeGifts.check(state, k), `gift {k} ready at 60 min`)
		PlaytimeGifts.claim(state, k)
	end
	expect(PlaytimeGifts.allClaimed(state), "all seven opened")
end)

test("a quick rejoin carries on the ladder and time away never counts", function()
	local state = PlaytimeGifts.fresh(nil)
	PlaytimeGifts.begin(state, DAY + 1000)
	PlaytimeGifts.tick(state, DAY + 1000 + 180) -- played 3 min, then left
	PlaytimeGifts.claim(state, 1)
	expect(not PlaytimeGifts.begin(state, DAY + 1180 + 10 * 60), "back after 10 min: same ladder")
	equal(state.played, 180, "the 10 minutes away did not count")
	expect(PlaytimeGifts.isClaimed(state, 1), "gift 1 stays opened")
	PlaytimeGifts.tick(state, DAY + 1180 + 10 * 60 + 120)
	expect(PlaytimeGifts.check(state, 2), "gift 2 after 5 min played in total")
	-- Away 30 minutes: a new ladder.
	expect(PlaytimeGifts.begin(state, state.seen + 30 * 60), "back after 30 min: new ladder")
	equal(state.played, 0, "starts from zero")
	expect(not PlaytimeGifts.isClaimed(state, 1), "and with every present closed")
end)

test("at most three new ladders a day, then a rejoin carries on the last one", function()
	local state = PlaytimeGifts.fresh(nil)
	local now = DAY + 60
	for n = 1, PlaytimeGifts.LaddersPerDay do
		expect(PlaytimeGifts.begin(state, now), `ladder {n} today`)
		now += 3600
		PlaytimeGifts.tick(state, now) -- an hour played
		for k = 1, 7 do
			PlaytimeGifts.claim(state, k)
		end
		now += 3600 -- then an hour away
	end
	expect(not PlaytimeGifts.begin(state, now), "no fourth ladder today")
	expect(PlaytimeGifts.allClaimed(state), "the last ladder carries on, all opened")
	expect(PlaytimeGifts.begin(state, DAY + 86400 + 60), "a new day brings a new ladder")
	equal(state.ladders, 1, "counted for the new day")
end)

test("broken or old saves load as a clean state", function()
	local state = PlaytimeGifts.fresh({ played = -5, seen = "x", claimed = 9999, day = 0 / 0, ladders = 2.7 })
	equal(state.played, 0, "negative played")
	equal(state.seen, 0, "text seen")
	expect(state.claimed >= 0 and state.claimed < 128, "claimed stays in the 7 bits")
	equal(state.day, 0, "NaN day")
	equal(state.ladders, 2, "whole ladders")
	expect(PlaytimeGifts.begin(PlaytimeGifts.fresh("nonsense"), DAY), "an old profile gets a ladder on its first join")
end)
