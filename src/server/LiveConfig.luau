--!strict
-- Settings that can change without publishing an update, read from the "GameConfig" DataStore
-- every minute. Two lists today: codes to switch off, and special events to switch off. From
-- Studio's command bar (with API access on, see the README) run, for example:
--   game:GetService("DataStoreService"):GetDataStore("GameConfig"):SetAsync("DisabledCodes", { "PREMIERE" })
--   game:GetService("DataStoreService"):GetDataStore("GameConfig"):SetAsync("DisabledEvents", { "CashRain" })
--   game:GetService("DataStoreService"):GetDataStore("GameConfig"):SetAsync("Numbers", { GiftCashMultiplier = 1.25 })
-- and every live server stops accepting that code, or running that event, within a minute.
-- { "ALL" } switches every special event off; an empty list {} turns them all back on.
-- "FilmFestival" in DisabledEvents switches the weekly Film Festival off (its goals and laurels).
-- "GlobalPulls" switches the cross-server Legend/Icon news off (sending and showing).
-- Numeric overrides are an explicit allowlist (Shared.LiveConfigNumbers); invalid/out-of-range
-- values are ignored, and a failed read keeps the last known values.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NumberConfig = require(ReplicatedStorage.Shared.LiveConfigNumbers)
local NumberDefinitions: { [string]: { default: number, min: number, max: number } } = NumberConfig.Definitions

local REFRESH_SECONDS = 60

local disabledCodes: { [string]: boolean } = {}
local disabledEvents: { [string]: boolean } = {}
local numbers: { [string]: number } = {}
local invalidNumberLogged: { [string]: boolean } = {}

local LiveConfig = {}

-- Reads a list of names from GameConfig as an upper-case set. nil when the read failed.
local function readList(key: string): { [string]: boolean }?
	local ok, value = pcall(function()
		return DataStoreService:GetDataStore("GameConfig"):GetAsync(key)
	end)
	if not ok then
		return nil
	end
	local set: { [string]: boolean } = {}
	if type(value) == "table" then
		for _, name in value do
			if type(name) == "string" then
				set[string.upper(name)] = true
			end
		end
	end
	return set
end

local function refresh()
	disabledCodes = readList("DisabledCodes") or disabledCodes
	disabledEvents = readList("DisabledEvents") or disabledEvents
	local ok, value = pcall(function()
		return DataStoreService:GetDataStore("GameConfig"):GetAsync("Numbers")
	end)
	if ok then
		local nextNumbers: { [string]: number } = {}
		if type(value) == "table" then
			for key, raw in value do
				local clean = if type(key) == "string" then NumberConfig.clean(key, raw) else nil
				if clean ~= nil then
					nextNumbers[key] = clean
				elseif type(key) == "string" and NumberDefinitions[key] ~= nil and not invalidNumberLogged[key] then
					invalidNumberLogged[key] = true
					warn(`[LiveConfig] ignored out-of-range or invalid number for {key}`)
				end
			end
		end
		numbers = nextNumbers
		for key, definition in NumberDefinitions do
			local effective = numbers[key] or definition.default
			local attribute = "LiveConfig_" .. key
			if ReplicatedStorage:GetAttribute(attribute) ~= effective then
				ReplicatedStorage:SetAttribute(attribute, effective)
			end
		end
	end
end

-- Returns only an allowlisted value. Invalid or absent values fall back to its shipped default.
function LiveConfig.number(key: string): number
	local definition = NumberDefinitions[key]
	if definition == nil then
		return 1
	end
	return numbers[key] or definition.default
end

function LiveConfig.codeDisabled(code: string): boolean
	return disabledCodes[code] == true
end

-- Whether special event `id` (SpecialEvents.List) is switched off, by name or by "ALL".
function LiveConfig.eventDisabled(id: string): boolean
	return disabledEvents.ALL == true or disabledEvents[string.upper(id)] == true
end

-- Whether `id` is listed by name in DisabledEvents ("ALL" does not count). Used for switches that
-- are not special events, e.g. "FirstSuperstar" turns off the new player's guaranteed Superstar.
function LiveConfig.switchedOff(id: string): boolean
	return disabledEvents[string.upper(id)] == true
end

function LiveConfig.start()
	task.spawn(function()
		while true do
			refresh()
			task.wait(REFRESH_SECONDS)
		end
	end)
end

return LiveConfig
