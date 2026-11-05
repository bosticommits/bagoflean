--!strict
-- Numbers that count up: the HUD Cash/Fame and reward texts ("+$5,000") roll to their new value
-- instead of jumping. Pure helpers; the client's Juice module does the animating.
local CountUp = {}

-- "1234567" -> "1,234,567" (whole numbers, a minus sign kept).
function CountUp.comma(n: number): string
	local s = tostring(math.abs(math.floor(n + 0.5)))
	local formatted = (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
	return if n <= -0.5 then "-" .. formatted else formatted
end

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

-- Finds the first Cash amount in a text ("You got $5,000!"): the text before it (including "$"),
-- the amount and the text after it. nil when there is none.
function CountUp.splitCash(text: string): (string?, number?, string?)
	local first, last = string.find(text, "%$[%d,]*%d")
	if first == nil or last == nil then
		return nil, nil, nil
	end
	local amount = tonumber((string.sub(text, first + 1, last):gsub(",", "")))
	if amount == nil then
		return nil, nil, nil
	end
	return string.sub(text, 1, first), amount, string.sub(text, last + 1)
end

-- A rise worth a pop: at least 5% of what the player had (and at least 10), so the steady
-- trickle of a big balance stays calm.
function CountUp.noticeable(before: number, after: number): boolean
	local delta = after - before
	return delta >= 10 and delta >= before * 0.05
end

return CountUp
