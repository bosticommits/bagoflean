--!strict
-- Picks where the phone tutorial bubble goes (Tutorial.luau): the first candidate that overlaps no
-- HUD rectangle and not the step's target. Pure so it can be tested.
local BubblePlacer = {}

export type Rect = { x: number, y: number, w: number, h: number }

local function overlapArea(a: Rect, b: Rect, margin: number): number
	local w = math.min(a.x + a.w, b.x + b.w + margin) - math.max(a.x, b.x - margin)
	local h = math.min(a.y + a.h, b.y + b.h + margin) - math.max(a.y, b.y - margin)
	return if w > 0 and h > 0 then w * h else 0
end
BubblePlacer.overlapArea = overlapArea

-- Overlap of a candidate's rects with the obstacles (grown by `margin`), plus the part that falls
-- outside `bounds`, as area. 0 means a clean fit.
function BubblePlacer.cost(rects: { Rect }, obstacles: { Rect }, bounds: Rect, margin: number): number
	local total = 0
	for _, r in rects do
		total += r.w * r.h - overlapArea(r, bounds, 0)
		for _, o in obstacles do
			total += overlapArea(r, o, margin)
		end
	end
	return total
end

-- Index of the first candidate (a list of rects) with zero cost, or nil.
function BubblePlacer.firstFree(candidates: { { Rect } }, obstacles: { Rect }, bounds: Rect, margin: number): number?
	for i, rects in candidates do
		if BubblePlacer.cost(rects, obstacles, bounds, margin) == 0 then
			return i
		end
	end
	return nil
end

-- Last resort: the least-overlap candidate that does not touch `target` (any, if all touch it).
function BubblePlacer.leastOverlap(candidates: { { Rect } }, obstacles: { Rect }, target: Rect?, bounds: Rect, margin: number): number
	local best, bestCost, bestHitsTarget = 1, math.huge, true
	for i, rects in candidates do
		local hits = false
		if target ~= nil then
			for _, r in rects do
				hits = hits or overlapArea(r, target, 0) > 0
			end
		end
		local cost = BubblePlacer.cost(rects, obstacles, bounds, margin)
		if (bestHitsTarget and not hits) or (hits == bestHitsTarget and cost < bestCost) then
			best, bestCost, bestHitsTarget = i, cost, hits
		end
	end
	return best
end

-- The bubble's height without waiting for Roblox to lay it out. The screenplay font is monospace
-- (0.6 em per character, 1.17 em per line), so greedy word wrapping can be counted exactly. Adds the
-- cue line, the 8 + 10 px padding, the 8 px gap and the 3 px border either side.
function BubblePlacer.cardHeight(text: string, width: number, textSize: number): number
	local perLine = math.max(1, math.floor((width - 24) / (textSize * 0.6)))
	local lines, used = 1, 0
	for word in string.gmatch(text, "%S+") do
		local len = utf8.len(word) or #word
		if used > 0 and used + 1 + len > perLine then
			lines += 1
			used = 0
		end
		used += (if used > 0 then 1 else 0) + len
		while used > perLine do -- a word longer than the line is broken by the label
			lines += 1
			used -= perLine
		end
	end
	return math.ceil((lines + 1) * textSize * 1.17) + 18 + 8 + 6
end

return BubblePlacer
