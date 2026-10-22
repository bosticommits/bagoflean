--!strict
-- Where players may walk, and the invisible walls round it. The walkable ground is a list of
-- rectangles on the ground plane (the boulevard, the sidewalks, the paths, the lots, the park
-- walks, Dusty Gulch's street); everything else (grass, desert, scenery) is off limits.
-- `walls` traces the outline of all the rectangles together and returns one wall segment per
-- straight stretch of that outline, so walls run along the exact borders of the paths and never
-- cross one.
local Walkways = {}

export type Rect = { x0: number, z0: number, x1: number, z1: number } -- x0 < x1, z0 < z1

-- A stretch of outline: from `a` to `b` (same x or same z). `out` points away from the walkable
-- side (+1 or -1 along the axis the wall is not running along).
export type Wall = { a: Vector2, b: Vector2, out: number, alongX: boolean }

function Walkways.rect(x0: number, z0: number, x1: number, z1: number): Rect
	return { x0 = math.min(x0, x1), z0 = math.min(z0, z1), x1 = math.max(x0, x1), z1 = math.max(z0, z1) }
end

function Walkways.isWalkable(rects: { Rect }, x: number, z: number): boolean
	for _, r in rects do
		if x >= r.x0 and x <= r.x1 and z >= r.z0 and z <= r.z1 then
			return true
		end
	end
	return false
end

-- How far (x, z) is from the nearest walkable ground: 0 when on it.
function Walkways.distance(rects: { Rect }, x: number, z: number): number
	local best = math.huge
	for _, r in rects do
		local dx = math.max(r.x0 - x, 0, x - r.x1)
		local dz = math.max(r.z0 - z, 0, z - r.z1)
		best = math.min(best, math.sqrt(dx * dx + dz * dz))
	end
	return best
end

local function sortedEdges(rects: { Rect }, low: string, high: string): { number }
	local seen: { [number]: boolean } = {}
	local list = {}
	for _, r in rects do
		for _, value in { (r :: any)[low] :: number, (r :: any)[high] :: number } do
			if not seen[value] then
				seen[value] = true
				table.insert(list, value)
			end
		end
	end
	table.sort(list)
	return list
end

-- The outline of the union of `rects`, as straight wall segments. Works on a grid cut at every
-- rectangle edge, so each cell is wholly walkable or not; a wall goes wherever a walkable cell
-- meets one that isn't, and neighbouring pieces in a line join into one segment.
function Walkways.walls(rects: { Rect }): { Wall }
	local xs = sortedEdges(rects, "x0", "x1")
	local zs = sortedEdges(rects, "z0", "z1")
	local nx, nz = #xs - 1, #zs - 1
	local cells: { { boolean } } = {}
	for i = 1, nx do
		cells[i] = {}
		local cx = (xs[i] + xs[i + 1]) / 2
		for j = 1, nz do
			cells[i][j] = Walkways.isWalkable(rects, cx, (zs[j] + zs[j + 1]) / 2)
		end
	end
	local function walk(i: number, j: number): boolean
		return i >= 1 and i <= nx and j >= 1 and j <= nz and cells[i][j]
	end

	local walls: { Wall } = {}
	-- Walls running along z, at x = xs[i], between cell column i-1 and i.
	for i = 1, nx + 1 do
		local runStart: number?, runOut = nil, 0
		for j = 1, nz + 1 do
			local left, right = walk(i - 1, j), walk(i, j)
			local out = if left and not right then 1 elseif right and not left then -1 else 0
			if out ~= runOut then
				if runStart ~= nil and runOut ~= 0 then
					table.insert(walls, { a = Vector2.new(xs[i], zs[runStart]), b = Vector2.new(xs[i], zs[j]), out = runOut, alongX = false })
				end
				runStart, runOut = j, out
			end
		end
	end
	-- Walls running along x, at z = zs[j], between cell row j-1 and j.
	for j = 1, nz + 1 do
		local runStart: number?, runOut = nil, 0
		for i = 1, nx + 1 do
			local below, above = walk(i, j - 1), walk(i, j)
			local out = if below and not above then 1 elseif above and not below then -1 else 0
			if out ~= runOut then
				if runStart ~= nil and runOut ~= 0 then
					table.insert(walls, { a = Vector2.new(xs[runStart], zs[j]), b = Vector2.new(xs[i], zs[j]), out = runOut, alongX = true })
				end
				runStart, runOut = i, out
			end
		end
	end
	return walls
end

return Walkways
