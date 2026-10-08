--!strict
-- Today's Studio Requests and this week's quests: rolls them over at the UTC day and week
-- boundaries, counts progress from gameplay, and syncs the rewards and Goals screens. Claiming is in RewardService. Kept separate (and free of gameplay
-- dependencies) so casting, movies and lots can report progress without a require cycle.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rewards = require(ReplicatedStorage.Shared.Rewards)
local AchievementTracker = require(script.Parent.AchievementTracker)
local DataService = require(script.Parent.DataService)
local Remotes = require(script.Parent.Remotes)

local rewardsSync = Remotes.get("RewardsSync")

local QuestTracker = {}

-- Makes sure the saved requests are today's and the weekly quests this week's (replacing the old
-- ones, claimed or not).
function QuestTracker.ensure(data: DataService.PlayerData)
	local now = os.time()
	local today = Rewards.today(now)
	if data.requests.day ~= today then
		local list: { DataService.Request } = {}
		for _, id in Rewards.requestsFor(today) do
			table.insert(list, { id = id, progress = 0, claimed = false })
		end
		data.requests = { day = today, list = list }
	end
	local week = Rewards.week(now)
	if data.weekly.week ~= week then
		local list: { DataService.Request } = {}
		for _, id in Rewards.weeklyFor(week) do
			table.insert(list, { id = id, progress = 0, claimed = false })
		end
		data.weekly = { week = week, list = list }
	end
end

function QuestTracker.sync(player: Player)
	local data = DataService.getData(player)
	if data == nil then
		return
	end
	QuestTracker.ensure(data)
	local now = os.time()
	rewardsSync:FireClient(player, {
		serverNow = now,
		today = Rewards.today(now),
		daily = data.daily,
		requests = data.requests.list,
		week = data.weekly.week,
		weekEnds = Rewards.weekStart(data.weekly.week + 1),
		weekly = data.weekly.list,
		codes = data.codes,
		stayGiftDay = data.stayGiftDay,
	})
end

-- Counts `amount` toward every unfinished request and weekly quest of this kind ("cast",
-- "premiere", "clap", "script", "collect", "hit", or "premiere:<genre>") and toward the lifetime
-- achievement counters. Server-side callers
-- only, after the action has succeeded.
function QuestTracker.track(player: Player, kind: string, amount: number?)
	local data = DataService.getData(player)
	if data == nil then
		return
	end
	AchievementTracker.count(player, kind, amount)
	QuestTracker.ensure(data)
	local changed = false
	for _, list in { data.requests.list, data.weekly.list } do
		for _, entry in list do
			local request = Rewards.getRequest(entry.id)
			if request ~= nil and request.kind == kind and not entry.claimed and entry.progress < request.target then
				entry.progress = math.min(request.target, entry.progress + (amount or 1))
				changed = true
			end
		end
	end
	if changed then
		DataService.markDirty(player)
		QuestTracker.sync(player)
	end
end

return QuestTracker
