--!strict
-- Lifetime counters for achievements, and the Goals screen sync. Claiming is in AchievementService.
-- Kept free of gameplay dependencies (like QuestTracker, which counts into it) so any service can
-- report progress without a require cycle.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Achievements = require(ReplicatedStorage.Shared.Achievements)
local DataService = require(script.Parent.DataService)
local Remotes = require(script.Parent.Remotes)

local achievementsSync = Remotes.get("AchievementsSync")

-- Progress-only changes (one more cast) are sent at most this often; a newly finished goal is
-- sent at once so its badge and "Goal reached!" message show straight away.
local SYNC_DELAY = 2

local pending: { [Player]: boolean } = {}
local lastReady: { [Player]: number } = {}

local AchievementTracker = {}

function AchievementTracker.view(data: DataService.PlayerData): Achievements.View
	return { stats = data.stats, index = data.index, trophies = data.trophies, fame = data.fame }
end

function AchievementTracker.sync(player: Player)
	pending[player] = nil
	local data = DataService.getData(player)
	if data == nil then
		return
	end
	local view = AchievementTracker.view(data)
	local progress: { [string]: number } = {}
	for _, achievement in Achievements.List do
		progress[achievement.id] = Achievements.progress(view, achievement)
	end
	lastReady[player] = #Achievements.claimable(view, data.achievements)
	achievementsSync:FireClient(player, { progress = progress, claimed = data.achievements })
end

-- Counts `amount` more of `kind` ("cast", "premiere", ...) for life. QuestTracker.track calls this
-- for every action it is told about, after the action has succeeded.
function AchievementTracker.count(player: Player, kind: string, amount: number?)
	local data = DataService.getData(player)
	if data == nil or table.find(Achievements.Counted, kind) == nil then
		return
	end
	data.stats[kind] = (data.stats[kind] or 0) + (amount or 1)
	DataService.markDirty(player)
	AchievementTracker.changed(player)
end

-- Something achievements read changed (a counter, the Index, Fame, trophies): sync soon, or now if
-- a goal just finished.
function AchievementTracker.changed(player: Player)
	local data = DataService.getData(player)
	if data == nil then
		return
	end
	local ready = #Achievements.claimable(AchievementTracker.view(data), data.achievements)
	if ready > (lastReady[player] or 0) then
		AchievementTracker.sync(player)
	elseif not pending[player] then
		pending[player] = true
		task.delay(SYNC_DELAY, function()
			if pending[player] then
				AchievementTracker.sync(player)
			end
		end)
	end
end

function AchievementTracker.forget(player: Player)
	pending[player] = nil
	lastReady[player] = nil
end

return AchievementTracker
