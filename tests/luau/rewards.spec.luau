local H = require("./harness")
local Events = H.require("Events")
local Movies = H.require("Movies")
local Rewards = H.require("Rewards")
local Shop = H.require("Shop")
local Upgrades = H.require("Upgrades")
local test, expect, equal = H.test, H.expect, H.equal

local function validReward(reward: any, label: string)
	local hasSomething = false
	for _, field in { "cash", "cashMinutes", "luckMinutes", "skips" } do
		if reward[field] ~= nil then
			expect(reward[field] > 0, `{label} {field} must be positive`)
			hasSomething = true
		end
	end
	if reward.script ~= nil then
		expect(Movies.isGenre(reward.script.genre), `{label} script genre {reward.script.genre}`)
		expect(Movies.getLength(reward.script.length) ~= nil, `{label} script length {reward.script.length}`)
		expect(reward.script.count > 0, `{label} script count`)
		hasSomething = true
	end
	expect(hasSomething, `{label} gives nothing`)
end

test("every daily, request, gift and product reward is valid", function()
	for day, reward in Rewards.Daily do
		validReward(reward, `daily day {day}`)
	end
	for _, request in Rewards.Requests do
		validReward(request.reward, `request {request.id}`)
		expect(request.target > 0, `request {request.id} target`)
	end
	for _, quest in Rewards.Weekly do
		validReward(quest.reward, `weekly quest {quest.id}`)
		expect(quest.target > 0, `weekly quest {quest.id} target`)
	end
	validReward(Rewards.StayGift, "stay gift")
	for _, product in Shop.Products do
		validReward(product.reward, `product {product.key}`)
	end
end)

test("daily streak continues, holds, and resets", function()
	local can, streak = Rewards.dailyStatus({ day = 99, streak = 4 }, 100)
	expect(can, "claim the next day")
	equal(streak, 5, "streak continues")
	can, streak = Rewards.dailyStatus({ day = 100, streak = 5 }, 100)
	expect(not can, "no second claim the same day")
	equal(streak, 5, "streak holds")
	can, streak = Rewards.dailyStatus({ day = 97, streak = 9 }, 100)
	expect(can, "claim after a gap")
	equal(streak, 1, "missed day resets the streak")
	can, streak = Rewards.dailyStatus({ day = 0, streak = 0 }, 100)
	equal(streak, 1, "new player starts at day 1")
end)

test("the daily track repeats after the last day", function()
	local days = #Rewards.Daily
	equal(Rewards.dailyReward(1), Rewards.Daily[1], "day 1")
	equal(Rewards.dailyReward(days), Rewards.Daily[days], "last day")
	equal(Rewards.dailyReward(days + 1), Rewards.Daily[1], "wraps")
	for day in Rewards.Milestones do
		expect(Rewards.Daily[day] ~= nil, `milestone day {day} is on the track`)
	end
end)

test("each day picks distinct, real Studio Requests", function()
	local seen = {}
	for _, request in Rewards.Requests do
		expect(not seen[request.id], `duplicate request {request.id}`)
		seen[request.id] = true
	end
	expect(#Rewards.Requests >= Rewards.RequestsPerDay, "enough requests to pick from")
	for day = 20000, 20030 do
		local ids = Rewards.requestsFor(day)
		equal(#ids, Rewards.RequestsPerDay, `count on day {day}`)
		local picked = {}
		for _, id in ids do
			expect(Rewards.getRequest(id) ~= nil, `unknown request {id}`)
			expect(not picked[id], `request {id} picked twice on day {day}`)
			picked[id] = true
		end
	end
end)

test("weeks run Monday to Sunday UTC", function()
	local monday = 20731 -- 5 Oct 2026, 00:00 UTC (a Monday)
	equal((monday + 3) % 7, 0, "day 20731 is a Monday (day 4 of 1970 was)")
	equal(Rewards.week(monday * 86400), Rewards.week((monday + 6) * 86400 + 86399), "Monday to Sunday is one week")
	equal(Rewards.week((monday + 7) * 86400), Rewards.week(monday * 86400) + 1, "next Monday starts a new week")
	equal(Rewards.week(monday * 86400 - 1), Rewards.week(monday * 86400) - 1, "Sunday night is the old week")
	local week = Rewards.week(monday * 86400)
	equal(Rewards.weekStart(week), monday * 86400, "weekStart is Monday 00:00")
	equal(Rewards.weekStart(week + 1), (monday + 7) * 86400, "the week ends when the next starts")
	equal(Rewards.week(0), 0, "the epoch week")
end)

test("each week has one real weekly quest per slot, that every player can finish", function()
	local seen = {}
	for _, quest in Rewards.Weekly do
		expect(not seen[quest.id], `duplicate weekly quest {quest.id}`)
		expect(Rewards.getRequest(quest.id) == quest, `{quest.id} is found by getRequest`)
		seen[quest.id] = true
		local genre = string.match(quest.kind, "^premiere:(.+)$")
		if genre ~= nil then
			expect(Movies.isGenre(genre), `{quest.id} asks for unknown genre {genre}`)
			expect((Movies.GenreFame[genre] or 0) <= 100, `{quest.id}: {genre} needs too much Fame for a weekly quest`)
		else
			expect(table.find({ "cast", "premiere", "hit", "clap", "script", "collect" }, quest.kind) ~= nil, `{quest.id} counts unknown kind {quest.kind}`)
		end
	end
	for week = 2900, 2960 do
		local ids = Rewards.weeklyFor(week)
		equal(#ids, #Rewards.WeeklySlots, `one quest per slot in week {week}`)
		for slot, id in ids do
			local quest = Rewards.getRequest(id)
			expect(quest ~= nil and quest.slot == Rewards.WeeklySlots[slot], `week {week} slot {slot} holds {id}`)
		end
		equal(table.concat(ids, ","), table.concat(Rewards.weeklyFor(week), ","), `week {week} is the same on every call`)
	end
end)

test("weekly quests cycle through every quest, and every genre", function()
	local seen, genres = {}, {}
	for week = 2900, 2909 do
		for _, id in Rewards.weeklyFor(week) do
			seen[id] = true
			local genre = string.match((Rewards.getRequest(id) :: Rewards.Request).kind, "^premiere:(.+)$")
			if genre ~= nil then
				genres[genre] = true
			end
		end
	end
	for _, quest in Rewards.Weekly do
		expect(seen[quest.id], `{quest.id} never comes up`)
	end
	local count = 0
	for _ in genres do
		count += 1
	end
	equal(count, 4, "all four open genres come up")
	expect(Rewards.weeklyFor(2900)[2] ~= Rewards.weeklyFor(2901)[2], "the genre changes week to week")
end)

test("weekly Cash floors stay far below the first upgrade, so day-one quests cannot skip early progress", function()
	local stage = Upgrades.get("Stages")
	expect(stage ~= nil, "Sound Stage upgrade exists")
	local firstStage = (stage :: Upgrades.Upgrade).costs[1]
	for _, quest in Rewards.Weekly do
		local floor = quest.reward.cash or 0
		expect(floor * 2 <= firstStage, `{quest.id} Cash floor ${floor} is over half the first Sound Stage (${firstStage})`)
	end
end)

test("a finished quest survives its day or week ending and can be claimed once", function()
	local dailyId, weeklyId = Rewards.Requests[1].id, Rewards.Weekly[1].id
	local dailyTarget, weeklyTarget = Rewards.Requests[1].target, Rewards.Weekly[1].target
	local carried = {}
	-- Yesterday: one finished (waiting), one finished and claimed, one not finished.
	Rewards.carryOver(carried, "daily", 20731, {
		{ id = dailyId, progress = dailyTarget, claimed = false },
		{ id = Rewards.Requests[2].id, progress = Rewards.Requests[2].target, claimed = true },
		{ id = Rewards.Requests[3].id, progress = Rewards.Requests[3].target - 1, claimed = false },
	})
	equal(#carried, 1, "only the finished, unclaimed quest is kept")
	equal(carried[1].key, `daily:20731:{dailyId}`, "keyed by scope, day and quest")
	-- Last week's weekly quest joins it.
	Rewards.carryOver(carried, "weekly", 2961, { { id = weeklyId, progress = weeklyTarget + 5, claimed = false } })
	equal(#carried, 2, "weekly quests are kept too")
	-- Repeating a rollover for the same list adds nothing.
	Rewards.carryOver(carried, "daily", 20731, { { id = dailyId, progress = dailyTarget, claimed = false } })
	equal(#carried, 2, "the same quest is never kept twice")
	-- Claiming removes it, so it cannot be claimed again, and other keys stay.
	local taken = Rewards.takeCarried(carried, `daily:20731:{dailyId}`)
	expect(taken ~= nil and taken.id == dailyId, "claim finds the quest by key")
	equal(#carried, 1, "claimed quest is gone")
	expect(Rewards.takeCarried(carried, `daily:20731:{dailyId}`) == nil, "a second claim finds nothing")
	expect(Rewards.takeCarried(carried, 3) == nil, "a non-string key finds nothing")
	expect(Rewards.takeCarried(carried, "daily:1:nope") == nil, "an unknown key finds nothing")
	equal(carried[1].scope, "weekly", "the other quest is untouched")
end)

test("unknown quest ids are not carried, and a long absence cannot build an endless pile", function()
	local carried = {}
	Rewards.carryOver(carried, "daily", 1, { { id = "NoSuchQuest", progress = 99, claimed = false } })
	equal(#carried, 0, "unknown ids are dropped")
	local first = Rewards.Requests[1]
	for day = 1, Rewards.CarryLimit + 5 do
		Rewards.carryOver(carried, "daily", day, { { id = first.id, progress = first.target, claimed = false } })
	end
	equal(#carried, Rewards.CarryLimit, "capped")
	equal(carried[#carried].key, `daily:{Rewards.CarryLimit + 5}:{first.id}`, "the newest are kept")
	equal(carried[1].key, `daily:6:{first.id}`, "the oldest gave way")
end)

test("cash rewards use the floor or minutes of income, whichever is more", function()
	local reward = { cash = 100, cashMinutes = 10 }
	equal(Rewards.cashAmount(reward, 0), 100, "floor")
	equal(Rewards.cashAmount(reward, 1), 600, "10 minutes at $1/s")
	equal(Rewards.cashAmount({ luckMinutes = 5 }, 50), 0, "no cash")
	equal(Rewards.describe({ cash = 1234567 }, 0), "$1,234,567", "comma formatting")
end)

test("Award Night runs 3 minutes every 30 minutes", function()
	local active, left = Events.awardNight(0)
	expect(active, "starts on the half hour")
	equal(left, Events.AwardNightLength, "full length left")
	active, left = Events.awardNight(Events.AwardNightLength)
	expect(not active, "ends after its length")
	equal(left, Events.AwardNightPeriod - Events.AwardNightLength, "time to the next one")
	active = Events.awardNight(Events.AwardNightPeriod * 1000 + 10)
	expect(active, "repeats every period")
end)

test("shop keys are unique and set ids never collide", function()
	local keys, ids = {}, {}
	for _, list in { Shop.Passes, Shop.Products } do
		for _, item in list do
			expect(not keys[item.key], `duplicate shop key {item.key}`)
			keys[item.key] = true
			if item.id ~= 0 then
				expect(not ids[item.id], `duplicate shop id {item.id}`)
				ids[item.id] = true
			end
		end
	end
end)
