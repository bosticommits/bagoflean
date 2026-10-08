--!strict
-- Claims achievements (the Goals screen). The client names the achievement; whether it is done and
-- not yet claimed, and what it gives, is decided here from the shared list.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Achievements = require(ReplicatedStorage.Shared.Achievements)
local Config = require(ReplicatedStorage.Shared.Config)
local AchievementTracker = require(script.Parent.AchievementTracker)
local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local Remotes = require(script.Parent.Remotes)
local RewardService = require(script.Parent.RewardService)

local claimAchievement = Remotes.get("ClaimAchievement")
local rewardResult = Remotes.get("RewardResult")

local lastClaim: { [Player]: number } = {}
local lastSync: { [Player]: number } = {}

local AchievementService = {}

local function fail(player: Player, text: string)
	rewardResult:FireClient(player, false, text)
end

local function onClaim(player: Player, id: any)
	local now = os.clock()
	if lastClaim[player] ~= nil and now - lastClaim[player] < Config.ActionCooldown then
		return fail(player, "Slow down!")
	end
	lastClaim[player] = now
	local data = DataService.getData(player)
	if data == nil then
		return fail(player, "Still loading your data")
	end
	local achievement = if type(id) == "string" then Achievements.get(id) else nil
	if achievement == nil then
		return fail(player, "That didn't work")
	end
	if data.achievements[achievement.id] then
		return fail(player, "Already claimed")
	end
	if not Achievements.isDone(AchievementTracker.view(data), achievement) then
		return fail(player, "Not done yet")
	end
	data.achievements[achievement.id] = true
	local text = RewardService.apply(player, data, achievement.reward, "TimedReward", "Achievement")
	Analytics.event(player, "AchievementClaim", 1, achievement.id)
	AchievementTracker.sync(player)
	RewardService.afterGrant(player, `{achievement.text}: {text}`)
end

function AchievementService.start()
	claimAchievement.OnServerEvent:Connect(onClaim)
	Remotes.get("AchievementsRequest").OnServerEvent:Connect(function(player)
		local now = os.clock()
		if lastSync[player] == nil or now - lastSync[player] >= 1 then
			lastSync[player] = now
			AchievementTracker.sync(player)
		end
	end)
end

function AchievementService.forget(player: Player)
	lastClaim[player] = nil
	lastSync[player] = nil
	AchievementTracker.forget(player)
end

return AchievementService
