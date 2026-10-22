--!strict
-- The scenery beyond the walkways, so the map never looks empty from where players can go:
-- woods of leafy trees, pines and bushes round the town and behind Starlight Park, a desert of
-- cacti, boulders and striped mesas behind Dusty Gulch, trees climbing the hills, and a ring of
-- big mountains on the horizon (snowy peaks behind the park, sandstone mesas behind the Gulch).
-- The props are the Blender map kit (MapKit); the mountains are Roblox terrain, filled in by the
-- server (MapService) from the list here.
local Build = require(script.Parent.Build)
local MapKit = require(script.Parent.MapKit)
local Walkways = require(script.Parent.Walkways)

type Builder = Build.Builder

local MapScenery = {}

-- The desert starts just past the front hedge (the hedge is at z = -127).
MapScenery.DesertZ = -130

-- Scenery keeps this far from anywhere players can walk, so nothing pokes out over a path.
local MARGIN = 7
-- Inside this box is the town itself, which has its own lawns, bushes and palms.
local TOWN_X, TOWN_Z = 194, 130
-- How far out the props go; past it the mountains take over.
local REACH = 500
local SPACING = 28

export type Mountain = { x: number, z: number, radius: number, height: number, style: string }
export type Hill = { at: Vector3, size: number, kit: string } -- kit: map kit Hill<kit>

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
	Walkways.rect(-244, -32, -206, 32), -- theatre
	Walkways.rect(-262, -85, -192, -12), -- west sound stage
	Walkways.rect(-230, 28, -200, 60), -- west water tower
	Walkways.rect(202, -56, 234, -24), -- east water tower
	Walkways.rect(228, -40, 292, 40), -- east sound stage
	Walkways.rect(196, 14, 212, 30), -- guard booth
	Walkways.rect(-40, 270, 40, 342), -- the gold star on the hill
	Walkways.rect(-110, 126, 110, 258), -- Starlight Park (it has its own trees)
	Walkways.rect(-40, -290, 40, -126), -- Dusty Gulch's street and buildings
	Walkways.rect(-75, -213, -36, -170), -- corral
	Walkways.rect(36, -200, 64, -172), -- wagon
	Walkways.rect(36, -246, 62, -218), -- water tank
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
	local far = r > 380
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

function MapScenery.spots(walk: { Walkways.Rect }, play: { Walkways.Rect }, hills: { Hill }): { Spot }
	local spots: { Spot } = {}
	for gx = -REACH, REACH, SPACING do
		for gz = -REACH, REACH, SPACING do
			-- Jitter each grid spot so the woods don't look planted in rows.
			local x = gx + (noise(gx, gz, 4) - 0.5) * SPACING * 0.8
			local z = gz + (noise(gx, gz, 5) - 0.5) * SPACING * 0.8
			local inTown = math.abs(x) < TOWN_X and math.abs(z) < TOWN_Z
			-- Far props never collide, so none stand where players can walk (the play areas, with
			-- room to spare so none pokes through the invisible walls).
			local inPlay = Walkways.distance(play, x, z) < MARGIN
			if not inTown and not inPlay and x * x + z * z < REACH * REACH and clear(x, z, KEEP_CLEAR) then
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

function MapScenery.build(b: Builder, walk: { Walkways.Rect }, play: { Walkways.Rect }, hills: { Hill })
	local folder = Instance.new("Folder")
	folder.Name = "Scenery"
	folder.Parent = b.parent
	local sb = Build.new(folder, b.base, b.scale)
	for _, spot in MapScenery.spots(walk, play, hills) do
		MapKit.place(sb, spot.name, CFrame.new(spot.at) * CFrame.Angles(0, math.rad(spot.yaw), 0), { scale = spot.scale, far = true })
	end
	-- Sand under the desert, out to the mountains (just above the grass, so the two never
	-- flicker). Two pieces: one part can be at most 2048 studs long.
	b:block("DesertFloor", Vector3.new(2048, 0.2, 900), Vector3.new(0, -0.07, MapScenery.DesertZ - 450), Color3.fromRGB(236, 196, 128), Enum.Material.Sand)
end

-- Fills the mountains into the terrain. Server only (terrain built there replicates). Each
-- mountain is a stack of 4-stud slices, narrower toward the top. `pause` runs after each
-- mountain, so the server can spread the work over a few frames.
function MapScenery.buildTerrain(terrain: Terrain, pause: (() -> ())?)
	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(96, 178, 84))
	terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(128, 122, 130))
	terrain:SetMaterialColor(Enum.Material.Snow, Color3.fromRGB(246, 248, 255))
	terrain:SetMaterialColor(Enum.Material.Sandstone, Color3.fromRGB(214, 124, 72))
	terrain:SetMaterialColor(Enum.Material.Sand, Color3.fromRGB(236, 196, 128))
	local slice = 4
	for _, m in MapScenery.Mountains do
		local y = -8
		while y < m.height do
			local t = math.max(y, 0) / m.height
			local radius, material
			if m.style == "mesa" then
				-- Steep sides in steps, then a flat top.
				local step = math.floor(t * 4)
				radius = m.radius * (1 - step * 0.09) * (if t > 0.9 then 0.9 else 1)
				material = if t < 0.12 then Enum.Material.Sand else Enum.Material.Sandstone
			else
				radius = m.radius * (1 - t) ^ 1.25 + 6
				material = if t < 0.38 then Enum.Material.Grass elseif t < 0.74 then Enum.Material.Rock else Enum.Material.Snow
			end
			terrain:FillCylinder(CFrame.new(m.x, y + slice / 2, m.z), slice, radius, material)
			y += slice
		end
		if pause ~= nil then
			pause()
		end
	end
end

return MapScenery
