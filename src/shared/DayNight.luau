--!strict
-- The town's day: the time of day is worked out from the server clock alone, so every server and
-- every player sees the same sky at the same moment (like Award Night). One day is 24 minutes:
-- a quick dawn, a sunny morning, a long golden afternoon, a sunset, and a short dusky-blue night.
-- src/client/DayNightWorld.luau sets the sky from it; special events take the sky over while they run.
local DayNight = {}

DayNight.DAY_SECONDS = 24 * 60

-- Each stretch of the day: where it starts (fraction of the day), and the clock (hours) at its
-- start. The clock runs evenly from one start to the next; past midnight it counts on above 24.
local STRETCHES = {
	{ from = 0.00, clock = 5.6, phase = "dawn" },
	{ from = 0.08, clock = 8, phase = "day" },
	{ from = 0.30, clock = 14, phase = "golden" }, -- the long golden afternoon (about 9 minutes)
	{ from = 0.68, clock = 17.6, phase = "dusk" },
	{ from = 0.78, clock = 18.9, phase = "night" }, -- the short night (about 5 minutes)
	{ from = 1.00, clock = 24 + 5.6, phase = "dawn" },
}

-- How far through the day `serverTime` is, 0 (dawn) to 1.
function DayNight.fraction(serverTime: number): number
	return (serverTime % DayNight.DAY_SECONDS) / DayNight.DAY_SECONDS
end

-- Lighting.ClockTime (0-24) and the phase ("dawn", "day", "golden", "dusk" or "night") at `serverTime`.
function DayNight.at(serverTime: number): (number, string)
	local f = DayNight.fraction(serverTime)
	for i = 1, #STRETCHES - 1 do
		local a, b = STRETCHES[i], STRETCHES[i + 1]
		if f < b.from then
			local u = (f - a.from) / (b.from - a.from)
			return (a.clock + (b.clock - a.clock) * u) % 24, a.phase
		end
	end
	return STRETCHES[1].clock, STRETCHES[1].phase
end

-- How dark it is at Lighting.ClockTime `clock`: 0 in daylight, 1 at night, easing in through the
-- sunset (17.6 to 19) and out through the dawn (5 to 6.6). Used for lamps, signs and the blue tint,
-- so they follow whatever the sky shows, events included.
function DayNight.darkness(clock: number): number
	local function ease(x: number): number
		x = math.clamp(x, 0, 1)
		return x * x * (3 - 2 * x)
	end
	if clock >= 12 then
		return ease((clock - 17.6) / 1.4)
	end
	return 1 - ease((clock - 5) / 1.6)
end

return DayNight
