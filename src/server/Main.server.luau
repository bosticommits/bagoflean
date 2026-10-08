--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Startup guard. A duplicated script (for example from two sync tools creating the same file) must
-- not start every service twice, and duplicate modules should be reported rather than ignored.
local container = script.Parent
if container:GetAttribute("MovieMogulStarted") then
	warn(`[MovieMogul] duplicate Main ignored ({script:GetFullName()}); remove the extra copy`)
	return
end
container:SetAttribute("MovieMogulStarted", true)
do
	local seen: { [string]: boolean } = {}
	for _, child in container:GetChildren() do
		if seen[child.Name] then
			warn(`[MovieMogul] duplicate script "{child.Name}" in {container:GetFullName()}; remove the extra copy`)
		end
		seen[child.Name] = true
	end
end

local Config = require(ReplicatedStorage.Shared.Config)
local AchievementService = require(script.Parent.AchievementService)
local Analytics = require(script.Parent.Analytics)
local AwardNightService = require(script.Parent.AwardNightService)
local CastingService = require(script.Parent.CastingService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local LiveConfig = require(script.Parent.LiveConfig)
local LotService = require(script.Parent.LotService)
local MapService = require(script.Parent.MapService)
local MovieService = require(script.Parent.MovieService)
local RebirthService = require(script.Parent.RebirthService)
local Remotes = require(script.Parent.Remotes)
local RewardService = require(script.Parent.RewardService)
local ShopService = require(script.Parent.ShopService)
local SoundSettingsService = require(script.Parent.SoundSettingsService)
local SpecialEventService = require(script.Parent.SpecialEventService)
local UpgradeService = require(script.Parent.UpgradeService)
local VisitService = require(script.Parent.VisitService)

MapService.start()
LeaderboardService.start()
LotService.start()
CastingService.start()
MovieService.start()
UpgradeService.start()
RebirthService.start()
RewardService.start()
ShopService.start()
AchievementService.start()
SoundSettingsService.start()
AwardNightService.start()
Analytics.start()
LiveConfig.start()
SpecialEventService.start()
VisitService.start()
Remotes.publish()

local function onPlayerAdded(player: Player)
	local data = DataService.load(player)
	if data == nil then
		-- Never fall back to defaults: that could overwrite a real profile later.
		if player.Parent == Players then
			player:Kick("Your data could not be loaded. Please rejoin.")
		end
		return
	end
	EconomyService.refresh(player)
	CastingService.refresh(player)
	RebirthService.refresh(player)
	-- A player can step on a claim pad before their data arrives (a quick rejoin waits for the old
	-- session to save). Redraw their lot now so it shows their stages and star, not an empty lot.
	LotService.refresh(player)
	player:SetAttribute("DataLoaded", true)
	Analytics.onboarding(player, Analytics.Steps.Joined)
	RewardService.joined(player)
	task.spawn(ShopService.load, player)

	-- Keep the pending-royalty and Luck readouts fresh for the HUD (Luck changes as boosts and Award
	-- Night start and end), and run the Auto-Collect pass.
	local lastAutoCollect = os.clock()
	while player.Parent == Players do
		local live = DataService.getData(player)
		if live == nil then
			break
		end
		if live.passes.AutoCollect and os.clock() - lastAutoCollect >= Config.AutoCollectSeconds then
			lastAutoCollect = os.clock()
			EconomyService.collect(player)
		end
		EconomyService.refresh(player)
		CastingService.refresh(player)
		task.wait(1)
	end
end

local function onPlayerRemoving(player: Player)
	LotService.release(player)
	EconomyService.forget(player)
	CastingService.forget(player)
	MovieService.forget(player)
	UpgradeService.forget(player)
	RebirthService.forget(player)
	RewardService.forget(player)
	AchievementService.forget(player)
	SpecialEventService.forget(player)
	VisitService.forget(player)
	Analytics.forget(player)
	DataService.release(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
