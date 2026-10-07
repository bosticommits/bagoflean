local H = require("./harness")
local Events = H.require("Events")
local Movies = H.require("Movies")
local Rewards = H.require("Rewards")
local Shop = H.require("Shop")
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
