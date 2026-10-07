--!strict
-- Settings that can change without publishing an update, read from the "GameConfig" DataStore
-- every minute. Today that is one list: codes to switch off. From Studio's command bar (with API
-- access on, see the README) run, for example:
--   game:GetService("DataStoreService"):GetDataStore("GameConfig"):SetAsync("DisabledCodes", { "PREMIERE" })
-- and every live server stops accepting that code within a minute. A failed read keeps the last list.
local DataStoreService = game:GetService("DataStoreService")

local REFRESH_SECONDS = 60

local disabledCodes: { [string]: boolean } = {}

local LiveConfig = {}

local function refresh()
	local ok, value = pcall(function()
		return DataStoreService:GetDataStore("GameConfig"):GetAsync("DisabledCodes")
	end)
	if not ok then
		return
	end
	local disabled: { [string]: boolean } = {}
	if type(value) == "table" then
		for _, code in value do
			if type(code) == "string" then
				disabled[string.upper(code)] = true
			end
		end
	end
	disabledCodes = disabled
end

function LiveConfig.codeDisabled(code: string): boolean
	return disabledCodes[code] == true
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
