local H = require("./harness")
local DayNight = H.require("DayNight")
local test, expect, equal = H.test, H.expect, H.equal

local DAY = DayNight.DAY_SECONDS

test("the same server time gives the same sky on every server", function()
	for _, t in { 0, 1234.5, 1_700_000_000, 1_800_000_321.25 } do
		local c1, p1 = DayNight.at(t)
		local c2, p2 = DayNight.at(t + DAY * 7)
		expect(math.abs(c1 - c2) < 1e-6, `clock repeats every day at {t}`)
		equal(p1, p2)
		expect(c1 >= 0 and c1 < 24, `clock {c1} is a time of day`)
	end
	expect(DAY >= 20 * 60 and DAY <= 30 * 60, "a day lasts 20 to 30 minutes")
end)

test("night is short and the golden afternoon is long", function()
	local counts: { [string]: number } = {}
	local steps = 2400
	local last = nil
	for i = 0, steps - 1 do
		local clock, phase = DayNight.at(i / steps * DAY)
		counts[phase] = (counts[phase] or 0) + 1
		if last ~= nil then
			-- The clock only moves forward (wrapping at midnight), never jumps.
			local step = (clock - last) % 24
			expect(step < 0.2, `clock moves smoothly at step {i}`)
		end
		last = clock
	end
	local night = (counts.night or 0) / steps
	local golden = (counts.golden or 0) / steps
	expect(night > 0.1 and night <= 0.25, `night is short ({night})`)
	expect(golden > night * 1.5, `golden afternoon ({golden}) is longer than night`)
	expect(golden >= (counts.day or 0) / steps, "golden afternoon is the longest stretch")
end)

test("darkness: day is light, night is dark but eases in", function()
	equal(DayNight.darkness(13), 0)
	equal(DayNight.darkness(16), 0)
	equal(DayNight.darkness(22), 1)
	equal(DayNight.darkness(2), 1)
	local dusk = DayNight.darkness(18.3)
	expect(dusk > 0 and dusk < 1, "dusk is in between")
	expect(DayNight.darkness(17.5) == 0, "Golden Hour's sky (17.5) counts as day")
	local _, phase = DayNight.at(DAY * 0.85)
	equal(phase, "night")
end)
