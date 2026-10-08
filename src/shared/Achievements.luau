--!strict
-- Achievements: lifetime goals with a one-time reward each (claimed on the Goals screen). Shared so
-- the screen shows exactly what the server checks and grants. Progress comes from lifetime counters
-- (`stats`, counted by the server from the same actions as Studio Requests) and from things the
-- save already holds (Index, Masterpiece trophies, Fame), so nothing here ever goes backwards.
--
-- Rewards are kept small: most are a few minutes of income, a short x2 Luck boost or a Skip, so
-- they add goals to chase without speeding up the curve in ECONOMY.md much. The economy sim reads
-- this list (one achievement per line), so keep each entry on one line.
local Actors = require(script.Parent.Actors)
local Shop = require(script.Parent.Shop)

local Achievements = {}

export type Reward = Shop.Reward

export type Achievement = {
	id: string, -- stable; saved in player data when claimed
	group: string, -- the screen shows one row per group: its next goal
	stat: string, -- what is counted, see Achievements.value
	target: number,
	text: string,
	reward: Reward,
}

-- Grouped and ordered easy to hard within each group.
Achievements.List = {
	{ id = "Cast1", group = "cast", stat = "cast", target = 10, text = "Hold 10 Casting Calls", reward = { cash = 50, cashMinutes = 2 } },
	{ id = "Cast2", group = "cast", stat = "cast", target = 100, text = "Hold 100 Casting Calls", reward = { cash = 150, cashMinutes = 3 } },
	{ id = "Cast3", group = "cast", stat = "cast", target = 500, text = "Hold 500 Casting Calls", reward = { cash = 1000, cashMinutes = 10 } },
	{ id = "Cast4", group = "cast", stat = "cast", target = 2500, text = "Hold 2,500 Casting Calls", reward = { luckMinutes = 10, skips = 1 } },
	{ id = "Cast5", group = "cast", stat = "cast", target = 10000, text = "Hold 10,000 Casting Calls", reward = { luckMinutes = 30, skips = 2 } },

	{ id = "Premiere1", group = "premiere", stat = "premiere", target = 1, text = "Premiere your first movie", reward = { cash = 30, cashMinutes = 2 } },
	{ id = "Premiere2", group = "premiere", stat = "premiere", target = 10, text = "Premiere 10 movies", reward = { script = { genre = "Action", length = "Indie", count = 2 } } },
	{ id = "Premiere3", group = "premiere", stat = "premiere", target = 50, text = "Premiere 50 movies", reward = { skips = 1, cash = 1000, cashMinutes = 10 } },
	{ id = "Premiere4", group = "premiere", stat = "premiere", target = 200, text = "Premiere 200 movies", reward = { skips = 2, cash = 3000, cashMinutes = 20 } },
	{ id = "Premiere5", group = "premiere", stat = "premiere", target = 1000, text = "Premiere 1,000 movies", reward = { skips = 3, luckMinutes = 30 } },

	{ id = "Hit1", group = "hit", stat = "hit", target = 1, text = "Get a Blockbuster or better", reward = { script = { genre = "Comedy", length = "Indie", count = 1 } } },
	{ id = "Hit2", group = "hit", stat = "hit", target = 10, text = "Get 10 Blockbusters or better", reward = { luckMinutes = 5 } },
	{ id = "Hit3", group = "hit", stat = "hit", target = 50, text = "Get 50 Blockbusters or better", reward = { skips = 1, cash = 2000, cashMinutes = 15 } },

	{ id = "Masterpiece1", group = "masterpiece", stat = "masterpiece", target = 1, text = "Make a Masterpiece", reward = { skips = 1 } },
	{ id = "Masterpiece2", group = "masterpiece", stat = "masterpiece", target = 5, text = "Make 5 Masterpieces", reward = { luckMinutes = 10 } },
	{ id = "Masterpiece3", group = "masterpiece", stat = "masterpiece", target = 25, text = "Make 25 Masterpieces", reward = { luckMinutes = 30, skips = 2 } },

	{ id = "Index1", group = "index", stat = "index", target = 5, text = "Discover 5 actors in the Index", reward = { cash = 50, cashMinutes = 2 } },
	{ id = "Index2", group = "index", stat = "index", target = 15, text = "Discover 15 actors in the Index", reward = { cash = 200, cashMinutes = 5 } },
	{ id = "Index3", group = "index", stat = "index", target = 30, text = "Discover 30 actors in the Index", reward = { skips = 1, cash = 1500, cashMinutes = 15 } },
	{ id = "Index4", group = "index", stat = "index", target = 45, text = "Discover 45 actors in the Index", reward = { luckMinutes = 15, skips = 1 } },
	{ id = "Index5", group = "index", stat = "index", target = 63, text = "Complete the whole Index", reward = { luckMinutes = 60, skips = 5, cash = 10000, cashMinutes = 60 } },

	{ id = "RareStar", group = "rare", stat = "tier:Star", target = 1, text = "Discover a Star actor", reward = { luckMinutes = 5 } },
	{ id = "RareSuperstar", group = "rare", stat = "tier:Superstar", target = 1, text = "Discover a Superstar actor", reward = { luckMinutes = 10 } },
	{ id = "RareLegend", group = "rare", stat = "tier:Legend", target = 1, text = "Discover a Legend actor", reward = { luckMinutes = 15, skips = 2 } },
	{ id = "RareIcon", group = "rare", stat = "tier:Icon", target = 1, text = "Discover an Icon actor", reward = { luckMinutes = 60, skips = 5 } },

	{ id = "Shiny1", group = "variant", stat = "variant:Shiny", target = 1, text = "Discover a Shiny actor", reward = { cash = 50, cashMinutes = 2 } },
	{ id = "Award1", group = "variant", stat = "variant:Award", target = 1, text = "Discover an Award-Winning actor", reward = { luckMinutes = 10 } },

	{ id = "Fame1", group = "fame", stat = "fame", target = 1000, text = "Reach 1,000 Fame", reward = { cash = 500, cashMinutes = 5 } },
	{ id = "Fame2", group = "fame", stat = "fame", target = 10000, text = "Reach 10,000 Fame", reward = { script = { genre = "Comedy", length = "Feature", count = 1 } } },
	{ id = "Fame3", group = "fame", stat = "fame", target = 100000, text = "Reach 100,000 Fame", reward = { skips = 2, luckMinutes = 10 } },
	{ id = "Fame4", group = "fame", stat = "fame", target = 1000000, text = "Reach 1,000,000 Fame", reward = { luckMinutes = 30, skips = 3 } },

	{ id = "Clap1", group = "clap", stat = "clap", target = 100, text = "Tap the clapperboard 100 times", reward = { cash = 50, cashMinutes = 2 } },
	{ id = "Clap2", group = "clap", stat = "clap", target = 1000, text = "Tap the clapperboard 1,000 times", reward = { luckMinutes = 5 } },
	{ id = "Clap3", group = "clap", stat = "clap", target = 5000, text = "Tap the clapperboard 5,000 times", reward = { skips = 2 } },

	{ id = "Script1", group = "script", stat = "script", target = 5, text = "Buy 5 scripts", reward = { cash = 30, cashMinutes = 2 } },
	{ id = "Script2", group = "script", stat = "script", target = 50, text = "Buy 50 scripts", reward = { script = { genre = "Comedy", length = "Indie", count = 3 } } },
	{ id = "Script3", group = "script", stat = "script", target = 250, text = "Buy 250 scripts", reward = { script = { genre = "Action", length = "Feature", count = 2 } } },

	{ id = "Collect1", group = "collect", stat = "collect", target = 10, text = "Collect the box office 10 times", reward = { cash = 50, cashMinutes = 2 } },
	{ id = "Collect2", group = "collect", stat = "collect", target = 100, text = "Collect the box office 100 times", reward = { luckMinutes = 5 } },
	{ id = "Collect3", group = "collect", stat = "collect", target = 500, text = "Collect the box office 500 times", reward = { skips = 2, cashMinutes = 20 } },
} :: { Achievement }

-- Lifetime counters the server keeps in `stats` (the same action kinds QuestTracker.track gets).
Achievements.Counted = table.freeze({ "cast", "premiere", "hit", "clap", "script", "collect" })

local byId: { [string]: Achievement } = {}
for _, achievement in Achievements.List do
	byId[achievement.id] = achievement
end

function Achievements.get(id: string): Achievement?
	return byId[id]
end

-- What progress is read from: the parts of the player's save that achievements look at.
export type View = {
	stats: { [string]: number },
	index: { [string]: boolean },
	trophies: number,
	fame: number,
}

-- How far along `stat` the player is.
function Achievements.value(view: View, stat: string): number
	if stat == "masterpiece" then
		return view.trophies
	elseif stat == "fame" then
		return view.fame
	elseif stat == "index" or string.sub(stat, 1, 5) == "tier:" or string.sub(stat, 1, 8) == "variant:" then
		local tierId = string.match(stat, "^tier:(.+)$")
		local variantId = string.match(stat, "^variant:(.+)$")
		local count = 0
		for key, found in view.index do
			if found ~= true then
				continue
			end
			local actorId, variant = string.match(key, "^([^:]+):(.+)$")
			local actor = if actorId ~= nil then Actors.getActor(actorId) else nil
			if actor == nil or Actors.getVariant(variant :: string) == nil then
				continue -- an old or unknown key never counts
			end
			if (tierId == nil or actor.tier == tierId) and (variantId == nil or variant == variantId) then
				count += 1
			end
		end
		return count
	end
	return view.stats[stat] or 0
end

-- Progress toward one achievement, capped at its target.
function Achievements.progress(view: View, achievement: Achievement): number
	return math.min(achievement.target, Achievements.value(view, achievement.stat))
end

function Achievements.isDone(view: View, achievement: Achievement): boolean
	return Achievements.value(view, achievement.stat) >= achievement.target
end

-- Achievements that are done but not claimed yet, in list order.
function Achievements.claimable(view: View, claimed: { [string]: boolean }): { string }
	local ids: { string } = {}
	for _, achievement in Achievements.List do
		if not claimed[achievement.id] and Achievements.isDone(view, achievement) then
			table.insert(ids, achievement.id)
		end
	end
	return ids
end

-- Groups in list order, each with its achievements easy to hard (one screen row per group).
function Achievements.groups(): { { id: string, list: { Achievement } } }
	local out: { { id: string, list: { Achievement } } } = {}
	local at: { [string]: number } = {}
	for _, achievement in Achievements.List do
		local slot = at[achievement.group]
		if slot == nil then
			table.insert(out, { id = achievement.group, list = {} })
			slot = #out
			at[achievement.group] = slot
		end
		table.insert(out[slot].list, achievement)
	end
	return out
end

return Achievements
