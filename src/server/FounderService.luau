--!strict
-- Founding Tester (rule in Shared/Founder). After launch day flips Config.LaunchWipe, players start
-- on a fresh PlayerData_v2 save; once per player we look at their old soft-launch save (read only)
-- and, if it finished the tutorial before the cut-off, they become a founder for good.
-- Attributes the client and the lot read:
--   "FoundingTester"  the gold [Founder] chat tag (set every join for founders)
--   "FounderNew"      set only on the one join that grants it: the client shows one thank-you toast
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BadgeAwards = require(script.Parent.BadgeAwards)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Founder = require(ReplicatedStorage.Shared.Founder)
local LiveConfig = require(script.Parent.LiveConfig)
local LotService = require(script.Parent.LotService)

local FounderService = {}

local function publish(player: Player)
	player:SetAttribute("FoundingTester", true)
	-- Every join, so the badge still lands if its id is added to Badges.List.FoundingTester.id (Shared/Badges) later.
	BadgeAwards.award(player, "FoundingTester")
end

-- Yields (one old-save read, once per player ever). Main runs it in its own task.
function FounderService.check(player: Player)
	local data = DataService.getData(player)
	if data == nil then
		return
	end
	if data.founder then
		publish(player)
		return
	end
	if data.founderChecked or not Config.LaunchWipe or LiveConfig.switchedOff("FounderCheck") then
		return
	end
	local ok, old, createdAt = DataService.oldSave(player.UserId)
	if not ok then
		return -- unsaved: asked again on the next join
	end
	-- The player may have left or their session moved while we waited: never write to stale data.
	local live = DataService.getData(player)
	if live == nil then
		return
	end
	if Founder.settle(live, Founder.isFounder(old, createdAt)) then
		publish(player)
		player:SetAttribute("FounderNew", true)
		LotService.refresh(player)
	end
end

return FounderService
