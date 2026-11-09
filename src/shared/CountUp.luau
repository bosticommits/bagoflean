--!strict
-- Numbers that count up: the HUD Cash/Fame and "+$X" texts roll to their new value
-- instead of jumping. Pure helpers; the client's Juice module does the animating.
local CountUp = {}

-- The value shown `alpha` (0..1) of the way from `from` to `to`, eased out (fast, then settling),
-- in whole numbers and landing exactly on `to`.
function CountUp.at(from: number, to: number, alpha: number): number
	if alpha >= 1 then
		return to
	end
	local t = math.clamp(alpha, 0, 1)
	local eased = 1 - (1 - t) * (1 - t)
	return math.floor(from + (to - from) * eased + 0.5)
end

-- A rise worth a pop: at least 5% of what the player had (and at least 10), so the steady
-- trickle of a big balance stays calm.
function CountUp.noticeable(before: number, after: number): boolean
	local delta = after - before
	return delta >= 10 and delta >= before * 0.05
end

return CountUp
