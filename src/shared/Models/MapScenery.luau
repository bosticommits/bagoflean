--!strict
-- The scenery beyond the walkways, so the map never looks empty from where players can go:
-- woods of leafy trees, pines and bushes round the town and behind Starlight Park, a desert of
-- cacti, boulders and striped mesas behind Dusty Gulch, trees climbing the hills, and a ring of
-- big mountains on the horizon (snowy peaks behind the park, sandstone mesas behind the Gulch).
-- Close to the paths, grass tufts, flower clumps and mossy boulders break up the flat lawns.
-- Everything is the low-poly Blender map kit (MapKit), mountains included.
local Build = require(script.Parent.Build)
local MapKit = require(script.Parent.MapKit)
local Walkways = require(script.Parent.Walkways)

type Builder = Build.Builder

local MapScenery = {}

-- The desert starts just past the front hedge (the hedge is at z = -119).
MapScenery.DesertZ = -122

-- Scenery keeps this far from anywhere players can walk, so nothing pokes out over a path.
local MARGIN = 7
-- Inside this box is the town itself, which has its own lawns, bushes and palms.
local TOWN_X, TOWN_Z = 132, 122
-- How far out the props go; past it the mountains take over.
local REACH = 470
local SPACING = 28

export type Mountain = { x: number, z: number, radius: number, height: number, style: string }
export type Hill = { at: Vector3, size: number, kit: string }

-- Big mountains in a ring round the map, out past the props. "peak" mountains have grass, rock
-- and snow; "mesa" ones are flat-topped sandstone, behind Dusty Gulch.
local function mountainRing(): { Mountain }
	local list: { Mountain } = {}
	local count = 20
	for i = 0, count - 1 do
		local angle = math.rad(i * 360 / count + 7)
		local wobble = math.sin(i * 2.7) -- a fixed spread of sizes, the same every server
		local distance = 650 + wobble * 50
		local x, z = math.sin(angle) * distance, math.cos(angle) * distance
		local desert = z < -150
		table.insert(list, {
			x = x,
			z = z,
			radius = if desert then 120 + wobble * 25 else 175 + wobble * 30,
			height = if desert then 90 + math.abs(wobble) * 40 else 190 + wobble * 70,
			style = if desert then "mesa" else "peak",
		})
	end
	return list
end

MapScenery.Mountains = table.freeze(mountainRing())

-- Big things already standing outside the walkways that scenery must leave room round
-- (the theatre, the backlot sound stages and water towers, the gate booth, the gold star, the
-- park's pond and screen, Dusty Gulch's corral, wagon and water tank). World x0, z0, x1, z1.
local KEEP_CLEAR: { Walkways.Rect } = {
	Walkways.rect(-182, -32, -144, 32), -- theatre
	Walkways.rect(-200, -85, -130, -12), -- west sound stage
	Walkways.rect(-168, 28, -138, 60), -- west water tower
	Walkways.rect(140, -56, 172, -24), -- east water tower
	Walkways.rect(166, -40, 230, 40), -- east sound stage
	Walkways.rect(134, 14, 150, 30), -- guard booth
	Walkways.rect(-40, 262, 40, 334), -- the gold star on the hill
	Walkways.rect(-110, 118, 110, 250), -- Starlight Park (it has its own trees)
	Walkways.rect(-40, -282, 40, -118), -- Dusty Gulch's street and buildings
	Walkways.rect(-75, -205, -36, -162), -- corral
	Walkways.rect(36, -192, 64, -164), -- wagon
	Walkways.rect(36, -238, 62, -210), -- water tank
}

-- A fixed pseudo-random number in [0, 1) for a grid spot, so every server builds the same woods.
local function noise(x: number, z: number, salt: number): number
	local n = math.sin(x * 12.9898 + z * 78.233 + salt * 37.719) * 43758.5453
	return n - math.floor(n)
end

local function clear(x: number, z: number, keep: { Walkways.Rect }): boolean
	return not Walkways.isWalkable(keep, x, z)
end

-- Height of the ground at (x, z): 0 on the flat, higher on a hill (hills are big balls sunk into
-- the ground; MapModels lists them).
function MapScenery.groundAt(hills: { Hill }, x: number, z: number): number
	local y = 0
	for _, hill in hills do
		local r = hill.size / 2
		local dx, dz = x - hill.at.X, z - hill.at.Z
		local d2 = dx * dx + dz * dz
		if d2 < r * r then
			y = math.max(y, hill.at.Y + math.sqrt(r * r - d2))
		end
	end
	return y
end

-- Which prop grows at (x, z), and how big, or nil for none.
local function choose(x: number, z: number): (string?, number)
	local r = math.sqrt(x * x + z * z)
	local roll = noise(x, z, 1)
	local size = 0.85 + noise(x, z, 2) * 0.5
	local far = r > 320
	if z < MapScenery.DesertZ then
		if far and roll < 0.12 then
			return "Mesa", 0.55 + noise(x, z, 3) * 0.5
		elseif roll < 0.5 then
			return "Cactus", size * (if far then 1.4 else 1)
		elseif roll < 0.85 then
			return "DesertRock", size * (if far then 1.8 else 1.2)
		end
		return nil, 0
	end
	if far then
		if roll < 0.62 then
			return "PineTree", size * 1.5
		elseif roll < 0.92 then
			return "ParkTree", size * 1.6
		end
		return "Bush", size * 2
	end
	if roll < 0.4 then
		return "ParkTree", size * 1.3
	elseif roll < 0.5 and z > 0 then
		return "BlossomTree", size * 1.3
	elseif roll < 0.75 then
		return "PineTree", size * 1.2
	end
	return "Bush", size * 1.4
end

-- Every prop the scenery would place: kit name, position on the ground, scale and turn. Kept
-- apart from `build` so tests can check where things go without building them.
export type Spot = { name: string, at: Vector3, scale: number, yaw: number }

function MapScenery.spots(walk: { Walkways.Rect }, hills: { Hill }): { Spot }
	local spots: { Spot } = {}
	for gx = -REACH, REACH, SPACING do
		for gz = -REACH, REACH, SPACING do
			-- Jitter each grid spot so the woods don't look planted in rows.
			local x = gx + (noise(gx, gz, 4) - 0.5) * SPACING * 0.8
			local z = gz + (noise(gx, gz, 5) - 0.5) * SPACING * 0.8
			local inTown = math.abs(x) < TOWN_X and math.abs(z) < TOWN_Z
			if not inTown and x * x + z * z < REACH * REACH and clear(x, z, KEEP_CLEAR) then
				local name, scale = choose(x, z)
				if name ~= nil and Walkways.distance(walk, x, z) > MARGIN + scale * 4 then
					local y = MapScenery.groundAt(hills, x, z)
					table.insert(spots, {
						name = name,
						-- Sunk a little so nothing floats on a slope.
						at = Vector3.new(x, y - (if y > 0 then 0.6 else 0), z),
						scale = scale,
						yaw = noise(x, z, 6) * 360,
					})
				end
			end
		end
	end
	return spots
end

-- The small things on the grass near the paths, where players see them up close: grass tufts,
-- flower clumps and mossy boulders, on a finer grid than the woods, inside the town's outer ring
-- and round the park. Not in the desert, on a path, or under something big.
local DRESS_SPACING = 14
local DRESS_REACH = 290
local DRESS_NEAR = 55

-- Like KEEP_CLEAR, but the park's lawns are dressed too: only its pond is left alone.
local DRESS_CLEAR: { Walkways.Rect } = table.clone(KEEP_CLEAR)
table.remove(DRESS_CLEAR, 8) -- Starlight Park, the 8th above
table.insert(DRESS_CLEAR, Walkways.rect(-84, 173, -26, 231)) -- the pond

function MapScenery.dressing(walk: { Walkways.Rect }, hills: { Hill }): { Spot }
	local spots: { Spot } = {}
	for gx = -DRESS_REACH, DRESS_REACH, DRESS_SPACING do
		for gz = -DRESS_REACH, DRESS_REACH, DRESS_SPACING do
			local x = gx + (noise(gx, gz, 7) - 0.5) * DRESS_SPACING * 0.9
			local z = gz + (noise(gx, gz, 8) - 0.5) * DRESS_SPACING * 0.9
			local d = Walkways.distance(walk, x, z)
			if z > MapScenery.DesertZ + 4 and d > 2.5 and d < DRESS_NEAR and clear(x, z, DRESS_CLEAR) then
				local roll = noise(x, z, 9)
				local name = if roll < 0.55 then "GrassTuft" elseif roll < 0.85 then "FlowerPatch" else "Boulder"
				local scale = if name == "Boulder" then 0.6 + noise(x, z, 10) * 0.6 else 1 + noise(x, z, 10) * 0.6
				if name ~= "Boulder" or d > 6 then
					local spot: Spot = {
						name = name,
						at = Vector3.new(x, MapScenery.groundAt(hills, x, z), z),
						scale = scale,
						yaw = noise(x, z, 11) * 360,
					}
					table.insert(spots, spot)
				end
			end
		end
	end
	return spots
end

function MapScenery.build(b: Builder, walk: { Walkways.Rect }, hills: { Hill })
	local folder = Instance.new("Folder")
	folder.Name = "Scenery"
	folder.Parent = b.parent
	local sb = Build.new(folder, b.base, b.scale)
	for _, spot in MapScenery.spots(walk, hills) do
		MapKit.place(sb, spot.name, CFrame.new(spot.at) * CFrame.Angles(0, math.rad(spot.yaw), 0), { scale = spot.scale, far = true })
	end
	-- The lawn dressing only once the meshes are imported: as stand-in parts it would cost phones
	-- a thousand parts for a few blobs.
	if MapKit.meshed("GrassTuft") then
		for _, spot in MapScenery.dressing(walk, hills) do
			MapKit.place(sb, spot.name, CFrame.new(spot.at) * CFrame.Angles(0, math.rad(spot.yaw), 0), { scale = spot.scale, far = true })
		end
	end
	-- The ring of mountains: snowy low-poly peaks (kit Mountain, 200 across, sized to each
	-- mountain's width) and, behind Dusty Gulch, the striped sandstone Mesa (about 26 tall,
	-- sized to the mountain's height so the desert stays low and wide open).
	for i, m in MapScenery.Mountains do
		local at = CFrame.new(m.x, -4, m.z) * CFrame.Angles(0, math.rad(i * 41), 0)
		if m.style == "mesa" then
			MapKit.place(sb, "Mesa", at, { scale = m.height / 26, far = true })
		else
			MapKit.place(sb, "Mountain", at, { scale = m.radius / 100, far = true })
		end
	end
	-- Sand under the desert, out to the mountains (just above the grass, so the two never
	-- flicker). Two pieces: one part can be at most 2048 studs long.
	b:block("DesertFloor", Vector3.new(2048, 0.2, 900), Vector3.new(0, -0.07, MapScenery.DesertZ - 450), Color3.fromRGB(236, 196, 128), Enum.Material.Sand)
end

return MapScenery
