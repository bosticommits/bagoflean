--!strict
-- Explicit allowlist of tunable live values and safe bounds. Unknown keys are ignored.
-- Keep defaults equal to the normal game rules; live config changes are temporary overrides.

export type Definition = { default: number, min: number, max: number }

local definitions: { [string]: Definition } = {
	CastingLuckMultiplier = { default = 1, min = 0.5, max = 2 },
	GiftCashMultiplier = { default = 1, min = 0.5, max = 2 },
	EventCoinMultiplier = { default = 1, min = 0.5, max = 2 },
	EventWeight_LuckyStar = { default = 1, min = 0, max = 5 },
	EventWeight_CashRain = { default = 1, min = 0, max = 5 },
	EventWeight_MysteryCrate = { default = 1, min = 0, max = 5 },
	EventWeight_Spotlight = { default = 1, min = 0, max = 5 },
	EventWeight_GoldenHour = { default = 1, min = 0, max = 5 },
	EventWeight_PumpkinPatch = { default = 1, min = 0, max = 5 },
	UpdateAt = { default = 0, min = 0, max = 4e9 }, -- os.time of a planned update restart; 0 = none
}

-- Accept only explicitly listed finite numbers within their safe ranges. Nil means ignore/reset.
local function clean(key: string, raw: unknown): number?
	local definition = definitions[key]
	if definition == nil or type(raw) ~= "number" or raw ~= raw or raw <= -math.huge or raw >= math.huge then
		return nil
	end
	if raw < definition.min or raw > definition.max then
		return nil
	end
	return raw
end

local WARN_SECONDS = 600

-- Seconds until a planned update restart while inside the warning window, else nil.
local function updateWarning(updateAt: number, now: number): number?
	local left = updateAt - now
	if left > 0 and left <= WARN_SECONDS then
		return left
	end
	return nil
end

return table.freeze({ Definitions = table.freeze(definitions), clean = clean, updateWarning = updateWarning })
