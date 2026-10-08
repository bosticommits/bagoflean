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
	-- M6 launch features
	passes: { [string]: boolean }, -- game passes confirmed owned (Shop pass key -> true)
	luckBoostUntil: number, -- os.time() the Lucky Casting boost ends
	skips: number, -- unused Skip Filming tokens
	daily: { day: number, streak: number }, -- last UTC day a daily reward was claimed
	requests: { day: number, list: { Request } }, -- today's Studio Requests
	weekly: { week: number, list: { Request } }, -- this week's quests (Rewards.week)
	carried: { Carried }, -- finished quests from earlier days or weeks, still to claim
	codes: { [string]: boolean }, -- redeemed codes
	purchaseIds: { string }, -- recent developer product receipts (grant-once log)
	stayGiftDay: number, -- last UTC day the "don't leave yet" gift was claimed
	funnel: number, -- highest onboarding funnel step logged (analytics)
	-- Achievements: lifetime action counters ("cast", "premiere", ...) and the ones claimed (by id)
	stats: { [string]: number },
	achievements: { [string]: boolean },
	rebirths: number, -- rebirths done (Rebirth.luau); never goes down
	-- Special events: what was picked up in the latest one ("coin3", "crate", "spotlight"), so
	-- rejoining or changing servers during it cannot pick the same thing up twice.
	eventKey: string, -- "<event id>:<start time>"; claims from older events are dropped
	eventClaims: { [string]: boolean },
	-- Studio visits (Visits.luau): applause other players gave this studio (cosmetic, never spent),
	-- and which studios this player toured and applauded today.
	likes: number,
	visits: { day: number, toured: { [string]: boolean }, applauded: { [string]: boolean } },
}

export type Request = { id: string, progress: number, claimed: boolean }
export type Carried = { key: string, id: string, scope: string }

local CURRENT_VERSION = 8 -- 6: rebirths, 7: weekly quests, 8: studio visits
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
	passes = {},
	luckBoostUntil = 0,
	skips = 0,
	daily = { day = 0, streak = 0 },
	requests = { day = 0, list = {} },
	weekly = { week = 0, list = {} },
	carried = {},
	codes = {},
	purchaseIds = {},
	stayGiftDay = 0,
	funnel = 99, -- profiles from before M6 are not new players; load() sets 0 for new ones
	stats = {},
	achievements = {},
	rebirths = 0,
	eventKey = "",
	eventClaims = {},
	likes = 0,
	visits = { day = 0, toured = {}, applauded = {} },
}

-- Developer product receipts remembered per player. Roblox redelivers an unacknowledged receipt
-- on a later join, never years later, so a short log is enough to grant each one exactly once.
local PURCHASE_ID_LOG = 100

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
	for _, field in { "accrued", "fame", "trophies", "luckBoostUntil", "skips", "funnel", "stayGiftDay", "rebirths", "likes" } do
		if type(data[field]) ~= "number" or data[field] ~= data[field] or data[field] < 0 then
			data[field] = 0
		end
	end
	data.rebirths = math.floor(data.rebirths)
	data.likes = math.floor(data.likes)
	if type(data.visits) ~= "table" or type(data.visits.day) ~= "number" or type(data.visits.toured) ~= "table" or type(data.visits.applauded) ~= "table" then
		data.visits = { day = 0, toured = {}, applauded = {} }
	end
	if type(data.stageCount) ~= "number" or data.stageCount < 1 then
		data.stageCount = 1
	end
	if type(data.eventKey) ~= "string" then
		data.eventKey = ""
	end
	for _, field in { "scripts", "upgrades", "rewards", "passes", "codes", "purchaseIds", "eventClaims" } do
		if type(data[field]) ~= "table" then
			data[field] = {}
		end
	end
	for _, field in { "stats", "achievements" } do
		if type(data[field]) ~= "table" then
			data[field] = {}
		end
	end
	for key, value in data.stats do
		if type(key) ~= "string" or type(value) ~= "number" or value ~= value or value < 0 then
			data.stats[key] = nil
		end
	end
	for _, field in { "films", "cinema" } do
		if type(data[field]) ~= "table" then
			data[field] = {}
		end
	end
	if type(data.daily) ~= "table" or type(data.daily.day) ~= "number" or type(data.daily.streak) ~= "number" then
		data.daily = { day = 0, streak = 0 }
	end
	if type(data.requests) ~= "table" or type(data.requests.day) ~= "number" or type(data.requests.list) ~= "table" then
		data.requests = { day = 0, list = {} }
	end
	if type(data.weekly) ~= "table" or type(data.weekly.week) ~= "number" or type(data.weekly.list) ~= "table" then
		data.weekly = { week = 0, list = {} }
	end
	-- Finished quests waiting to be claimed: keep only well-formed entries (see Rewards.carryOver).
	local carried = {}
	if type(data.carried) == "table" then
		for _, waiting in data.carried do
			if type(waiting) == "table" and type(waiting.key) == "string" and type(waiting.id) == "string" and type(waiting.scope) == "string" then
				table.insert(carried, { key = waiting.key, id = waiting.id, scope = waiting.scope })
			end
		end
	end
	data.carried = carried
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
		profile.Data.funnel = 0 -- a new player: log their onboarding funnel
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

-- Yields. Developer product receipts (ProfileStore's purchase-id pattern): applies `grant` to the
-- player's data at most once per purchase id, and returns true only once a save containing both the
-- grant and the id has reached the DataStore. `grant` must not yield, so the two land in one save.
-- On false the receipt stays unprocessed; if the grant did happen, the logged id stops a second one.
function DataService.grantPurchaseOnce(player: Player, purchaseId: string, grant: (PlayerData) -> ()): boolean
	local profile = profiles[player]
	if profile == nil or not profile:IsActive() then
		return false
	end
	local data = profile.Data :: PlayerData
	if table.find(data.purchaseIds, purchaseId) == nil then
		local ok, err = pcall(function()
			grant(data)
		end)
		if not ok then
			warn(`[DataService] purchase {purchaseId} grant failed: {err}`)
			return false
		end
		table.insert(data.purchaseIds, purchaseId)
		while #data.purchaseIds > PURCHASE_ID_LOG do
			table.remove(data.purchaseIds, 1)
		end
	end

	local saved = false
	local function check(lastSaved: any)
		local ids = if type(lastSaved) == "table" then lastSaved.purchaseIds else nil
		if type(ids) == "table" and table.find(ids, purchaseId) ~= nil then
			saved = true
		end
	end
	check(profile.LastSavedData)
	local connection = profile.OnAfterSave:Connect(check)
	if not saved then
		profile:Save()
	end
	local waited = 0
	while not saved and profile:IsActive() and waited < RELEASE_WAIT_SECONDS * 2 do
		task.wait(0.1)
		waited += 0.1
	end
	connection:Disconnect()
	return saved
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
