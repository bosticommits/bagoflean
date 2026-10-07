--!strict
-- Daily login rewards and daily Studio Requests (plan section 5). Shared so the rewards screen shows
-- exactly what the server grants. Days are UTC days (os.time() // 86400) on both sides.
local Shop = require(script.Parent.Shop)

local Rewards = {}

export type Reward = Shop.Reward

-- A 7-day streak track that repeats. Missing a day starts again at day 1.
Rewards.Daily = {
	{ cash = 150, cashMinutes = 5 },
	{ cash = 300, cashMinutes = 10 },
	{ script = { genre = "Action", length = "Indie", count = 1 } },
	{ cash = 600, cashMinutes = 20 },
	{ luckMinutes = 10 },
	{ cash = 1000, cashMinutes = 30 },
	{ skips = 1, cash = 2000, cashMinutes = 60 },
} :: { Reward }

-- "Don't leave yet!" gift: offered when the player opens the Roblox menu (often to leave), once
-- per UTC day, after StayGiftMinSeconds of play in that session.
Rewards.StayGift = { luckMinutes = 10, cash = 300, cashMinutes = 10 } :: Reward

export type Request = {
	id: string, -- stable; saved in player data
	kind: string, -- the action that counts (see QuestTracker.track callers)
	target: number,
	text: string,
	reward: Reward,
}

-- Three of these are picked each day (the same three for everyone).
Rewards.Requests = {
	{ id = "Cast10", kind = "cast", target = 10, text = "Hold 10 Casting Calls", reward = { cash = 200, cashMinutes = 10 } },
	{ id = "Premiere2", kind = "premiere", target = 2, text = "Premiere 2 movies", reward = { cash = 300, cashMinutes = 15 } },
	{ id = "Clap30", kind = "clap", target = 30, text = "Tap the clapperboard 30 times", reward = { cash = 150, cashMinutes = 5 } },
	{ id = "Scripts3", kind = "script", target = 3, text = "Buy 3 scripts", reward = { cash = 200, cashMinutes = 10 } },
	{ id = "Collect5", kind = "collect", target = 5, text = "Collect the box office 5 times", reward = { cash = 150, cashMinutes = 5 } },
	{ id = "Hit1", kind = "hit", target = 1, text = "Get a Blockbuster or better", reward = { luckMinutes = 5 } },
} :: { Request }
Rewards.RequestsPerDay = 3

local requestById: { [string]: Request } = {}
for _, request in Rewards.Requests do
	requestById[request.id] = request
end

function Rewards.getRequest(id: string): Request?
	return requestById[id]
end

function Rewards.today(now: number): number
	return now // 86400
end

-- The day's request ids: a fixed shuffle seeded by the day, so it is the same on every server.
function Rewards.requestsFor(day: number): { string }
	local random = Random.new(day)
	local ids: { string } = {}
	for _, request in Rewards.Requests do
		table.insert(ids, request.id)
	end
	for i = #ids, 2, -1 do
		local j = random:NextInteger(1, i)
		ids[i], ids[j] = ids[j], ids[i]
	end
	return { table.unpack(ids, 1, Rewards.RequestsPerDay) }
end

-- Saved daily state: the day last claimed and the streak reached on it.
export type DailyState = { day: number, streak: number }

-- (can claim today, streak that today's claim would reach)
function Rewards.dailyStatus(daily: DailyState, today: number): (boolean, number)
	if daily.day >= today then
		return false, daily.streak
	end
	if daily.day == today - 1 then
		return true, daily.streak + 1
	end
	return true, 1
end

function Rewards.dailyReward(streak: number): Reward
	return Rewards.Daily[(streak - 1) % #Rewards.Daily + 1]
end

-- Cash a reward gives right now: its floor, or minutes of the player's income if that is more,
-- so cash rewards stay worth having late in the game.
function Rewards.cashAmount(reward: Reward, ratePerSecond: number): number
	local amount = reward.cash or 0
	if reward.cashMinutes ~= nil then
		amount = math.max(amount, ratePerSecond * reward.cashMinutes * 60)
	end
	return math.floor(amount)
end

local function comma(n: number): string
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

-- Short text for the UI and for "you got" messages.
function Rewards.describe(reward: Reward, ratePerSecond: number): string
	local parts: { string } = {}
	local cash = Rewards.cashAmount(reward, ratePerSecond)
	if cash > 0 then
		table.insert(parts, "$" .. comma(cash))
	end
	if reward.script ~= nil then
		local s = reward.script
		table.insert(parts, `{s.count} {s.genre} {s.length} script{if s.count == 1 then "" else "s"}`)
	end
	if reward.luckMinutes ~= nil then
		table.insert(parts, `x2 Luck {reward.luckMinutes} min`)
	end
	if reward.skips ~= nil then
		table.insert(parts, `{reward.skips} Skip Filming`)
	end
	return table.concat(parts, " + ")
end

return Rewards
