--!strict
-- The town's landmarks and film sets (see MapModels): the Grand Premiere Theatre and the Studio
-- Gate at the two ends of the boulevard, a themed film set in each back street between the lots,
-- street furniture, a far-off city skyline, Dusty Gulch, Starlight Park and the blimp.
--
-- Every model is a Blender model from the map kit (art/blender/map_kit.py and town_kit.py,
-- placed by MapKit); this file only says where each one goes and what its signs say. The ground
-- they stand on (streets, paths, boardwalks, lawns, the pond's water) is still flat parts.
--
-- Each piece is laid out in its own space like the rest of the models (origin at the bottom
-- centre, front toward -Z); MapModels places them. Phones come first: lights only where they make
-- a focal point (lamps, lanterns, the theatre marquee), and small parts cast no shadow
-- (MapModels.build).
local Build = require(script.Parent.Build)
local FilmScenes = require(script.Parent.Parent.FilmScenes)
local LotModels = require(script.Parent.LotModels)
local MapKit = require(script.Parent.MapKit)

type Builder = Build.Builder

local P = Build.Palette
local NEON = Enum.Material.Neon
local GRASS = Enum.Material.Grass

local PINK = Color3.fromRGB(255, 120, 170)
local CHROMA = Color3.fromRGB(40, 200, 90) -- green screen green
local TEAL = Color3.fromRGB(32, 178, 190)

local TownSets = {}

-- Starlight Park's pond, in the park's own space (MapLife paddles the ducks round it).
TownSets.Pond = Vector3.new(-55, 0, 82)
TownSets.PondRadius = 26

-- The loops the park's ducks paddle (src/client/MapLife.luau), in the pond's own space: the big
-- one with its duckling behind, and one on its own, clear of the island and the bridge.
-- tests/luau/map.spec.luau checks every loop stays on open water.
export type DuckLoop = { centre: Vector3, radius: number, lap: number, lag: number }
TownSets.DuckLoops = table.freeze({
	{ centre = Vector3.new(11, 0.5, -9), radius = 5, lap = 40, lag = 0 },
	{ centre = Vector3.new(11, 0.5, -9), radius = 5, lap = 40, lag = 0.55 },
	{ centre = Vector3.new(-14, 0.5, -12), radius = 4, lap = 32, lag = 2 },
} :: { DuckLoop })

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

local function yaw(degrees: number): CFrame
	return CFrame.Angles(0, math.rad(degrees), 0)
end

-- Grand Premiere Theatre -------------------------------------------------------------------------

-- A movie palace (map kit PremiereTheatre): steps up to a bulb-lit marquee, columns and poster
-- cases, a tall "RNG" sign with a gold star on top, side wings, and searchlights. About 52 wide
-- and 29 deep; the bottom step is at z = -3.
function TownSets.theatre(b: Builder)
	MapKit.place(b, "PremiereTheatre", CFrame.identity, {
		hitbox = true,
		labels = {
			Marquee = { text = "TONIGHT: YOUR PREMIERE", color = P.Burgundy, stroke = 0 },
			Blade = { text = "R\nN\nG", color = P.Gold, stroke = 6 },
			PosterSpace = { text = "SPACE\nCOWBOYS", color = P.OffWhite },
			PosterLove = { text = "LOVE IN\nPARIS", color = P.OffWhite },
		},
	})
	-- The marquee's bulbs light the steps and the carpet below (a warm pool you walk into).
	local glow = b:block("MarqueeGlow", v(1, 0.2, 1), v(0, 7.9, 2.5), P.Light)
	glow.Transparency = 1
	glow.CanCollide = false
	glow.CanQuery = false
	glow.CanTouch = false
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Bottom
	spot.Angle = 120
	spot.Range = 20
	spot.Brightness = 2.2
	spot.Color = Color3.fromRGB(255, 214, 150)
	spot.Parent = glow

	-- Searchlights on the front corners of the plinth.
	for _, side in { -1, 1 } do
		LotModels.searchlight(b:sub(v(side * 23, 1, 2)), side * 25, P.Light)
	end
end

-- Studio Gate ------------------------------------------------------------------------------------

-- A grand studio entrance (map kit StudioGate): two towers, an arch with "HOLLYWOOD RNG STUDIOS"
-- on both faces and a gold star, iron gates swung open, and a guard booth. About 36 wide; the
-- road runs through the middle.
function TownSets.studioGate(b: Builder)
	local words: MapKit.Label = { text = "HOLLYWOOD RNG STUDIOS", color = P.Gold, stroke = 4 }
	MapKit.place(b, "StudioGate", CFrame.identity, { hitbox = true, labels = { SignFront = words, SignBack = words } })
	MapKit.place(b, "GuardBooth", v(-22, 0, -4))
end

-- Back street film sets --------------------------------------------------------------------------
-- Each set fills one of the paths between the lots: 20 studs across (x -10..10) and 64 long
-- (z -32..32, -Z toward the boulevard). Props keep to the sides (|x| >= 5.5) so the middle stays
-- a clear walk.

local function directorChair(b: Builder, at: CFrame, label: string?, solid: boolean?)
	MapKit.place(b, "DirectorChair", at, {
		solid = solid,
		labels = if label ~= nil then { Back = { text = label, color = P.Gold, stroke = 0 } } else nil,
	})
end

local function crate(b: Builder, at: Vector3, size: number, turn: number?)
	MapKit.place(b, "PropCrate", CFrame.new(at) * yaw(turn or 0), { scale = size / 3 })
end

-- The sign at the street end of a set. `kit` is the frame color (SetSign<Color>).
local function sign(b: Builder, at: Vector3, text: string, kit: string, color: Color3)
	MapKit.place(b, "SetSign" .. kit, at, { labels = { Sign = { text = text, color = color, stroke = 0 } } })
end

-- The green screen set: a chroma wall with a marked floor, a camera on a crane aimed at it,
-- director's chairs, two lights and a giant clapperboard.
function TownSets.greenScreen(b: Builder)
	MapKit.place(b, "ChromaWall", CFrame.new(9.6, 0.2, 2) * yaw(90))
	MapKit.place(b, "CameraCrane", CFrame.new(-7.5, 0.2, 2) * yaw(-90))
	directorChair(b, CFrame.new(-7.6, 0.2, 11) * yaw(-90), "DIRECTOR")
	directorChair(b, CFrame.new(-7.6, 0.2, 14) * yaw(-90), nil)
	MapKit.place(b, "LightStand", CFrame.new(6.2, 0.2, -9) * yaw(-70))
	MapKit.place(b, "LightStand", CFrame.new(6.2, 0.2, 13) * yaw(-110))
	MapKit.place(b, "Clapperboard", CFrame.new(-7.5, 0.2, -22) * yaw(90))
	sign(b, v(-7.5, 0.2, -29), "STAGE 9", "Green", CHROMA)
end

-- The props yard: stacked crates, a giant dinosaur head from a monster movie, a fake moon and a
-- rolling spotlight.
function TownSets.propsYard(b: Builder)
	crate(b, v(8, 0.2, -20), 3.4)
	crate(b, v(8, 3.6, -20), 2.6, 20)
	crate(b, v(8.2, 0.2, -16), 2.8, -10)
	crate(b, v(-8, 0.2, 20), 3.2, 8)
	crate(b, v(-8, 3.4, 20), 2.4, -15)
	crate(b, v(8, 0.2, 22), 3, 30)
	-- The dinosaur head, mouth open, roaring at people walking in.
	MapKit.place(b, "DinoHead", v(-7.8, 0.2, 2))
	MapKit.place(b, "PropMoon", v(8, 0.2, 8))
	MapKit.place(b, "RollingSpotlight", CFrame.new(-7.6, 0.2, -10) * yaw(-60))
	sign(b, v(-7.5, 0.2, -29), "PROPS DEPT.", "Red", P.Carpet)
end

-- Star trailers: two trailers with stars on their doors, striped awnings, and chairs out front.
function TownSets.trailers(b: Builder)
	for i, trailer in { { z = -13, kit = "StarTrailerRed" }, { z = 9, kit = "StarTrailerBlue" } } do
		MapKit.place(b, trailer.kit, v(8.2, 0.2, trailer.z))
		-- A table and two chairs out front.
		local z = trailer.z + (if i == 1 then -1 else 1) * 0.5
		MapKit.place(b, "PatioTable", v(-7.4, 0.2, z))
		directorChair(b, CFrame.new(-7.4, 0.2, z - 2), nil)
		directorChair(b, CFrame.new(-7.4, 0.2, z + 2) * yaw(180), nil)
	end
	sign(b, v(-7.5, 0.2, -29), "STAR TRAILERS", "Gold", P.Gold)
end

-- Food corner: a taco truck, a popcorn cart, and tables with umbrellas.
function TownSets.foodCorner(b: Builder)
	MapKit.place(b, "TacoTruck", v(8, 0.2, -2), {
		labels = { TruckSign = { text = "TACOS", color = P.OffWhite, stroke = 4 } },
	})
	MapKit.place(b, "PopcornCart", CFrame.new(-7.4, 0.2, -12) * yaw(90))
	for k, z in { 2, 10, 18 } do
		MapKit.place(b, if k % 2 == 0 then "CafeTableTeal" else "CafeTableGold", CFrame.new(-7.4, 0.2, z) * yaw(k * 25))
	end
	sign(b, v(-7.5, 0.2, -29), "FOOD CORNER", "Pink", PINK)
end

-- Sidewalk and skyline ---------------------------------------------------------------------------

-- A round poster column with a gold dome, its poster facing front. `kit`: PosterColumn<Color>
-- (Green, Blue, Pink or Red).
function TownSets.posterColumn(b: Builder, title: string, kit: string)
	MapKit.place(b, "PosterColumn" .. kit, CFrame.identity, {
		labels = { Poster = { text = title, color = P.OffWhite, stroke = 2 } },
	})
end

-- Far-off city towers behind the hills, pale and hazy. `seed` varies heights and spacing.
function TownSets.skyline(b: Builder, count: number, spread: number, seed: number)
	-- A tiny fixed sequence (Random isn't available in the preview tool), so the skyline never
	-- changes between servers.
	local state: number = seed
	local function number(lo: number, hi: number): number
		state = (state * 1103515245 + 12345) % 2147483648
		return lo + state / 2147483648 * (hi - lo)
	end
	for i = 0, count - 1 do
		local x = -spread / 2 + (i + number(0.1, 0.9)) * spread / count
		local height = number(60, 150) * (1 - math.abs(x) / spread * 0.9)
		local z = number(-20, 20)
		local kit = "CityTower" .. tostring(1 + i % 3)
		MapKit.place(b, kit, CFrame.new(x, 0, z) * yaw(number(-15, 15)), { scale = height / 115, far = true })
	end
end

-- Lawn with flowers, for the corners round the landmarks.
function TownSets.flowerBed(b: Builder, size: Vector3)
	b:block("Lawn", v(size.X, 0.34, size.Z), v(0, 0.17, 0), P.Green, GRASS)
	b:block("LawnEdge", v(size.X + 0.4, 0.27, size.Z + 0.4), v(0, 0.135, 0), P.Cream)
	local n = 0
	for x = -size.X / 2 + 2, size.X / 2 - 1.5, 3.5 do
		n += 1
		MapKit.place(b, "FlowerPatch", CFrame.new(x, 0.34, if n % 2 == 0 then -size.Z / 5 else size.Z / 5) * yaw(n * 67), { solid = false })
	end
end

-- Street life (pass 2) ---------------------------------------------------------------------------

-- A rounded vintage convertible, about 4.4 wide and 9.6 long, nose toward -Z. `kit`:
-- VintageCar<Color> (Teal, Pink, Gold or Red).
function TownSets.car(b: Builder, kit: string)
	MapKit.place(b, "VintageCar" .. kit, CFrame.identity)
end

-- A bus stop: a roof on two posts, a bench, a back panel with a poster, and a round sign.
function TownSets.busStop(b: Builder)
	MapKit.place(b, "BusStop", CFrame.identity, {
		labels = {
			Poster = { text = "MONSTER\nISLAND\nNOW SHOWING", color = P.OffWhite, stroke = 2 },
			BusSign = { text = "BUS", color = P.OffWhite, stroke = 0 },
		},
	})
end

function TownSets.hydrant(b: Builder)
	MapKit.place(b, "Hydrant", CFrame.identity)
end

function TownSets.trashBin(b: Builder)
	MapKit.place(b, "TrashBin", CFrame.identity)
end

-- A newspaper stand: a green kiosk with stacks of papers and a striped roof.
function TownSets.newsStand(b: Builder)
	MapKit.place(b, "NewsStand", CFrame.identity, {
		labels = { NewsSign = { text = "DAILY STAR", color = P.Gold, stroke = 0 } },
	})
end

-- The outer ring (pass 3) ------------------------------------------------------------------------
-- Two big areas out through gaps in the hedge (MapModels.Layout.sideGap): Dusty Gulch, a western
-- film town behind the front row, and Starlight Park behind the back row. Chunky shapes, bold
-- colors and thick trims, like the Roblox front page. Each is laid out with its entrance at z = 0
-- and the area running toward +Z.

local WATER = Color3.fromRGB(64, 196, 240)
local WATER_LIGHT = Color3.fromRGB(130, 222, 250)
local SAND = Color3.fromRGB(240, 205, 140)
local DUST = Color3.fromRGB(222, 170, 110)

local function shade(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

-- A fence (map kit Fence<Color>: 5-stud sections with a post at each end) from `from` to `to`.
local function fenceRun(b: Builder, from: Vector3, to: Vector3, kit: string)
	local delta = to - from
	local length = delta.Magnitude
	local sections = math.max(1, math.round(length / 5))
	local each = length / sections
	-- Turned by hand rather than with CFrame.lookAt, which the test runner's CFrame gets backwards.
	local turn = CFrame.Angles(0, math.atan2(-delta.X, -delta.Z), 0) * CFrame.Angles(0, math.pi / 2, 0)
	for i = 0, sections - 1 do
		local mid = from + delta * ((i + 0.5) / sections)
		MapKit.place(b, "Fence" .. kit, CFrame.new(mid) * turn, { scale = each / 5 })
	end
end

-- Dusty Gulch ------------------------------------------------------------------------------------

type WesternInfo = { title: string, kit: string, color: Color3 }

-- A false-front western building, about 20 wide and 15 deep, front toward -Z: the Blender model
-- (map kit Western<Name>: clapboard front, stepped top, porch or balcony, its own details), with
-- the building's name lettered on its sign board.
local function westernBuilding(b: Builder, info: WesternInfo)
	MapKit.place(b, info.kit, CFrame.identity, { labels = { Sign = { text = info.title, color = info.color } } })
end

-- The facing (degrees, for yaw()) that turns a model's front (-Z) from (x, z) toward (tx, tz).
local function toward(x: number, z: number, tx: number, tz: number): number
	return math.deg(math.atan2(x - tx, z - tz))
end

-- Turned so a model's X axis runs along `delta`, its front (-Z) to the left of the way it runs.
local function along(delta: Vector3): CFrame
	return yaw(math.deg(math.atan2(-delta.Z, delta.X)))
end

-- A run of backlot fence (map kit BacklotFence: 12-stud sections hung with green mesh on their
-- front) from `from` to `to`, the mesh facing to the left of the way it runs. `signs` letters a studio banner on
-- the sections it names (1 is the first). A drift of sand at every other post (never at the run's
-- ends, which may be a gateway) hides the ground's edge.
local function backlotFence(b: Builder, from: Vector3, to: Vector3, signs: { [number]: string }?)
	local delta = to - from
	local sections = math.max(1, math.round(delta.Magnitude / 12))
	local turn = along(delta)
	for i = 0, sections - 1 do
		local mid = from + delta * ((i + 0.5) / sections)
		local text = if signs then signs[i + 1] else nil
		MapKit.place(b, if text then "BacklotFenceSign" else "BacklotFence", CFrame.new(mid) * turn, {
			scale = delta.Magnitude / sections / 12,
			labels = if text then { Sign = { text = text, color = P.Burgundy, stroke = 0 } } else nil,
		})
		if i % 2 == 1 then
			MapKit.place(b, "BacklotBerm", CFrame.new(from + delta * (i / sections)) * turn * yaw(if i % 4 == 1 then 8 else -10), { solid = false })
		end
	end
	MapKit.place(b, "BacklotFencePost", to)
end

-- A cable run along the ground through `points`: lengths of map kit BacklotCable laid end to end,
-- overlapping a little (and past the ends of runs shorter than a length).
local function cableRun(b: Builder, points: { Vector3 })
	for k = 1, #points - 1 do
		local from, to = points[k], points[k + 1]
		local delta = to - from
		local pieces = math.max(1, math.ceil(delta.Magnitude / 8))
		for i = 0, pieces - 1 do
			local mid = from + delta * ((i + 0.5) / pieces)
			MapKit.place(b, "BacklotCable", CFrame.new(mid) * along(delta), { solid = false })
		end
	end
end

-- Dusty Gulch as an open studio backlot (art/blender/backlot_kit.py), in the Gulch's space: green
-- mesh fence round the lot (open at the town hedge and at Moon Base's gate, x = -88, z = 81),
-- painted flats propped up behind the street's end and behind the hotel, light rigs aimed at the
-- action with cables back to a generator, a basecamp of star trailers and a craft services tent
-- behind the east row, and the director's video village down the street from the camera. The
-- film crew's patch (x 3..13, z 100..130), the actors' street and the stunt landing stay clear by
-- about 12 studs; tests/luau/map.spec.luau checks it.
TownSets.GulchCrewClear = { x0 = -9, z0 = 88, x1 = 25, z1 = 142 }
TownSets.GulchMoonWay = { x0 = -88, z0 = 70, x1 = -20, z1 = 92 }

local function gulchBacklot(b: Builder)
	local G = 0.1 -- the desert ground
	local S = 0.2 -- the street
	local W = 0.8 -- the boardwalks
	local ACTION = v(-5, 0, 114)
	local function aim(x: number, z: number): number
		return toward(x, z, ACTION.X, ACTION.Z)
	end

	-- The fence, clockwise from the town hedge on the west (-X) side, leaving the way out to Moon
	-- Base's gate open.
	backlotFence(b, v(-85, G, 2), v(-85, G, 68), { [3] = "BACKLOT 9" })
	MapKit.place(b, "BacklotFencePost", v(-85, G, 94))
	backlotFence(b, v(-85, G, 94), v(-85, G, 157))
	backlotFence(b, v(-85, G, 157), v(85, G, 157))
	backlotFence(b, v(85, G, 157), v(85, G, 2), { [4] = "QUIET ON SET", [9] = "STUDIO PROPERTY" })

	local gear: { FilmScenes.Gear } = {
		-- Painted flats: a trail running off to the horizon closing the street's end, a desert sky
		-- behind the hotel (it rises over the roofs behind the shot), and one by the wagon with
		-- its bracing toward the way in.
		{ kit = "BacklotFlatTrail", at = v(0, S, 149), yaw = 0, solid = true },
		{ kit = "BacklotFlatDesert", at = v(-43, G, 132), yaw = -90, solid = true },
		{ kit = "BacklotFlatDesert", at = v(-56, G, 37), yaw = 180, solid = true },
		{ kit = "BacklotBrace", at = v(-36, G, 52), yaw = 90 },

		-- Lights aimed at the showdown from the street's far end, and a fresnel down the street.
		{ kit = "BacklotTrussTower", at = v(34, G, 141), yaw = aim(34, 141), light = true, solid = true },
		{ kit = "BacklotScaffold", at = v(-30, G, 139), yaw = aim(-30, 139), light = true, solid = true },
		{ kit = "BacklotCStand", at = v(-23, G, 131), yaw = aim(-23, 131) },
		{ kit = "BacklotGroundLight", at = v(-11, S, 84), yaw = aim(-11, 84) },
		{ kit = "BacklotCase", at = v(-12, S, 79), yaw = 15 },

		-- Power: the generator behind the truss tower; the runs are below.
		{ kit = "BacklotGenerator", at = v(52, G, 149), yaw = 90, solid = true },
		{ kit = "BacklotCableRamp", at = v(0, S, 145), yaw = 0 },
		{ kit = "BacklotCableCoil", at = v(44, G, 141), yaw = 30 },
		{ kit = "BacklotCaseStack", at = v(40, G, 147), yaw = -15 },
		{ kit = "BacklotCart", at = v(-38, G, 145), yaw = 80 },
		{ kit = "BacklotCase", at = v(-36, G, 128), yaw = -20 },

		-- The director's video village, down the street from the camera, out of the shot: the
		-- monitors face the way in, the chairs face the monitors (and the action beyond them).
		{ kit = "BacklotVideoVillage", at = v(9, S, 80), yaw = 0 },
		{ kit = "DirectorChair", at = v(6.5, S, 75.5), yaw = 180 },
		{ kit = "DirectorChair", at = v(9.5, S, 75.2), yaw = 180, label = "DIRECTOR" },
		{ kit = "DirectorChair", at = v(12.5, S, 75.5), yaw = 180 },
		{ kit = "BacklotScriptTable", at = v(17, W, 77), yaw = 90 },
		{ kit = "BacklotAppleBoxes", at = v(16.5, W, 83), yaw = 20 },

		-- Basecamp behind the east row: star trailers, craft services, a grip cart.
		{ kit = "StarTrailerRed", at = v(64, G, 96), yaw = 0, solid = true },
		{ kit = "StarTrailerBlue", at = v(64, G, 117), yaw = 0, solid = true },
		{ kit = "DirectorChair", at = v(56, G, 92), yaw = 120 },
		{ kit = "DirectorChair", at = v(56, G, 121), yaw = 60 },
		{ kit = "BacklotCraftTent", at = v(46, G, 131), yaw = 90, label = "CRAFT SERVICES", solid = true },
		{ kit = "BacklotCart", at = v(44, G, 106), yaw = 5 },
		{ kit = "BacklotCase", at = v(42, G, 112), yaw = -25 },
	}
	TownSets.filmSetGear(b, gear, true)

	-- Generator to the truss tower, and on across the street's end (over the ramp) to the
	-- scaffold and down the west boardwalk to the fresnel.
	cableRun(b, { v(48, G, 145.5), v(36, G, 142.5) })
	cableRun(b, { v(36, G, 142.5), v(28, S, 145), v(-24, S, 145), v(-29, G, 140) })
	cableRun(b, { v(-24, S, 145), v(-13.2, S, 137), v(-13.2, S, 87) })

	-- Scrub where the set dressing meets the desert.
	for i, at in { v(-48, G, 153), v(56, G, 140), v(72, G, 122), v(-62, G, 33), v(-30, G, 54), v(48, G, 88), v(-44, G, 150), v(-80, G, 100), v(80, G, 46) } do
		MapKit.place(b, "BacklotClump", CFrame.new(at) * yaw(i * 61), { solid = false })
	end
end

-- Dusty Gulch: a western film town, about 160 wide and 150 long. A welcome arch over the road in,
-- a dusty main street with eight false-front buildings on boardwalks (saloon, bank, sheriff, hotel
-- and more), hitching rails, barrels and crates, a corral, a covered wagon, a water tank, blocky
-- mesas and cacti, and a film crew shooting scenes by the hotel (Dusty Gulch is the first film set).
function TownSets.westernTown(b: Builder)
	local length = 150
	b:block("DesertGround", v(170, 0.1, length + 6), v(0, 0.05, length / 2 + 3), SAND)
	b:block("DustStreet", v(28, 0.2, length), v(0, 0.1, length / 2), DUST)
	for _, x in { -5, 5 } do
		b:block("DustRut", v(1.6, 0.06, length), v(x, 0.23, length / 2), shade(DUST, 0.12))
	end
	for _, s in { -1, 1 } do
		b:block("Boardwalk", v(6, 0.8, 112), v(s * 17, 0.4, 80), P.Wood)
		b:block("BoardwalkEdge", v(0.7, 0.9, 112), v(s * 14.2, 0.45, 80), P.Bark)
	end

	-- The welcome arch.
	local welcome: MapKit.Label = { text = "DUSTY GULCH", color = P.Gold, stroke = 4 }
	MapKit.place(b, "GulchArch", v(0, 0.2, 6), { hitbox = true, labels = { SignFront = welcome, SignBack = welcome } })

	-- The buildings, fronts on the boardwalks facing the street.
	local west: { WesternInfo } = {
		{ title = "SALOON", kit = "WesternSaloon", color = Color3.fromRGB(205, 70, 50) },
		{ title = "BANK", kit = "WesternBank", color = Color3.fromRGB(60, 130, 215) },
		{ title = "BARBER", kit = "WesternBarber", color = Color3.fromRGB(235, 115, 165) },
		{ title = "HOTEL", kit = "WesternHotel", color = Color3.fromRGB(145, 95, 205) },
	}
	local east: { WesternInfo } = {
		{ title = "SHERIFF", kit = "WesternSheriff", color = Color3.fromRGB(240, 175, 50) },
		{ title = "GENERAL STORE", kit = "WesternGeneralStore", color = Color3.fromRGB(100, 175, 75) },
		{ title = "POST OFFICE", kit = "WesternPostOffice", color = TEAL },
		{ title = "BLACKSMITH", kit = "WesternBlacksmith", color = Color3.fromRGB(150, 105, 80) },
	}
	for i = 1, 4 do
		local z = 10 + i * 26
		westernBuilding(b:sub(CFrame.new(-20, 0.8, z) * yaw(-90)), west[i])
		westernBuilding(b:sub(CFrame.new(20, 0.8, z) * yaw(90)), east[i])
	end
	-- Wanted posters on the sheriff's boardwalk, facing the street.
	for _, z in { 27.2, 44.8 } do
		MapKit.place(b, "WantedBoard", CFrame.new(14.4, 4.1, z) * yaw(90), {
			labels = { Poster = { text = "WANTED", color = P.Burgundy, stroke = 0 } },
		})
	end

	-- Street life: hitching rails, troughs, barrels, crates and hay along the boardwalks.
	for _, s in { -1, 1 } do
		for _, z in { 48, 100 } do
			MapKit.place(b, "HitchRail", v(s * 12.6, 0.2, z))
		end
		MapKit.place(b, "Trough", v(s * 12.6, 0.2, 74))
	end
	for _, at in { v(-16, 0.8, 24), v(-14.6, 0.8, 26.2), v(16, 0.8, 128), v(16, 0.8, 24), v(-16, 0.8, 128) } do
		MapKit.place(b, "Barrel", CFrame.new(at) * yaw(at.Z * 13))
	end
	crate(b, v(15.6, 0.8, 50), 2.6, 15)
	crate(b, v(15.6, 3.4, 50), 2, -10)
	crate(b, v(-15.8, 0.8, 76), 2.4, 30)
	MapKit.place(b, "HayBale", CFrame.new(16, 0.8, 75) * yaw(90))
	MapKit.place(b, "HayBale", CFrame.new(16, 2.8, 75.4) * yaw(80))
	-- Tumbleweeds resting in the street.
	for _, at in { v(-4, 0.2, 60), v(6, 0.2, 112) } do
		MapKit.place(b, "Tumbleweed", at, { solid = false })
	end

	-- The corral with hay and a trough, east behind the buildings.
	local corral = b:sub(v(56, 0.1, 64))
	local c = 14
	fenceRun(corral, v(-c, 0, -c), v(c, 0, -c), "Wood")
	fenceRun(corral, v(c, 0, -c), v(c, 0, c), "Wood")
	fenceRun(corral, v(c, 0, c), v(-c, 0, c), "Wood")
	fenceRun(corral, v(-c, 0, c), v(-c, 0, 4), "Wood")
	fenceRun(corral, v(-c, 0, -4), v(-c, 0, -c), "Wood")
	MapKit.place(corral, "HayBale", v(6, 0, 6))
	MapKit.place(corral, "HayBale", CFrame.new(8, 0, 2) * yaw(70))
	MapKit.place(corral, "HayBale", v(7, 2, 4.5))
	MapKit.place(corral, "Trough", CFrame.new(-4, 0, -8) * yaw(90))

	-- A covered wagon, west behind the buildings, and a water tank on stilts.
	MapKit.place(b, "Wagon", CFrame.new(-50, 0.1, 58) * yaw(20))
	MapKit.place(b, "WaterTank", v(-48, 0.1, 104))

	-- Oil lanterns on posts along both boardwalks, hanging out over the street, lit warm.
	for _, s in { -1, 1 } do
		for _, z in { 30, 56, 82, 108, 132 } do
			MapKit.place(b, "Lantern", CFrame.new(s * 14.9, 0.8, z) * yaw(s * 90), {
				light = { range = 14, brightness = 1.6, color = Color3.fromRGB(255, 176, 92) },
			})
		end
	end

	-- Cacti, boulders and mesas round the edges.
	local cacti = { v(-28, 0, 16), v(34, 0, 22), v(-60, 0, 20), v(-60, 0, 148), v(36, 0, 140), v(70, 0, 104), v(-70, 0, 52), v(52, 0, 30) }
	for i, at in cacti do
		MapKit.place(b, "Cactus", CFrame.new(at) * yaw(i * 47), { scale = 0.8 + (i % 3) * 0.2 })
	end
	for i, at in { v(-40, 0, 6), v(44, 0, 10), v(-66, 0, 116), v(64, 0, 70), v(-30, 0, 146) } do
		MapKit.place(b, "DesertRock", CFrame.new(at) * yaw(i * 71), { scale = 0.9 + (i % 2) * 0.4 })
	end
	for i, info in { { at = v(-70, 0, 130), size = 0.75 }, { at = v(72, 0, 135), size = 0.85 }, { at = v(-74, 0, 18), size = 0.5 }, { at = v(76, 0, 24), size = 0.55 } } do
		MapKit.place(b, "Mesa", CFrame.new(info.at) * yaw(i * 33), { scale = info.size })
	end

	-- The film set's gear in the street by the hotel: a camera on a crane filming across at the
	-- balcony, the director's chair, a light, and hay bales for the stunt double to land on. The
	-- crew and the actors themselves are puppets each player's game moves (FilmScenes, FilmSetWorld).
	TownSets.filmSetGear(b, FilmScenes.Sets.Gulch.gear)
	gulchBacklot(b)
end

-- A film set's gear (FilmScenes.Sets[...].gear), in the set's own space. `loose`: backlot
-- dressing players walk through (cases, cables, stands), except pieces marked `solid`.
function TownSets.filmSetGear(b: Builder, gear: { FilmScenes.Gear }, loose: boolean?)
	for _, g in gear do
		local at = CFrame.new(g.at) * yaw(g.yaw)
		if g.kit == "DirectorChair" then
			directorChair(b, at, g.label, if loose then g.solid == true else g.solid)
		elseif g.kit == "JungleTemple" then
			MapKit.place(b, g.kit, at, { hitbox = true }) -- players climb its steps
		else
			MapKit.place(b, g.kit, at, {
				solid = if loose then g.solid == true else g.solid,
				light = if g.light then { range = 16, brightness = 1.8, color = Color3.fromRGB(255, 164, 80) } else nil,
				labels = if g.label then { Sign = { text = g.label, color = P.Gold } } else nil,
			})
		end
	end
end

-- Moon Base (film set 2), in its own space (MapModels.FilmSets): the gate at the origin, the set
-- running along +Z, from x = -57 to 63 and z = 2.5 to 112. An open studio backlot: a fenced lot of
-- desert sand with the crew's base camp at the front (star trailers, craft services, a generator,
-- the video village, cases and cables), and the moon set in the middle on grey dust that fades out
-- to sand, lit from truss towers and scaffolds, with painted flats at the far end. The camera
-- stands near the gate filming toward the flats, so everything tall keeps to the sides and the
-- back. Models: art/blender/space_kit.py (the moon) and backlot_kit.py (the studio).

-- The moon set (in set space). The hero spots FilmScenes plays on: the lander's porch and ladder
-- at (-8, 76), the flag at (0.9, 61) and the foam rock the alien hides behind at (16, 80).
local MOON_SET: { FilmScenes.Gear } = {
	{ kit = "MoonFlatEarthrise", at = v(0, 0.2, 101), yaw = 0 },
	{ kit = "MoonFlatStarfield", at = v(39.4, 0.2, 96.3), yaw = 15 },
	{ kit = "MoonFlatHorizon", at = v(-39.4, 0.2, 96.3), yaw = -15 },
	{ kit = "MoonGroundRow", at = v(-8, 0.2, 98), yaw = 0 },
	{ kit = "MoonGroundRow", at = v(14, 0.2, 97.5), yaw = 4 },
	{ kit = "MoonLanderHero", at = v(-8, 0.2, 76), yaw = 0 },
	{ kit = "MoonRocketPad", at = v(36, 0.2, 74), yaw = 180 },
	{ kit = "MoonHabitat", at = v(-36, 0.2, 82), yaw = 0 },
	{ kit = "MoonBuggyHero", at = v(24, 0.2, 54), yaw = 60 },
	{ kit = "MoonTracks", at = v(35, 0.2, 60.5), yaw = 60 },
	{ kit = "MoonFoamRock", at = v(16, 0.2, 80), yaw = 0 },
	{ kit = "MoonFlagMark", at = v(0.9, 0.2, 61), yaw = 0 },
	{ kit = "MoonFootprints", at = v(-4.2, 0.2, 66.6), yaw = 141 },
	{ kit = "MoonCraterBig", at = v(-32, 0.2, 58), yaw = 20 },
	{ kit = "MoonCraterMid", at = v(6, 0.2, 90), yaw = 0 },
	{ kit = "MoonCraterSmall", at = v(-16, 0.2, 92), yaw = 40 },
	{ kit = "MoonCraterSmall", at = v(30, 0.2, 40), yaw = 0 },
	{ kit = "MoonRegolith", at = v(20, 0.2, 90), yaw = 30 },
	{ kit = "MoonRegolith", at = v(-20, 0.2, 70), yaw = -20 },
	{ kit = "MoonBoulders", at = v(48, 0.2, 52), yaw = 20 },
	{ kit = "MoonBoulders", at = v(-22, 0.2, 98), yaw = 200 },
	{ kit = "MoonPebbles", at = v(-14, 0.2, 64), yaw = 0 },
	{ kit = "MoonPebbles", at = v(10, 0.2, 72), yaw = 90 },
	{ kit = "MoonPebbles", at = v(26, 0.2, 86), yaw = 30 },
	{ kit = "MoonFakeEarth", at = v(-17, 0.2, 52), yaw = 160 },
	{ kit = "MoonPropCart", at = v(17, 0.2, 38), yaw = 90 },
}

-- The studio round it: lights, base camp and crew gear (in set space).
local MOON_BACKLOT: { FilmScenes.Gear } = {
	-- Lights: truss towers and scaffolds round the sides aimed at the action, a fresnel and flags.
	{ kit = "BacklotTrussTower", at = v(54, 0.2, 46), yaw = 112 },
	{ kit = "BacklotTrussTower", at = v(-52, 0.2, 50), yaw = -109 },
	{ kit = "BacklotScaffold", at = v(36, 0.2, 98), yaw = 50 },
	{ kit = "BacklotScaffold", at = v(-24, 0.2, 104), yaw = -30 },
	{ kit = "BacklotGroundLight", at = v(-18, 0.2, 62), yaw = -95 },
	{ kit = "BacklotCStand", at = v(-14, 0.2, 56), yaw = 200 },
	{ kit = "BacklotCStand", at = v(26, 0.2, 70), yaw = 120 },
	-- Base camp, east (+x): two star trailers and the generator.
	{ kit = "StarTrailerRed", at = v(52, 0.2, 14), yaw = 0 },
	{ kit = "StarTrailerBlue", at = v(52, 0.2, 31), yaw = 0 },
	{ kit = "PatioTable", at = v(43, 0.2, 22), yaw = 0 },
	{ kit = "BacklotGenerator", at = v(34, 0.2, 10), yaw = 90 },
	{ kit = "BacklotCart", at = v(30, 0.2, 26), yaw = 70 },
	{ kit = "BacklotCableCoil", at = v(26, 0.2, 14), yaw = 0 },
	-- Base camp, west (-x): craft services, the video village, cases.
	{ kit = "BacklotCraftTent", at = v(-46, 0.2, 16), yaw = -90 },
	{ kit = "BacklotScriptTable", at = v(-38, 0.2, 26), yaw = -60 },
	{ kit = "BacklotVideoVillage", at = v(-24, 0.2, 40), yaw = 0 },
	{ kit = "BacklotCaseStack", at = v(-44, 0.2, 34), yaw = -80 },
	{ kit = "BacklotCase", at = v(-37, 0.2, 38), yaw = 20 },
	{ kit = "BacklotCase", at = v(-32, 0.2, 12), yaw = -10 },
	{ kit = "BacklotAppleBoxes", at = v(-14, 0.2, 36), yaw = 30 },
	{ kit = "BacklotAppleBoxes", at = v(10, 0.2, 34), yaw = -20 },
	{ kit = "BacklotCaseStack", at = v(44, 0.2, 64), yaw = 100 },
	-- Desert scatter in the sand round the edges.
	{ kit = "BacklotBerm", at = v(-50, 0.2, 76), yaw = 80 },
	{ kit = "BacklotBerm", at = v(56, 0.2, 88), yaw = -70 },
	{ kit = "BacklotBerm", at = v(-20, 0.2, 18), yaw = 10 },
	{ kit = "BacklotClump", at = v(16, 0.2, 18), yaw = 0 },
	{ kit = "BacklotClump", at = v(-52, 0.2, 100), yaw = 60 },
	{ kit = "BacklotClump", at = v(58, 0.2, 72), yaw = 120 },
	{ kit = "BacklotClump", at = v(-8, 0.2, 26), yaw = 200 },
}

-- Gear FilmScenes lists for Moon Base that the layout above replaces (its first, simpler set
-- pieces); the crew's own gear (camera, chairs, lights) still comes from FilmScenes.
local MOON_REPLACED = {
	SpaceBackdrop = true,
	MoonRocket = true,
	MoonLander = true,
	MoonDome = true,
	MoonBuggy = true,
	MoonCrater = true,
	MoonRock = true,
}

-- A run of kit model `kit` (`length` studs long along its X) from `from` to `to`, stretched to fit.
local function run(b: Builder, kit: string, length: number, from: Vector3, to: Vector3)
	local delta = to - from
	local sections = math.max(1, math.round(delta.Magnitude / length))
	-- Turned by hand rather than with CFrame.lookAt, which the test runner's CFrame gets backwards.
	local turn = CFrame.Angles(0, math.atan2(-delta.X, -delta.Z), 0) * CFrame.Angles(0, math.pi / 2, 0)
	for i = 0, sections - 1 do
		MapKit.place(b, kit, CFrame.new(from + delta * ((i + 0.5) / sections)) * turn, {
			scale = delta.Magnitude / sections / length,
			solid = kit ~= "BacklotCable",
		})
	end
end

function TownSets.moonBase(b: Builder)
	-- The ground: grey moon dust in overlapping rounds round the action, each ringed by two paler
	-- rounds that fade it into the desert sand, so the set has no hard edge.
	local dust = Color3.fromRGB(201, 204, 210)
	local tones = { dust, Color3.fromRGB(213, 201, 183), Color3.fromRGB(224, 199, 156) }
	local rounds = { -- { x, z, radius }
		{ 0, 74, 26 }, { -26, 82, 20 }, { 26, 80, 20 }, { -32, 60, 14 }, { 30, 62, 14 },
		{ 0, 92, 13 }, { -22, 93, 11 }, { 22, 93, 11 }, { 40, 86, 12 }, { -42, 88, 12 },
	}
	for k = 3, 1, -1 do
		for _, r in rounds do
			b:cylinder("MoonDust", 0.1, 2 * (r[3] + (k - 1) * 5), v(r[1], 0.04 + (4 - k) * 0.03, r[2]), tones[k], Enum.Material.Sand)
		end
	end
	-- The way in from the gate to the camera: packed dirt.
	b:block("MoonTrack", v(10, 0.1, 36), v(0, 0.06, 20), DUST, Enum.Material.Sand)

	-- The lot's fence, with the gate in the middle of the front.
	local x0, x1, z0, z1 = -56, 62, 2.5, 111
	run(b, "BacklotFence", 12, v(-11, 0, z0), v(x0, 0, z0))
	run(b, "BacklotFence", 12, v(x1, 0, z0), v(11, 0, z0))
	run(b, "BacklotFence", 12, v(x0, 0, z0), v(x0, 0, z1))
	run(b, "BacklotFence", 12, v(x0, 0, z1), v(x1, 0, z1))
	run(b, "BacklotFence", 12, v(x1, 0, z1), v(x1, 0, z0))
	for _, at in { v(x0, 0, z0), v(x0, 0, z1), v(x1, 0, z1), v(x1, 0, z0) } do
		MapKit.place(b, "BacklotFencePost", at)
	end
	local quiet: MapKit.Label = { text = "QUIET ON SET", color = P.Burgundy, stroke = 0 }
	MapKit.place(b, "BacklotFenceSign", CFrame.new(x1 - 0.5, 0, 56) * yaw(90), { labels = { Sign = quiet } })
	MapKit.place(b, "BacklotFenceSign", CFrame.new(x0 + 0.5, 0, 26) * yaw(-90), { labels = { Sign = quiet } })

	-- Cables from the generator: along the front past the gate path (over a ramp) to the video
	-- village, and up the east side to the truss tower.
	run(b, "BacklotCable", 8, v(30, 0.2, 10), v(4, 0.2, 10))
	MapKit.place(b, "BacklotCableRamp", CFrame.new(0, 0.2, 10) * yaw(0))
	run(b, "BacklotCable", 8, v(-4, 0.2, 10), v(-24, 0.2, 10))
	run(b, "BacklotCable", 8, v(-24, 0.2, 10), v(-24, 0.2, 34))
	run(b, "BacklotCable", 8, v(36, 0.2, 14), v(50, 0.2, 40))

	TownSets.filmSetGear(b, MOON_SET)
	TownSets.filmSetGear(b, MOON_BACKLOT)
	for _, g in FilmScenes.Sets.MoonBase.gear do
		if not MOON_REPLACED[g.kit] then
			TownSets.filmSetGear(b, { g })
		end
	end
	-- Two more chairs at the video village.
	directorChair(b, CFrame.new(-26.5, 0.2, 35.5) * yaw(180), "PRODUCER")
	directorChair(b, CFrame.new(-21.5, 0.2, 35.5) * yaw(180), nil)
end

-- The Jungle Temple (film set 3), in its own space: the gate at the origin, the set running along
-- +Z, from x = -36 to 84. Jungle floor with a dirt path to a clearing in front of the temple
-- (art/blender/jungle_kit.py).
function TownSets.jungleTemple(b: Builder)
	local floor = Color3.fromRGB(74, 122, 52)
	local dirt = Color3.fromRGB(150, 110, 70)
	b:block("JungleGround", v(124, 0.2, 126), v(24, 0.1, 61), floor, Enum.Material.Grass)
	b:block("JunglePath", v(12, 0.2, 46), v(0, 0.12, 22), dirt, Enum.Material.Ground)
	b:block("JungleClearing", v(48, 0.2, 42), v(24, 0.12, 65), dirt, Enum.Material.Ground)
	TownSets.filmSetGear(b, FilmScenes.Sets.Jungle.gear)
end

-- Starlight Park ---------------------------------------------------------------------------------

local BLOSSOM = Color3.fromRGB(255, 160, 205)

-- Park trees, benches and lamps are Blender kit models (MapKit).
local function parkTree(b: Builder, height: number, color: Color3)
	MapKit.place(b, if color == BLOSSOM then "BlossomTree" else "ParkTree", CFrame.identity, { scale = height / 7 })
end

local function parkLamp(b: Builder)
	MapKit.place(b, "ParkLamp", CFrame.identity, {
		light = { range = 16, brightness = 1.4, color = Color3.fromRGB(255, 222, 160) },
	})
end

-- Starlight Park: about 210 wide and 125 deep. An arch in from the hedge, a wide path to a
-- fountain plaza, a big pond with an island, a bridge and ducks, a bandstand, lamps, benches,
-- blocky trees (some in blossom), flower beds, and an open-air movie screen at the far end with
-- picnic blankets in front, under the gold star hill.
function TownSets.park(b: Builder)
	-- Paths: the main path to the screen, a cross path through the fountain plaza, and a spur to
	-- the bandstand.
	local function path(name: string, size: Vector3, at: Vector3)
		b:block(name, v(size.X, 0.2, size.Z), at + v(0, 0.1, 0), P.Paving)
		local along = size.Z > size.X
		for _, s in { -1, 1 } do
			local offset = if along then v(s * (size.X / 2 + 0.4), 0, 0) else v(0, 0, s * (size.Z / 2 + 0.4))
			local edgeSize = if along then v(0.8, 0.3, size.Z) else v(size.X, 0.3, 0.8)
			b:block("PathEdge", edgeSize, at + offset + v(0, 0.15, 0), P.Cream)
		end
	end
	path("ParkPath", v(10, 0, 90), v(0, 0, 45))
	path("ParkPath", v(130, 0, 8), v(25, 0, 50))
	path("ParkPath", v(8, 0, 22), v(60, 0, 65))
	-- A path from the cross path up to the pond's bridge, and a paved square in front of the
	-- movie screen where the main path ends.
	path("ParkPath", v(8, 0, 32), v(-24, 0, 70))
	path("ParkPath", v(40, 0, 18), v(0, 0, 97))

	-- The entrance arch.
	local name: MapKit.Label = { text = "STARLIGHT PARK", color = P.OffWhite, stroke = 4 }
	MapKit.place(b, "ParkArch", v(0, 0, 4), { hitbox = true, labels = { SignFront = name, SignBack = name } })

	-- The fountain plaza where the paths cross: paving rings, the Blender fountain, and a jet of
	-- water with spray.
	local plaza = v(0, 0, 50)
	b:cylinder("FountainPlaza", 0.24, 26, plaza + v(0, 0.12, 0), P.Paving)
	b:cylinder("FountainPlazaRing", 0.28, 22, plaza + v(0, 0.14, 0), P.Cream)
	b:cylinder("FountainPlazaInner", 0.3, 20, plaza + v(0, 0.15, 0), P.Paving)
	MapKit.place(b, "ParkFountain", plaza + v(0, 0.3, 0))
	local jet = b:cylinder("FountainJet", 3, 0.8, plaza + v(0, 6.6, 0), WATER_LIGHT, NEON)
	local splash = b:ball("FountainSplash", 2.2, plaza + v(0, 8.2, 0), WATER_LIGHT, NEON)
	jet.Transparency = 0.3
	splash.Transparency = 0.4
	jet.CanCollide = false
	splash.CanCollide = false

	-- The pond, west of the main path: a stone rim, bright water, an island with a blossom tree,
	-- a bridge out to it, lily pads and ducks.
	local pond = TownSets.Pond
	local radius = TownSets.PondRadius
	b:cylinder("PondWater", 0.5, radius * 2, pond + v(0, 0.25, 0), WATER)
	b:cylinder("PondShine", 0.52, radius * 1.3, pond + v(0, 0.27, 0), WATER_LIGHT)
	local stones = 22
	for i = 0, stones - 1 do
		local a = i / stones * math.pi * 2
		local at = pond + v(math.sin(a) * (radius + 1), 0, math.cos(a) * (radius + 1))
		MapKit.place(b, "PondStone", CFrame.new(at) * CFrame.Angles(0, a, 0), { scale = 1.1 + (i % 3) * 0.08 })
	end
	local island = pond + v(-6, 0, 2)
	b:cylinder("Island", 1, 16, island + v(0, 0.5, 0), P.Green, GRASS)
	b:cylinder("IslandSand", 0.8, 17.4, island + v(0, 0.4, 0), SAND)
	parkTree(b:sub(island + v(0, 1, 0)), 8, BLOSSOM)
	-- The bridge from the east shore to the island, its ramp down on the shore end.
	local fromX, toX = pond.X + radius + 3, island.X + 7
	MapKit.place(b, "FootBridge", v((fromX + toX) / 2, 0, island.Z), { hitbox = true })
	for _, at in { v(8, 0, -10), v(-14, 0, -12), v(12, 0, 12), v(-4, 0, 16), v(16, 0, -2) } do
		MapKit.place(b, "LilyPad", CFrame.new(pond + at + v(0, 0.5, 0)) * yaw(at.X * 31), { solid = false })
	end
	MapKit.place(b, "LilyFlower", pond + v(12, 0.5, 12), { solid = false })
	-- Ducks (src/client/MapLife.luau paddles them round the pond). Each knows its loop, where the
	-- pond's middle is in the world and where it was put, so MapLife never has to guess.
	for i, duck in { { at = v(10, 0.5, -4), turn = 30, size = 0.9 }, { at = v(13, 0.5, -1), turn = 40, size = 0.55 }, { at = v(-16, 0.5, -10), turn = 200, size = 0.8 } } do
		local model = MapKit.place(b, "Duck", CFrame.new(pond + duck.at) * yaw(duck.turn), { scale = duck.size, solid = false })
		model:SetAttribute("DuckLoop", i)
		model:SetAttribute("PondCentre", b:at(pond).Position)
		model:SetAttribute("Home", model.WorldPivot)
	end

	-- The bandstand, east of the main path (octagonal, with a striped roof). People walk in.
	MapKit.place(b, "Bandstand", v(60, 0, 86), { hitbox = true })

	-- The open-air movie screen at the far end, with picnic blankets on the lawn in front.
	MapKit.place(b, "MovieScreen", v(0, 0, 112), {
		labels = {
			Screen = { text = "NOW SHOWING\nHOLLYWOOD RNG", color = P.Gold, stroke = 5 },
			Marquee = { text = "MOVIES UNDER THE STARS", color = P.Gold, stroke = 3 },
		},
	})
	for i, at in { v(-14, 0, 92), v(0, 0, 96), v(14, 0, 92) } do
		MapKit.place(b, "PicnicBlanket", CFrame.new(at + v(0, 0.2, 0)) * yaw(i * 12 - 24), { solid = false })
	end

	-- Lamps and benches along the main path.
	for _, z in { 18, 34, 66, 82 } do
		for _, s in { -1, 1 } do
			parkLamp(b:sub(v(s * 7, 0, z)))
		end
	end
	for _, info in { { at = v(9, 0, 26), turn = -90 }, { at = v(-9, 0, 26), turn = 90 }, { at = v(9, 0, 74), turn = -90 }, { at = v(-9, 0, 74), turn = 90 } } do
		MapKit.place(b, "ParkBench", CFrame.new(info.at) * yaw(info.turn))
	end

	-- Trees and flowers.
	local trees = {
		v(-22, 0, 14), v(-40, 0, 26), v(-70, 0, 34), v(-92, 0, 20), v(-96, 0, 60), v(-94, 0, 108),
		v(-28, 0, 116), v(22, 0, 16), v(40, 0, 28), v(76, 0, 30), v(96, 0, 18), v(94, 0, 64),
		v(88, 0, 110), v(34, 0, 112), v(28, 0, 72), v(-44, 0, 36),
	}
	for i, at in trees do
		local color = if i % 4 == 0 then BLOSSOM elseif i % 2 == 0 then P.DarkGreen else P.Green
		parkTree(b:sub(CFrame.new(at) * yaw(i * 37)), 7 + (i % 3) * 1.5, color)
	end
	for _, info in { { at = v(-16, 0, 38), size = v(10, 0, 6) }, { at = v(16, 0, 38), size = v(10, 0, 6) }, { at = v(-13, 0, 62), size = v(8, 0, 6) }, { at = v(16, 0, 62), size = v(10, 0, 6) }, { at = v(40, 0, 60), size = v(14, 0, 6) } } do
		TownSets.flowerBed(b:sub(info.at), info.size)
	end

	-- A low ranch fence along the two sides.
	for _, s in { -1, 1 } do
		if s < 0 then
			-- A gap on the west side for the Jungle Temple film set's gate.
			fenceRun(b, v(s * 106, 0, 2), v(s * 106, 0, 30), "White")
			fenceRun(b, v(s * 106, 0, 50), v(s * 106, 0, 124), "White")
		else
			fenceRun(b, v(s * 106, 0, 2), v(s * 106, 0, 124), "White")
		end
	end
end

-- The blimp ---------------------------------------------------------------------------------------

-- A big striped blimp that drifts round the town (src/client/Blimp.luau moves it). Nose toward -Z,
-- about 46 long. Returns the model, pivoted at its middle.
function TownSets.blimp(b: Builder): Model
	local middle = MapKit.bounds("Blimp").center
	local banner: MapKit.Label = { text = "HOLLYWOOD RNG", color = P.Gold, stroke = 4 }
	local model = MapKit.place(b, "Blimp", CFrame.new(-middle), { far = true, labels = { BannerA = banner, BannerB = banner } })
	Build.decorative(model)
	model.WorldPivot = b:at(CFrame.identity)
	return model
end

return TownSets
