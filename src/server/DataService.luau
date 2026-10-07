--!strict
-- Owns player persistence. ProfileStore (vendored, Apache-2.0, see LICENSE-ProfileStore) does the
-- session locking, autosave, and save-on-shutdown. This module is the only code that touches it.
-- In Studio without DataStore access, ProfileStore falls back to a mock store by itself.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ProfileStore = require(script.Parent.ProfileStore)

-- A movie being filmed. Times are os.time() stamps, so filming continues while offline.
export type Film = {
	stage: number,
	title: string,
	genre: string,
	length: string,
	cast: { string }, -- "actorId:variantId" keys; these copies are busy until the premiere
	startTime: number,
	endTime: number,
}

-- A premiered movie sitting in the cinema earning royalties.
export type CinemaMovie = {
	title: string,
	genre: string,
	result: string,
	payout: number,
	time: number,
}

export type PlayerData = {
	version: number,
	cash: number,
	lastCollect: number, -- os.time() royalties were last banked into `accrued`
	accrued: number, -- banked cinema royalties waiting for the collect pad
	fame: number, -- never resets; unlocks things in M4
	stageCount: number,
	roster: { [string]: number }, -- "actorId:variantId" -> copies owned
	index: { [string]: boolean }, -- "actorId:variantId" -> ever discovered (kept through Sequel)
	scripts: { [string]: number }, -- "genre:lengthId" -> unused scripts
	films: { Film },
	cinema: { CinemaMovie },
	upgrades: { [string]: number }, -- upgrade id -> level (Stages lives in stageCount)
	rewards: { [string]: boolean }, -- claimed Index rewards: "tier:<id>" / "genre:<name>"
	trophies: number, -- Masterpiece premieres ever (shown on the lot)
	tutorialDone: boolean,
}

local CURRENT_VERSION = 4
local RELEASE_WAIT_SECONDS = 30

local TEMPLATE: PlayerData = {
	version = CURRENT_VERSION,
	cash = 0,
	lastCollect = 0, -- replaced with the join time for brand-new profiles in load()
	accrued = 0,
	fame = 0,
	stageCount = 1,
	roster = {},
	index = {},
	scripts = {},
	films = {},
	cinema = {},
	upgrades = {},
	rewards = {},
	trophies = 0,
	tutorialDone = false,
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
	if type(data.tutorialDone) ~= "boolean" then
		data.tutorialDone = false
	end
	for _, field in { "accrued", "fame", "trophies" } do
		if type(data[field]) ~= "number" or data[field] ~= data[field] or data[field] < 0 then
			data[field] = 0
		end
	end
	if type(data.stageCount) ~= "number" or data.stageCount < 1 then
		data.stageCount = 1
	end
	for _, field in { "scripts", "upgrades", "rewards" } do
		if type(data[field]) ~= "table" then
			data[field] = {}
		end
	end
	for _, field in { "films", "cinema" } do
		if type(data[field]) ~= "table" then
			data[field] = {}
		end
	end
	data.version = CURRENT_VERSION
end

-- Yields. Returns the player's data, or nil if it could not be loaded safely.
-- Callers must never substitute defaults on nil: that could overwrite a real profile.
function DataService.load(player: Player): PlayerData?
	local userId = player.UserId
	-- A rejoin waits for the previous session's save to finish, but not forever: if the DataStore is
	-- struggling we give up (the caller kicks) rather than leave the player hanging.
	local waited = 0
	while releasing[userId] do
		if waited >= RELEASE_WAIT_SECONDS then
			warn(`[DataService] gave up waiting for {userId}'s previous session to release`)
			return nil
		end
		task.wait(0.2)
		waited += 0.2
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
		-- Brand-new profile: royalties start now, and a little starting Cash for the tutorial.
		profile.Data.lastCollect = os.time()
		profile.Data.cash = Config.StartingCash
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
	-- Hold off a rejoin on this server until the release has gone through (bounded; ProfileStore
	-- keeps retrying the save on its own after we stop waiting).
	local waited = 0
	while profile:IsActive() and waited < RELEASE_WAIT_SECONDS do
		task.wait(0.1)
		waited += 0.1
	end
	releasing[userId] = nil
end

return DataService
