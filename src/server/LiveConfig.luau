--!strict
-- Settings that can change without publishing an update, read from the "GameConfig" DataStore
-- every minute. Two lists today: codes to switch off, and special events to switch off. From
-- Studio's command bar (with API access on, see the README) run, for example:
--   game:GetService("DataStoreService"):GetDataStore("GameConfig"):SetAsync("DisabledCodes", { "PREMIERE" })
--   game:GetService("DataStoreService"):GetDataStore("GameConfig"):SetAsync("DisabledEvents", { "CashRain" })
-- and every live server stops accepting that code, or running that event, within a minute.
-- { "ALL" } switches every special event off; an empty list {} turns them all back on.
-- A failed read keeps the last list.
local DataStoreService = game:GetService("DataStoreService")

local REFRESH_SECONDS = 60

local disabledCodes: { [string]: boolean } = {}
local disabledEvents: { [string]: boolean } = {}

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
end

function LiveConfig.codeDisabled(code: string): boolean
	return disabledCodes[code] == true
end

-- Whether special event `id` (SpecialEvents.List) is switched off, by name or by "ALL".
function LiveConfig.eventDisabled(id: string): boolean
	return disabledEvents.ALL == true or disabledEvents[string.upper(id)] == true
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
