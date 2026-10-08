--!strict
-- Daily login rewards and daily Studio Requests (plan section 5). Shared so the rewards screen shows
-- exactly what the server grants. Days are UTC days (os.time() // 86400) on both sides.
local Shop = require(script.Parent.Shop)

local Rewards = {}

export type Reward = Shop.Reward

-- A 21-day streak track that repeats, with big milestone days (7, 14, 21). Missing a day starts
-- again at day 1.
Rewards.Daily = {
	{ cash = 150, cashMinutes = 5 },
	{ cash = 300, cashMinutes = 10 },
	{ script = { genre = "Action", length = "Indie", count = 1 } },
	{ cash = 600, cashMinutes = 20 },
	{ luckMinutes = 10 },
	{ cash = 1000, cashMinutes = 30 },
	{ skips = 1, cash = 2000, cashMinutes = 60 }, -- 7
	{ cash = 800, cashMinutes = 25 },
	{ luckMinutes = 15 },
	{ script = { genre = "Comedy", length = "Indie", count = 2 } },
	{ cash = 1500, cashMinutes = 40 },
	{ skips = 1 },
	{ cash = 2000, cashMinutes = 45 },
	{ luckMinutes = 30, skips = 2, cash = 5000, cashMinutes = 120 }, -- 14
	{ cash = 1500, cashMinutes = 40 },
	{ luckMinutes = 15 },
	{ script = { genre = "Action", length = "Feature", count = 1 } },
	{ cash = 2500, cashMinutes = 60 },
	{ skips = 1 },
	{ cash = 3000, cashMinutes = 60 },
	{ luckMinutes = 60, skips = 3, cash = 10000, cashMinutes = 240 }, -- 21
} :: { Reward }

-- Milestone days: shown big, as "play N days in a row to unlock this rare reward".
Rewards.Milestones = { [7] = true, [14] = true, [21] = true } :: { [number]: boolean }

-- "Don't leave yet!" gift: offered when the player opens the Roblox menu (often to leave), once
-- per UTC day, after StayGiftMinSeconds of play in that session.
Rewards.StayGift = { luckMinutes = 10, cash = 300, cashMinutes = 10 } :: Reward

export type Request = {
	id: string, -- stable; saved in player data
	kind: string, -- the action that counts (see QuestTracker.track callers)
	target: number,
	text: string,
	reward: Reward,
	slot: string?, -- weekly quests only: which of the week's three slots it can fill
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

-- Weekly quests: one from each slot, shared by every player for the whole week (Monday to Sunday,
-- UTC). Bigger than a daily request and meant to be spread over the week. Rewards are small like
-- the rest (a short Luck boost, a Skip, 30 to 60 minutes of income). Cash floors stay low ($100 to
-- $300, far under the $600 second sound stage): a new player can finish a quest on day one, so the
-- reward has to scale with income (cashMinutes) rather than be a big fixed sum. See ECONOMY.md
-- before raising them. The "genre" slot asks for premieres of one genre and cycles through all of them, so
-- a player who sticks to one genre is nudged to try the others. Sci-Fi is left out: it opens at
-- 2,000 Fame, and a weekly quest must be possible for every player. Kinds are the ones
-- QuestTracker.track gets; "premiere:<genre>" is counted on top of "premiere". The economy sim
-- reads this list, so keep each quest on one line.
Rewards.WeeklySlots = table.freeze({ "volume", "genre", "skill" })
Rewards.Weekly = {
	{ id = "WPremiere12", slot = "volume", kind = "premiere", target = 12, text = "Premiere 12 movies", reward = { cash = 250, cashMinutes = 45 } },
	{ id = "WCast60", slot = "volume", kind = "cast", target = 60, text = "Hold 60 Casting Calls", reward = { cash = 200, cashMinutes = 40 } },
	{ id = "WCollect25", slot = "volume", kind = "collect", target = 25, text = "Collect the box office 25 times", reward = { cash = 150, cashMinutes = 30 } },
	{ id = "WAction3", slot = "genre", kind = "premiere:Action", target = 3, text = "Premiere 3 Action movies", reward = { luckMinutes = 20, skips = 1 } },
	{ id = "WComedy3", slot = "genre", kind = "premiere:Comedy", target = 3, text = "Premiere 3 Comedy movies", reward = { luckMinutes = 20, skips = 1 } },
	{ id = "WHorror3", slot = "genre", kind = "premiere:Horror", target = 3, text = "Premiere 3 Horror movies", reward = { luckMinutes = 20, skips = 1 } },
	{ id = "WRomance3", slot = "genre", kind = "premiere:Romance", target = 3, text = "Premiere 3 Romance movies", reward = { luckMinutes = 20, skips = 1 } },
	{ id = "WHit3", slot = "skill", kind = "hit", target = 3, text = "Get 3 Blockbusters or better", reward = { skips = 2, cash = 300, cashMinutes = 60 } },
	{ id = "WClap300", slot = "skill", kind = "clap", target = 300, text = "Tap the clapperboard 300 times", reward = { luckMinutes = 15, cash = 150, cashMinutes = 30 } },
	{ id = "WScripts8", slot = "skill", kind = "script", target = 8, text = "Buy 8 scripts", reward = { script = { genre = "Comedy", length = "Indie", count = 2 }, cash = 100, cashMinutes = 20 } },
} :: { Request }

local requestById: { [string]: Request } = {}
for _, request in Rewards.Requests do
	requestById[request.id] = request
end
for _, quest in Rewards.Weekly do
	requestById[quest.id] = quest
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

-- Weeks run Monday to Sunday (UTC). Day 0 (1 Jan 1970) was a Thursday, so Monday is day 4.
function Rewards.week(now: number): number
	return (now // 86400 + 3) // 7
end

-- Unix time a week starts at (the Monday 00:00 UTC), so `weekStart(week + 1)` is when it ends.
function Rewards.weekStart(week: number): number
	return (week * 7 - 3) * 86400
end

-- The week's quest ids, one per slot in WeeklySlots order. Each slot steps through its quests one
-- per week, so every quest comes round (and every genre, in the genre slot) and the same on every
-- server.
function Rewards.weeklyFor(week: number): { string }
	local ids: { string } = {}
	for _, slot in Rewards.WeeklySlots do
		local pool: { Request } = {}
		for _, quest in Rewards.Weekly do
			if quest.slot == slot then
				table.insert(pool, quest)
			end
		end
		table.insert(ids, pool[week % #pool + 1].id)
	end
	return ids
end

-- A finished quest whose day or week ended before it was claimed. It waits in `carried` (saved)
-- until claimed, once: `key` names that one quest instance ("daily:<day>:<id>" or
-- "weekly:<week>:<id>"), so a claim names it exactly and can never hit another quest.
export type Carried = { key: string, id: string, scope: string }
export type Progress = { id: string, progress: number, claimed: boolean }

-- Most finished quests kept waiting. A player away for weeks does not build an endless pile: the
-- oldest give way. Three daily and three weekly quests a period fit well inside it.
Rewards.CarryLimit = 12

-- When a day or week rolls over, moves the old list's finished-but-unclaimed quests into `carried`
-- (in place) and returns it. `scope` is "daily" or "weekly" and `period` the day or week the old
-- list belonged to. Safe to repeat for the same list: a key is never added twice.
function Rewards.carryOver(carried: { Carried }, scope: string, period: number, old: { Progress }): { Carried }
	for _, entry in old do
		local request = requestById[entry.id]
		if request ~= nil and not entry.claimed and entry.progress >= request.target then
			local key = `{scope}:{period}:{entry.id}`
			local known = false
			for _, waiting in carried do
				if waiting.key == key then
					known = true
					break
				end
			end
			if not known then
				table.insert(carried, { key = key, id = entry.id, scope = scope })
			end
		end
	end
	while #carried > Rewards.CarryLimit do
		table.remove(carried, 1)
	end
	return carried
end

-- Removes and returns the carried quest with this key, or nil if it is not waiting (already claimed).
function Rewards.takeCarried(carried: { Carried }, key: any): Carried?
	if type(key) ~= "string" then
		return nil
	end
	for index, waiting in carried do
		if waiting.key == key then
			table.remove(carried, index)
			return waiting
		end
	end
	return nil
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
