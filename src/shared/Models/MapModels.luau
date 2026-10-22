--!strict
-- The town around the studio lots, so the six lots form one place instead of islands on a
-- baseplate: the boulevard with its red carpet, the spawn plaza and fountain, sidewalks with
-- Walk of Fame stars, paths that join every lot, the store stands, and hills with the gold star
-- sign around the edge. The landmarks at the ends of the boulevard and the film sets in the back
-- streets come from TownSets. Every prop and building is a Blender model from the map kit
-- (art/blender/map_kit.py and town_kit.py, placed by MapKit); the ground (roads, paths, lawns) is
-- flat parts.
--
-- World space: X runs along the boulevard, Z across it. Lots 1-3 sit at -Z and lots 4-6 at +Z,
-- all facing the boulevard. The grass is at y = 0 and paths are 0.2 studs thick on top of it.
local ActorModels = require(script.Parent.ActorModels)
local Build = require(script.Parent.Build)
local IconModels = require(script.Parent.IconModels)
local LotModels = require(script.Parent.LotModels)
local FilmSets = require(script.Parent.Parent.FilmSets)
local MapKit = require(script.Parent.MapKit)
local MapScenery = require(script.Parent.MapScenery)
local TownSets = require(script.Parent.TownSets)
local Walkways = require(script.Parent.Walkways)

type Builder = Build.Builder

local P = Build.Palette
local NEON = Enum.Material.Neon
local GRASS = Enum.Material.Grass
local METAL = Enum.Material.Metal

local MapModels = {}

-- The lots stand well apart, so the boulevard is long and roomy: between neighbouring lots a
-- path runs back between two tall boulevard buildings, and a big building closes each end.
local LOT_SPACING = 116
local COLUMNS = 3
local ROW_Z = 78
local LOT_HALF = LotModels.Layout.size / 2

MapModels.Layout = table.freeze({
	roadHalf = 9, -- boulevard asphalt: z = -9..9
	sidewalkTo = ROW_Z - LOT_HALF, -- sidewalks reach the lot fronts (z = 50)
	townX = 186, -- outer edge of the path that runs round the town
	townZ = 122,
	ringWidth = 8,
	lotSpacing = LOT_SPACING,
	alleyX = LOT_SPACING / 2, -- the paths between neighbouring lots
	alleyWidth = 20,
	plazaRadius = 24,
	fenceX = 191,
	fenceZ = 127,
	-- Players appear on the plaza looking past the fountain at the Shop and Rewards stands.
	spawn = CFrame.new(0, 0.65, -15) * CFrame.Angles(0, math.pi, 0),
	-- Gold star sign on the big hill behind lots 4-6.
	hillStar = Vector3.new(0, 44, 306),
	-- The boulevard runs out through the hedge at both ends: west to the Grand Premiere Theatre
	-- (its bottom step), east through the Studio Gate.
	endGap = 14,
	theatreX = -209,
	gateX = 208,
	backlotEnd = 237, -- where the road through the Studio Gate meets the sound stage door
	-- Pass 3: a gap in the middle of the front and back hedges leads out to Dusty Gulch, the
	-- western film town (front, -Z), and Starlight Park (back, +Z). The blimp circles the town.
	sideGap = 8,
	blimpHeight = 120,
	blimpRadius = 300,
})

local Lay = MapModels.Layout

-- Dusty Gulch's own space (TownSets.westernTown builds in it): its street starts at the front
-- hedge and runs away from town, toward world -Z.
MapModels.GulchFrame = CFrame.new(0, 0, -(Lay.fenceZ + 1)) * CFrame.Angles(0, math.pi, 0)

-- The film sets (rules in Shared/FilmSets): the gate on the path in, facing the town, and the area
-- behind it, where owners earn the box office bonus. An invisible wall runs across the whole way
-- in at the gate; FilmSetWorld opens it for owners on their own screen.
export type FilmSetInfo = {
	id: string,
	frame: CFrame, -- the set's own space (FilmScenes): the gate at the origin, the set along +Z
	gate: CFrame, -- the gate's feet; its -Z faces the town, like a kit model's front
	wallWidth: number, -- the wall across the way in
	wallX: number, -- the wall's middle, along the gate (in the gate's space)
	area: Walkways.Rect, -- inside the set, past the gate
}

-- Moon Base: out in the desert east of Dusty Gulch, its gate on the Gulch's east edge (so players
-- reach it through the Gulch), the set running toward world +X.
MapModels.MoonFrame = CFrame.new(88, 0, -209) * CFrame.Angles(0, math.pi / 2, 0)
-- The Jungle Temple: in the woods west of Starlight Park, its gate in the park's west fence, the
-- set running toward world -X.
MapModels.JungleFrame = CFrame.new(-108, 0, 168) * CFrame.Angles(0, -math.pi / 2, 0)

local function filmSet(id: string, frame: CFrame, wallWidth: number, wallX: number, area: Walkways.Rect): FilmSetInfo
	return { id = id, frame = frame, gate = frame * CFrame.new(0, 0.2, 1.5), wallWidth = wallWidth, wallX = wallX, area = area }
end

MapModels.FilmSets = table.freeze({
	filmSet("Gulch", MapModels.GulchFrame, 172, 0, Walkways.rect(-86, -(Lay.fenceZ + 1) - 158, 86, -(Lay.fenceZ + 4))),
	filmSet("MoonBase", MapModels.MoonFrame, 124, 3, Walkways.rect(90.5, -272, 200, -152)),
	filmSet("Jungle", MapModels.JungleFrame, 124, 24, Walkways.rect(-232, 132, -110.5, 252)),
} :: { FilmSetInfo })

-- The lawns along each lot's front, either side of its gate (x from, x to).
local LAWN_SPANS: { { number } } = {}
for col = -1, 1 do
	local c = col * LOT_SPACING
	table.insert(LAWN_SPANS, { c - 30, c - 6 })
	table.insert(LAWN_SPANS, { c + 6, c + 30 })
end
local LAWN_FROM = Lay.sidewalkTo - 16 -- the lawns' boulevard edge

-- Where lot `index` (1-6) sits, as the lot-space CFrame LotModels expects: origin at the lot's
-- ground centre, lot-space -Z toward the boulevard.
function MapModels.lotBase(index: number): CFrame
	local col = (index - 1) % COLUMNS
	local row = (index - 1) // COLUMNS
	local center = Vector3.new((col - 1) * LOT_SPACING, 0, if row == 0 then -ROW_Z else ROW_Z)
	-- The back row turns round so lot-space -Z still points at the boulevard.
	return CFrame.new(center) * (if row == 0 then CFrame.Angles(0, math.pi, 0) else CFrame.identity)
end

-- Store stands -----------------------------------------------------------------------------------

export type StandInfo = {
	screen: string, -- the screen its prompt opens (src/client/Screens.luau)
	title: string, -- big sign over the stand
	action: string, -- prompt button text
	icon: string, -- IconModels id on the roof
	iconScale: number?, -- default 2 (the film camera is already tall)
	color: Color3, -- awning and counter, matching the screen's menu button
	kit: string, -- the map kit stand in that color: StoreStand<kit>
	keeper: string, -- the (common) actor serving behind the counter
	x: number,
	z: number, -- on the sidewalk; stands face the boulevard
}

local PURPLE = Color3.fromRGB(160, 77, 255)
local TEAL = Color3.fromRGB(32, 178, 190)
local INK = Color3.fromRGB(11, 15, 31) -- the menus' outline color (UiKit.INK)

-- From spawn, players look past the fountain at the Shop and Rewards stands.
MapModels.Stands = table.freeze({
	{ screen = "Shop", title = "SHOP", action = "Open Shop", icon = "popcorn", color = P.Gold, kit = "Gold", keeper = "AdModel", x = -22, z = 28 },
	{ screen = "Daily", title = "REWARDS", action = "Daily Rewards", icon = "gift", color = PURPLE, kit = "Purple", keeper = "BackgroundExtra", x = 22, z = 28 },
	{ screen = "Requests", title = "REQUESTS", action = "Studio Requests", icon = "clapper", color = P.Carpet, kit = "Red", keeper = "NervousIntern", x = -40, z = 28 },
	{ screen = "Codes", title = "CODES", action = "Enter a Code", icon = "ticket", color = P.Blue, kit = "Blue", keeper = "IndieSidekick", x = 40, z = 28 },
	{ screen = "Studio", title = "MOVIES", action = "Make a Movie", icon = "camera", iconScale = 1.1, color = P.Green, kit = "Green", keeper = "StuntDouble", x = -40, z = -28 },
	{ screen = "Upgrades", title = "UPGRADES", action = "Upgrade Studio", icon = "arrow", color = TEAL, kit = "Teal", keeper = "SoapRegular", x = -22, z = -28 },
	{ screen = "Odds", title = "CASTING ODDS", action = "See the Odds", icon = "dice", color = P.Blue, kit = "Blue", keeper = "AdModel", x = 22, z = -28 },
	{ screen = "Actors", title = "TALENT INDEX", action = "Your Actors", icon = "star", color = PURPLE, kit = "Purple", keeper = "NervousIntern", x = 40, z = -28 },
} :: { StandInfo })

-- Where a stand stands: on the sidewalk, front (-Z in its own space) toward the boulevard.
function MapModels.standBase(info: StandInfo): CFrame
	local cf = CFrame.new(info.x, 0.2, info.z)
	return if info.z < 0 then cf * CFrame.Angles(0, math.pi, 0) else cf
end

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

-- Two squares turned 45 degrees to each other: a chunky 8-point star, lying flat.
local function flatStar(b: Builder, name: string, size: number, at: Vector3, thickness: number, color: Color3, material: Enum.Material?)
	b:block(name, v(size, thickness, size), at, color, material)
	b:block(name, v(size, thickness, size), CFrame.new(at) * CFrame.Angles(0, math.rad(45), 0), color, material)
end

-- Dark outline round sign text, like the menus' outlined labels.
local function outline(label: TextLabel, thickness: number)
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = thickness
	stroke.Parent = label
end

-- An invisible, non-colliding part (a holder for a prompt, a billboard or an effect).
local function ghost(b: Builder, name: string, at: CFrame | Vector3): BasePart
	local part = b:block(name, v(1, 1, 1), at, P.OffWhite)
	part.Transparency = 1
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	return part
end

-- A market stand (map kit StoreStand<kit>: counter, striped awning, shelves of goods, a lit sign
-- and potted plants), with the store's name on its sign, the action on its counter, a big 3D
-- icon on the roof, its name floating above, and an actor serving. Returns the invisible part
-- the prompt goes on.
function MapModels.stand(parent: Instance, base: CFrame, info: StandInfo): BasePart
	local model = Instance.new("Model")
	model.Name = "Stand_" .. info.screen
	model.Parent = parent
	local b = Build.new(model, base)
	local kit = "StoreStand" .. info.kit
	MapKit.place(b, kit, CFrame.identity, {
		hitbox = true,
		labels = {
			Counter = { text = info.action, color = P.OffWhite, stroke = 4 },
			Sign = { text = info.title, color = P.Gold, stroke = 4 },
		},
	})
	IconModels.build(model, info.icon, b:at(v(0, 11.9, -0.4)), info.iconScale or 2)

	-- The name again, floating over the icon and turned to the camera, so it reads from anywhere
	-- down the street (white letters with a dark outline, like the menu buttons).
	local board = ghost(b, "StandNameAnchor", MapKit.spot(kit, "Sign"))
	local nameGui = Instance.new("BillboardGui")
	nameGui.Name = "StandName"
	nameGui.Size = UDim2.fromScale(13, 2.6) -- studs
	nameGui.StudsOffsetWorldSpace = Vector3.new(0, 12.6, 0)
	nameGui.LightInfluence = 0
	nameGui.MaxDistance = 160
	nameGui.Parent = board
	local name = Instance.new("TextLabel")
	name.Name = "Text"
	name.Size = UDim2.fromScale(1, 1)
	name.BackgroundTransparency = 1
	name.Text = info.title
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextScaled = true
	name.Font = Enum.Font.FredokaOne
	name.Parent = nameGui
	outline(name, 2)

	-- Someone serving, on the step behind the counter.
	ActorModels.build(model, b:at(v(0, 1, 1.8)), info.keeper)

	-- A glowing ring on the ground in front, where the prompt appears.
	b:cylinder("PromptRing", 0.06, 6, v(0, 0.03, -7.2), info.color, NEON)
	b:cylinder("PromptSpot", 0.12, 5.2, v(0, 0.06, -7.2), P.Paving)

	return ghost(b, "PromptAnchor", v(0, 3, -2.4))
end

-- Plaza ------------------------------------------------------------------------------------------

local function bench(b: Builder)
	MapKit.place(b, "ParkBench", CFrame.identity)
end

local function planter(b: Builder, palmHeight: number)
	MapKit.place(b, "Planter", CFrame.identity)
	LotModels.palm(b:sub(v(0, 1, 0)), palmHeight, 7)
end

-- Fountain (map kit PlazaFountain: basin, rim and pedestal) with a giant gold trophy in the
-- middle of the spawn plaza, water jets and spray.
local function fountain(b: Builder)
	local words: MapKit.Label = { text = "HOLLYWOOD RNG", color = P.Burgundy, stroke = 0 }
	MapKit.place(b, "PlazaFountain", CFrame.identity, { labels = { PlaqueFront = words, PlaqueBack = words } })
	LotModels.trophy(Build.new(b.parent, b:at(v(0, 3.8, 0)), 3.6))
	-- Water jets round the statue.
	for i = 0, 5 do
		local a = math.rad(i * 60 + 30)
		local jet = b:cylinder("Jet", 2.4, 0.5, CFrame.Angles(0, a, 0) * CFrame.new(0, 2.6, -5.6), Color3.fromRGB(190, 230, 255), NEON)
		jet.Transparency = 0.35
		jet.CanCollide = false
	end
	local spray = ghost(b, "SprayAnchor", v(0, 4.5, 0))
	local drops = Instance.new("ParticleEmitter")
	drops.Name = "Spray"
	drops.Color = ColorSequence.new(Color3.fromRGB(200, 235, 255))
	drops.LightEmission = 0.4
	drops.Size = NumberSequence.new(0.35, 0.1)
	drops.Transparency = NumberSequence.new(0.2, 0.8)
	drops.Lifetime = NumberRange.new(0.8, 1.1)
	drops.Rate = 30
	drops.Speed = NumberRange.new(10, 13)
	drops.SpreadAngle = Vector2.new(35, 35)
	drops.Acceleration = Vector3.new(0, -35, 0)
	drops.Parent = spray
end

local function plaza(b: Builder)
	local r = Lay.plazaRadius
	-- Rings of gold, paving and red carpet, each a little higher than the one under it (stacked
	-- surfaces closer than about 0.05 studs flicker from far away).
	b:cylinder("PlazaEdge", 0.3, r * 2 + 2, v(0, 0.15, 0), P.Gold)
	b:cylinder("Plaza", 0.36, r * 2, v(0, 0.18, 0), P.OffWhite)
	b:cylinder("PlazaCarpet", 0.42, 30, v(0, 0.21, 0), P.Carpet, Enum.Material.Fabric)
	b:cylinder("PlazaInner", 0.48, 27, v(0, 0.24, 0), P.Paving)
	fountain(b:sub(v(0, 0.48, 0)))

	-- Gold star where players appear.
	local spawn = Lay.spawn.Position
	flatStar(b, "SpawnStar", 4.6, v(spawn.X, 0.51, spawn.Z), 0.06, P.Gold)
	b:cylinder("SpawnStarMiddle", 0.08, 2.2, v(spawn.X, 0.55, spawn.Z), P.Carpet)

	-- Palms in planters and benches facing the fountain on the diagonals; searchlights on the
	-- boulevard sides.
	for i = 0, 3 do
		local yaw = math.rad(45 + i * 90)
		local dir = CFrame.Angles(0, yaw, 0)
		planter(Build.new(b.parent, b:at(dir * CFrame.new(0, 0.36, -(r - 3.5)))), 16)
		bench(Build.new(b.parent, b:at(dir * CFrame.new(0, 0.42, -(r - 9)) * CFrame.Angles(0, math.pi, 0))))
	end
	for _, side in { -1, 1 } do
		LotModels.searchlight(b:sub(v(side * (r - 4), 0.36, 0)), if side > 0 then 35 else -35, P.Light)
	end
end

-- Streets ----------------------------------------------------------------------------------------

-- The Blender double-globe street lamp, with one warm light (Future lighting makes it a real
-- pool of light on the paving at dusk).
local LAMP_LIGHT = { range = 16, brightness = 1.5, color = Color3.fromRGB(255, 214, 150) }

local function lamp(b: Builder, at: Vector3)
	MapKit.place(b, "TownLamp", at, { solid = true, light = LAMP_LIGHT })
end

local function walkOfFameStar(b: Builder, x: number, z: number)
	b:block("FameTile", v(3.6, 0.06, 3.6), v(x, 0.23, z), P.Charcoal)
	flatStar(b, "FameStar", 2.2, v(x, 0.28, z), 0.06, Color3.fromRGB(240, 140, 150))
	b:cylinder("FameMedal", 0.08, 0.9, v(x, 0.32, z), P.Gold, METAL)
end

local function streets(b: Builder)
	local x0, z0 = Lay.townX, Lay.townZ
	local length = x0 * 2
	local road = Lay.roadHalf
	local front = Lay.sidewalkTo
	local ring = Lay.ringWidth

	-- Boulevard: asphalt with a red carpet down the middle, gold-edged. The carpet stops just
	-- past the arches with a gold strip, and a curb closes each end of the road.
	b:block("Road", v(length, 0.15, road * 2), v(0, 0.075, 0), P.Asphalt)
	local carpetHalf = x0 - 3
	b:block("BoulevardCarpet", v(carpetHalf * 2, 0.06, 6), v(0, 0.18, 0), P.Carpet, Enum.Material.Fabric)
	for _, z in { -3.2, 3.2 } do
		b:block("BoulevardCarpetEdge", v(carpetHalf * 2, 0.07, 0.4), v(0, 0.185, z), P.Gold)
	end
	-- East, the carpet stops under the arch with a gold strip; west, it carries on to the theatre
	-- (landmarks()).
	b:block("CarpetEnd", v(0.4, 0.07, 6.8), v(carpetHalf + 0.2, 0.185, 0), P.Gold)
	-- Crossings in front of the outer lots' gates (the middle lots cross through the plaza).
	for _, x in { -LOT_SPACING, LOT_SPACING } do
		for _, side in { -1, 1 } do
			for i = 0, 2 do
				b:block("Crossing", v(10, 0.06, 1.2), v(x, 0.18, side * (4.2 + i * 2)), P.OffWhite)
			end
		end
	end

	-- Sidewalks up to the lot fronts, with a cream curb, lamps, palms and Walk of Fame stars.
	local plazaGap = Lay.plazaRadius + 1
	for _, side in { -1, 1 } do
		b:block("Sidewalk", v(length, 0.2, front - road), v(0, 0.1, side * (road + front) / 2), P.Paving)
		for _, dir in { -1, 1 } do
			local curbLength = x0 - plazaGap
			b:block("Curb", v(curbLength, 0.35, 0.8), v(dir * (plazaGap + curbLength / 2), 0.175, side * (road + 0.4)), P.Cream)
		end
		-- Along the curb, lamps and palms by turns, leaving the crossings clear.
		local n = 0
		for x = 32, x0 - 10, 12 do
			if math.abs(x - LOT_SPACING) > 7 then
				n += 1
				for _, dir in { -1, 1 } do
					if n % 2 == 1 then
						lamp(b, v(dir * x, 0.2, side * (road + 1.8)))
					else
						LotModels.palm(b:sub(v(dir * x, 0.2, side * (road + 2))), 15, 6)
					end
				end
			end
		end
		for x = 32, x0 - 8, 12 do
			for _, dir in { -1, 1 } do
				walkOfFameStar(b, dir * x, side * 15)
			end
		end
	end

	-- Lawns with bushes and flowers along the lot fronts, leaving the gates, the paths between the
	-- lots and the corners clear.
	local lawnFrom, lawnTo = LAWN_FROM, front - 0.5
	for _, side in { -1, 1 } do
		for _, span in LAWN_SPANS do
			local left, right = span[1], span[2]
			local zMid = side * (lawnFrom + lawnTo) / 2
			b:block("Lawn", v(right - left, 0.34, lawnTo - lawnFrom), v((left + right) / 2, 0.17, zMid), P.Green, GRASS)
			b:block("LawnEdge", v(right - left + 0.4, 0.27, lawnTo - lawnFrom + 0.4), v((left + right) / 2, 0.135, zMid), P.Cream)
			local n = 0
			for x = left + 3, right - 2, 5 do
				n += 1
				if n % 2 == 1 then
					MapKit.place(b, "Bush", CFrame.new(x, 0.34, side * (lawnTo - 2)) * CFrame.Angles(0, n, 0), { scale = 0.7 })
				else
					MapKit.place(b, "FlowerPatch", CFrame.new(x + 0.4, 0.34, side * (lawnTo - 2.8)) * CFrame.Angles(0, n, 0), { solid = false })
				end
			end
		end
	end

	-- A ramp up into each lot's gate.
	for index = 1, 6 do
		local lot = Build.new(b.parent, MapModels.lotBase(index))
		lot:wedge("GateRamp", v(10, 0.8, 3), v(0, 0.6, -LOT_HALF - 1.5), P.Paving)
	end

	-- Paths between the lots, a path right round the outside, and lamps along them.
	local alleyLength = z0 - ring - front
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local zMid = sz * (front + alleyLength / 2)
			b:block("Alley", v(Lay.alleyWidth, 0.2, alleyLength), v(sx * Lay.alleyX, 0.1, zMid), P.Paving)
			-- Side path, from the sidewalk to the back path.
			b:block("SidePath", v(ring, 0.2, z0 - front), v(sx * (x0 - ring / 2), 0.1, sz * (front + z0) / 2), P.Paving)
		end
		b:block("BackPath", v(length - ring * 2, 0.2, ring), v(0, 0.1, sx * (z0 - ring / 2)), P.Paving)
		for x = -140, 140, 40 do
			lamp(b, v(x, 0.2, sx * (z0 - 1.5)))
		end
		-- Bushes on the grass behind the lots and beside the outer ones.
		local behind = z0 - ring - 4
		for x = -(x0 - 20), x0 - 20, 8 do
			if math.abs(math.abs(x) - Lay.alleyX) > Lay.alleyWidth / 2 + 1 then
				MapKit.place(b, "Bush", CFrame.new(x, 0, sx * behind) * CFrame.Angles(0, x, 0), { scale = 0.75 })
			end
		end
		for z = front + 6, behind, 8 do
			for _, sz in { -1, 1 } do
				MapKit.place(b, "Bush", CFrame.new(sx * (x0 - ring - 4), 0, sz * z) * CFrame.Angles(0, z, 0), { scale = 0.75 })
			end
		end
	end
end

-- Edge of town -----------------------------------------------------------------------------------

-- Hedge round the town with cream pillars, like the lots' own fences (map kit HedgeSection and
-- TownPillar).
local function hedgeRun(b: Builder, from: Vector3, to: Vector3)
	local delta = to - from
	local length = delta.Magnitude
	local sections = math.max(1, math.round(length / 10))
	local each = length / sections
	local turn = if math.abs(delta.X) > math.abs(delta.Z) then CFrame.identity else CFrame.Angles(0, math.pi / 2, 0)
	for i = 0, sections - 1 do
		local mid = from + delta * ((i + 0.5) / sections)
		MapKit.place(b, "HedgeSection", CFrame.new(mid) * turn, { scale = each / 10 })
	end
end

local function fence(b: Builder)
	local fx, fz = Lay.fenceX, Lay.fenceZ
	-- The hedges at the boulevard's ends leave a gap for the road out to the landmarks.
	local gap = Lay.endGap
	for _, s in { -1, 1 } do
		for _, sz in { -1, 1 } do
			hedgeRun(b, v(s * fx, 0, sz * gap), v(s * fx, 0, sz * fz))
		end
		local half = Lay.sideGap
		for _, sx in { -1, 1 } do
			hedgeRun(b, v(sx * half, 0, s * fz), v(sx * (fx + 1), 0, s * fz))
		end
	end
	local function pillar(x: number, z: number)
		MapKit.place(b, "TownPillar", v(x, 0, z))
	end
	local count = 8
	for i = 0, count do
		local x = -fx + i * fx * 2 / count
		if x ~= 0 then
			pillar(x, -fz)
			pillar(x, fz)
		end
	end
	for _, x in { -Lay.sideGap, Lay.sideGap } do
		pillar(x, -fz)
		pillar(x, fz)
	end
	for i = 1, count - 1 do
		local z = -fz + i * fz * 2 / count
		if math.abs(z) > gap then
			pillar(-fx, z)
			pillar(fx, z)
		end
	end
	for _, z in { -gap, gap } do
		pillar(-fx, z)
		pillar(fx, z)
	end
end

-- "HOLLYWOOD BLVD" arch over each end of the boulevard (map kit BoulevardArch; its signs face
-- along the boulevard).
local function arch(b: Builder)
	local words: MapKit.Label = { text = "HOLLYWOOD BLVD", color = P.Gold, stroke = 4 }
	MapKit.place(b, "BoulevardArch", CFrame.identity, { labels = { SignA = words, SignB = words } })
end

-- The Blender studio water tower, with "HOLLYWOOD RNG" on its sign plate.
local function waterTower(b: Builder)
	MapKit.place(b, "WaterTower", CFrame.identity, { solid = true })
	local plate = b:block("TowerSign", v(7.4, 2.6, 0.05), v(0, 25.2, -5.85), P.Cream)
	plate.Transparency = 1
	plate.CanCollide = false
	plate.CanQuery = false
	Build.sign(plate, Enum.NormalId.Front, "HOLLYWOOD RNG", P.Burgundy)
end

-- The near hills round the town: big low-poly balls (map kit Hill<kit>, modelled 100 across)
-- sunk into the ground. The ones behind Dusty Gulch are sand-colored, in the desert. (The far ring
-- of mountains is terrain, see MapScenery.)
MapModels.Hills = table.freeze({
	{ at = v(0, -70, 368), size = 260, kit = "Green" },
	{ at = v(-220, -80, 343), size = 190, kit = "Dark" },
	{ at = v(225, -78, 338), size = 180, kit = "Dark" },
	{ at = v(70, -80, -373), size = 210, kit = "Sand" },
	{ at = v(-140, -85, -358), size = 190, kit = "Dust" },
	{ at = v(340, -85, 20), size = 200, kit = "Green" },
	{ at = v(-345, -85, -20), size = 200, kit = "Green" },
} :: { MapScenery.Hill })

local function hills(b: Builder)
	for _, hill in MapModels.Hills do
		local feet = hill.at - v(0, hill.size / 2, 0)
		MapKit.place(b, "Hill" .. hill.kit, CFrame.new(feet) * CFrame.Angles(0, hill.size, 0), { scale = hill.size / 100, far = true })
	end
	-- The landmark: a giant gold star sign on the big hill, leaning back into the slope (the kit
	-- model stands upright with the star's middle 15 up).
	MapKit.place(b, "HillStar", CFrame.new(Lay.hillStar) * CFrame.Angles(math.rad(30), 0, 0) * CFrame.new(0, -15, 0), { far = true })
end

-- Big sound stages and the water towers outside the hedge.
local function backlot(b: Builder)
	local look = { owned = true, accent = P.Carpet, filming = false }
	local west = CFrame.new(-Lay.fenceX - 30, 0, -48) * CFrame.Angles(0, math.rad(-90), 0)
	LotModels.soundStage(Build.new(b.parent, b:at(west), 2.4), 7, look)
	-- East, the road through the Studio Gate ends at this stage's door.
	local east = CFrame.new(Lay.backlotEnd + 17, 0, 0) * CFrame.Angles(0, math.rad(90), 0)
	LotModels.soundStage(Build.new(b.parent, b:at(east), 2.4), 8, { owned = true, accent = P.Blue, filming = true })
	waterTower(b:sub(v(-Lay.fenceX - 24, 0, 44)))
	waterTower(b:sub(v(Lay.fenceX + 26, 0, -40)))
end

-- Landmarks and film sets (TownSets) ----------------------------------------------------------------

-- Where each back street's film set goes: the path between two lots, its -Z toward the boulevard.
MapModels.Sets = table.freeze({
	{ set = "greenScreen", x = -1, z = -1 },
	{ set = "propsYard", x = 1, z = -1 },
	{ set = "trailers", x = -1, z = 1 },
	{ set = "foodCorner", x = 1, z = 1 },
})

local function landmarks(b: Builder)
	local x0, gap = Lay.townX, Lay.endGap
	-- West: a forecourt out to the theatre steps, the carpet running all the way.
	local west = Lay.theatreX
	local length = -x0 - west
	b:block("Forecourt", v(length, 0.2, gap * 2), v(-x0 - length / 2, 0.1, 0), P.Paving)
	b:block("ForecourtCarpet", v(length + 3, 0.06, 6), v(-x0 - length / 2 + 1.5, 0.23, 0), P.Carpet, Enum.Material.Fabric)
	for _, z in { -3.2, 3.2 } do
		b:block("ForecourtCarpetEdge", v(length + 3, 0.07, 0.4), v(-x0 - length / 2 + 1.5, 0.235, z), P.Gold)
	end
	TownSets.theatre(b:sub(CFrame.new(west - 3, 0, 0) * CFrame.Angles(0, math.rad(-90), 0)))
	LotModels.stanchions(b:sub(CFrame.new(west + 8, 0.2, 0) * CFrame.Angles(0, math.rad(-90), 0)), -6, 6, 4)
	for _, z in { -1, 1 } do
		LotModels.palm(b:sub(v(west + 3, 0.2, z * 10)), 15, 6)
		TownSets.flowerBed(b:sub(v(-x0 - 11, 0.2, z * (gap + 4))), v(12, 0, 6))
	end

	-- East: the road carries on through the Studio Gate to the backlot.
	local east = Lay.gateX
	local road = Lay.backlotEnd - x0
	b:block("BacklotRoad", v(road, 0.15, Lay.roadHalf * 2), v(x0 + road / 2, 0.075, 0), P.Asphalt)
	for _, z in { -1, 1 } do
		b:block("BacklotVerge", v(road, 0.2, gap - Lay.roadHalf), v(x0 + road / 2, 0.1, z * (gap + Lay.roadHalf) / 2), P.Paving)
		TownSets.flowerBed(b:sub(v(x0 + 11, 0.2, z * (gap + 4))), v(12, 0, 6))
	end
	TownSets.studioGate(b:sub(CFrame.new(east, 0.2, 0) * CFrame.Angles(0, math.rad(90), 0)))

	-- A film set in each back street.
	for _, info in MapModels.Sets do
		local base = CFrame.new(info.x * Lay.alleyX, 0.2, info.z * (Lay.sidewalkTo + 32))
		if info.z < 0 then
			base *= CFrame.Angles(0, math.pi, 0)
		end
		local build = (TownSets :: any)[info.set] :: (Builder) -> ()
		build(Build.new(b.parent, base))
	end

	-- Poster columns on the sidewalks.
	local posters = {
		{ x = -64, z = 26, title = "MONSTER\nISLAND", kit = "Green" },
		{ x = 64, z = 26, title = "SPACE\nCOWBOYS", kit = "Blue" },
		{ x = -64, z = -26, title = "LOVE IN\nPARIS", kit = "Pink" },
		{ x = 64, z = -26, title = "THE LAST\nHEIST", kit = "Red" },
		{ x = -150, z = 26, title = "ROBOT\nCHEF", kit = "Blue" },
		{ x = 150, z = 26, title = "DRAGON\nKING", kit = "Red" },
		{ x = -150, z = -26, title = "PIRATE\nPUPS", kit = "Green" },
		{ x = 150, z = -26, title = "GHOST\nMALL", kit = "Pink" },
	}
	for _, poster in posters do
		local face = if poster.z > 0 then CFrame.identity else CFrame.Angles(0, math.pi, 0)
		TownSets.posterColumn(b:sub(CFrame.new(poster.x, 0.2, poster.z) * face), poster.title, poster.kit)
	end

	-- Street life: vintage cars parked at the boulevard's ends (the middle stays clear for the
	-- Mystery Crate and Cash Rain coins) and on the backlot road, a bus stop, a news stand,
	-- hydrants and bins.
	local cars = {
		{ x = x0 - 6.5, z = 1, kit = "Teal" },
		{ x = -(x0 - 6.5), z = -1, kit = "Pink" },
		{ x = 140, z = -1, kit = "Red" },
		{ x = -140, z = 1, kit = "Gold" },
		{ x = x0 + 34, z = 1, kit = "Gold" },
		{ x = x0 + 40, z = -1, kit = "Red" },
	}
	for _, car in cars do
		-- Driving on the right: +Z side heads toward -X, -Z side toward +X.
		local yaw = if car.z > 0 then math.rad(90) else math.rad(-90)
		TownSets.car(b:sub(CFrame.new(car.x, 0.15, car.z * 6.6) * CFrame.Angles(0, yaw, 0)), car.kit)
	end
	TownSets.busStop(b:sub(CFrame.new(96, 0.2, -22) * CFrame.Angles(0, math.pi, 0)))
	TownSets.busStop(b:sub(CFrame.new(-128, 0.2, 22)))
	TownSets.newsStand(b:sub(v(-96, 0.2, 24)))
	TownSets.newsStand(b:sub(CFrame.new(128, 0.2, -24) * CFrame.Angles(0, math.pi, 0)))
	for _, spot in { v(54, 0.2, 11.5), v(-54, 0.2, -11.5), v(102, 0.2, 11.5), v(-102, 0.2, -11.5), v(158, 0.2, -11.5), v(-158, 0.2, 11.5) } do
		TownSets.hydrant(b:sub(spot))
	end
	for _, spot in { v(76, 0.2, -24), v(-76, 0.2, 24), v(30, 0.2, -24), v(-30, 0.2, 24), v(170, 0.2, 24), v(-170, 0.2, -24) } do
		TownSets.trashBin(b:sub(spot))
	end
	-- A pale strip along each curb, so the wide sidewalks read as paved walks.
	for _, side in { -1, 1 } do
		for _, dir in { -1, 1 } do
			local from, to = Lay.plazaRadius + 1, Lay.townX
			b:block("SidewalkStrip", v(to - from, 0.05, 2.4), v(dir * (from + to) / 2, 0.225, side * (Lay.roadHalf + 2.2)), P.OffWhite)
		end
	end

	-- Pass 3: paths out through the hedge gaps to Starlight Park (back) and Dusty Gulch (front),
	-- and the blimp (src/client/Blimp.luau drifts it round the town).
	local out, edge = Lay.townZ, Lay.fenceZ + 1
	for _, s in { -1, 1 } do
		b:block("SidePath", v(Lay.sideGap * 2, 0.2, edge - out + 1), v(0, 0.1, s * (out + edge + 1) / 2), P.Paving)
	end
	TownSets.park(b:sub(v(0, 0, edge)))
	TownSets.westernTown(b:sub(MapModels.GulchFrame))
	TownSets.blimp(b:sub(CFrame.new(0, Lay.blimpHeight, -Lay.blimpRadius) * CFrame.Angles(0, math.rad(-90), 0)))

	-- A hazy city skyline past the theatre (the front is desert and mesas now, behind Dusty Gulch).
	TownSets.skyline(b:sub(CFrame.new(-540, -8, 40) * CFrame.Angles(0, math.rad(90), 0)), 8, 320, 11)
end

-- Boulevard buildings ------------------------------------------------------------------------------
-- Tall Blender buildings (art/blender/boulevard_kit.py) line the boulevard: a narrow pair at the
-- front of each path between the lots, with the path running back between them, and a wide one
-- closing each end of town. Their fronts stand just past the sidewalk, facing the boulevard.

export type BuildingInfo = {
	kit: string, -- map kit model
	x: number, -- middle of its front
	z: number, -- 1 for the back row (+Z), -1 for the front row
	labels: { [string]: string }, -- sign text by kit spot
}

local NEAR, FAR = Lay.alleyX - 19.2, Lay.alleyX + 19.2 -- narrow buildings either side of a path
local END_X = (LOT_SPACING + LOT_HALF + Lay.townX - Lay.ringWidth) / 2 -- wide buildings at the ends

MapModels.Buildings = table.freeze({
	{ kit = "HotelStardust", x = -END_X, z = 1, labels = { Canopy = "HOTEL STARDUST", Roof = "STARDUST" } },
	{ kit = "ApartmentsPink", x = -FAR, z = 1, labels = { Shop = "FLOWERS", Billboard = "DRAGON KING" } },
	{ kit = "CostumeShopPurple", x = -NEAR, z = 1, labels = { Shop = "COSTUMES", Blade = "W\nI\nG\nS", BladeBack = "W\nI\nG\nS" } },
	{ kit = "StarCafe", x = NEAR, z = 1, labels = { Shop = "STAR CAFE", Pylon = "CAFE" } },
	{ kit = "ApartmentsTeal", x = FAR, z = 1, labels = { Shop = "BOOKS", Billboard = "SPACE COWBOYS" } },
	{ kit = "SunsetTower", x = END_X, z = 1, labels = { Sign = "SUNSET TOWER" } },
	{ kit = "SunsetTower", x = -END_X, z = -1, labels = { Sign = "SUNSET TOWER" } },
	{ kit = "ApartmentsButter", x = -FAR, z = -1, labels = { Shop = "BAKERY", Billboard = "LOVE IN PARIS" } },
	{ kit = "RadioStation", x = -NEAR, z = -1, labels = { Sign = "KRNG RADIO" } },
	{ kit = "CostumeShopMint", x = NEAR, z = -1, labels = { Shop = "HATS & WIGS", Blade = "H\nA\nT\nS", BladeBack = "H\nA\nT\nS" } },
	{ kit = "ApartmentsLilac", x = FAR, z = -1, labels = { Shop = "VIDEO", Billboard = "NOW CASTING" } },
	{ kit = "HotelStardust", x = END_X, z = -1, labels = { Canopy = "HOTEL STARDUST", Roof = "STARDUST" } },
} :: { BuildingInfo })

-- Neon and bulb signs read gold; shop boards read white.
local SIGN_COLORS: { [string]: Color3 } = {
	Shop = P.OffWhite,
	Billboard = P.OffWhite,
	Blade = P.Gold,
	BladeBack = P.Gold,
	Sign = P.OffWhite,
	Pylon = P.Carpet,
	Canopy = P.Gold,
	Roof = P.Gold,
}

local WIDE = { HotelStardust = true, SunsetTower = true }

-- Where building `info` stands: its feet in the middle of the model, the front wall 1 stud past
-- the end of the sidewalk, facing the boulevard.
function MapModels.buildingBase(info: BuildingInfo): CFrame
	local depth = if WIDE[info.kit] then 24 else 20 -- the main block, without awnings and canopies
	local cf = CFrame.new(info.x, 0, info.z * (Lay.sidewalkTo + 1 + depth / 2))
	return if info.z < 0 then cf * CFrame.Angles(0, math.pi, 0) else cf
end

local function buildings(b: Builder)
	for _, info in MapModels.Buildings do
		local labels: { [string]: MapKit.Label } = {}
		for spot, text in info.labels do
			labels[spot] = { text = text, color = SIGN_COLORS[spot] or P.OffWhite, stroke = 3 }
		end
		MapKit.place(b, info.kit, MapModels.buildingBase(info), { labels = labels })
	end
end

-- Walkable ground ---------------------------------------------------------------------------------
-- The paths: the boulevard and its sidewalks, the lots, the paths between and round them, the
-- forecourt to the theatre, the road through the Studio Gate, Starlight Park's walks and Dusty
-- Gulch's street. Everything players need stands on them, and the background scenery keeps off
-- them. (Players may also walk on the grass: the invisible walls only run round PlayAreas.)

local function walkAreas(): { Walkways.Rect }
	local R = Walkways.rect
	local x0, z0, ring = Lay.townX, Lay.townZ, Lay.ringWidth
	local front, gap = Lay.sidewalkTo, Lay.endGap
	local areas: { Walkways.Rect } = {
		R(-x0, -LAWN_FROM, x0, LAWN_FROM), -- the boulevard, the plaza and the sidewalks up to the lawns
		R(Lay.theatreX, -gap, -x0, gap), -- forecourt to the theatre steps
		R(Lay.theatreX - 8.5, -13, Lay.theatreX, 13), -- the steps and the porch under the marquee
		R(x0, -gap, Lay.backlotEnd, gap), -- the road through the Studio Gate
	}
	-- Between the lawns, the sidewalks reach the lot gates, the paths between the lots and the
	-- path round the outside.
	for _, side in { -1, 1 } do
		local edges = { -x0 }
		for _, span in LAWN_SPANS do
			table.insert(edges, span[1])
			table.insert(edges, span[2])
		end
		table.insert(edges, x0)
		for i = 1, #edges, 2 do
			table.insert(areas, R(edges[i], side * LAWN_FROM, edges[i + 1], side * front))
		end
		for _, sx in { -1, 1 } do
			table.insert(areas, R(sx * (Lay.alleyX - Lay.alleyWidth / 2), side * front, sx * (Lay.alleyX + Lay.alleyWidth / 2), side * (z0 - ring)))
			table.insert(areas, R(sx * (x0 - ring), side * front, sx * x0, side * z0))
		end
		table.insert(areas, R(-x0, side * (z0 - ring), x0, side * z0))
		-- Out through the hedge gap to the park (back) and the Gulch (front).
		table.insert(areas, R(-Lay.sideGap, side * z0, Lay.sideGap, side * (Lay.fenceZ + 1)))
	end
	for index = 1, 6 do
		local p = MapModels.lotBase(index).Position
		table.insert(areas, R(p.X - LOT_HALF, p.Z - LOT_HALF, p.X + LOT_HALF, p.Z + LOT_HALF))
	end

	-- Starlight Park (TownSets.park, laid out from z = edge toward +Z).
	local e = Lay.fenceZ + 1
	for _, r in {
		R(-5.8, 0, 5.8, 90), -- the main path, with its curbs
		R(-40, 45.2, 90, 54.8), -- the cross path through the fountain plaza
		R(-12, 39, 12, 61), -- the fountain plaza
		R(-8.6, 36.5, 8.6, 63.5),
		R(55.2, 54, 64.8, 77), -- the spur to the bandstand
		R(51, 77, 69, 95), -- the bandstand
		R(-28.8, 54, -19.2, 86), -- the path to the pond
		R(-54, 81.5, -19.2, 86.5), -- the bridge
		R(-67.5, 77.5, -54, 90.5), -- the island
		R(-20.4, 87.6, 20.4, 106.4), -- the square in front of the movie screen
	} do
		table.insert(areas, R(r.x0, e + r.z0, r.x1, e + r.z1))
	end
	-- Dusty Gulch (TownSets.westernTown, turned to run toward -Z): the street and boardwalks.
	table.insert(areas, R(-20, -e - 150, 20, -e))
	return areas
end

MapModels.WalkAreas = table.freeze(walkAreas())

-- The playable map: the town inside its hedge, the theatre forecourt, the road through the Studio
-- Gate, Starlight Park and Dusty Gulch. Players walk anywhere inside (paths, lawns, grass); the
-- only invisible walls run round the outside of all of it together, so nobody wanders off into
-- the woods or the desert, and there are no walls inside the map.
local function playAreas(): { Walkways.Rect }
	local R = Walkways.rect
	local fx, fz = Lay.fenceX + 1, Lay.fenceZ + 1 -- the outer face of the hedge
	return {
		R(-fx, -fz, fx, fz), -- the town, inside the hedge
		R(Lay.theatreX - 8.5, -30, -fx, 30), -- the theatre forecourt, its palms and flower beds
		R(fx, -30, Lay.backlotEnd + 1, 30), -- the Studio Gate road up to the sound stage door
		R(-108, fz, 108, fz + 128), -- Starlight Park, to its ranch fences and the movie screen
		R(-86, -fz - 158, 86, -fz), -- Dusty Gulch and its desert edges
		R(86, -272, 200, -152), -- Moon Base, past the Gulch's east edge
		R(-232, 132, -108, 252), -- the Jungle Temple, past the park's west fence
	}
end

MapModels.PlayAreas = table.freeze(playAreas())

local WALL_HEIGHT = 400 -- far higher than anything players could jump from
local WALL_THICK = 4

-- The invisible walls: one along each straight stretch of the play areas' outline, standing just
-- outside it, and a square post filling each outside corner where two walls meet.
-- Film set gates ---------------------------------------------------------------------------------

-- Where the gate's boom is hinged, in the gate's space: just inside the left post, resting across
-- the path on the right post (FilmSetWorld lifts it for owners).
MapModels.GateArmHinge = CFrame.new(-8, 3.25, 0)

-- Each film set's gate (kit SetGate and SetGateArm), the invisible wall across the way in, and an
-- anchor for the buy prompt. Returns the anchors.
local function filmSetGates(b: Builder): { { id: string, anchor: BasePart } }
	local anchors: { { id: string, anchor: BasePart } } = {}
	for _, info in MapModels.FilmSets do
		local g = b:sub(info.gate)
		local set = FilmSets.get(info.id)
		assert(set ~= nil, `no film set called {info.id}`)
		local sign: MapKit.Label = { text = string.upper(set.name) .. " FILM SET", color = P.Gold, stroke = 4 }
		local gate = MapKit.place(g, "SetGate", CFrame.identity, {
			labels = { Sign = sign, SignBack = sign, Price = { text = FilmSets.priceText(set), color = P.Gold, stroke = 0 } },
		})
		gate.Name = "FilmSetGate"
		gate:SetAttribute("FilmSet", info.id)
		local arm = MapKit.place(g, "SetGateArm", MapModels.GateArmHinge)
		arm.Name = "FilmSetGateArm"
		arm:SetAttribute("FilmSet", info.id)
		local wall = g:block("FilmSetWall", v(info.wallWidth, WALL_HEIGHT, 2), v(info.wallX, WALL_HEIGHT / 2 - 1, 0), P.Grey)
		wall:SetAttribute("FilmSet", info.id)
		local anchor = g:block("FilmSetPrompt", v(1, 1, 1), v(0, 3, -1.5), P.Grey)
		anchor:SetAttribute("FilmSet", info.id)
		for _, part in { wall, anchor } do
			part.Transparency = 1
			part.CastShadow = false
			part.CanTouch = false
			part.CanQuery = false
		end
		anchor.CanCollide = false
		table.insert(anchors, { id = info.id, anchor = anchor :: BasePart })
	end
	return anchors
end

local function walls(b: Builder)
	local y = WALL_HEIGHT / 2 - 1
	local half = WALL_THICK / 2
	for _, wall in Walkways.walls(MapModels.PlayAreas) do
		local length = (wall.b - wall.a).Magnitude
		local mid = (wall.a + wall.b) / 2
		if wall.alongX then
			b:block("MapWall", v(length, WALL_HEIGHT, WALL_THICK), v(mid.X, y, mid.Y + wall.out * half), P.Grey)
		else
			b:block("MapWall", v(WALL_THICK, WALL_HEIGHT, length), v(mid.X + wall.out * half, y, mid.Y), P.Grey)
		end
		for _, endInfo in { { at = wall.a, beyond = -1 }, { at = wall.b, beyond = 1 } } do
			local p = endInfo.at
			local corner = if wall.alongX
				then Vector2.new(p.X + endInfo.beyond * half, p.Y + wall.out * half)
				else Vector2.new(p.X + wall.out * half, p.Y + endInfo.beyond * half)
			if not Walkways.isWalkable(MapModels.PlayAreas, corner.X, corner.Y) then
				b:block("MapWall", v(WALL_THICK, WALL_HEIGHT, WALL_THICK), v(corner.X, y, corner.Y), P.Grey)
			end
		end
	end
end

-- Everything ------------------------------------------------------------------------------------

-- Thin trim laid over the paths: it never collides, so nobody trips on a lip a few hundredths of
-- a stud high (people walk on the path under it), and it casts no shadow.
local GROUND_TRIM = {
	BoulevardCarpet = true,
	BoulevardCarpetEdge = true,
	ChromaFloor = true,
	FloorMark = true,
	ForecourtCarpet = true,
	SidewalkStrip = true,
	Blanket = true,
	BridgePlank = true,
	DesertGround = true,
	DesertFloor = true,
	DustRut = true,
	DustStreet = true,
	FountainPlaza = true,
	FountainPlazaInner = true,
	FountainPlazaRing = true,
	LilyPad = true,
	PathEdge = true,
	PondShine = true,
	PondWater = true,
	ForecourtCarpetEdge = true,
	TheatreCarpet = true,
	CarpetEnd = true,
	Crossing = true,
	Curb = true,
	FameMedal = true,
	FameStar = true,
	FameTile = true,
	Lawn = true,
	LawnEdge = true,
	PlazaCarpet = true,
	PlazaEdge = true,
	PlazaInner = true,
	PromptRing = true,
	PromptSpot = true,
	RoadEnd = true,
	SpawnStar = true,
	SpawnStarMiddle = true,
}

-- Walking surfaces, hills and tiny bits: shadows nobody would notice, so skip drawing them.
local NO_SHADOW = {
	Alley = true,
	BackPath = true,
	BacklotRoad = true,
	BacklotVerge = true,
	BladeBulbs = true,
	Forecourt = true,
	GateTip = true,
	MarqueeBulbs = true,
	MoonCrater = true,
	SkylineTop = true,
	SkylineTower = true,
	TheatrePlinth = true,
	TheatreStep = true,
	Flower = true,
	Boardwalk = true,
	BoardwalkEdge = true,
	BlimpBanner = true,
	BlimpBannerTrim = true,
	BlimpEnd = true,
	BlimpEngine = true,
	BlimpFin = true,
	BlimpFinTip = true,
	BlimpGondola = true,
	BlimpGondolaBase = true,
	BlimpHull = true,
	BlimpNose = true,
	BlimpProp = true,
	BlimpStripe = true,
	BlimpWindows = true,
	FountainJet = true,
	FountainSplash = true,
	Island = true,
	IslandSand = true,
	ParkPath = true,
	PondStone = true,
	GateRamp = true,
	Ground = true,
	Hill = true,
	Plaza = true,
	Road = true,
	SidePath = true,
	Sidewalk = true,
	SignBulb = true,
	StandFloorTrim = true,
}

export type Built = {
	stands: { { info: StandInfo, anchor: BasePart } }, -- anchor: where the stand's prompt goes
	filmSets: { { id: string, anchor: BasePart } }, -- anchor: where the gate's buy prompt goes
}

-- Build the whole town into `parent`. The lots themselves are built by LotService (LotLook).
function MapModels.build(parent: Instance): Built
	local b = Build.new(parent, CFrame.identity)
	b:block("Ground", v(2048, 1, 2048), v(0, -0.5, 0), P.Green, GRASS) -- the largest part Roblox allows
	streets(b)
	plaza(b)
	fence(b)
	for _, side in { -1, 1 } do
		arch(b:sub(CFrame.new(side * (Lay.townX - 4), 0.2, 0)))
	end
	backlot(b)
	hills(b)
	landmarks(b)
	TownSets.moonBase(b:sub(MapModels.MoonFrame))
	TownSets.jungleTemple(b:sub(MapModels.JungleFrame))
	buildings(b)
	walls(b)
	local filmSets = filmSetGates(b)
	MapScenery.build(b, MapModels.WalkAreas, MapModels.PlayAreas, MapModels.Hills)

	local stands = {}
	for _, info in MapModels.Stands do
		table.insert(stands, { info = info, anchor = MapModels.stand(parent, MapModels.standBase(info), info) })
	end

	for _, part in parent:GetDescendants() do
		if part:IsA("BasePart") then
			if part.Name == "MapWall" then
				part.Transparency = 1
				part.CastShadow = false
				part.CanQuery = false
				part.CanTouch = false
			elseif GROUND_TRIM[part.Name] then
				part.CanCollide = false
				part.CastShadow = false
			elseif NO_SHADOW[part.Name] then
				part.CastShadow = false
			end
		end
	end
	return { stands = stands, filmSets = filmSets }
end

return MapModels
