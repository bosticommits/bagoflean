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

local function directorChair(b: Builder, at: CFrame, label: string?)
	MapKit.place(b, "DirectorChair", at, {
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
	local cacti = { v(-34, 0, 20), v(34, 0, 22), v(-62, 0, 30), v(-30, 0, 132), v(36, 0, 140), v(70, 0, 104), v(-70, 0, 52), v(52, 0, 30) }
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
end

-- A film set's gear (FilmScenes.Sets[...].gear), in the set's own space.
function TownSets.filmSetGear(b: Builder, gear: { FilmScenes.Gear })
	for _, g in gear do
		local at = CFrame.new(g.at) * yaw(g.yaw)
		if g.kit == "DirectorChair" then
			directorChair(b, at, g.label)
		elseif g.kit == "JungleTemple" then
			MapKit.place(b, g.kit, at, { hitbox = true }) -- players climb its steps
		else
			MapKit.place(b, g.kit, at, {
				light = if g.light then { range = 16, brightness = 1.8, color = Color3.fromRGB(255, 164, 80) } else nil,
			})
		end
	end
end

-- Moon Base (film set 2), in its own space (MapModels.FilmSets): the gate at the origin, the set
-- running along +Z, from x = -57 to 63. Grey moon dust with a paler track from the gate to the
-- camera; the rocket, lander, dome and backdrop are Blender models (art/blender/space_kit.py).
function TownSets.moonBase(b: Builder)
	local dust = Color3.fromRGB(201, 204, 210)
	b:block("MoonGround", v(124, 0.2, 116), v(3, 0.1, 56), dust, Enum.Material.Sand)
	b:block("MoonTrack", v(10, 0.2, 38), v(0, 0.12, 19), dust:Lerp(Color3.new(1, 1, 1), 0.35), Enum.Material.Sand)
	TownSets.filmSetGear(b, FilmScenes.Sets.MoonBase.gear)
end

-- The Jungle Temple (film set 3), in its own space: the gate at the origin, the set running along
-- +Z, from x = -36 to 84 and z = 0 to 126 (MapModels.FilmSets). An open backlot: a chain-link fence
-- round the lot, the star trailers and craft services by the dirt road in, the director's village
-- and the camera in the clearing, and the themed set beyond: the temple (FilmScenes gear) with
-- ruins, fake rocks, a river and a bridge, lit from truss towers and scaffolds and backed by
-- painted flats whose wooden bracing shows from behind. Models: art/blender/jungle_kit.py and
-- backlot_kit.py.
--
-- Kept clear for the scene (src/shared/FilmScenes.luau): the camera and crew corner (x 8 to 40,
-- z 40 to 66), the boulder's run down the steps to z = 66 (x 18 to 30) and the explorer's dive
-- to (31, 74.5).
local JUNGLE_DIRT = Color3.fromRGB(150, 110, 70)

-- One piece of the Jungle Temple's dressing: kit model, where (x, z on the set's ground), facing.
-- `soft` pieces (ground cover, cables) don't collide; `walk` ones are walked on (hitbox).
type Dressing = { kit: string, x: number, z: number, turn: number, soft: boolean?, walk: boolean?, light: boolean?, scale: number? }

local function dress(kit: string, x: number, z: number, turn: number?, extra: { soft: boolean?, walk: boolean?, light: boolean?, scale: number? }?): Dressing
	local e = extra or {}
	return { kit = kit, x = x, z = z, turn = turn or 0, soft = e.soft, walk = e.walk, light = e.light, scale = e.scale }
end

local SOFT = { soft = true }
local LIT = { light = true }

local JUNGLE_DRESSING: { Dressing } = {
	-- Worn dirt: the road in from the gate and the clearing in front of the temple, overlapping
	-- ragged patches so neither ends in a straight line.
	dress("JungleDirtPatchLong", 0, 9, 92, SOFT),
	dress("JungleDirtPatchLong", 1, 27, 86, SOFT),
	dress("JungleDirtPatchSmall", -2, 40, 30, SOFT),
	dress("JungleDirtPatch", 8, 50, 10, SOFT),
	dress("JungleDirtPatch", 26, 48, -8, SOFT),
	dress("JungleDirtPatch", 42, 54, 25, SOFT),
	dress("JungleDirtPatch", 12, 64, -20, SOFT),
	dress("JungleDirtPatch", 32, 64, 15, SOFT),
	dress("JungleDirtPatch", 20, 76, 0, SOFT),
	dress("JungleDirtPatchLong", 24, 70, 90, SOFT),
	dress("JungleDirtPatchSmall", 4, 78, 40, SOFT),
	dress("JungleDirtPatchSmall", 44, 74, -30, SOFT),
	dress("JungleDirtPatchSmall", 50, 44, 60, SOFT),
	dress("JungleDirtPatchSmall", -4, 56, 10, SOFT),
	-- The back of the shrine on top of the temple is a plywood flat, like the rest of the set.
	-- The road in: two star trailers (doors toward the road), craft services across from them.
	dress("StarTrailerRed", -22, 9, 180),
	dress("StarTrailerBlue", -22, 26, 180),
	dress("PatioTable", -12, 17.5),
	dress("BacklotGenerator", -31, 52),
	dress("BacklotScriptTable", 19, 27, 90),
	dress("BacklotAppleBoxes", 13, 9, 30),
	dress("BacklotCaseStack", 30, 8, -90),
	-- The director's village beside the camera, out of the crew's way.
	dress("BacklotVideoVillage", 1, 54, 180),
	dress("BacklotCart", 44, 46, -90),
	dress("BacklotCase", 44, 40.5, 10),
	dress("BacklotAppleBoxes", 36, 42, -15),
	dress("BacklotCableCoil", 6, 45, 20, SOFT),
	-- Lights: truss towers and scaffolds aimed at the temple steps, a scrim beside the action.
	dress("BacklotTrussTower", -14, 48, -130, LIT),
	dress("BacklotTrussTower", 62, 48, 130, LIT),
	dress("BacklotScaffold", -9, 70, -110, LIT),
	dress("BacklotScaffold", 58, 68, 110, LIT),
	dress("BacklotScrim", 47, 70, 150),
	dress("BacklotCStand", 4, 68, -150),
	dress("BacklotGroundLight", 24, 118, 180), -- behind the temple, lighting the backdrop
	dress("BacklotCaseStack", -20, 54, 90),
	dress("BacklotCase", 68, 54, -20),
	-- Cable runs from the generator along the edge of the clearing, a crossover where they cross
	-- the road, and risers to the towers.
	dress("BacklotCable", -26, 42, 0, SOFT),
	dress("BacklotCable", -18, 42, 0, SOFT),
	dress("BacklotCable", -10, 42, 0, SOFT),
	dress("BacklotCableRamp", -3, 42, 0, SOFT),
	dress("BacklotCableRamp", 3, 42, 0, SOFT),
	dress("BacklotCable", 10, 42, 0, SOFT),
	dress("BacklotCable", 18, 42, 0, SOFT),
	dress("BacklotCable", 26, 42, 0, SOFT),
	dress("BacklotCable", 34, 42, 0, SOFT),
	dress("BacklotCable", 42, 42, 0, SOFT),
	dress("BacklotCable", 50, 42, 0, SOFT),
	dress("BacklotCable", 58, 42, 0, SOFT),
	dress("BacklotCable", 62, 45, 90, SOFT),
	dress("BacklotCable", -14, 45, 90, SOFT),
	dress("BacklotCable", -12, 56, 90, SOFT),
	dress("BacklotCable", -12, 64, 90, SOFT),

	-- The themed set. Backdrop flats behind the temple, bracing toward the back fence.
	dress("JungleBackdrop", 24, 115.5),
	dress("JungleBackdropSide", -10, 111, -25),
	dress("JungleBackdropSide", 58, 111, 25),
	-- Fake rock walls either side of the temple, plywood backs showing behind.
	dress("JungleFakeCliff", -6, 104, -10),
	dress("JungleFakeRock", 49, 106, 15),
	dress("JungleFakeRock", 72, 104, 30),
	-- The river: out from behind the left flat, past a plank bridge, bending off under the fence.
	dress("JungleRiver", -26, 94, 90, SOFT),
	dress("JungleRiverBend", -38, 82, 180, SOFT),
	dress("JungleBridge", -26, 97, 90, { walk = true }),
	-- Ruins round the clearing.
	dress("JungleStoneHead", 58, 79, -25),
	dress("JungleColumnFallen", -12, 60, 25),
	dress("JungleArch", 48, 30, -15),
	dress("JungleVines", -2, 94, 90),
	dress("JungleVines", 50, 94, -90),
	dress("JungleRuin", 66, 84, 40),
	-- Plants on the set.
	dress("JungleBanana", -16, 78, 20),
	dress("JungleBanana", 68, 74, 200),
	dress("JungleBigLeaf", 4, 76, 0, SOFT),
	dress("JungleBigLeaf", 45, 79, 60, SOFT),
	dress("JungleBigLeaf", -20, 104, 90, SOFT),
	dress("JungleBush", 42, 100, 0),
	dress("JungleBush", 6, 100, 120),
	dress("JungleBush", -30, 76, 40),
	dress("JungleFlowers", 12, 73, 0, SOFT),
	dress("JungleFlowers", 38, 70, 90, SOFT),
	dress("JungleFlowers", -18, 88, 30, SOFT),
	dress("JungleFlowers", 60, 90, 0, SOFT),
	dress("JungleRoots", -8, 90, 0, SOFT),
	dress("JungleRoots", 56, 98, 140, SOFT),
	dress("JungleLeafLitter", 10, 86, 0, SOFT),
	dress("JungleLeafLitter", 40, 88, 50, SOFT),
	dress("JungleLeafLitter", -4, 70, 20, SOFT),
	dress("JungleLeafLitter", 54, 62, 80, SOFT),
	-- Leaves blown over the edges of the worn clearing and road, so they don't end in straight lines.
	dress("JungleLeafLitter", 0.5, 47, 90, SOFT),
	dress("JungleLeafLitter", 47.5, 52, 100, SOFT),
	dress("JungleLeafLitter", 47, 80, 70, SOFT),
	dress("JungleLeafLitter", 1, 82, 120, SOFT),
	dress("JungleLeafLitter", 30, 44.5, 0, SOFT),

	-- The edges: mossy mounds, ferns and leaves along the fence so the lot fades into the woods.
	dress("JungleMound", -31, 6, 10),
	dress("JungleMound", -32, 62, 80),
	dress("JungleMound", 79, 8, -20),
	dress("JungleMound", 80, 30, 90),
	dress("JungleMound", 79, 92, 70),
	dress("JungleMound", 80, 116, 0),
	dress("JungleMound", -31, 118, 30),
	dress("JungleFern", -32, 44, 10),
	dress("JungleFern", -31, 100, 60),
	dress("JungleFern", 80, 52, 0),
	dress("JungleFern", 79, 78, 30),
	dress("JungleFern", 8, 4, 80),
	dress("JungleFern", -12, 4, 20),
	dress("JungleBush", 30, 3, 0),
	dress("JungleBush", 60, 4, 50),
	dress("JungleBigLeaf", 72, 18, 40, SOFT),
	dress("JungleLeafLitter", -12, 37, 0, SOFT),
	dress("JungleLeafLitter", 11, 34, 70, SOFT),
	dress("JungleLeafLitter", 66, 22, 30, SOFT),
	dress("JungleLeafLitter", -28, 86, 10, SOFT),
	dress("JunglePalm", 76, 10, 250),
	dress("JungleTree", -29, 120, 70),
	dress("JungleTree", 77, 121, 160),
	dress("JungleBanana", -30, 110, 10),
	dress("JungleBigLeaf", 76, 108, 30, SOFT),
	dress("JungleBush", -24, 122, 0),
	dress("JungleFern", 70, 122, 50),
	dress("JungleBigLeaf", -31, 30, 120, SOFT),
	dress("JungleBush", -30, 38, 0),
	dress("JungleBanana", 78, 40, 300),
	dress("JungleFern", 74, 30, 0),
	dress("JungleBigLeaf", 78, 62, 200, SOFT),
	dress("JunglePalm", 40, 6, 80),
	-- The woods outside the fence.
	dress("JungleTree", -44, 18, 30),
	dress("JungleTree", -46, 60, 140),
	dress("JungleTree", -44, 104, 250),
	dress("JungleTree", 92, 26, 80),
	dress("JungleTree", 94, 72, 200),
	dress("JungleTree", 92, 112, 10),
	dress("JungleTree", 0, 136, 100),
	dress("JungleTree", 46, 138, 300),
	dress("JunglePalm", -42, 40, 30),
	dress("JunglePalm", -42, 84, 160),
	dress("JunglePalm", 90, 50, 290),
	dress("JunglePalm", 90, 94, 20),
	dress("JunglePalm", 24, 134, 0),
	dress("JunglePalm", 72, 134, 120),
	dress("JungleMound", -42, 120, 40),
	dress("JungleMound", 90, 128, 0),
}

-- A run of backlot chain-link fence (12-stud sections, overlapping a little to fit the length)
-- from `from` to `to`, its green mesh facing `inward` degrees.
local function backlotFence(b: Builder, from: Vector3, to: Vector3, inward: number, signs: { [number]: string }?)
	local delta = to - from
	local sections = math.ceil(delta.Magnitude / 12)
	for i = 1, sections do
		local mid = from + delta * ((i - 0.5) / sections)
		local text = signs and signs[i]
		MapKit.place(b, if text then "BacklotFenceSign" else "BacklotFence", CFrame.new(mid) * yaw(inward), {
			labels = if text then { Sign = { text = text, color = P.Navy, stroke = 0 } } else nil,
		})
	end
end

function TownSets.jungleTemple(b: Builder)
	-- The lot's ground is the same green as the woods round it, so it has no edge; the dirt road
	-- and the clearing are ragged worn patches on it (in JUNGLE_DRESSING).
	b:block("JungleGround", v(124, 0.2, 126), v(24, 0.1, 61), P.Green, GRASS)
	TownSets.filmSetGear(b, FilmScenes.Sets.Jungle.gear)

	-- The fence: down both sides and across the back, with studio banners by the way in.
	backlotFence(b, v(-35.5, 0.2, 0), v(-35.5, 0.2, 125.5), -90, { [2] = "STAGE 3: JUNGLE" })
	backlotFence(b, v(83.5, 0.2, 0), v(83.5, 0.2, 125.5), 90, { [2] = "QUIET! FILMING" })
	backlotFence(b, v(-35.5, 0.2, 125.5), v(83.5, 0.2, 125.5), 0)
	for _, at in { v(-35.5, 0.2, 125.5), v(83.5, 0.2, 125.5), v(-35.5, 0.2, 0), v(83.5, 0.2, 0) } do
		MapKit.place(b, "BacklotFencePost", at)
	end

	for _, d in JUNGLE_DRESSING do
		MapKit.place(b, d.kit, CFrame.new(d.x, 0.2, d.z) * yaw(d.turn), {
			solid = if d.soft then false else nil,
			hitbox = d.walk,
			scale = d.scale,
			light = if d.light then { range = 18, brightness = 1.6, color = Color3.fromRGB(255, 236, 200) } else nil,
		})
	end
	-- The back of the shrine on top of the temple is a plywood flat, like the rest of the set.
	MapKit.place(b, "JungleShrineBack", v(24, 16.2, 101))
	-- Jungle undergrowth along the outside of the fence and canopy trees behind it (past the play
	-- area, so nobody walks into it), cycling through the plants so no two neighbours match.
	local plants = { "JungleFern", "JungleBigLeaf", "JungleBush", "JungleMound", "JungleBanana", "JungleFern", "JungleBush" }
	local function undergrowth(from: Vector3, to: Vector3, out: Vector3, seed: number)
		local n = math.floor((to - from).Magnitude / 7)
		for i = 0, n do
			local k = (i * 3 + seed) % #plants + 1
			local wobble = ((i * 37 + seed * 11) % 5) - 2
			local at = from:Lerp(to, i / n) + out * (4 + wobble * 0.8)
			MapKit.place(b, plants[k], CFrame.new(at) * yaw(i * 67 + seed * 23), { solid = false })
			if i % 2 == 0 then
				local tree = if (i + seed) % 4 == 0 then "JunglePalm" else "JungleTree"
				MapKit.place(b, tree, CFrame.new(at + out * (10 + wobble * 2)) * yaw(i * 41), { far = true, scale = 0.9 + (i % 3) * 0.15 })
			end
		end
	end
	undergrowth(v(-35.5, 0.2, 44), v(-35.5, 0.2, 126), v(-1, 0, 0), 1) -- nearer the gate is a studio lot
	undergrowth(v(83.5, 0.2, 2), v(83.5, 0.2, 126), v(1, 0, 0), 2)
	undergrowth(v(-35.5, 0.2, 125.5), v(83.5, 0.2, 125.5), v(0, 0, 1), 3)

	MapKit.place(b, "BacklotCraftTent", CFrame.new(19, 0.2, 16) * yaw(90), {
		labels = { Sign = { text = "CRAFT SERVICES", color = P.Burgundy, stroke = 0 } },
	})
	directorChair(b, CFrame.new(-12, 0.2, 15.5) * yaw(180), nil)
	directorChair(b, CFrame.new(-12, 0.2, 19.5), nil)
	directorChair(b, CFrame.new(7, 0.2, 49) * yaw(180), "PRODUCER")
	directorChair(b, CFrame.new(9.6, 0.2, 49) * yaw(180), nil)
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

	-- The way to the Jungle Temple film set: a dirt trail from the cross path's west end to the
	-- gap in the west fence, a jungle arch over the gap, and signposts pointing the way from the
	-- fountain plaza and the end of the cross path.
	b:block("JungleTrail", v(66, 0.2, 10), v(-73, 0.1, 44), JUNGLE_DIRT, Enum.Material.Ground)
	local jungle: MapKit.Label = { text = "JUNGLE TEMPLE", color = P.Gold, stroke = 4 }
	MapKit.place(b, "JungleGateArch", CFrame.new(-106, 0, 40) * yaw(-90), { labels = { Sign = jungle } })
	for _, at in { v(-17, 0, 44), v(-41, 0, 57.5) } do
		MapKit.place(b, "JungleSignpost", at, { labels = { Sign = { text = "JUNGLE", color = P.OffWhite, stroke = 3 } } })
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
