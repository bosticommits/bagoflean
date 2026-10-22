--!strict
-- Today's Studio Requests, this week's quests and this week's Film Festival goals: rolls them over
-- at the UTC day and week boundaries, counts progress from gameplay, and syncs the rewards and
-- Goals screens. Claiming is in RewardService. Kept separate (and free of gameplay
-- dependencies) so casting, movies and lots can report progress without a require cycle.
-- Finishing all three festival goals wins the festival: a Festival Laurel is saved here and
-- SpecialEventService (set as `festivalWon`) shows it on the lot.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rewards = require(ReplicatedStorage.Shared.Rewards)
local SpecialEvents = require(ReplicatedStorage.Shared.SpecialEvents)
local AchievementTracker = require(script.Parent.AchievementTracker)
local DataService = require(script.Parent.DataService)
local LiveConfig = require(script.Parent.LiveConfig)
local Remotes = require(script.Parent.Remotes)

local rewardsSync = Remotes.get("RewardsSync")

local QuestTracker = {}

-- Called after a player wins this week's festival (their laurel is already saved).
QuestTracker.festivalWon = nil :: ((player: Player, festival: SpecialEvents.Festival) -> ())?

-- This week's Film Festival, or nil while LiveConfig has festivals switched off.
function QuestTracker.festival(now: number): SpecialEvents.Festival?
	local off = if LiveConfig.eventDisabled(SpecialEvents.FestivalId) then { [SpecialEvents.FestivalId] = true } else nil
	return SpecialEvents.festivalAt(now, off)
end

-- Whether the player has won the festival of `week`.
function QuestTracker.wonFestival(data: DataService.PlayerData, week: number): boolean
	for _, laurel in data.laurels do
		if laurel.week == week then
			return true
		end
	end
	return false
end

-- Makes sure the saved requests are today's and the weekly quests and festival goals this week's. The old ones are
-- replaced, but any that were finished and not yet claimed move to `data.carried` first and stay
-- claimable (Rewards.carryOver), so a reset never takes a reward the player had earned.
function QuestTracker.ensure(data: DataService.PlayerData)
	local now = os.time()
	local today = Rewards.today(now)
	if data.requests.day ~= today then
		Rewards.carryOver(data.carried, "daily", data.requests.day, data.requests.list)
		local list: { DataService.Request } = {}
		for _, id in Rewards.requestsFor(today) do
			table.insert(list, { id = id, progress = 0, claimed = false })
		end
		data.requests = { day = today, list = list }
	end
	local week = Rewards.week(now)
	if data.weekly.week ~= week then
		Rewards.carryOver(data.carried, "weekly", data.weekly.week, data.weekly.list)
		local list: { DataService.Request } = {}
		for _, id in Rewards.weeklyFor(week) do
			table.insert(list, { id = id, progress = 0, claimed = false })
		end
		data.weekly = { week = week, list = list }
	end
	-- Festival goals: only while festivals are on. Switched off mid-week, the goals keep their
	-- progress and come back if it is switched on again the same week.
	if data.festival.week ~= week then
		Rewards.carryOver(data.carried, "festival", data.festival.week, data.festival.list)
		local festival = QuestTracker.festival(now)
		local list: { DataService.Request } = {}
		if festival ~= nil then
			for _, id in Rewards.festivalFor(festival.genre) do
				table.insert(list, { id = id, progress = 0, claimed = false })
			end
		end
		data.festival = { week = if festival ~= nil then week else 0, list = list }
	end
end

function QuestTracker.sync(player: Player)
	local data = DataService.getData(player)
	if data == nil then
		return
	end
	QuestTracker.ensure(data)
	local now = os.time()
	local festival = QuestTracker.festival(now)
	local festivalOn = festival ~= nil and data.festival.week == festival.week
	rewardsSync:FireClient(player, {
		serverNow = now,
		today = Rewards.today(now),
		daily = data.daily,
		requests = data.requests.list,
		week = data.weekly.week,
		weekEnds = Rewards.weekStart(data.weekly.week + 1),
		weekly = data.weekly.list,
		carried = data.carried,
		codes = data.codes,
		stayGiftDay = data.stayGiftDay,
		-- This week's festival goals (nil while festivals are off) and whether it is won yet.
		festivalWeek = if festivalOn then data.festival.week else nil,
		festival = if festivalOn then data.festival.list else nil,
		festivalWon = festivalOn and QuestTracker.wonFestival(data, data.festival.week),
		laurels = #data.laurels,
	})
end

-- All of this week's festival goals are done: save the laurel (once) and tell SpecialEventService.
local function checkFestival(player: Player, data: DataService.PlayerData)
	local festival = QuestTracker.festival(os.time())
	if festival == nil or data.festival.week ~= festival.week or #data.festival.list == 0 then
		return
	end
	if QuestTracker.wonFestival(data, festival.week) then
		return
	end
	for _, entry in data.festival.list do
		local goal = Rewards.getRequest(entry.id)
		if goal == nil or entry.progress < goal.target then
			return
		end
	end
	table.insert(data.laurels, { week = festival.week, genre = festival.genre, season = festival.season })
	DataService.markDirty(player)
	local callback = QuestTracker.festivalWon
	if callback ~= nil then
		callback(player, festival)
	end
end

-- Counts `amount` toward every unfinished request, weekly quest and festival goal of this kind
-- ("cast", "premiere", "clap", "script", "collect", "hit", "request", "premiere:<genre>" or
-- "hit:<genre>") and toward the lifetime achievement counters. Server-side callers
-- only, after the action has succeeded.
function QuestTracker.track(player: Player, kind: string, amount: number?)
	local data = DataService.getData(player)
	if data == nil then
		return
	end
	AchievementTracker.count(player, kind, amount)
	QuestTracker.ensure(data)
	local changed = false
	local lists = { data.requests.list, data.weekly.list }
	local festival = QuestTracker.festival(os.time())
	local festivalOn = festival ~= nil and data.festival.week == festival.week
	if festivalOn then
		table.insert(lists, data.festival.list)
	end
	for _, list in lists do
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
		if festivalOn then
			checkFestival(player, data)
		end
		QuestTracker.sync(player)
	end
end

-- Studio only, for playtests: finishes this week's festival goals (they still need claiming).
function QuestTracker.finishFestival(player: Player)
	local data = DataService.getData(player)
	if data == nil then
		return
	end
	QuestTracker.ensure(data)
	for _, entry in data.festival.list do
		local goal = Rewards.getRequest(entry.id)
		if goal ~= nil then
			entry.progress = goal.target
		end
	end
	DataService.markDirty(player)
	checkFestival(player, data)
	QuestTracker.sync(player)
end

return QuestTracker
