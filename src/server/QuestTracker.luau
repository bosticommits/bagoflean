--!strict
-- Today's Studio Requests: rolls them over at the UTC day boundary, counts progress from gameplay,
-- and syncs the rewards screen. Claiming is in RewardService. Kept separate (and free of gameplay
-- dependencies) so casting, movies and lots can report progress without a require cycle.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rewards = require(ReplicatedStorage.Shared.Rewards)
local DataService = require(script.Parent.DataService)
local Remotes = require(script.Parent.Remotes)

local rewardsSync = Remotes.get("RewardsSync")

local QuestTracker = {}

-- Makes sure the saved requests are today's (replacing yesterday's, claimed or not).
function QuestTracker.ensure(data: DataService.PlayerData)
	local today = Rewards.today(os.time())
	if data.requests.day == today then
		return
	end
	local list: { DataService.Request } = {}
	for _, id in Rewards.requestsFor(today) do
		table.insert(list, { id = id, progress = 0, claimed = false })
	end
	data.requests = { day = today, list = list }
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
		codes = data.codes,
	})
end

-- Counts `amount` toward every unfinished request of this kind ("cast", "premiere", "clap",
-- "script", "collect", "hit"). Server-side callers only, after the action has succeeded.
function QuestTracker.track(player: Player, kind: string, amount: number?)
	local data = DataService.getData(player)
	if data == nil then
		return
	end
	QuestTracker.ensure(data)
	local changed = false
	for _, entry in data.requests.list do
		local request = Rewards.getRequest(entry.id)
		if request ~= nil and request.kind == kind and not entry.claimed and entry.progress < request.target then
			entry.progress = math.min(request.target, entry.progress + (amount or 1))
			changed = true
		end
	end
	if changed then
		DataService.markDirty(player)
		QuestTracker.sync(player)
	end
end

return QuestTracker
