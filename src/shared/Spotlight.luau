--!strict
-- The four dim rectangles around a cut-out hole (Tutorial.luau). Pure so it can be tested.
local Spotlight = {}

export type Rect = { x: number, y: number, w: number, h: number }

-- Top, bottom, left, right bands covering the area except the target box padded by `pad`.
-- The hole is clamped inside the area, so a target half off-screen leaves no negative sizes.
function Spotlight.rects(areaW: number, areaH: number, x: number, y: number, w: number, h: number, pad: number): { Rect }
	local x0 = math.clamp(x - pad, 0, areaW)
	local y0 = math.clamp(y - pad, 0, areaH)
	local x1 = math.clamp(x + w + pad, x0, areaW)
	local y1 = math.clamp(y + h + pad, y0, areaH)
	return {
		{ x = 0, y = 0, w = areaW, h = y0 },
		{ x = 0, y = y1, w = areaW, h = areaH - y1 },
		{ x = 0, y = y0, w = x0, h = y1 - y0 },
		{ x = x1, y = y0, w = areaW - x1, h = y1 - y0 },
	}
end

return Spotlight
