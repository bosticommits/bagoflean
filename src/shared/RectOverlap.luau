--!strict
-- Pure rectangle maths (px), so tests/luau can check it outside Roblox. The tutorial arrow uses it to hide
-- only when it (or its target) would draw over an open panel.
local RectOverlap = {}

export type Rect = { x: number, y: number, w: number, h: number }

-- True when the two rects share area (touching edges do not count).
function RectOverlap.overlaps(a: Rect, b: Rect): boolean
	return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

-- `r` grown by `by` px on every side.
function RectOverlap.inflate(r: Rect, by: number): Rect
	return { x = r.x - by, y = r.y - by, w = r.w + 2 * by, h = r.h + 2 * by }
end

-- True when `r` overlaps any rect in `list`.
function RectOverlap.overlapsAny(r: Rect, list: { Rect }): boolean
	for _, other in list do
		if RectOverlap.overlaps(r, other) then
			return true
		end
	end
	return false
end

return RectOverlap
