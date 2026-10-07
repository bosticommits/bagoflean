local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local H = require("./harness")
local MapModels = H.require("Models/MapModels")
local LotModels = H.require("Models/LotModels")
local test, expect, equal = H.test, H.expect, H.equal

local Vector3 = roblox.Vector3
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
