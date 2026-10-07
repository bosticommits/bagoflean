--!strict
-- The town around the studio lots, so the six lots form one place instead of islands on a
-- baseplate: the boulevard with its red carpet, the spawn plaza and fountain, sidewalks with
-- Walk of Fame stars, paths that join every lot, the store stands, and hills with the gold star
-- sign around the edge. Built from parts in the style of ART_STYLE.md (section 7). Curved props
-- use the Blender meshes once imported (palm trees, searchlights, the trophy statue).
--
-- World space: X runs along the boulevard, Z across it. Lots 1-3 sit at -Z and lots 4-6 at +Z,
-- all facing the boulevard. The grass is at y = 0 and paths are 0.2 studs thick on top of it.
local ActorModels = require(script.Parent.ActorModels)
local Build = require(script.Parent.Build)
local IconModels = require(script.Parent.IconModels)
local LotModels = require(script.Parent.LotModels)

type Builder = Build.Builder

local P = Build.Palette
local NEON = Enum.Material.Neon
local GRASS = Enum.Material.Grass
local METAL = Enum.Material.Metal

local MapModels = {}

local LOT_SPACING = 80
local COLUMNS = 3
local ROW_Z = 70
local LOT_HALF = LotModels.Layout.size / 2

MapModels.Layout = table.freeze({
	roadHalf = 9, -- boulevard asphalt: z = -9..9
	sidewalkTo = ROW_Z - LOT_HALF, -- sidewalks reach the lot fronts (z = 42)
	townX = 124, -- outer edge of the path that runs round the town
	townZ = 114,
	ringWidth = 8,
	alleyX = 40, -- the paths between neighbouring lots
	alleyWidth = 20,
	plazaRadius = 24,
	fenceX = 129,
	fenceZ = 119,
	-- Players appear on the plaza looking past the fountain at the Shop and Rewards stands.
	spawn = CFrame.new(0, 0.4, -15) * CFrame.Angles(0, math.pi, 0),
	-- Gold star sign on the big hill behind lots 4-6.
	hillStar = Vector3.new(0, 44, 190),
})

local Lay = MapModels.Layout

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
	keeper: string, -- the (common) actor serving behind the counter
	x: number,
	z: number, -- on the sidewalk; stands face the boulevard
}

local PURPLE = Color3.fromRGB(160, 77, 255)
local TEAL = Color3.fromRGB(32, 178, 190)

-- From spawn, players look past the fountain at the Shop and Rewards stands.
MapModels.Stands = table.freeze({
	{ screen = "Shop", title = "SHOP", action = "Open Shop", icon = "popcorn", color = P.Gold, keeper = "AdModel", x = -22, z = 28 },
	{ screen = "Daily", title = "REWARDS", action = "Daily Rewards", icon = "gift", color = PURPLE, keeper = "BackgroundExtra", x = 22, z = 28 },
	{ screen = "Requests", title = "REQUESTS", action = "Studio Requests", icon = "clapper", color = P.Carpet, keeper = "NervousIntern", x = -40, z = 28 },
	{ screen = "Codes", title = "CODES", action = "Enter a Code", icon = "ticket", color = P.Blue, keeper = "IndieSidekick", x = 40, z = 28 },
	{ screen = "Studio", title = "MOVIES", action = "Make a Movie", icon = "camera", iconScale = 1.1, color = P.Green, keeper = "StuntDouble", x = -40, z = -28 },
	{ screen = "Upgrades", title = "UPGRADES", action = "Upgrade Studio", icon = "arrow", color = TEAL, keeper = "SoapRegular", x = -22, z = -28 },
	{ screen = "Odds", title = "CASTING ODDS", action = "See the Odds", icon = "dice", color = P.Blue, keeper = "AdModel", x = 22, z = -28 },
	{ screen = "Actors", title = "TALENT INDEX", action = "Your Actors", icon = "star", color = PURPLE, keeper = "NervousIntern", x = 40, z = -28 },
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

-- A market stand: counter, striped awning, lit sign with the store's name, a big 3D icon
-- on the roof, and an actor serving. Returns the invisible part the prompt goes on.
function MapModels.stand(parent: Instance, base: CFrame, info: StandInfo): BasePart
	local model = Instance.new("Model")
	model.Name = "Stand_" .. info.screen
	model.Parent = parent
	local b = Build.new(model, base)
	local accent = info.color

	-- Floor, walls and shelves.
	b:block("StandFloor", v(12, 0.4, 9), v(0, 0.2, 0.6), P.Paving)
	b:block("StandFloorTrim", v(12.4, 0.2, 9.4), v(0, 0.1, 0.6), P.Burgundy)
	b:block("BackWall", v(11, 7, 0.8), v(0, 3.9, 4.6), P.Cream)
	for _, side in { -1, 1 } do
		b:block("SideWall", v(0.8, 7, 5.4), v(side * 5.1, 3.9, 2.3), P.Cream)
		b:cylinder("Post", 3.8, 0.7, v(side * 5.1, 5.5, -1.1), P.Cream)
	end
	for i, y in { 4.6, 6.2 } do
		b:block("Shelf", v(9, 0.25, 1.1), v(0, y, 3.7), P.Wood)
		for j = -2, 2 do
			local shade = if (i + j) % 2 == 0 then accent else accent:Lerp(P.OffWhite, 0.45)
			b:block("Goods", v(1.1, 0.9, 0.8), v(j * 1.7, y + 0.57, 3.7), shade)
		end
	end

	-- Counter with the store name on its front.
	local counter = b:block("Counter", v(10.2, 3, 1.6), v(0, 1.9, -0.6), accent)
	b:block("CounterBand", v(10.4, 0.5, 1.7), v(0, 0.65, -0.6), P.Burgundy)
	b:block("CounterTop", v(11, 0.4, 2.2), v(0, 3.6, -0.7), P.Wood)
	Build.sign(counter, Enum.NormalId.Front, info.action, P.OffWhite)

	-- Roof and a striped awning sloping down over the counter, with a flap along its edge.
	b:block("Roof", v(12, 0.6, 7.2), v(0, 7.7, 1.5), P.Burgundy)
	local slope = math.atan2(1.3, 3)
	local stripes = 6
	for i = 0, stripes - 1 do
		local x = -6 + (i + 0.5) * 12 / stripes
		local color = if i % 2 == 0 then accent else P.OffWhite
		b:block("Awning", v(12 / stripes, 0.3, 3.3), CFrame.new(x, 7.05, -3.6) * CFrame.Angles(-slope, 0, 0), color)
		b:block("Valance", v(12 / stripes, 0.9, 0.2), v(x, 5.95, -5.1), if i % 2 == 0 then P.OffWhite else accent)
	end

	-- Lit sign on the roof, and the big icon above it.
	b:block("SignFrame", v(10.8, 3.6, 0.4), v(0, 9.9, -0.7), accent)
	local board = b:block("Sign", v(10, 2.8, 0.3), v(0, 9.9, -0.95), P.Navy)
	Build.sign(board, Enum.NormalId.Front, info.title, P.Gold)
	for i = 0, 5 do
		b:ball("SignBulb", 0.45, v(-4.5 + i * 1.8, 11.85, -0.9), P.Light, NEON)
	end
	IconModels.build(model, info.icon, b:at(v(0, 11.9, -0.4)), info.iconScale or 2)

	-- Someone serving, and a plant on either side.
	ActorModels.build(model, b:at(v(0, 0.4, 1.8)), info.keeper)
	for _, side in { -1, 1 } do
		b:cylinder("PlantPot", 1.2, 1.6, v(side * 7.2, 0.6, -2.4), P.Burgundy)
		b:ball("Plant", 2, v(side * 7.2, 1.9, -2.4), P.DarkGreen, GRASS)
	end

	-- A glowing ring on the ground in front, where the prompt appears.
	b:cylinder("PromptRing", 0.06, 6, v(0, 0.03, -7.2), accent, NEON)
	b:cylinder("PromptSpot", 0.08, 5.2, v(0, 0.04, -7.2), P.Paving)

	local anchor = b:block("PromptAnchor", v(10, 3, 1), v(0, 2, -2.2), P.OffWhite)
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	return anchor
end

-- Plaza ------------------------------------------------------------------------------------------

local function bench(b: Builder)
	b:block("BenchSeat", v(5, 0.4, 1.6), v(0, 1.3, 0), P.Wood)
	b:block("BenchBack", v(5, 1.4, 0.3), v(0, 2.2, 0.75), P.Wood)
	for _, x in { -2, 2 } do
		b:block("BenchLeg", v(0.4, 1.1, 1.6), v(x, 0.55, 0), P.Charcoal, METAL)
	end
end

local function planter(b: Builder, palmHeight: number)
	b:cylinder("Planter", 1, 5, v(0, 0.5, 0), P.Burgundy)
	b:cylinder("PlanterSoil", 0.2, 4.2, v(0, 1.05, 0), P.DarkGreen, GRASS)
	LotModels.palm(b:sub(v(0, 1, 0)), palmHeight, 7)
end

-- Fountain with a giant gold trophy in the middle of the spawn plaza.
local function fountain(b: Builder)
	local radius = 9
	b:cylinder("FountainBasin", 1.4, radius * 2, v(0, 0.7, 0), P.Cream)
	local water = b:cylinder("FountainWater", 0.1, radius * 2 - 1.4, v(0, 1.45, 0), Color3.fromRGB(110, 190, 245), Enum.Material.Glass)
	water.Transparency = 0.25
	-- Rim: a ring of blocks round the edge.
	local segments = 18
	for i = 0, segments - 1 do
		local a = math.rad(i * 360 / segments)
		local width = 2 * math.pi * radius / segments + 0.3
		b:block("FountainRim", v(width, 0.5, 1.3), CFrame.Angles(0, a, 0) * CFrame.new(0, 1.65, -radius + 0.55), P.Burgundy)
	end
	-- Pedestal and statue.
	b:cylinder("StatueBase", 3.2, 6, v(0, 1.6, 0), P.Burgundy)
	b:cylinder("StatueBand", 0.4, 6.3, v(0, 3, 0), P.Gold, METAL)
	b:cylinder("StatueTop", 0.6, 6.6, v(0, 3.5, 0), P.Cream)
	for _, side in { -1, 1 } do
		local plaque = b:block("Plaque", v(3.4, 1, 0.2), CFrame.Angles(0, if side > 0 then 0 else math.pi, 0) * CFrame.new(0, 2.3, -3.05), P.Gold)
		Build.sign(plaque, Enum.NormalId.Front, "HOLLYWOOD RNG", P.Burgundy)
	end
	LotModels.trophy(Build.new(b.parent, b:at(v(0, 3.8, 0)), 3.6))
	-- Water jets round the statue.
	for i = 0, 5 do
		local a = math.rad(i * 60 + 30)
		local jet = b:cylinder("Jet", 2.4, 0.5, CFrame.Angles(0, a, 0) * CFrame.new(0, 2.6, -5.6), Color3.fromRGB(190, 230, 255), NEON)
		jet.Transparency = 0.35
		jet.CanCollide = false
	end
	local spray = b:block("SprayAnchor", v(1, 1, 1), v(0, 4.5, 0), P.OffWhite)
	spray.Transparency = 1
	spray.CanCollide = false
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
	-- Rings of paving, red carpet and gold, each a hair higher than the one under it.
	b:cylinder("PlazaEdge", 0.3, r * 2 + 2, v(0, 0.15, 0), P.Gold)
	b:cylinder("Plaza", 0.32, r * 2, v(0, 0.16, 0), P.OffWhite)
	b:cylinder("PlazaCarpet", 0.34, 30, v(0, 0.17, 0), P.Carpet, Enum.Material.Fabric)
	b:cylinder("PlazaInner", 0.36, 27, v(0, 0.18, 0), P.Paving)
	fountain(b:sub(v(0, 0.36, 0)))

	-- Gold star where players appear.
	local spawn = Lay.spawn.Position
	flatStar(b, "SpawnStar", 4.6, v(spawn.X, 0.4, spawn.Z), 0.06, P.Gold)
	b:cylinder("SpawnStarMiddle", 0.08, 2.2, v(spawn.X, 0.42, spawn.Z), P.Carpet)

	-- Palms in planters and benches facing the fountain on the diagonals; searchlights on the
	-- boulevard sides.
	for i = 0, 3 do
		local yaw = math.rad(45 + i * 90)
		local dir = CFrame.Angles(0, yaw, 0)
		planter(Build.new(b.parent, b:at(dir * CFrame.new(0, 0.32, -(r - 3.5)))), 16)
		bench(Build.new(b.parent, b:at(dir * CFrame.new(0, 0.34, -(r - 9)) * CFrame.Angles(0, math.pi, 0))))
	end
	for _, side in { -1, 1 } do
		LotModels.searchlight(b:sub(v(side * (r - 4), 0.32, 0)), if side > 0 then 35 else -35, P.Light)
	end
end

-- Streets ----------------------------------------------------------------------------------------

local function lamp(b: Builder, at: Vector3)
	LotModels.lamp(b:sub(at), 9)
end

local function walkOfFameStar(b: Builder, x: number, z: number)
	b:block("FameTile", v(3.6, 0.06, 3.6), v(x, 0.23, z), P.Charcoal)
	flatStar(b, "FameStar", 2.2, v(x, 0.25, z), 0.06, Color3.fromRGB(240, 140, 150))
	b:cylinder("FameMedal", 0.08, 0.9, v(x, 0.28, z), P.Gold, METAL)
end

local function streets(b: Builder)
	local x0, z0 = Lay.townX, Lay.townZ
	local length = x0 * 2
	local road = Lay.roadHalf
	local front = Lay.sidewalkTo
	local ring = Lay.ringWidth

	-- Boulevard: asphalt with a red carpet down the middle, gold-edged.
	b:block("Road", v(length, 0.15, road * 2), v(0, 0.075, 0), P.Asphalt)
	b:block("BoulevardCarpet", v(length, 0.06, 6), v(0, 0.18, 0), P.Carpet, Enum.Material.Fabric)
	for _, z in { -3.2, 3.2 } do
		b:block("BoulevardCarpetEdge", v(length, 0.07, 0.4), v(0, 0.185, z), P.Gold)
	end
	-- Crossings in front of the outer lots' gates (the middle lots cross through the plaza).
	for _, x in { -LOT_SPACING, LOT_SPACING } do
		for _, side in { -1, 1 } do
			for i = 0, 2 do
				b:block("Crossing", v(10, 0.04, 1.2), v(x, 0.17, side * (4.2 + i * 2)), P.OffWhite)
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
		for _, x in { 32, 48, 72, 88, 108 } do
			for _, dir in { -1, 1 } do
				lamp(b, v(dir * x, 0.2, side * (road + 1.8)))
			end
		end
		for _, x in { 60, 100 } do
			for _, dir in { -1, 1 } do
				LotModels.palm(b:sub(v(dir * x, 0.2, side * (road + 2))), 15, 6)
			end
		end
		for x = 32, 116, 12 do
			for _, dir in { -1, 1 } do
				walkOfFameStar(b, dir * x, side * 15)
			end
		end
	end

	-- Lawns with bushes and flowers along the lot fronts, leaving the gates, the paths between the
	-- lots and the corners clear.
	local lawnFrom, lawnTo = 34, front - 0.5
	local flowers = { P.Carpet, P.Gold, Color3.fromRGB(240, 140, 150), P.OffWhite }
	for _, side in { -1, 1 } do
		for _, span in { { -110, -86 }, { -74, -50 }, { -30, -6 }, { 6, 30 }, { 50, 74 }, { 86, 110 } } do
			local left, right = span[1], span[2]
			local zMid = side * (lawnFrom + lawnTo) / 2
			b:block("Lawn", v(right - left, 0.3, lawnTo - lawnFrom), v((left + right) / 2, 0.15, zMid), P.Green, GRASS)
			b:block("LawnEdge", v(right - left + 0.4, 0.22, lawnTo - lawnFrom + 0.4), v((left + right) / 2, 0.11, zMid), P.Cream)
			local n = 0
			for x = left + 3, right - 2, 5 do
				n += 1
				if n % 2 == 1 then
					b:ball("Bush", 2.6, v(x, 1, side * (lawnTo - 2)), P.DarkGreen, GRASS)
				else
					b:ball("Flower", 1, v(x, 0.6, side * (lawnTo - 2.2)), flowers[(n // 2) % #flowers + 1])
					b:ball("Flower", 0.9, v(x + 0.9, 0.55, side * (lawnTo - 3.6)), flowers[(n // 2 + 1) % #flowers + 1])
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
			lamp(b, v(sx * (Lay.alleyX - 8), 0.2, zMid))
			for _, along in { 12, 48 } do
				LotModels.palm(b:sub(v(sx * Lay.alleyX, 0.2, sz * (front + along))), 14, 5)
			end
			-- Side path, from the sidewalk to the back path.
			b:block("SidePath", v(ring, 0.2, z0 - front), v(sx * (x0 - ring / 2), 0.1, sz * (front + z0) / 2), P.Paving)
		end
		b:block("BackPath", v(length - ring * 2, 0.2, ring), v(0, 0.1, sx * (z0 - ring / 2)), P.Paving)
		for x = -100, 100, 40 do
			lamp(b, v(x, 0.2, sx * (z0 - 1.5)))
		end
		-- Bushes on the grass behind the lots and beside the outer ones.
		local behind = z0 - ring - 4
		for x = -104, 104, 8 do
			if math.abs(math.abs(x) - Lay.alleyX) > Lay.alleyWidth / 2 + 1 then
				b:ball("Bush", 2.6, v(x, 1, sx * behind), P.DarkGreen, GRASS)
			end
		end
		for z = front + 6, behind, 8 do
			for _, sz in { -1, 1 } do
				b:ball("Bush", 2.6, v(sx * (x0 - ring - 4), 1, sz * z), P.DarkGreen, GRASS)
			end
		end
	end
end

-- Edge of town -----------------------------------------------------------------------------------

-- Hedge round the town with cream pillars, like the lots' own fences.
local function fence(b: Builder)
	local fx, fz = Lay.fenceX, Lay.fenceZ
	local h = 3
	local function hedge(center: Vector3, size: Vector3)
		b:block("TownHedge", v(size.X, h, size.Z), center + v(0, h / 2, 0), P.DarkGreen, GRASS)
		b:block("TownHedgeTop", v(size.X + 0.2, 0.5, size.Z + 0.2), center + v(0, h + 0.25, 0), P.Green, GRASS)
	end
	for _, s in { -1, 1 } do
		hedge(v(s * fx, 0, 0), v(2, 0, fz * 2))
		hedge(v(0, 0, s * fz), v(fx * 2 + 2, 0, 2))
	end
	local function pillar(x: number, z: number)
		b:block("TownPillar", v(2.8, 4.8, 2.8), v(x, 2.4, z), P.Cream)
		b:block("TownPillarCap", v(3.2, 0.6, 3.2), v(x, 5.1, z), P.Burgundy)
		b:ball("TownPillarLamp", 1.2, v(x, 6, z), P.Light, NEON)
	end
	local count = 8
	for i = 0, count do
		local x = -fx + i * fx * 2 / count
		pillar(x, -fz)
		pillar(x, fz)
	end
	for i = 1, count - 1 do
		local z = -fz + i * fz * 2 / count
		pillar(-fx, z)
		pillar(fx, z)
	end
end

-- "HOLLYWOOD BLVD" arch over each end of the boulevard (its signs face along the boulevard).
local function arch(b: Builder)
	local span = Lay.roadHalf + 3.5
	for _, side in { -1, 1 } do
		b:block("ArchFoot", v(3.6, 1.2, 3.6), v(0, 0.6, side * span), P.Burgundy)
		b:block("ArchPost", v(2.6, 14, 2.6), v(0, 8.2, side * span), P.Cream)
		b:ball("ArchLamp", 2, v(0, 17.6, side * span), P.Light, NEON)
	end
	b:block("ArchBeam", v(2, 1, span * 2 + 2.6), v(0, 15.6, 0), P.Burgundy)
	b:block("ArchSignTrim", v(1, 4.8, span * 2 - 3), v(0, 12.9, 0), P.Gold)
	local board = b:block("ArchSign", v(1.2, 4, span * 2 - 4), v(0, 12.9, 0), P.Navy)
	Build.sign(board, Enum.NormalId.Left, "HOLLYWOOD BLVD", P.Gold)
	Build.sign(board, Enum.NormalId.Right, "HOLLYWOOD BLVD", P.Gold)
end

local function waterTower(b: Builder)
	for _, x in { -3.5, 3.5 } do
		for _, z in { -3.5, 3.5 } do
			b:block("TowerLeg", v(0.8, 20, 0.8), v(x, 10, z), P.Steel, METAL)
		end
	end
	b:block("TowerBrace", v(8, 0.5, 0.5), v(0, 8, -3.5), P.Steel, METAL)
	b:block("TowerBrace", v(8, 0.5, 0.5), v(0, 8, 3.5), P.Steel, METAL)
	b:cylinder("TowerDeck", 0.6, 13, v(0, 20.3, 0), P.Steel, METAL)
	b:cylinder("TowerTank", 9, 11, v(0, 25, 0), P.Cream)
	for _, y in { 21.5, 28.5 } do
		b:cylinder("TowerBand", 0.6, 11.3, v(0, y, 0), P.Burgundy)
	end
	b:cylinder("TowerRoof", 1.2, 11.6, v(0, 30.1, 0), P.Burgundy)
	b:cylinder("TowerRoofTop", 1, 7, v(0, 31.2, 0), P.Burgundy)
	b:ball("TowerKnob", 1.2, v(0, 32, 0), P.Gold, METAL)
	local plate = b:block("TowerSign", v(8, 3, 0.4), v(0, 25, -5.4), P.Cream)
	Build.sign(plate, Enum.NormalId.Front, "HOLLYWOOD RNG", P.Burgundy)
end

local function hills(b: Builder)
	local hillList: { { at: Vector3, size: number, color: Color3 } } = {
		{ at = v(0, -70, 270), size = 260, color = P.Green },
		{ at = v(-170, -80, 230), size = 190, color = P.DarkGreen },
		{ at = v(175, -78, 225), size = 180, color = P.DarkGreen },
		{ at = v(60, -80, -250), size = 210, color = P.Green },
		{ at = v(-120, -85, -235), size = 190, color = P.DarkGreen },
		{ at = v(270, -85, 20), size = 200, color = P.Green },
		{ at = v(-275, -85, -20), size = 200, color = P.Green },
	}
	for _, hill in hillList do
		b:ball("Hill", hill.size, hill.at, hill.color, GRASS)
	end
	-- The landmark: a giant gold star sign on the big hill, leaning back into the slope.
	local starAt = CFrame.new(Lay.hillStar) * CFrame.Angles(math.rad(-60), 0, 0)
	local sign = b:sub(starAt)
	sign:block("HillStar", v(24, 1.5, 24), CFrame.identity, P.Gold, NEON)
	sign:block("HillStar", v(24, 1.5, 24), CFrame.Angles(0, math.rad(45), 0), P.Gold, NEON)
	sign:cylinder("HillStarMiddle", 1.7, 14, CFrame.identity, P.Light, NEON)
end

-- Big sound stages and the water tower behind the ends of the boulevard.
local function backlot(b: Builder)
	local look = { owned = true, accent = P.Carpet, filming = false }
	local west = CFrame.new(-Lay.fenceX - 30, 0, -34) * CFrame.Angles(0, math.rad(-90), 0)
	LotModels.soundStage(Build.new(b.parent, b:at(west), 2.4), 7, look)
	local east = CFrame.new(Lay.fenceX + 30, 0, 34) * CFrame.Angles(0, math.rad(90), 0)
	LotModels.soundStage(Build.new(b.parent, b:at(east), 2.4), 8, { owned = true, accent = P.Blue, filming = true })
	waterTower(b:sub(v(-Lay.fenceX - 26, 0, 36)))
	waterTower(b:sub(v(Lay.fenceX + 26, 0, -36)))
end

-- Everything ------------------------------------------------------------------------------------

export type Built = {
	stands: { { info: StandInfo, anchor: BasePart } }, -- anchor: where the stand's prompt goes
}

-- Build the whole town into `parent`. The lots themselves are built by LotService (LotLook).
function MapModels.build(parent: Instance): Built
	local b = Build.new(parent, CFrame.identity)
	b:block("Ground", v(1400, 1, 1400), v(0, -0.5, 0), P.Green, GRASS)
	streets(b)
	plaza(b)
	fence(b)
	for _, side in { -1, 1 } do
		arch(b:sub(CFrame.new(side * (Lay.townX - 4), 0.2, 0)))
	end
	backlot(b)
	hills(b)

	local stands = {}
	for _, info in MapModels.Stands do
		table.insert(stands, { info = info, anchor = MapModels.stand(parent, MapModels.standBase(info), info) })
	end
	return { stands = stands }
end

return MapModels
