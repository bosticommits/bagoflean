--!strict
-- The four dim rectangles around a cut-out hole (Tutorial.luau). Pure so it can be tested.
local Spotlight = {}

export type Rect = { x: number, y: number, w: number, h: number }

-- Top, bottom, left, right bands covering the area except the target box padded by `pad`.
-- The hole is clamped inside the area, so a target half off-screen leaves no negative sizes.
function Spotlight.rects(areaW: number, areaH: number, x: number, y: number, w: number, h: number, pad: number): { Rect }
	-- Whole pixels: starts floor, ends ceil, so neighbouring bands share an edge (no 1 px seam) and
	-- the hole only ever grows by a fraction of a pixel.
	local x0 = math.floor(math.clamp(x - pad, 0, areaW))
	local y0 = math.floor(math.clamp(y - pad, 0, areaH))
	local x1 = math.ceil(math.clamp(x + w + pad, x0, areaW))
	local y1 = math.ceil(math.clamp(y + h + pad, y0, areaH))
	return {
		{ x = 0, y = 0, w = areaW, h = y0 },
		{ x = 0, y = y1, w = areaW, h = areaH - y1 },
		{ x = 0, y = y0, w = x0, h = y1 - y0 },
		{ x = x1, y = y0, w = areaW - x1, h = y1 - y0 },
	}
end

return Spotlight
