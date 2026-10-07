--!strict
-- Award Night (plan section 5). The schedule lives in Shared/Events, and the boosts are applied
-- where the numbers are used (CastingService.castLuck, MovieService premiere payouts). This module
-- only announces the start to the server and refreshes everyone's Luck readout at both edges.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Events = require(ReplicatedStorage.Shared.Events)
local CastingService = require(script.Parent.CastingService)
local Remotes = require(script.Parent.Remotes)

local AwardNightService = {}

function AwardNightService.start()
	task.spawn(function()
		local wasActive = Events.awardNight(os.time())
		while true do
			task.wait(1)
			local active = Events.awardNight(os.time())
			if active ~= wasActive then
				wasActive = active
				for _, player in Players:GetPlayers() do
					CastingService.refresh(player)
				end
				if active then
					local minutes = Events.AwardNightLength // 60
					Remotes.announce(`AWARD NIGHT! x{Config.AwardNightLuckMultiplier} casting Luck and x{Config.AwardNightPayoutMultiplier} premiere payouts for {minutes} minutes!`)
				end
			end
		end
	end)
end

return AwardNightService
