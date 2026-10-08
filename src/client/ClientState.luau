--!strict
-- The one client copy of server-synced data (roster, Index, studio snapshot). Screens read this and
-- listen to `changed`; none of them keep their own copy or talk to the sync remotes directly.
local Players = game:GetService("Players")

local ClientState = {}

ClientState.roster = {} :: { [string]: number }
ClientState.index = {} :: { [string]: boolean }
-- Latest StudioSync payload: serverNow, stageCount, fame, rate, scripts, films, cinema, upgrades, rewards.
ClientState.studio = nil :: any
ClientState.syncedAt = 0
-- Latest RewardsSync payload: serverNow, today, daily { day, streak }, requests, codes.
ClientState.rewards = nil :: any

local changedEvent = Instance.new("BindableEvent")
-- Fires "roster", "studio" or "rewards" after the state above has been updated.
ClientState.changed = changedEvent.Event

-- The server's clock now, from the last sync plus local time since.
function ClientState.serverNow(): number
	local studio = ClientState.studio
	if studio == nil then
		return 0
	end
	return studio.serverNow + (os.clock() - ClientState.syncedAt)
end

-- The slice of studio state the shared Upgrades functions read.
function ClientState.stats(): any
	local studio = ClientState.studio
	return {
		upgrades = if studio ~= nil then studio.upgrades else {},
		stageCount = if studio ~= nil then studio.stageCount else 1,
		rewards = if studio ~= nil then studio.rewards else {},
		passes = if studio ~= nil then studio.passes else {},
		rebirths = if studio ~= nil then studio.rebirths else 0,
	}
end

function ClientState.start(remotes: Instance)
	local player = Players.LocalPlayer
	local rosterSync = remotes:WaitForChild("RosterSync") :: RemoteEvent
	local studioSync = remotes:WaitForChild("StudioSync") :: RemoteEvent
	local rosterRequest = remotes:WaitForChild("RosterRequest") :: RemoteEvent
	local studioRequest = remotes:WaitForChild("StudioRequest") :: RemoteEvent
	local rewardsSync = remotes:WaitForChild("RewardsSync") :: RemoteEvent
	local rewardsRequest = remotes:WaitForChild("RewardsRequest") :: RemoteEvent

	rosterSync.OnClientEvent:Connect(function(roster, index)
		if type(roster) == "table" and type(index) == "table" then
			ClientState.roster = roster
			ClientState.index = index
			changedEvent:Fire("roster")
		end
	end)
	studioSync.OnClientEvent:Connect(function(studio)
		if type(studio) == "table" then
			ClientState.studio = studio
			ClientState.syncedAt = os.clock()
			changedEvent:Fire("studio")
		end
	end)

	rewardsSync.OnClientEvent:Connect(function(rewards)
		if type(rewards) == "table" then
			ClientState.rewards = rewards
			changedEvent:Fire("rewards")
		end
	end)

	-- Ask once the server has loaded this player's data.
	task.spawn(function()
		while not player:GetAttribute("DataLoaded") do
			player.AttributeChanged:Wait()
		end
		rosterRequest:FireServer()
		studioRequest:FireServer()
		rewardsRequest:FireServer()
	end)
end

return ClientState
