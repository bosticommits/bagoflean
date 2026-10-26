--!strict
-- Playtime gift ladder: presents that open after 2, 5, 10 ... 60 minutes of play in a session.
-- Shared so the server (RewardService) and the row of presents (PlaytimeGiftsUi) use the same rules,
-- and so the rules tests can check them.
--
-- Anti-farming, kept kid-simple:
-- - Only time in the game counts (`played`), never time away.
-- - A new ladder only starts after AwayMinutes away. A quick rejoin or server hop carries on the
--   same ladder (it is saved in the profile), so rejoining every 2 minutes gets nothing new.
-- - At most LaddersPerDay new ladders a UTC day. After that, a rejoin carries on the last one.
-- Rewards are small early and grow; the last one is a free Lucky Casting boost. The economy sim
-- reads this list, so keep each gift on one line.
local Shop = require(script.Parent.Shop)

local PlaytimeGifts = {}

PlaytimeGifts.AwayMinutes = 30
PlaytimeGifts.LaddersPerDay = 3

export type Gift = { minutes: number, reward: Shop.Reward }

PlaytimeGifts.Ladder = {
	{ minutes = 2, reward = { cash = 25, cashMinutes = 1 } },
	{ minutes = 5, reward = { cash = 50, cashMinutes = 2 } },
	{ minutes = 10, reward = { skips = 1 } },
	{ minutes = 15, reward = { cash = 100, cashMinutes = 5 } },
	{ minutes = 25, reward = { luckMinutes = 5 } },
	{ minutes = 40, reward = { script = { genre = "Comedy", length = "Indie", count = 2 }, cash = 200, cashMinutes = 10 } },
	{ minutes = 60, reward = { luckMinutes = 15, skips = 1, cash = 300, cashMinutes = 15 } },
} :: { Gift }

-- Saved in the profile (`gifts`). Times are os.time() seconds.
export type State = {
	played: number, -- seconds played in this ladder
	seen: number, -- last time the player was known to be in the game (0 = never)
	claimed: number, -- bitmask: bit k-1 set once gift k is opened
	day: number, -- UTC day `ladders` counts for
	ladders: number, -- ladders started that day
}

local function count(value: any): number
	return if type(value) == "number" and value == value and value >= 0 and value < math.huge then math.floor(value) else 0
end

-- A clean state from whatever was saved (old profiles have nothing).
function PlaytimeGifts.fresh(saved: any): State
	local s = if type(saved) == "table" then saved else {}
	return {
		played = count(s.played),
		seen = count(s.seen),
		claimed = count(s.claimed) % 2 ^ #PlaytimeGifts.Ladder,
		day = count(s.day),
		ladders = count(s.ladders),
	}
end

-- Banks the time played since `seen`. Call while the player is in the game (join, claim, leave).
function PlaytimeGifts.tick(state: State, now: number)
	if state.seen > 0 and now > state.seen then
		state.played += now - state.seen
	end
	state.seen = now
end

-- The player joined: starts a new ladder if they were away long enough and today's cap allows,
-- otherwise carries on the old one. Returns true if a new ladder started.
function PlaytimeGifts.begin(state: State, now: number): boolean
	local today = now // 86400
	if state.day ~= today then
		state.day = today
		state.ladders = 0
	end
	local away = state.seen == 0 or now - state.seen >= PlaytimeGifts.AwayMinutes * 60
	state.seen = now -- time away never counts as played
	if away and state.ladders < PlaytimeGifts.LaddersPerDay then
		state.played = 0
		state.claimed = 0
		state.ladders += 1
		return true
	end
	return false
end

function PlaytimeGifts.isClaimed(state: State, k: number): boolean
	return bit32.btest(state.claimed, bit32.lshift(1, k - 1))
end

function PlaytimeGifts.allClaimed(state: State): boolean
	return state.claimed == 2 ^ #PlaytimeGifts.Ladder - 1
end

-- Whether gift `k` (from the client, so anything) can be opened now; and why not.
function PlaytimeGifts.check(state: State, k: any): (boolean, string?)
	if type(k) ~= "number" or k ~= math.floor(k) or k < 1 or k > #PlaytimeGifts.Ladder then
		return false, "That didn't work"
	end
	if PlaytimeGifts.isClaimed(state, k) then
		return false, "Already opened"
	end
	local left = PlaytimeGifts.Ladder[k].minutes * 60 - state.played
	if left > 0 then
		return false, `Ready in {math.ceil(left / 60)} min`
	end
	return true, nil
end

function PlaytimeGifts.claim(state: State, k: number)
	state.claimed = bit32.bor(state.claimed, bit32.lshift(1, k - 1))
end

return PlaytimeGifts
