--!strict
-- Owns player persistence. One DataStore record per player: { lock, data }.
-- Session locking: a server only loads a profile after writing its own lock into the record.
-- A lock held by another server is respected until it is released or goes stale (no heartbeat).
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

export type PlayerData = {
	version: number,
	cash: number,
	lastCollect: number, -- os.time() of the last cinema collect
}

type Lock = { owner: string, time: number }
type SessionRecord = { lock: Lock?, data: PlayerData }
type Session = {
	player: Player,
	key: string,
	data: PlayerData,
	dirty: boolean,
	saving: boolean,
	lost: boolean,
}

local STORE_NAME = "PlayerData_v1"
local CURRENT_VERSION = 1
local LOCK_STALE_SECONDS = 120 -- must be well above HEARTBEAT_SECONDS
local HEARTBEAT_SECONDS = 30 -- autosave and lock refresh
local LOCK_RETRY_SECONDS = 4
local LOCK_RETRY_ATTEMPTS = 8
local API_RETRIES = 4
local SHUTDOWN_WAIT_SECONDS = 25

local SERVER_ID = HttpService:GenerateGUID(false)
-- In Studio, an unpublished place or disabled API access makes DataStore calls fail. Fall back to
-- memory there so playtests still work. Outside Studio this never happens: loads fail and kick.
local useMock = false
local mockRecords: { [string]: SessionRecord } = {}

local function isStudioApiError(message: string): boolean
	return RunService:IsStudio()
		and (string.find(message, "Studio access", 1, true) ~= nil or string.find(message, "publish this place", 1, true) ~= nil)
end

local storeOk, storeOrError = pcall(function()
	return DataStoreService:GetDataStore(STORE_NAME)
end)
local store: DataStore = if storeOk then storeOrError else nil :: any
if not storeOk then
	if isStudioApiError(tostring(storeOrError)) then
		warn("[DataService] DataStore unavailable in Studio; using in-memory data (nothing is saved).")
		useMock = true
	else
		error(storeOrError)
	end
end

local sessions: { [Player]: Session } = {}
local releasing: { [number]: boolean } = {}
local inflightReleases = 0

local DataService = {}

local function newData(): PlayerData
	return {
		version = CURRENT_VERSION,
		cash = Config.StartingCash,
		lastCollect = os.time(),
	}
end

-- Fill missing or malformed fields. Extend with `if version < N` steps when the schema changes.
local function migrate(raw: any): PlayerData
	local data: any = if type(raw) == "table" then table.clone(raw) else {}
	local defaults = newData()
	if type(data.cash) ~= "number" or data.cash ~= data.cash or data.cash < 0 then
		data.cash = defaults.cash
	end
	if type(data.lastCollect) ~= "number" then
		data.lastCollect = defaults.lastCollect
	end
	data.version = CURRENT_VERSION
	return data :: PlayerData
end

local function update(key: string, transform: (SessionRecord?) -> SessionRecord?): (boolean, string?)
	if useMock then
		local result = transform(mockRecords[key])
		if result ~= nil then
			mockRecords[key] = result
		end
		return true, nil
	end

	local lastError: string? = nil
	for attempt = 1, API_RETRIES do
		local ok, err = pcall(function()
			store:UpdateAsync(key, transform)
		end)
		if ok then
			return true, nil
		end
		lastError = tostring(err)
		if isStudioApiError(lastError) then
			warn("[DataService] DataStore unavailable in Studio; using in-memory data (nothing is saved).")
			useMock = true
			return update(key, transform)
		end
		task.wait(0.5 * 2 ^ attempt + math.random() * 0.25)
	end
	return false, lastError
end

local function save(session: Session, release: boolean): boolean
	while session.saving do
		task.wait()
	end
	if session.lost then
		return false
	end
	session.saving = true

	local snapshot = table.clone(session.data)
	session.dirty = false
	local lockLost = false
	local ok, err = update(session.key, function(old)
		lockLost = false
		if old == nil or old.lock == nil or old.lock.owner ~= SERVER_ID then
			lockLost = true
			return nil
		end
		return {
			lock = if release then nil else { owner = SERVER_ID, time = os.time() },
			data = snapshot,
		}
	end)
	session.saving = false

	if lockLost then
		session.lost = true
		warn(`[DataService] lost session lock for {session.key}`)
		if session.player.Parent == Players then
			session.player:Kick("Your data session was taken over by another server. Please rejoin.")
		end
		return false
	end
	if not ok then
		session.dirty = true
		warn(`[DataService] save failed for {session.key}: {err}`)
		return false
	end
	return true
end

-- Yields. Returns the player's data, or nil if it could not be loaded safely.
-- Callers must never substitute defaults on nil: that could overwrite a real profile.
function DataService.load(player: Player): PlayerData?
	local userId = player.UserId
	local key = "player_" .. userId

	while releasing[userId] do
		task.wait(0.2)
	end

	for _ = 1, LOCK_RETRY_ATTEMPTS do
		if player.Parent ~= Players then
			return nil
		end

		local blocked = false
		local loaded: PlayerData? = nil
		local ok, err = update(key, function(old)
			blocked = false
			loaded = nil
			local now = os.time()
			if old ~= nil and old.lock ~= nil and old.lock.owner ~= SERVER_ID and now - old.lock.time < LOCK_STALE_SECONDS then
				blocked = true
				return nil
			end
			local data = migrate(if old ~= nil then old.data else nil)
			loaded = data
			return { lock = { owner = SERVER_ID, time = now }, data = data }
		end)

		if not ok then
			warn(`[DataService] load failed for {key}: {err}`)
			return nil
		end
		if loaded ~= nil then
			sessions[player] = {
				player = player,
				key = key,
				data = loaded,
				dirty = false,
				saving = false,
				lost = false,
			}
			return loaded
		end
		if not blocked then
			return nil
		end
		task.wait(LOCK_RETRY_SECONDS)
	end
	warn(`[DataService] {key} is locked by another server`)
	return nil
end

-- Live data for gameplay code. Nil while loading, after the lock is lost, or after release.
function DataService.getData(player: Player): PlayerData?
	local session = sessions[player]
	if session == nil or session.lost then
		return nil
	end
	return session.data
end

function DataService.markDirty(player: Player)
	local session = sessions[player]
	if session ~= nil then
		session.dirty = true
	end
end

-- Final save plus lock release. Safe to call more than once.
function DataService.release(player: Player)
	local session = sessions[player]
	if session == nil then
		return
	end
	sessions[player] = nil
	releasing[player.UserId] = true
	inflightReleases += 1

	for attempt = 1, 3 do
		if save(session, true) or session.lost then
			break
		end
		task.wait(attempt)
	end

	releasing[player.UserId] = nil
	inflightReleases -= 1
end

task.spawn(function()
	while true do
		task.wait(HEARTBEAT_SECONDS)
		for _, session in sessions do
			task.spawn(save, session, false)
		end
	end
end)

game:BindToClose(function()
	local remaining = {}
	for player in sessions do
		table.insert(remaining, player)
	end
	for _, player in remaining do
		task.spawn(DataService.release, player)
	end
	local started = os.clock()
	while inflightReleases > 0 and os.clock() - started < SHUTDOWN_WAIT_SECONDS do
		task.wait(0.1)
	end
end)

return DataService
