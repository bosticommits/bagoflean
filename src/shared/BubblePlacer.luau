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

-- Placement ---------------------------------------------------------------------------------------
export type Pick = {
	bustRight: number,
	bustY: number,
	cardRight: number,
	cardY: number,
	width: number,
	textSize: number,
	clean: boolean, -- no overlap at all; false for a last-resort pick
}

export type Input = {
	areaW: number,
	areaH: number,
	hud: { Rect }, -- visible HUD parts
	panels: { Rect }, -- open panels (they move aside for the bubble, so they only decide the pick)
	target: Rect?, -- the step's target
	bust: number, -- bust size
	text: string, -- the line shown
	maxWidth: number, -- card width to try first
	margin: number, -- clearance from everything, also from the screen edge
	previous: Pick?, -- the last pick: kept while it stays clean
}

local BORDER = 3 -- the card and bust outlines draw this far outside their frames
-- Spots keep margin + BORDER from neighbours so the drawn outline still clears them.
local TIERS = { { 1, 16 }, { 220, 15 }, { 200, 14 } } -- width (1 = Input.maxWidth), TextSize

local function grow(r: Rect, by: number): Rect
	return { x = r.x - by, y = r.y - by, w = r.w + 2 * by, h = r.h + 2 * by }
end

local function spotRects(p: Pick, bust: number, h: number): { Rect }
	return {
		grow({ x = p.bustRight - bust, y = p.bustY, w = bust, h = bust }, BORDER),
		grow({ x = p.cardRight - p.width, y = p.cardY, w = p.width, h = h }, BORDER),
	}
end

-- The candidate spots, in order: under the bust, left of the bust, bottom centre above whatever
-- sits at the bottom (the CAST bar), bottom left, top centre.
function BubblePlacer.spots(areaW: number, areaH: number, hud: { Rect }, margin: number, bust: number, w: number, textSize: number, h: number): { Pick }
	local picks: { Pick } = {}
	local function add(bustRight: number, bustY: number, cardRight: number, cardY: number)
		table.insert(picks, { bustRight = bustRight, bustY = bustY, cardRight = cardRight, cardY = cardY, width = w, textSize = textSize, clean = false })
	end
	-- Under the HUD readouts over the band [left, right] in the top 40 % of the screen.
	local function below(left: number, right: number): number
		local lowest = 0
		for _, r in hud do
			if r.y < areaH * 0.4 and r.x < right and r.x + r.w > left then
				lowest = math.max(lowest, r.y + r.h)
			end
		end
		return lowest
	end
	local right = areaW - margin
	local gw, gh = w + 8 + bust, math.max(h, bust)
	local centre = math.floor((areaW - gw) / 2)
	local y1 = below(right - w, right) + margin
	add(right, y1, right, y1 + bust + 6)
	local y2 = below(right - gw, right) + margin
	add(right, y2, right - bust - 8, y2)
	local floor = areaH - margin
	for _, r in hud do
		if r.y > areaH * 0.5 and r.x < centre + gw and r.x + r.w > centre then
			floor = math.min(floor, r.y - margin)
		end
	end
	add(centre + gw, floor - gh, centre + w, floor - gh)
	add(margin + gw, areaH - margin - gh, margin + w, areaH - margin - gh)
	local top = below(centre, centre + gw) + margin
	add(centre + gw, top, centre + w, top)
	return picks
end

-- Where the bubble and bust go. Keeps `previous` while it stays clean (so a toast does not make it
-- hop); else the first clean spot at 260 px, 220 px, then 200 px; else the least-overlap spot that
-- leaves the target alone. (Tutorial skips this while a panel is open and uses the fixed corner.)
function BubblePlacer.place(input: Input): Pick
	local bounds: Rect = { x = 0, y = 0, w = input.areaW, h = input.areaH }
	local obstacles = table.clone(input.hud)
	for _, r in input.panels do
		table.insert(obstacles, r)
	end
	if input.target ~= nil then
		table.insert(obstacles, input.target)
	end
	local function heightFor(width: number, textSize: number): number
		return BubblePlacer.cardHeight(input.text, width, textSize)
	end
	local prev = input.previous
	if prev ~= nil and prev.clean then
		if BubblePlacer.cost(spotRects(prev, input.bust, heightFor(prev.width, prev.textSize)), obstacles, bounds, input.margin) == 0 then
			return prev
		end
	end
	local all: { Pick } = {}
	local allRects: { { Rect } } = {}
	for _, tier in TIERS do
		local w = if tier[1] == 1 then math.min(input.maxWidth, 260) else tier[1]
		local h = heightFor(w, tier[2])
		for _, pick in BubblePlacer.spots(input.areaW, input.areaH, input.hud, input.margin + BORDER, input.bust, w, tier[2], h) do
			local rects = spotRects(pick, input.bust, h)
			if BubblePlacer.cost(rects, obstacles, bounds, input.margin) == 0 then
				pick.clean = true
				return pick
			end
			table.insert(all, pick)
			table.insert(allRects, rects)
		end
	end
	return all[BubblePlacer.leastOverlap(allRects, obstacles, input.target, bounds, input.margin)]
end

return BubblePlacer
