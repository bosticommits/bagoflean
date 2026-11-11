--!strict
local Clock = {}

-- "m:ss", or "h:mm:ss" past an hour.
function Clock.format(seconds: number): string
	local total = math.max(0, math.ceil(seconds))
	local h, m, sec = total // 3600, (total % 3600) // 60, total % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, sec)
	end
	return string.format("%d:%02d", m, sec)
end

return Clock
