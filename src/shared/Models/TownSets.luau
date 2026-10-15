--!strict
-- The town's landmarks and film sets (map revamp pass 1, see MapModels): the Grand Premiere
-- Theatre and the Studio Gate at the two ends of the boulevard, a themed film set in each back
-- street between the lots, poster columns on the sidewalks, and a far-off city skyline.
--
-- Each piece is laid out in its own space like the rest of the models (origin at the bottom
-- centre, front toward -Z); MapModels places them. Phones come first: lights only where they make
-- a focal point (lamps, lanterns, the theatre marquee), small parts cast no shadow
-- (MapModels.build), and every piece stays within a few dozen parts.
--
-- The buildings and props themselves are low-poly Blender models from the map kit
-- (art/blender/map_kit_town.py, placed with MapKit). Their sign boards are blank: the words go on
-- a see-through board in front (`words`), and the big ones players walk round or onto get plain
-- invisible blocks to bump into (`blocker`), which are kinder to walk on than a mesh's outline.
local Build = require(script.Parent.Build)
local LotModels = require(script.Parent.LotModels)
local MapKit = require(script.Parent.MapKit)

type Builder = Build.Builder

local P = Build.Palette
local NEON = Enum.Material.Neon
local METAL = Enum.Material.Metal
local GLASS = Enum.Material.Glass
local GRASS = Enum.Material.Grass

local INK = Color3.fromRGB(11, 15, 31) -- the menus' outline color (UiKit.INK)
local PINK = Color3.fromRGB(255, 120, 170)
local CHROMA = Color3.fromRGB(40, 200, 90) -- green screen green
local TEAL = Color3.fromRGB(32, 178, 190)

local TownSets = {}

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

local function outlined(target: BasePart, face: Enum.NormalId, text: string, color: Color3, thickness: number?): TextLabel
	local label = Build.sign(target, face, text, color)
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = thickness or 4
	stroke.Parent = label
	return label
end

-- A see-through board carrying a sign's words, just in front of a kit model's blank board.
-- `outline` gives the words the menus' dark outline.
local function words(b: Builder, size: Vector3, at: CFrame | Vector3, face: Enum.NormalId, text: string, color: Color3, outline: number?): BasePart
	local board = b:block("SignWords", size, at, P.OffWhite)
	board.Transparency = 1
	board.CanCollide = false
	board.CanQuery = false
	board.CanTouch = false
	board.CastShadow = false
	if outline ~= nil then
		outlined(board, face, text, color, outline)
	else
		Build.sign(board, face, text, color)
	end
	return board
end

-- An invisible block players bump into (or stand on), for a kit model that isn't solid itself.
local function blocker(b: Builder, size: Vector3, at: CFrame | Vector3, round: boolean?): BasePart
	local p = if round then b:cylinder("Blocker", size.Y, size.X, at, P.Grey) else b:block("Blocker", size, at, P.Grey)
	p.Transparency = 1
	p.CanTouch = false
	p.CastShadow = false
	return p
end

-- Grand Premiere Theatre -------------------------------------------------------------------------

-- A movie palace: steps up to a bulb-lit marquee, columns and poster cases, a tall "RNG" sign
-- with a gold star on top, side wings and searchlights. About 52 wide and 26 deep; the bottom
-- step is at z = -3.
function TownSets.theatre(b: Builder)
	MapKit.place(b, "Theatre", CFrame.identity)
	-- The plinth and steps to walk up, the porch under the marquee, and the hall and wings.
	blocker(b, v(52, 1, 26), v(0, 0.5, 13))
	for i = 0, 2 do
		local h = (3 - i) / 3
		blocker(b, v(26, h, 1), v(0, h / 2, -i - 0.5))
	end
	blocker(b, v(34, 22, 20), v(0, 12, 16))
	for _, side in { -1, 1 } do
		blocker(b, v(8.6, 14, 17), v(side * 21.3, 8, 16.5))
	end
	for _, x in { -15, -9, 9, 15 } do
		blocker(b, v(2.2, 12, 2.2), v(x, 7, 4.6))
	end

	-- The bulbs under the marquee light the steps and the carpet below (a warm pool you walk into).
	local underside = blocker(b, v(25, 0.3, 6.4), v(0, 7.9, 2.5))
	underside.Name = "MarqueeGlow"
	underside.CanCollide = false
	underside.CanQuery = false
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Bottom
	spot.Angle = 120
	spot.Range = 20
	spot.Brightness = 2.2
	spot.Color = Color3.fromRGB(255, 214, 150)
	spot.Parent = underside
	words(b, v(24, 2.6, 0.05), v(0, 10, -1.3), Enum.NormalId.Front, "TONIGHT: YOUR PREMIERE", P.Burgundy)
	-- Two films "coming soon" in the poster cases, and the tall RNG blade.
	for _, poster in { { x = -12, title = "SPACE\nCOWBOYS" }, { x = 12, title = "LOVE IN\nPARIS" } } do
		words(b, v(3.4, 5, 0.05), v(poster.x, 5.2, 5.55), Enum.NormalId.Front, poster.title, P.OffWhite, 3)
	end
	words(b, v(5.6, 18, 0.05), v(0, 22.3, 4.25), Enum.NormalId.Front, "R\nN\nG", P.Gold, 6)

	-- Searchlights on the front corners of the plinth.
	for _, side in { -1, 1 } do
		LotModels.searchlight(b:sub(v(side * 23, 1, 2)), side * 25, P.Light)
	end
end

-- Studio Gate ------------------------------------------------------------------------------------

-- A grand studio entrance: two towers, an arch with "HOLLYWOOD RNG STUDIOS" on both faces and a gold
-- star, iron gates swung open, and a guard booth. About 36 wide; the road runs through the middle.
function TownSets.studioGate(b: Builder)
	MapKit.place(b, "StudioGate", CFrame.identity)
	for _, side in { -1, 1 } do
		blocker(b, v(7.4, 26, 7.4), v(side * 14, 13, 0))
		-- The gate swung back against the tower.
		blocker(b, v(0.6, 9, 9), v(side * 10.6, 4.5, 5.4))
	end
	blocker(b, v(5.4, 6, 5.4), v(-22, 3, -4))
	for _, z in { -2.35, 2.35 } do
		words(b, v(19.6, 3.4, 0.05), v(0, 21.5, z), if z < 0 then Enum.NormalId.Front else Enum.NormalId.Back, "HOLLYWOOD RNG STUDIOS", P.Gold, 4)
	end
end

-- Back street film sets --------------------------------------------------------------------------
-- Each set fills one of the paths between the lots: 20 studs across (x -10..10) and 64 long
-- (z -32..32, -Z toward the boulevard). Props keep to the sides (|x| >= 5.5) so the middle stays
-- a clear walk.

local function directorChair(b: Builder, label: string?)
	MapKit.place(b, "DirectorChair", CFrame.identity, { solid = true })
	if label ~= nil then
		words(b, v(2, 0.8, 0.05), v(0, 2.5, 0.8), Enum.NormalId.Back, label, P.Gold)
	end
end

local function lightStand(b: Builder)
	MapKit.place(b, "LightStand", CFrame.identity, { solid = true })
end

local function crate(b: Builder, at: Vector3, size: number, yaw: number?)
	MapKit.place(b, "Crate", CFrame.new(at) * CFrame.Angles(0, math.rad(yaw or 0), 0), { scale = size / 3, solid = true })
end

local function sign(b: Builder, at: Vector3, text: string, color: Color3)
	MapKit.place(b, "SetSign", at, { solid = true })
	words(b, v(6, 1.8, 0.05), at + v(0, 5.6, -0.3), Enum.NormalId.Front, text, color)
end

-- The green screen set: a chroma wall with a marked floor, a camera on a crane aimed at it,
-- director's chairs, two lights and a giant clapperboard.
function TownSets.greenScreen(b: Builder)
	b:block("ChromaWall", v(0.8, 11, 26), v(9.6, 5.7, 2), CHROMA)
	for _, z in { -8, 12 } do
		b:wedge("ChromaBrace", v(0.6, 4, 1.4), CFrame.new(10.6, 2.2, z) * CFrame.Angles(0, math.rad(-90), 0), P.Steel, METAL)
	end
	b:block("ChromaFloor", v(4, 0.06, 26), v(7.2, 0.23, 2), CHROMA)
	for _, a in { 45, -45 } do
		b:block("FloorMark", v(0.3, 0.06, 2), CFrame.new(7, 0.27, 2) * CFrame.Angles(0, math.rad(a), 0), P.Gold)
	end
	-- Camera crane aimed at the wall, director's chairs, two lights and a giant clapperboard.
	MapKit.place(b, "CameraCrane", v(-7.5, 0.2, 2), { solid = true })
	for _, z in { 11, 14 } do
		directorChair(b:sub(CFrame.new(-7.6, 0.2, z) * CFrame.Angles(0, math.rad(-90), 0)), if z == 11 then "DIRECTOR" else nil)
	end
	for _, z in { -9, 13 } do
		lightStand(b:sub(CFrame.new(6.2, 0.2, z) * CFrame.Angles(0, math.rad(if z < 0 then -70 else -110), 0)))
	end
	MapKit.place(b, "Clapperboard", CFrame.new(-7.5, 0.2, -22) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(math.rad(-10), 0, 0), { solid = true })
	sign(b, v(-7.5, 0.2, -29), "STAGE 9", CHROMA)
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
	-- The dinosaur head, mouth open, roaring at people walking in; a fake moon on a stand; a
	-- rolling spotlight aimed across the yard.
	MapKit.place(b, "DinoHead", v(-7.8, 0.2, 2), { solid = true })
	MapKit.place(b, "PropMoon", v(8, 0.2, 8), { solid = true })
	MapKit.place(b, "SpotCart", CFrame.new(-7.6, 0.2, -10) * CFrame.Angles(0, math.rad(-60), 0), { solid = true })
	sign(b, v(-7.5, 0.2, -29), "PROPS DEPT.", P.Carpet)
end

-- Star trailers: two trailers with stars on their doors, striped awnings, and chairs out front.
function TownSets.trailers(b: Builder)
	for i, trailer in { { z = -13, kit = "TrailerRed" }, { z = 9, kit = "TrailerBlue" } } do
		MapKit.place(b, trailer.kit, v(8.2, 0.2, trailer.z), { solid = true })
		-- A table and two chairs out front.
		local z = trailer.z + (if i == 1 then -1 else 1) * 0.5
		MapKit.place(b, "PatioTable", v(-7.4, 0.2, z), { solid = true })
		for _, dz in { -2, 2 } do
			directorChair(b:sub(CFrame.new(-7.4, 0.2, z + dz) * CFrame.Angles(0, if dz < 0 then 0 else math.pi, 0)), nil)
		end
	end
	sign(b, v(-7.5, 0.2, -29), "STAR TRAILERS", P.Gold)
end

-- Food corner: a taco truck, a popcorn cart, and tables with umbrellas.
function TownSets.foodCorner(b: Builder)
	MapKit.place(b, "TacoTruck", v(8, 0.2, -2), { solid = true })
	words(b, v(0.05, 1.8, 8), v(8 - 1.85, 8.2, -1), Enum.NormalId.Left, "TACOS", P.OffWhite, 4)
	MapKit.place(b, "PopcornCart", CFrame.new(-7.4, 0.2, -12) * CFrame.Angles(0, math.rad(90), 0), { solid = true })
	-- Tables with umbrellas.
	for k, z in { 2, 10, 18 } do
		MapKit.place(b, if k % 2 == 0 then "CafeTableTeal" else "CafeTableGold", v(-7.4, 0.2, z), { solid = true })
	end
	sign(b, v(-7.5, 0.2, -29), "FOOD CORNER", PINK)
end

-- Sidewalk and skyline ---------------------------------------------------------------------------

-- A round poster column with a gold dome, its poster facing front.
function TownSets.posterColumn(b: Builder, title: string, color: Color3)
	MapKit.place(b, "PosterColumn", CFrame.identity, { solid = true })
	for k = 0, 3 do
		local face = CFrame.Angles(0, math.rad(k * 90), 0) * CFrame.new(0, 4.2, -1.42)
		local poster = b:block("ColumnPoster", v(1.9, 4.4, 0.1), face, if k == 0 then color else color:Lerp(P.OffWhite, 0.35))
		if k == 0 then
			outlined(poster, Enum.NormalId.Front, title, P.OffWhite, 2)
		end
	end
end

-- Far-off city towers behind the hills, pale and hazy. `seed` varies heights and widths.
function TownSets.skyline(b: Builder, count: number, spread: number, seed: number)
	-- A tiny fixed sequence (Random isn't available in the preview tool), so the skyline never
	-- changes between servers.
	local state: number = seed
	local function number(lo: number, hi: number): number
		state = (state * 1103515245 + 12345) % 2147483648
		return lo + state / 2147483648 * (hi - lo)
	end
	local shades = { Color3.fromRGB(176, 192, 222), Color3.fromRGB(160, 178, 212), Color3.fromRGB(190, 202, 226) }
	for i = 0, count - 1 do
		local x = -spread / 2 + (i + number(0.1, 0.9)) * spread / count
		local width = number(16, 30)
		local height = number(60, 150) * (1 - math.abs(x) / spread * 0.9)
		local z = number(-20, 20)
		local color = shades[math.min(#shades, 1 + math.floor(number(0, #shades)))]
		b:block("SkylineTower", v(width, height, width * number(0.7, 1.1)), v(x, height / 2, z), color)
		if number(0, 1) < 0.45 then
			b:block("SkylineTop", v(width * 0.55, height * 0.12, width * 0.55), v(x, height * 1.06, z), color)
		end
	end
end

-- Lawn with flowers, for the corners round the landmarks.
function TownSets.flowerBed(b: Builder, size: Vector3)
	b:block("Lawn", v(size.X, 0.34, size.Z), v(0, 0.17, 0), P.Green, GRASS)
	b:block("LawnEdge", v(size.X + 0.4, 0.27, size.Z + 0.4), v(0, 0.135, 0), P.Cream)
	-- Low-poly flower clumps (Blender kit) along the bed.
	local n = 0
	for x = -size.X / 2 + 2, size.X / 2 - 2, 3.4 do
		n += 1
		MapKit.place(b, "FlowerPatch", CFrame.new(x, 0.34, if n % 2 == 0 then -0.8 else 0.8) * CFrame.Angles(0, math.rad(n * 61), 0), { scale = 0.8 })
	end
end

-- Street life (pass 2) ---------------------------------------------------------------------------

-- A rounded vintage convertible, about 4.4 wide and 9.6 long, nose toward -Z. `kit` picks its
-- color (CarTeal, CarPink, CarGold, CarRed).
function TownSets.car(b: Builder, kit: string)
	MapKit.place(b, kit, CFrame.identity)
	blocker(b, v(4.4, 3, 9.4), v(0, 1.5, 0))
end

-- A bus stop: a roof on two posts, a bench, a back panel with a poster, and a round sign.
function TownSets.busStop(b: Builder)
	MapKit.place(b, "BusStop", CFrame.identity, { solid = true })
	b:block("ShelterBack", v(8, 5.6, 0.3), v(0, 3.6, 1.6), P.Glass, GLASS).Transparency = 0.5
	local label = words(b, v(3, 4.2, 0.05), v(1.8, 3.6, 1.33), Enum.NormalId.Front, "MONSTER\nISLAND\nNOW SHOWING", P.OffWhite, 2)
	label.Name = "ShelterPoster"
	words(b, v(1.6, 1.6, 0.05), v(5.2, 7.6, -1.5), Enum.NormalId.Front, "BUS", P.OffWhite)
end

function TownSets.hydrant(b: Builder)
	MapKit.place(b, "Hydrant", CFrame.identity, { solid = true })
end

function TownSets.trashBin(b: Builder)
	MapKit.place(b, "TrashBin", CFrame.identity, { solid = true })
end

-- A newspaper stand: a green kiosk with stacks of papers and a striped roof.
function TownSets.newsStand(b: Builder)
	MapKit.place(b, "NewsStand", CFrame.identity, { solid = true })
	words(b, v(4, 0.9, 0.05), v(0, 3.2, -1.5), Enum.NormalId.Front, "DAILY STAR", P.Gold)
end

-- The outer ring (pass 3) ------------------------------------------------------------------------
-- Two big walkable areas out through gaps in the hedge (MapModels.Layout.sideGap): Dusty Gulch, a
-- western film town behind the front row, and Starlight Park behind the back row. Chunky shapes,
-- bold colors and thick trims, like the Roblox front page. Each is laid out with its entrance at
-- z = 0 and the area running toward +Z.

local WATER = Color3.fromRGB(64, 196, 240)
local WATER_LIGHT = Color3.fromRGB(130, 222, 250)
local SAND = Color3.fromRGB(240, 205, 140)
local DUST = Color3.fromRGB(222, 170, 110)
local STONE = Color3.fromRGB(176, 182, 194)
local BLOSSOM = Color3.fromRGB(255, 160, 205)

local function shade(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

-- Dusty Gulch ------------------------------------------------------------------------------------

type WesternInfo = { title: string, kit: string, w: number, h: number, color: Color3 }

-- A false-front western building, about w wide and 15 deep, front toward -Z: the Blender model
-- (map kit Western<Name>: clapboard front, stepped top, porch or balcony, its own details), with
-- the building's name lettered on its sign board.
local function westernBuilding(b: Builder, info: WesternInfo)
	MapKit.place(b, info.kit, CFrame.identity)
	local board = b:block("WesternSignText", v(info.w - 4.4, 3, 0.05), v(0, info.h - 3.2, -1), P.Cream)
	board.Transparency = 1
	board.CanCollide = false
	board.CanQuery = false
	board.CanTouch = false
	outlined(board, Enum.NormalId.Front, info.title, info.color, 3)
end

local function barrel(b: Builder)
	MapKit.place(b, "Barrel", CFrame.identity, { solid = true })
end

local function hayBale(b: Builder)
	MapKit.place(b, "HayBale", CFrame.identity, { solid = true })
end

local function fenceRun(b: Builder, from: Vector3, to: Vector3, color: Color3)
	local delta = to - from
	local length = delta.Magnitude
	-- Turned by hand rather than with CFrame.lookAt, which the test runner's CFrame gets backwards.
	local frame = CFrame.new(from) * CFrame.Angles(0, math.atan2(-delta.X, -delta.Z), 0)
	for _, y in { 1.4, 2.8 } do
		b:block("FenceRail", v(0.5, 0.6, length), frame * CFrame.new(0, y, -length / 2), color)
	end
	local posts = math.max(1, math.floor(length / 7))
	for i = 0, posts do
		b:block("FencePost", v(0.9, 3.8, 0.9), frame * CFrame.new(0, 1.9, -i * length / posts), shade(color, 0.15))
	end
end

-- Dusty Gulch: a western film town, about 160 wide and 150 long. A welcome arch over the road in,
-- a dusty main street with eight false-front buildings on boardwalks (saloon, bank, sheriff, hotel
-- and more), hitching rails, barrels and crates, a corral, a covered wagon, a water tank, blocky
-- mesas and cacti, and a film crew shooting at the far end.
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

	-- The welcome arch (Blender kit), its sign lettered on both faces.
	MapKit.place(b, "GulchArch", CFrame.identity)
	for _, x in { -16, 16 } do
		blocker(b, v(2.4, 17, 2.4), v(x, 8.5, 6), true)
	end
	words(b, v(20.6, 4.4, 0.05), v(0, 10, 5.55), Enum.NormalId.Front, "DUSTY GULCH", P.Gold, 4)
	words(b, v(20.6, 4.4, 0.05), v(0, 10, 6.45), Enum.NormalId.Back, "DUSTY GULCH", P.Gold, 4)

	-- The buildings, fronts on the boardwalks facing the street.
	local west: { WesternInfo } = {
		{ title = "SALOON", kit = "WesternSaloon", w = 20, h = 20, color = Color3.fromRGB(205, 70, 50) },
		{ title = "BANK", kit = "WesternBank", w = 18, h = 16, color = Color3.fromRGB(60, 130, 215) },
		{ title = "BARBER", kit = "WesternBarber", w = 16, h = 14, color = Color3.fromRGB(235, 115, 165) },
		{ title = "HOTEL", kit = "WesternHotel", w = 20, h = 20, color = Color3.fromRGB(145, 95, 205) },
	}
	local east: { WesternInfo } = {
		{ title = "SHERIFF", kit = "WesternSheriff", w = 18, h = 15, color = Color3.fromRGB(240, 175, 50) },
		{ title = "GENERAL STORE", kit = "WesternGeneralStore", w = 22, h = 16, color = Color3.fromRGB(100, 175, 75) },
		{ title = "POST OFFICE", kit = "WesternPostOffice", w = 18, h = 14, color = TEAL },
		{ title = "BLACKSMITH", kit = "WesternBlacksmith", w = 18, h = 15, color = Color3.fromRGB(150, 105, 80) },
	}
	for i = 1, 4 do
		local z = 10 + i * 26
		westernBuilding(b:sub(CFrame.new(-20, 0.8, z) * CFrame.Angles(0, math.rad(-90), 0)), west[i])
		westernBuilding(b:sub(CFrame.new(20, 0.8, z) * CFrame.Angles(0, math.rad(90), 0)), east[i])
	end
	-- Wanted posters on the sheriff's boardwalk.
	for _, z in { 27.2, 44.8 } do
		local poster = b:block("WantedPoster", v(0.2, 2.8, 2.2), v(14.25, 5.6, z), P.Cream)
		Build.sign(poster, Enum.NormalId.Left, "WANTED", P.Burgundy)
	end

	-- Street life: hitching rails, troughs, barrels, crates and hay along the boardwalks.
	for _, s in { -1, 1 } do
		for _, z in { 48, 100 } do
			MapKit.place(b, "HitchRail", v(s * 12.6, 0, z), { solid = true })
		end
		MapKit.place(b, "Trough", v(s * 12.6, 0, 74), { solid = true })
		b:block("TroughWater", v(1.6, 0.1, 5.4), v(s * 12.6, 1.75, 74), WATER)
	end
	for _, at in { v(-16, 0.8, 24), v(-14.6, 0.8, 26.2), v(16, 0.8, 128), v(16, 0.8, 24), v(-16, 0.8, 128) } do
		barrel(b:sub(at))
	end
	crate(b, v(15.6, 0.8, 50), 2.6, 15)
	crate(b, v(15.6, 3.4, 50), 2, -10)
	crate(b, v(-15.8, 0.8, 76), 2.4, 30)
	hayBale(b:sub(CFrame.new(16, 0.8, 75) * CFrame.Angles(0, math.rad(90), 0)))
	hayBale(b:sub(CFrame.new(16, 2.8, 75.4) * CFrame.Angles(0, math.rad(80), 0)))
	for i, at in { v(-4, 0.2, 60), v(6, 0.2, 112) } do
		MapKit.place(b, "Tumbleweed", CFrame.new(at) * CFrame.Angles(0, math.rad(i * 70), 0), { solid = true })
	end

	-- The corral with hay and a trough, east behind the buildings.
	local corral = b:sub(v(56, 0.1, 64))
	local c = 14
	fenceRun(corral, v(-c, 0, -c), v(c, 0, -c), P.Wood)
	fenceRun(corral, v(c, 0, -c), v(c, 0, c), P.Wood)
	fenceRun(corral, v(c, 0, c), v(-c, 0, c), P.Wood)
	fenceRun(corral, v(-c, 0, c), v(-c, 0, 4), P.Wood)
	fenceRun(corral, v(-c, 0, -4), v(-c, 0, -c), P.Wood)
	hayBale(corral:sub(v(6, 0, 6)))
	hayBale(corral:sub(CFrame.new(8, 0, 2) * CFrame.Angles(0, math.rad(70), 0)))
	hayBale(corral:sub(v(7, 2, 4.5)))
	MapKit.place(corral, "Trough", CFrame.new(-4, 0, -8) * CFrame.Angles(0, math.rad(90), 0), { solid = true })
	corral:block("TroughWater", v(5.4, 0.1, 1.6), v(-4, 1.65, -8), WATER)

	-- A covered wagon, west behind the buildings, and a water tank on stilts.
	MapKit.place(b, "Wagon", CFrame.new(-50, 0.1, 58) * CFrame.Angles(0, math.rad(20), 0), { solid = true })
	MapKit.place(b, "WaterTank", v(-48, 0.1, 104))

	-- Oil lanterns on posts along both boardwalks, hanging out over the street, lit warm.
	for _, s in { -1, 1 } do
		for _, z in { 30, 56, 82, 108, 132 } do
			MapKit.place(b, "Lantern", CFrame.new(s * 14.9, 0.8, z) * CFrame.Angles(0, math.rad(s * 90), 0), {
				solid = true,
				light = { range = 14, brightness = 1.6, color = Color3.fromRGB(255, 176, 92) },
			})
		end
	end

	-- Cacti, boulders and mesas round the edges.
	local cacti = { v(-34, 0, 20), v(34, 0, 22), v(-62, 0, 30), v(-30, 0, 132), v(36, 0, 140), v(70, 0, 104), v(-72, 0, 80), v(52, 0, 30) }
	for i, at in cacti do
		MapKit.place(b, "Cactus", CFrame.new(at) * CFrame.Angles(0, math.rad(i * 47), 0), { scale = 0.8 + (i % 3) * 0.2 })
	end
	for i, at in { v(-40, 0, 6), v(44, 0, 10), v(-66, 0, 116), v(64, 0, 70), v(-30, 0, 146) } do
		MapKit.place(b, "DesertRock", CFrame.new(at) * CFrame.Angles(0, math.rad(i * 71), 0), { scale = 0.9 + (i % 2) * 0.4 })
	end
	for i, info in { { at = v(-70, 0, 130), size = 0.75 }, { at = v(72, 0, 135), size = 0.85 }, { at = v(-74, 0, 18), size = 0.5 }, { at = v(76, 0, 24), size = 0.55 } } do
		MapKit.place(b, "Mesa", CFrame.new(info.at) * CFrame.Angles(0, math.rad(i * 33), 0), { scale = info.size })
	end

	-- At the far end, a film crew shoots a showdown: a camera on a crane, a light and chairs.
	local crew = b:sub(CFrame.new(0, 0.2, 140) * CFrame.Angles(0, math.pi, 0))
	-- The crane's arm reaches toward its +X, so turned a quarter it reaches up the street.
	MapKit.place(crew, "CameraCrane", CFrame.Angles(0, math.rad(90), 0), { scale = 1.25, solid = true })
	for _, x in { -7, 7 } do
		directorChair(crew:sub(CFrame.new(x, 0, 4) * CFrame.Angles(0, math.pi, 0)), if x < 0 then "DIRECTOR" else nil)
	end
	lightStand(crew:sub(CFrame.new(-10, 0, -2) * CFrame.Angles(0, math.rad(20), 0)))
end

-- Starlight Park ---------------------------------------------------------------------------------

-- Park trees, benches and lamps are Blender kit models (MapKit).
local function parkTree(b: Builder, height: number, color: Color3)
	MapKit.place(b, if color == BLOSSOM then "BlossomTree" else "ParkTree", CFrame.identity, { scale = height / 7, solid = true })
end

local function parkBench(b: Builder)
	MapKit.place(b, "ParkBench", CFrame.identity, { solid = true })
end

local function parkLamp(b: Builder)
	MapKit.place(b, "ParkLamp", CFrame.identity, {
		solid = true,
		light = { range = 16, brightness = 1.4, color = Color3.fromRGB(255, 222, 160) },
	})
end

local function duck(b: Builder, scale: number)
	-- Named so src/client/MapLife.luau can find the ducks and paddle them round the pond.
	local model = MapKit.place(b, "Duck", CFrame.identity, { scale = scale * 0.75 })
	model:AddTag("PondDuck")
end

local function picnicBlanket(b: Builder)
	MapKit.place(b, "PicnicBlanket", CFrame.identity)
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
	MapKit.place(b, "ParkArch", CFrame.identity)
	for _, x in { -10, 10 } do
		blocker(b, v(3.4, 11, 3.4), v(x, 5.5, 4))
	end
	words(b, v(18, 3.6, 0.05), v(0, 15, 3.6), Enum.NormalId.Front, "STARLIGHT PARK", P.OffWhite, 4)
	words(b, v(18, 3.6, 0.05), v(0, 15, 4.4), Enum.NormalId.Back, "STARLIGHT PARK", P.OffWhite, 4)

	-- The fountain plaza where the paths cross.
	local plaza = v(0, 0, 50)
	b:cylinder("FountainPlaza", 0.24, 26, plaza + v(0, 0.12, 0), P.Paving)
	b:cylinder("FountainPlazaRing", 0.28, 22, plaza + v(0, 0.14, 0), P.Cream)
	b:cylinder("FountainPlazaInner", 0.3, 20, plaza + v(0, 0.15, 0), P.Paving)
	MapKit.place(b, "ParkFountain", plaza)
	blocker(b, v(12, 1.6, 12), plaza + v(0, 0.8, 0), true)
	blocker(b, v(5, 4.6, 5), plaza + v(0, 2.3, 0), true)
	b:cylinder("FountainWater", 0.2, 10.6, plaza + v(0, 1.5, 0), WATER)
	b:cylinder("FountainBowlWater", 0.2, 4.4, plaza + v(0, 4.55, 0), WATER_LIGHT)
	b:cylinder("FountainJet", 3, 0.8, plaza + v(0, 6, 0), WATER_LIGHT, NEON).Transparency = 0.3
	b:ball("FountainSplash", 2.2, plaza + v(0, 7.6, 0), WATER_LIGHT, NEON).Transparency = 0.4

	-- The pond, west of the main path: a stone rim, bright water, an island with a blossom tree,
	-- a bridge out to it, lily pads and ducks.
	local pond = v(-55, 0, 82)
	local radius = 26
	b:cylinder("PondWater", 0.5, radius * 2, pond + v(0, 0.25, 0), WATER)
	b:cylinder("PondShine", 0.52, radius * 1.3, pond + v(0, 0.27, 0), WATER_LIGHT)
	local stones = 22
	for i = 0, stones - 1 do
		local a = i / stones * math.pi * 2
		local at = pond + v(math.sin(a) * (radius + 1), 0.6, math.cos(a) * (radius + 1))
		b:block("PondStone", v(7.6, 1.2, 2.6), CFrame.new(at) * CFrame.Angles(0, a, 0), if i % 2 == 0 then STONE else shade(STONE, 0.1))
	end
	local island = pond + v(-6, 0, 2)
	b:cylinder("Island", 1, 16, island + v(0, 0.5, 0), P.Green, GRASS)
	b:cylinder("IslandSand", 0.8, 17.4, island + v(0, 0.4, 0), SAND)
	parkTree(b:sub(island + v(0, 1, 0)), 8, BLOSSOM)
	-- The bridge from the east shore to the island, with fence rails like a ranch fence.
	local fromX, toX = pond.X + radius + 3, island.X + 7
	local bridgeLength = fromX - toX
	local mid = v((fromX + toX) / 2, 0, island.Z)
	-- The Blender bridge is 28 long; stretched to fit if the pond ever changes size.
	MapKit.place(b, "PondBridge", mid, { scale = bridgeLength / 28 })
	blocker(b, v(bridgeLength, 0.8, 5), mid + v(0, 1.8, 0))
	for _, s in { -1, 1 } do
		blocker(b, v(bridgeLength, 3.4, 0.6), mid + v(0, 3.9, s * 2.3))
	end
	local ramp = b:wedge("Blocker", v(5, 2.2, 3), CFrame.new(fromX + 1.5, 1.1, island.Z) * CFrame.Angles(0, math.rad(-90), 0), P.Grey)
	ramp.Transparency = 1
	ramp.CanTouch = false
	ramp.CastShadow = false
	for _, at in { v(8, 0, -10), v(-14, 0, -12), v(12, 0, 12), v(-4, 0, 16), v(16, 0, -2) } do
		b:cylinder("LilyPad", 0.12, 3, pond + at + v(0, 0.56, 0), P.DarkGreen)
	end
	MapKit.place(b, "FlowerPatch", pond + v(12, 0.5, 12), { scale = 0.5 })
	duck(b:sub(CFrame.new(pond + v(10, 0.5, -4)) * CFrame.Angles(0, math.rad(30), 0)), 1.6)
	duck(b:sub(CFrame.new(pond + v(13, 0.5, -1)) * CFrame.Angles(0, math.rad(40), 0)), 0.9)
	duck(b:sub(CFrame.new(pond + v(-16, 0.5, -10)) * CFrame.Angles(0, math.rad(200), 0)), 1.4)

	-- The bandstand, east of the main path (Blender kit: octagonal, with a striped roof).
	MapKit.place(b, "Bandstand", v(60, 0, 86))
	-- Its floor and steps to walk up, and the eight posts round the edge.
	local band = b:sub(v(60, 0, 86))
	blocker(band, v(18.8, 1.84, 18.8), v(0, 0.92, 0), true)
	blocker(band, v(6, 0.8, 2), v(0, 0.4, -10.2))
	blocker(band, v(6, 1.3, 0.8), v(0, 0.65, -9.4))
	for i = 0, 7 do
		local a = math.rad(i * 45)
		blocker(band, v(0.9, 8, 0.9), v(math.sin(a) * 8.2, 5.6, -math.cos(a) * 8.2), true)
	end

	-- The open-air movie screen at the far end, with picnic blankets on the lawn in front.
	local screen = b:sub(v(0, 0, 112))
	MapKit.place(screen, "MovieScreen", CFrame.identity)
	for _, x in { -24, 24 } do
		blocker(screen, v(2.4, 30, 2.4), v(x, 15, 1))
	end
	blocker(screen, v(46, 24, 1), v(0, 17, 1))
	words(screen, v(43, 21, 0.05), v(0, 17, 0.15), Enum.NormalId.Front, "NOW SHOWING\nHOLLYWOOD RNG", P.Gold, 5)
	words(screen, v(30, 3.6, 0.05), v(0, 31, 0.55), Enum.NormalId.Front, "MOVIES UNDER THE STARS", P.Gold, 3)
	for i, at in { v(-14, 0, 92), v(0, 0, 96), v(14, 0, 92) } do
		picnicBlanket(b:sub(CFrame.new(at) * CFrame.Angles(0, math.rad(i * 12 - 24), 0)))
	end

	-- Lamps and benches along the main path.
	for _, z in { 18, 34, 66, 82 } do
		for _, s in { -1, 1 } do
			parkLamp(b:sub(v(s * 7, 0, z)))
		end
	end
	for _, info in { { at = v(9, 0, 26), yaw = -90 }, { at = v(-9, 0, 26), yaw = 90 }, { at = v(9, 0, 74), yaw = -90 }, { at = v(-9, 0, 74), yaw = 90 } } do
		parkBench(b:sub(CFrame.new(info.at) * CFrame.Angles(0, math.rad(info.yaw), 0)))
	end

	-- Trees and flowers.
	local trees = {
		v(-22, 0, 14), v(-40, 0, 26), v(-70, 0, 34), v(-92, 0, 20), v(-96, 0, 60), v(-94, 0, 108),
		v(-28, 0, 116), v(22, 0, 16), v(40, 0, 28), v(76, 0, 30), v(96, 0, 18), v(94, 0, 64),
		v(88, 0, 110), v(34, 0, 112), v(28, 0, 72), v(-44, 0, 36),
	}
	for i, at in trees do
		local color = if i % 4 == 0 then BLOSSOM elseif i % 2 == 0 then P.DarkGreen else P.Green
		parkTree(b:sub(CFrame.new(at) * CFrame.Angles(0, math.rad(i * 37), 0)), 7 + (i % 3) * 1.5, color)
	end
	for _, info in { { at = v(-16, 0, 38), size = v(10, 0, 6) }, { at = v(16, 0, 38), size = v(10, 0, 6) }, { at = v(-13, 0, 62), size = v(8, 0, 6) }, { at = v(16, 0, 62), size = v(10, 0, 6) }, { at = v(40, 0, 60), size = v(14, 0, 6) } } do
		TownSets.flowerBed(b:sub(info.at), info.size)
	end

	-- A low ranch fence along the two sides.
	for _, s in { -1, 1 } do
		fenceRun(b, v(s * 106, 0, 2), v(s * 106, 0, 124), P.OffWhite)
	end
end

-- The blimp ---------------------------------------------------------------------------------------

-- A big striped blimp that drifts round the town (src/client/Blimp.luau moves it). Nose toward -Z,
-- about 46 long. Returns the model, pivoted at its middle.
function TownSets.blimp(b: Builder): Model
	local g, model = b:group("Blimp")
	local along = CFrame.Angles(math.rad(90), 0, 0)
	g:cylinder("BlimpHull", 30, 14, along, P.OffWhite)
	for _, z in { -15, 15 } do
		g:ball("BlimpEnd", 14, v(0, 0, z), P.OffWhite)
	end
	g:ball("BlimpNose", 6, v(0, 0, -20.6), P.Carpet)
	for _, z in { -10, 10 } do
		g:cylinder("BlimpStripe", 1.6, 14.4, CFrame.new(0, 0, z) * along, P.Carpet)
	end
	g:cylinder("BlimpStripe", 0.8, 14.4, CFrame.new(0, 0, -8.4) * along, P.Gold, METAL)
	g:cylinder("BlimpStripe", 0.8, 14.4, CFrame.new(0, 0, 8.4) * along, P.Gold, METAL)
	for _, side in { -1, 1 } do
		g:block("BlimpBannerTrim", v(0.4, 5.4, 17), v(side * 6.9, 0, 0), P.Gold)
		local panel = g:block("BlimpBanner", v(0.5, 4.6, 16), v(side * 7, 0, 0), P.Carpet)
		outlined(panel, if side < 0 then Enum.NormalId.Left else Enum.NormalId.Right, "HOLLYWOOD RNG", P.Gold, 4)
	end
	-- Four chunky tail fins with red tips.
	for _, fin in { { size = v(1, 8, 8), at = v(0, 7.5, 18) }, { size = v(1, 7, 8), at = v(0, -7, 18) }, { size = v(8, 1, 8), at = v(7.5, 0, 18) }, { size = v(8, 1, 8), at = v(-7.5, 0, 18) } } do
		g:block("BlimpFin", fin.size, fin.at, P.Gold)
		local tip = fin.at + v(math.sign(fin.at.X) * 3.6, math.sign(fin.at.Y) * 3.6, 2.6)
		g:block("BlimpFinTip", v(if fin.at.X ~= 0 then 2 else 1.1, if fin.at.Y ~= 0 then 2 else 1.1, 3), tip, P.Carpet)
	end
	-- The gondola under the middle, with a row of windows and two propellers.
	g:block("BlimpGondola", v(4.6, 3, 11), v(0, -8.2, -2), P.Cream)
	g:block("BlimpGondolaBase", v(5, 0.6, 11.4), v(0, -9.8, -2), P.Gold, METAL)
	g:block("BlimpWindows", v(4.7, 1.1, 9), v(0, -7.8, -2), P.Navy, GLASS)
	for _, x in { -3.4, 3.4 } do
		g:cylinder("BlimpEngine", 3, 1.6, CFrame.new(x, -8, 3) * along, P.Steel, METAL)
		g:block("BlimpProp", v(0.3, 3.4, 0.3), v(x, -8, 4.7), P.Charcoal)
	end
	Build.decorative(model)
	model.WorldPivot = g:at(CFrame.identity)
	return model
end

return TownSets
