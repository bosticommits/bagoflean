--!strict
-- Owns player persistence. ProfileStore (vendored, Apache-2.0, see LICENSE-ProfileStore) does the
-- session locking, autosave, and save-on-shutdown. This module is the only code that touches it.
-- In Studio without DataStore access, ProfileStore falls back to a mock store by itself.
local Players = game:GetService("Players")

local ProfileStore = require(script.Parent.ProfileStore)

export type PlayerData = {
	version: number,
	cash: number,
	lastCollect: number, -- os.time() of the last cinema collect
	roster: { [string]: number }, -- "actorId:variantId" -> copies owned (spent on movies in M3)
	index: { [string]: boolean }, -- "actorId:variantId" -> ever discovered (kept through Sequel)
}

local CURRENT_VERSION = 1

local TEMPLATE: PlayerData = {
	version = CURRENT_VERSION,
	cash = 0,
	lastCollect = 0, -- replaced with the join time for brand-new profiles in load()
	roster = {},
	index = {},
}

local playerStore = ProfileStore.New("PlayerData_v1", TEMPLATE)

local profiles: { [Player]: any } = {}
local releasing: { [number]: boolean } = {}

local DataService = {}

-- Repairs malformed fields. Add `if version < N` steps here when the schema changes.
local function migrate(data: any)
	if type(data.cash) ~= "number" or data.cash ~= data.cash or data.cash < 0 then
		data.cash = 0
	end
	if type(data.lastCollect) ~= "number" then
		data.lastCollect = os.time()
	end
	if type(data.roster) ~= "table" then
		data.roster = {}
	end
	if type(data.index) ~= "table" then
		data.index = {}
	end
	data.version = CURRENT_VERSION
end

-- Yields. Returns the player's data, or nil if it could not be loaded safely.
-- Callers must never substitute defaults on nil: that could overwrite a real profile.
function DataService.load(player: Player): PlayerData?
	local userId = player.UserId
	while releasing[userId] do
		task.wait(0.2)
	end

	local profile = playerStore:StartSessionAsync("player_" .. userId, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if profile == nil then
		return nil
	end
	if player.Parent ~= Players then
		profile:EndSession()
		return nil
	end

	profile:AddUserId(userId)
	profile:Reconcile()
	if profile.Data.lastCollect == 0 then
		profile.Data.lastCollect = os.time() -- new profile: royalties start now
	end
	migrate(profile.Data)

	profiles[player] = profile
	profile.OnSessionEnd:Connect(function()
		-- Another server took the session, or it ended. Gameplay must stop using this data.
		if profiles[player] == profile then
			profiles[player] = nil
		end
		if player.Parent == Players then
			player:Kick("Your data session ended. Please rejoin.")
		end
	end)
	return profile.Data :: PlayerData
end

-- Live data for gameplay code. Nil while loading, after the session ends, or after release.
function DataService.getData(player: Player): PlayerData?
	local profile = profiles[player]
	if profile == nil or not profile:IsActive() then
		return nil
	end
	return profile.Data :: PlayerData
end

-- Kept so callers state intent; ProfileStore saves changes to Profile.Data on its own.
function DataService.markDirty(_player: Player) end

-- Final save plus session release. Safe to call more than once.
function DataService.release(player: Player)
	local profile = profiles[player]
	if profile == nil then
		return
	end
	profiles[player] = nil
	local userId = player.UserId
	releasing[userId] = true
	profile:EndSession()
	-- Hold off a rejoin on this server until the release has gone through.
	while profile:IsActive() do
		task.wait(0.1)
	end
	releasing[userId] = nil
end

return DataService
