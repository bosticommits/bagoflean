local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local H = require("./harness")
local MapModels = H.require("Models/MapModels")
local LotModels = H.require("Models/LotModels")
local MapKit = H.require("Models/MapKit")
local MapScenery = H.require("Models/MapScenery")
local Walkways = H.require("Models/Walkways")
local SpecialEvents = H.require("SpecialEvents")
local test, expect, equal = H.test, H.expect, H.equal

local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame
local Color3 = roblox.Color3
local Lay = MapModels.Layout
local LOT_HALF = LotModels.Layout.size / 2

local town = roblox.Instance.new("Folder")
local built = MapModels.build(town)

-- A part's world-space bounding box (corners min, max), including any turn.
local function bounds(part: any): (any, any)
	local cf, size = part.CFrame, part.Size / 2
	local extent = Vector3.new(
		math.abs(cf.RightVector.X) * size.X + math.abs(cf.UpVector.X) * size.Y + math.abs(cf.LookVector.X) * size.Z,
		math.abs(cf.RightVector.Y) * size.X + math.abs(cf.UpVector.Y) * size.Y + math.abs(cf.LookVector.Y) * size.Z,
		math.abs(cf.RightVector.Z) * size.X + math.abs(cf.UpVector.Z) * size.Y + math.abs(cf.LookVector.Z) * size.Z
	)
	return cf.Position - extent, cf.Position + extent
end

local function lotSquares(): { { x: number, z: number } }
	local squares = {}
	for index = 1, 6 do
		local p = MapModels.lotBase(index).Position
		table.insert(squares, { x = p.X, z = p.Z })
	end
	return squares
end

-- Scenery that is meant to reach under or into other things.
local SKIP = { Ground = true, Hill = true, GateRamp = true }

test("lots sit where they always did and face the boulevard", function()
	for index = 1, 6 do
		local base = MapModels.lotBase(index)
		local col, row = (index - 1) % 3, (index - 1) // 3
		equal(base.Position.X, (col - 1) * 80, `lot {index} x`)
		equal(base.Position.Z, if row == 0 then -70 else 70, `lot {index} z`)
		-- Lot-space -Z (the gate side, a CFrame's LookVector) points at z = 0.
		expect(base.LookVector.Z * base.Position.Z < 0, `lot {index} faces the boulevard`)
	end
end)

test("nothing in the town is built inside a lot", function()
	for _, part in town:GetDescendants() do
		if part:IsA("BasePart") and not SKIP[part.Name] then
			local lo, hi = bounds(part)
			for _, lot in lotSquares() do
				local inside = lo.X < lot.x + LOT_HALF - 0.05
					and hi.X > lot.x - LOT_HALF + 0.05
					and lo.Z < lot.z + LOT_HALF - 0.05
					and hi.Z > lot.z - LOT_HALF + 0.05
				expect(not inside, `{part:GetFullName()} at {part.CFrame.Position} overlaps the lot at {lot.x}, {lot.z}`)
			end
		end
	end
end)

test("every lot gate has a ramp up from the sidewalk", function()
	local ramps = 0
	for _, part in town:GetDescendants() do
		if part.Name == "GateRamp" then
			ramps += 1
			local lo, hi = bounds(part)
			expect(math.abs(lo.Y - 0.2) < 0.01 and math.abs(hi.Y - 1) < 0.01, "ramp runs from the sidewalk to the lot floor")
			expect(math.min(math.abs(lo.Z), math.abs(hi.Z)) >= Lay.sidewalkTo - 3.01, "ramp is in front of a gate")
		end
	end
	equal(ramps, 6, "ramps")
end)

test("stands stand on the sidewalk, clear of the road, the plaza and each other", function()
	local boxes = {}
	for _, stand in built.stands do
		local model = town:FindFirstChild("Stand_" .. stand.info.screen)
		expect(model ~= nil, `stand {stand.info.screen} built`)
		local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				local a, b = bounds(part)
				lo, hi = lo:Min(a), hi:Max(b)
				-- Closest point of this part to the plaza's centre.
				local nearX = if a.X > 0 then a.X elseif b.X < 0 then -b.X else 0
				local nearZ = if a.Z > 0 then a.Z elseif b.Z < 0 then -b.Z else 0
				expect(math.sqrt(nearX ^ 2 + nearZ ^ 2) > Lay.plazaRadius + 1, `{stand.info.screen} {part.Name} is on the plaza`)
			end
		end
		expect(math.min(math.abs(lo.Z), math.abs(hi.Z)) > Lay.roadHalf + 1, `{stand.info.screen} is off the road`)
		expect(math.max(math.abs(lo.Z), math.abs(hi.Z)) < Lay.sidewalkTo, `{stand.info.screen} is in front of the lots`)
		for _, other in boxes do
			local apart = lo.X > other.hi.X or hi.X < other.lo.X or lo.Z > other.hi.Z or hi.Z < other.lo.Z
			expect(apart, `{stand.info.screen} overlaps {other.name}`)
		end
		table.insert(boxes, { name = stand.info.screen, lo = lo, hi = hi })
		expect(stand.anchor.Transparency == 1 and not stand.anchor.CanCollide, `{stand.info.screen} prompt anchor is invisible`)
	end
	equal(#boxes, #MapModels.Stands, "stands")
end)

test("every stand opens a screen the client knows", function()
	local registered = {}
	for _, file in fs.readDir("src/client") do
		local source = fs.readFile(`src/client/{file}`)
		for name in string.gmatch(source, 'Screens%.register%("([%w]+)"') do
			registered[name] = true
		end
	end
	local seen = {}
	for _, info in MapModels.Stands do
		expect(registered[info.screen], `stand {info.title} opens "{info.screen}", which no screen registers`)
		expect(not seen[info.screen], `two stands open {info.screen}`)
		seen[info.screen] = true
	end
end)

test("players spawn on the plaza, clear of the fountain", function()
	local p = Lay.spawn.Position
	local fromCentre = math.sqrt(p.X ^ 2 + p.Z ^ 2)
	expect(fromCentre > 11 and fromCentre < Lay.plazaRadius - 3, `spawn {p} is {fromCentre} from the fountain`)
	-- Looking toward the centre of town (past the fountain), not at the edge of the map.
	expect(Lay.spawn.LookVector:Dot(-p.Unit) > 0.9, "spawn faces the fountain")
end)

-- Walkways ---------------------------------------------------------------------------------------

local walk = MapModels.WalkAreas
local function walkable(x: number, z: number): boolean
	return Walkways.isWalkable(walk, x, z)
end

test("everything players need is on walkable ground", function()
	local spawn = Lay.spawn.Position
	expect(walkable(spawn.X, spawn.Z), "spawn")
	for _, info in MapModels.Stands do
		local ring = MapModels.standBase(info) * CFrame.new(0, 0, -7.2)
		expect(walkable(ring.Position.X, ring.Position.Z), `{info.title} prompt ring`)
	end
	for _, spot in SpecialEvents.CoinSpots do
		expect(walkable(spot.X, spot.Z), `coin {spot}`)
	end
	for _, spot in SpecialEvents.CrateSpots do
		expect(walkable(spot.X, spot.Z), `crate {spot}`)
	end
	for index = 1, 6 do
		local gate = MapModels.lotBase(index) * CFrame.new(0, 0, -LOT_HALF - 1.5)
		expect(walkable(gate.Position.X, gate.Position.Z), `lot {index} gate ramp`)
	end
end)

test("every part of the map can be walked to from spawn", function()
	-- Flood the walkable ground on a 2-stud grid, starting at spawn.
	local step = 2
	local seen: { [string]: boolean } = {}
	local spawn = Lay.spawn.Position
	local queue = { { math.round(spawn.X / step), math.round(spawn.Z / step) } }
	seen[`{queue[1][1]},{queue[1][2]}`] = true
	local head = 1
	while head <= #queue do
		local cell = queue[head]
		head += 1
		for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local i, j = cell[1] + d[1], cell[2] + d[2]
			local key = `{i},{j}`
			if not seen[key] and walkable(i * step, j * step) then
				seen[key] = true
				table.insert(queue, { i, j })
			end
		end
	end
	local function reached(x: number, z: number): boolean
		return seen[`{math.round(x / step)},{math.round(z / step)}`] == true
	end
	for index = 1, 6 do
		local p = MapModels.lotBase(index).Position
		expect(reached(p.X, p.Z), `lot {index}`)
	end
	local e = Lay.fenceZ + 1
	for _, place in {
		{ "theatre steps", Lay.theatreX - 2, 0 },
		{ "studio gate road", 170, 0 },
		{ "park movie screen", 0, e + 100 },
		{ "park bandstand", 60, e + 86 },
		{ "park island", -60, e + 84 },
		{ "Dusty Gulch's far end", 0, -e - 145 },
		{ "back path corner", 120, 110 },
	} do
		expect(reached(place[2] :: number, place[3] :: number), place[1] :: string)
	end
end)

local play = MapModels.PlayAreas
local function inPlay(x: number, z: number): boolean
	return Walkways.isWalkable(play, x, z)
end

test("every path lies inside the playable map", function()
	for _, r in walk do
		for _, corner in { { r.x0, r.z0 }, { r.x1, r.z0 }, { r.x0, r.z1 }, { r.x1, r.z1 } } do
			expect(inPlay(corner[1], corner[2]), `path corner {corner[1]}, {corner[2]} is outside the map`)
		end
	end
end)

local mapWalls = {}
for _, part in town:GetDescendants() do
	if part.Name == "MapWall" then
		table.insert(mapWalls, part)
	end
	expect(part.Name ~= "PathWall", "no walls along the paths any more")
end

-- Is there an invisible wall within `reach` studs of (x, z)?
local function wallNear(x: number, z: number, reach: number): boolean
	for _, part in mapWalls do
		local lo, hi = bounds(part)
		if Walkways.distance({ Walkways.rect(lo.X, lo.Z, hi.X, hi.Z) }, x, z) <= reach then
			return true
		end
	end
	return false
end

test("the only invisible walls run round the outside of the map", function()
	expect(#mapWalls >= 12, `only {#mapWalls} walls`)
	for _, part in mapWalls do
		expect(part.Transparency == 1 and part.CanCollide and not part.CastShadow, `wall {part.Transparency} {part.CanCollide} {part.CastShadow}`)
		expect(part.Size.Y >= 300, "too tall to jump over")
		local lo, hi = bounds(part)
		local mid = (lo + hi) / 2
		for _, p in { mid, Vector3.new(lo.X + 0.5, 0, lo.Z + 0.5), Vector3.new(hi.X - 0.5, 0, hi.Z - 0.5) } do
			expect(not inPlay(p.X, p.Z), `wall at {p} stands inside the map`)
		end
	end
	-- Lawns, grass between the paths, the park's lawns and the Gulch's desert: no wall anywhere near.
	local e = Lay.fenceZ + 1
	for _, probe in { { -20, 37 }, { 18, -38 }, { 0, 102 }, { 126, 60 }, { 9, e + 20 }, { -24, -e - 60 }, { -60, e + 40 }, { 60, -e - 100 } } do
		local x, z = probe[1], probe[2]
		expect(inPlay(x, z), `{x}, {z} is part of the map`)
		expect(not wallNear(x, z, 3), `a wall stands inside the map near {x}, {z}`)
	end
end)

test("players can't walk off the map: walls close every way out", function()
	-- Flood outward from spawn on a 2-stud grid through the play areas: it must stay inside, and a
	-- wall must stand on every edge it reaches.
	local step = 2
	local spawn = Lay.spawn.Position
	local seen: { [string]: boolean } = {}
	local queue = { { math.round(spawn.X / step), math.round(spawn.Z / step) } }
	seen[`{queue[1][1]},{queue[1][2]}`] = true
	local head, edges, open = 1, 0, 0
	while head <= #queue do
		local cell = queue[head]
		head += 1
		for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local i, j = cell[1] + d[1], cell[2] + d[2]
			local key = `{i},{j}`
			if not seen[key] then
				if inPlay(i * step, j * step) then
					seen[key] = true
					table.insert(queue, { i, j })
				else
					edges += 1
					if not wallNear(i * step, j * step, step) then
						open += 1
					end
				end
			end
		end
	end
	expect(edges > 100, `only {edges} edge cells`)
	equal(open, 0, "edge cells with no wall")
	-- The whole map is one piece: spawn reaches the park, the Gulch, the theatre and the gate road.
	local e = Lay.fenceZ + 1
	for _, place in { { 0, e + 100 }, { 0, -e - 145 }, { Lay.theatreX - 2, 0 }, { 160, 0 }, { 120, 110 } } do
		expect(seen[`{math.round(place[1] / step)},{math.round(place[2] / step)}`] == true, `can't reach {place[1]}, {place[2]}`)
	end
end)

-- Scenery ----------------------------------------------------------------------------------------

test("the scenery fills the background but stays off the paths", function()
	local spots = MapScenery.spots(walk, play, MapModels.Hills)
	expect(#spots > 250, `only {#spots} scenery props`)
	expect(#spots < 900, `{#spots} scenery props is too many for phones`)
	local kinds = {}
	for _, spot in spots do
		kinds[spot.name] = true
		expect(Walkways.distance(walk, spot.at.X, spot.at.Z) > 7, `{spot.name} at {spot.at} is too close to a path`)
		expect(not inPlay(spot.at.X, spot.at.Z), `{spot.name} at {spot.at} stands inside the map but never collides`)
		if spot.at.Z < MapScenery.DesertZ then
			expect(spot.name == "Cactus" or spot.name == "DesertRock" or spot.name == "Mesa", `{spot.name} in the desert`)
		end
	end
	for _, name in { "ParkTree", "PineTree", "Bush", "Cactus", "DesertRock", "Mesa" } do
		expect(kinds[name], `no {name} in the scenery`)
	end
	-- Far scenery never collides or casts shadows.
	local scenery = town:FindFirstChild("Scenery")
	expect(scenery ~= nil, "scenery folder")
	for _, part in (scenery :: any):GetDescendants() do
		if part:IsA("BasePart") then
			expect(not part.CanCollide and not part.CastShadow, `{part:GetFullName()} is light`)
		end
	end
end)

test("the mountains ring the map out past everything else", function()
	expect(#MapScenery.Mountains >= 12, "mountains")
	for _, m in MapScenery.Mountains do
		local d = math.sqrt(m.x ^ 2 + m.z ^ 2)
		expect(d - m.radius > 400, `mountain at {m.x}, {m.z} comes too close`)
		expect(d + m.radius < 1000, `mountain at {m.x}, {m.z} runs off the ground`)
		if m.z < -200 then
			equal(m.style, "mesa", "mountains behind Dusty Gulch are desert mesas")
		end
	end
end)

test("every map kit model has a part version, a size and builds", function()
	local names = MapKit.names()
	expect(#names >= 20, "kit models")
	local folder = roblox.Instance.new("Folder")
	local Build = H.require("Models/Build")
	for _, name in names do
		local model = MapKit.place(Build.new(folder, CFrame.identity), name, CFrame.identity)
		expect(#model:GetChildren() > 0, `{name} builds parts`)
	end
	-- Lamps and lanterns get a light.
	local lamp = MapKit.place(Build.new(folder, CFrame.identity), "TownLamp", CFrame.identity, { light = { range = 10, brightness = 1, color = Color3.new(1, 1, 1) } })
	expect(lamp:FindFirstChild("LightSpot") ~= nil, "lamp light")
end)
