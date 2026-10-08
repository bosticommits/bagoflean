--!strict
-- The town's landmarks and film sets (map revamp pass 1, see MapModels): the Grand Premiere
-- Theatre and the Studio Gate at the two ends of the boulevard, a themed film set in each back
-- street between the lots, poster columns on the sidewalks, and a far-off city skyline.
--
-- Each piece is laid out in its own space like the rest of the models (origin at the bottom
-- centre, front toward -Z); MapModels places them. Phones come first: no lights, small parts cast
-- no shadow (MapModels.build), and every piece stays within a few dozen parts.
local Build = require(script.Parent.Build)
local IconModels = require(script.Parent.IconModels)
local LotModels = require(script.Parent.LotModels)

type Builder = Build.Builder

local P = Build.Palette
local NEON = Enum.Material.Neon
local METAL = Enum.Material.Metal
local GLASS = Enum.Material.Glass
local GRASS = Enum.Material.Grass
local FABRIC = Enum.Material.Fabric

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

-- Grand Premiere Theatre -------------------------------------------------------------------------

-- A movie palace: steps up to a bulb-lit marquee, columns and poster cases, a tall "RNG" sign
-- with a gold star on top, side wings and searchlights. About 52 wide and 26 deep; the bottom
-- step is at z = -3.
function TownSets.theatre(b: Builder)
	-- Plinth and three steps up to it, with the red carpet running up the middle.
	b:block("TheatrePlinth", v(52, 1, 26), v(0, 0.5, 13), P.Burgundy)
	for i = 0, 2 do
		local h = (3 - i) / 3
		b:block("TheatreStep", v(26, h, 1), v(0, h / 2, -i - 0.5), P.Cream)
		b:block("TheatreCarpet", v(6, 0.06, 1), v(0, h + 0.03, -i - 0.5), P.Carpet, FABRIC)
	end
	b:block("TheatreCarpet", v(6, 0.06, 6), v(0, 1.03, 3), P.Carpet, FABRIC)

	-- The hall, with a gold band and a burgundy cornice.
	b:block("TheatreHall", v(34, 20, 20), v(0, 11, 16), P.Cream)
	b:block("TheatreBand", v(34.4, 0.8, 20.4), v(0, 17.5, 16), P.Gold, METAL)
	b:block("TheatreCornice", v(35.2, 1.2, 21.2), v(0, 21.4, 16), P.Burgundy)
	-- Wings either side, a little lower, with tall arched windows.
	for _, side in { -1, 1 } do
		b:block("TheatreWing", v(8.6, 13, 17), v(side * 21.3, 7.5, 16.5), P.Cream)
		b:block("TheatreWingTop", v(9.2, 1, 17.6), v(side * 21.3, 14.4, 16.5), P.Burgundy)
		for _, x in { -2.2, 2.2 } do
			b:block("TheatreWindow", v(2.2, 6, 0.3), v(side * 21.3 + x, 6, 7.9), P.Navy, GLASS)
			b:cylinder("TheatreWindowArch", 0.3, 2.2, CFrame.new(side * 21.3 + x, 9, 7.95) * CFrame.Angles(math.rad(90), 0, 0), P.Navy, GLASS)
		end
	end

	-- Columns along the front, with gold tops.
	for _, x in { -15, -9, 9, 15 } do
		b:block("TheatreColumnBase", v(2.2, 1, 2.2), v(x, 1.5, 4.6), P.Burgundy)
		b:cylinder("TheatreColumn", 10.5, 1.6, v(x, 7.25, 4.6), P.Cream)
		b:block("TheatreColumnTop", v(2.4, 0.8, 2.4), v(x, 12.9, 4.6), P.Gold, METAL)
	end
	-- Three glass doors in gold frames.
	for _, x in { -4.2, 0, 4.2 } do
		b:block("TheatreDoorFrame", v(3.8, 6.8, 0.3), v(x, 4.4, 5.95), P.Gold, METAL)
		b:block("TheatreDoor", v(3.2, 6.2, 0.3), v(x, 4.1, 5.8), P.Navy, GLASS)
	end
	-- Poster cases between the columns: two films "coming soon".
	for _, poster in { { x = -12, title = "SPACE\nCOWBOYS", color = P.Blue }, { x = 12, title = "LOVE IN\nPARIS", color = PINK } } do
		b:block("PosterCase", v(4, 5.6, 0.3), v(poster.x, 5.2, 5.9), P.Gold, METAL)
		local art = b:block("Poster", v(3.4, 5, 0.3), v(poster.x, 5.2, 5.75), poster.color)
		outlined(art, Enum.NormalId.Front, poster.title, P.OffWhite, 3)
	end

	-- The marquee: a deep canopy over the doors, a lit board on its front and bulbs underneath.
	b:block("Marquee", v(26, 3.6, 7), v(0, 10, 2.5), P.Burgundy)
	b:block("MarqueeCrest", v(27, 0.6, 7.6), v(0, 12.1, 2.5), P.Gold, METAL)
	b:block("MarqueeBulbs", v(25, 0.3, 6.4), v(0, 8.1, 2.5), P.Light, NEON)
	local board = b:block("MarqueeBoard", v(24, 2.6, 0.3), v(0, 10, -1.1), P.OffWhite)
	Build.sign(board, Enum.NormalId.Front, "TONIGHT: YOUR PREMIERE", P.Burgundy)
	for _, y in { 8.55, 11.45 } do
		b:block("MarqueeBulbs", v(24.6, 0.3, 0.3), v(0, y, -1.3), P.Light, NEON)
	end
	for _, x in { -12.15, 12.15 } do
		b:block("MarqueeBulbs", v(0.3, 3.2, 0.3), v(x, 10, -1.3), P.Light, NEON)
	end

	-- The tall "RNG" sign rising over the roof, edged with bulbs, with the gold star on top.
	b:block("BladeFrame", v(6.6, 19, 1.2), v(0, 22.3, 5.2), P.Gold, METAL)
	local blade = b:block("BladeSign", v(5.6, 18, 0.6), v(0, 22.3, 4.6), P.Navy)
	outlined(blade, Enum.NormalId.Front, "R\nN\nG", P.Gold, 6)
	for _, x in { -2.95, 2.95 } do
		b:block("BladeBulbs", v(0.35, 18, 0.35), v(x, 22.3, 4.2), P.Light, NEON)
	end
	IconModels.build(b.parent, "star", b:at(v(0, 31.6, 5)), 1.6)

	-- Searchlights on the front corners of the plinth.
	for _, side in { -1, 1 } do
		LotModels.searchlight(b:sub(v(side * 23, 1, 2)), side * 25, P.Light)
	end
end

-- Studio Gate ------------------------------------------------------------------------------------

-- A grand studio entrance: two towers, an arch with "HOLLYWOOD RNG STUDIOS" on both faces and a gold
-- star, iron gates swung open, and a guard booth. About 36 wide; the road runs through the middle.
function TownSets.studioGate(b: Builder)
	for _, side in { -1, 1 } do
		local x = side * 14
		b:block("GateTowerBase", v(7.4, 2, 7.4), v(x, 1, 0), P.Burgundy)
		b:block("GateTower", v(6, 22, 6), v(x, 13, 0), P.Cream)
		for _, y in { 6, 18 } do
			b:block("GateTowerBand", v(6.4, 0.8, 6.4), v(x, y, 0), P.Gold, METAL)
		end
		b:block("GateTowerCap", v(7.2, 1.4, 7.2), v(x, 24.7, 0), P.Burgundy)
		b:ball("GateTowerKnob", 2.4, v(x, 26.4, 0), P.Gold, METAL)
		-- An iron gate swung back against the tower, so the way through is open.
		local hinge = side * 10.6
		for _, y in { 1.2, 8.4 } do
			b:block("GateRail", v(0.35, 0.35, 9), v(hinge, y, 5.4), P.Charcoal, METAL)
		end
		for k = 0, 4 do
			local z = 1.6 + k * 1.9
			b:block("GateBar", v(0.3, 8.4, 0.3), v(hinge, 4.8, z), P.Charcoal, METAL)
			b:ball("GateTip", 0.6, v(hinge, 9.2, z), P.Gold, METAL)
		end
	end
	-- The arch and its sign.
	b:block("GateArch", v(22.2, 5, 4), v(0, 21.5, 0), P.Cream)
	for _, y in { 18.8, 24.2 } do
		b:block("GateArchTrim", v(22.4, 0.6, 4.4), v(0, y, 0), P.Gold, METAL)
	end
	for _, z in { -2.15, 2.15 } do
		local board = b:block("GateSign", v(19.6, 3.4, 0.3), v(0, 21.5, z), P.Navy)
		outlined(board, if z < 0 then Enum.NormalId.Front else Enum.NormalId.Back, "HOLLYWOOD RNG STUDIOS", P.Gold, 4)
	end
	IconModels.build(b.parent, "star", b:at(v(0, 24.5, 0)), 1.5)

	-- A guard booth beside the gate.
	local booth = b:sub(v(-22, 0, -4))
	booth:block("BoothBase", v(5.4, 0.6, 5.4), v(0, 0.3, 0), P.Burgundy)
	booth:block("Booth", v(5, 4.4, 5), v(0, 2.8, 0), P.Cream)
	booth:block("BoothWindow", v(3.6, 1.8, 0.2), v(0, 3.4, -2.55), P.Glass, GLASS)
	booth:block("BoothWindow", v(0.2, 1.8, 3.2), v(2.55, 3.4, 0), P.Glass, GLASS)
	booth:block("BoothRoof", v(6.2, 0.8, 6.2), v(0, 5.4, 0), P.Burgundy)
	booth:ball("BoothLamp", 1, v(0, 6.2, 0), P.Light, NEON)
end

-- Back street film sets --------------------------------------------------------------------------
-- Each set fills one of the paths between the lots: 20 studs across (x -10..10) and 64 long
-- (z -32..32, -Z toward the boulevard). Props keep to the sides (|x| >= 5.5) so the middle stays
-- a clear walk.

local function directorChair(b: Builder, label: string?)
	for _, x in { -0.9, 0.9 } do
		b:block("ChairFrame", v(0.25, 2.6, 1.6), v(x, 1.3, 0), P.Wood)
	end
	b:block("ChairSeat", v(1.8, 0.15, 1.5), v(0, 1.5, 0), P.Charcoal, FABRIC)
	local back = b:block("ChairBack", v(2, 0.8, 0.15), v(0, 2.5, 0.7), P.Charcoal, FABRIC)
	if label ~= nil then
		Build.sign(back, Enum.NormalId.Back, label, P.Gold)
	end
end

local function lightStand(b: Builder, color: Color3)
	b:block("StandFoot", v(1.6, 0.3, 1.6), v(0, 0.15, 0), P.Charcoal, METAL)
	b:cylinder("StandPole", 6, 0.3, v(0, 3.2, 0), P.Steel, METAL)
	b:block("StandLamp", v(2.2, 1.8, 1.2), v(0, 6.6, 0), P.Charcoal, METAL)
	b:block("StandLampFace", v(1.8, 1.4, 0.1), v(0, 6.6, -0.62), color, NEON)
end

local function crate(b: Builder, at: Vector3, size: number, yaw: number?)
	local cf = CFrame.new(at + v(0, size / 2, 0)) * CFrame.Angles(0, math.rad(yaw or 0), 0)
	b:block("PropCrate", v(size, size, size), cf, P.Wood)
	b:block("PropCrateBand", v(size + 0.1, size * 0.18, size + 0.1), cf, P.Bark)
end

local function sign(b: Builder, at: Vector3, text: string, color: Color3)
	b:block("SetSignPost", v(0.4, 6, 0.4), at + v(0, 3, 0.3), P.Charcoal, METAL)
	b:block("SetSignFrame", v(6.4, 2.2, 0.3), at + v(0, 5.6, 0), color)
	local board = b:block("SetSign", v(6, 1.8, 0.3), at + v(0, 5.6, -0.1), P.OffWhite)
	Build.sign(board, Enum.NormalId.Front, text, color)
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
	-- Camera crane: a dolly, a post, and a long arm with a counterweight and the camera.
	local crane = b:sub(CFrame.new(-7.5, 0.2, 2))
	crane:block("CraneDolly", v(3, 1, 4.4), v(0, 0.7, 0), P.Charcoal, METAL)
	crane:cylinder("CranePost", 5, 0.8, v(0, 3.7, 0), P.Steel, METAL)
	local arm = CFrame.new(0, 6.3, 0) * CFrame.Angles(0, 0, math.rad(14))
	crane:block("CraneArm", v(11, 0.6, 0.6), arm * CFrame.new(2.5, 0, 0), P.Gold, METAL)
	crane:block("CraneWeight", v(1.6, 1.6, 1.6), arm * CFrame.new(-2.6, -0.5, 0), P.Charcoal, METAL)
	crane:block("CraneCamera", v(1.8, 1.4, 1.2), arm * CFrame.new(8.2, -1, 0), P.Charcoal)
	crane:cylinder("CraneLens", 0.9, 0.8, arm * CFrame.new(9.4, -1, 0) * CFrame.Angles(0, 0, math.rad(90)), P.Steel, METAL)
	for _, z in { 11, 14 } do
		directorChair(b:sub(CFrame.new(-7.6, 0.2, z) * CFrame.Angles(0, math.rad(-90), 0)), if z == 11 then "DIRECTOR" else nil)
	end
	for _, z in { -9, 13 } do
		lightStand(b:sub(CFrame.new(6.2, 0.2, z) * CFrame.Angles(0, math.rad(if z < 0 then -70 else -110), 0)), P.Light)
	end
	-- A giant clapperboard leaning by the entrance.
	local clap = b:sub(CFrame.new(-7.5, 0.2, -22) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(math.rad(-10), 0, 0))
	clap:block("ClapBoard", v(5, 3.6, 0.4), v(0, 1.8, 0), P.Charcoal)
	for i = 0, 3 do
		clap:block("ClapStripe", v(1.25, 0.8, 0.45), v(-1.875 + i * 1.25, 4, 0), if i % 2 == 0 then P.OffWhite else P.Charcoal)
	end
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

	-- The dinosaur head, mouth open, roaring at people walking in.
	local dino = b:sub(CFrame.new(-7.8, 0.2, 2))
	local green = Color3.fromRGB(110, 190, 80)
	dino:block("DinoNeck", v(3.4, 3, 3.4), v(0, 1.5, 2.8), green)
	dino:block("DinoSkull", v(4.4, 3.8, 5), v(0, 4, 0.6), green)
	dino:block("DinoSnout", v(3.6, 2.2, 4), v(0, 4.4, -3.4), green)
	dino:block("DinoJaw", v(3.2, 0.9, 4.6), CFrame.new(0, 2.3, -2.6) * CFrame.Angles(math.rad(-12), 0, 0), Color3.fromRGB(90, 160, 70))
	for _, x in { -1.3, -0.45, 0.45, 1.3 } do
		dino:wedge("DinoTooth", v(0.5, 0.7, 0.4), CFrame.new(x, 3, -5) * CFrame.Angles(math.rad(180), 0, 0), P.OffWhite)
	end
	for _, x in { -1.6, 1.6 } do
		dino:block("DinoEye", v(0.8, 0.8, 0.8), v(x * 1.06, 5.2, -0.9), P.Gold, NEON)
		dino:block("DinoBrow", v(1.2, 0.4, 1.4), v(x * 1.06, 5.9, -0.9), Color3.fromRGB(80, 140, 60))
	end
	for i = 0, 2 do
		dino:wedge("DinoSpike", v(0.6, 1.2, 1.4), v(0, 6.5, 2.4 - i * 1.8), P.Carpet)
	end

	-- A fake moon on a stand, for space movies.
	b:block("MoonStand", v(2.4, 1.2, 2.4), v(8, 0.8, 8), P.Charcoal, METAL)
	b:ball("PropMoon", 6, v(8, 4.4, 8), Color3.fromRGB(225, 225, 215))
	for _, crater in { v(-1.6, 1, -2.3), v(1.2, -0.6, -2.6), v(0.3, 1.9, -1.9) } do
		b:ball("MoonCrater", 1.3, v(8, 4.4, 8) + crater, Color3.fromRGB(180, 180, 172))
	end
	-- A rolling spotlight aimed across the yard.
	local spot = b:sub(CFrame.new(-7.6, 0.2, -10) * CFrame.Angles(0, math.rad(-60), 0))
	spot:block("SpotCart", v(2.6, 0.8, 2.6), v(0, 0.8, 0), P.Carpet)
	spot:cylinder("SpotDrum", 2.4, 2, CFrame.new(0, 2.6, 0) * CFrame.Angles(math.rad(70), 0, 0), P.Steel, METAL)
	spot:cylinder("SpotLens", 0.1, 1.7, CFrame.new(0, 2.6, 0) * CFrame.Angles(math.rad(70), 0, 0) * CFrame.new(0, 1.25, 0), P.Light, NEON)
	sign(b, v(-7.5, 0.2, -29), "PROPS DEPT.", P.Carpet)
end

-- Star trailers: two trailers with stars on their doors, striped awnings, and chairs out front.
function TownSets.trailers(b: Builder)
	for i, trailer in { { z = -13, color = P.Carpet }, { z = 9, color = P.Blue } } do
		local t = b:sub(v(8.2, 0.2, trailer.z))
		t:block("TrailerBody", v(5.4, 5, 13), v(0, 3.4, 0), P.OffWhite)
		t:block("TrailerStripe", v(5.5, 0.9, 13.1), v(0, 2.4, 0), trailer.color)
		t:block("TrailerRoof", v(5.7, 0.4, 13.3), v(0, 6.1, 0), P.Steel, METAL)
		for _, z in { -4, 4 } do
			t:cylinder("TrailerWheel", 0.8, 1.8, CFrame.new(-2.3, 0.9, z) * CFrame.Angles(0, 0, math.rad(90)), P.Charcoal)
		end
		for _, z in { -4.2, 4.2 } do
			t:block("TrailerWindow", v(0.2, 1.4, 2.4), v(-2.75, 4.2, z), P.Glass, GLASS)
		end
		t:block("TrailerDoor", v(0.2, 3.6, 1.8), v(-2.75, 3.2, 0), P.Burgundy)
		IconModels.build(b.parent, "star", t:at(CFrame.new(-2.95, 3.9, 0) * CFrame.Angles(0, math.rad(-90), 0)), 0.32)
		t:block("TrailerStep", v(1.6, 0.6, 2.2), v(-3.6, 0.5, 0), P.Steel, METAL)
		for k = 0, 2 do
			t:block("TrailerAwning", v(2.4, 0.2, 2.6), CFrame.new(-4, 5.2, -2.6 + k * 2.6) * CFrame.Angles(0, 0, math.rad(-12)), if k % 2 == 0 then trailer.color else P.OffWhite)
		end
		-- A table and two chairs out front.
		local z = trailer.z + (if i == 1 then -1 else 1) * 0.5
		b:cylinder("PatioTable", 0.2, 2.4, v(-7.4, 2.1, z), P.OffWhite)
		b:cylinder("PatioTableLeg", 1.9, 0.3, v(-7.4, 1.15, z), P.Steel, METAL)
		for _, dz in { -2, 2 } do
			directorChair(b:sub(CFrame.new(-7.4, 0.2, z + dz) * CFrame.Angles(0, if dz < 0 then 0 else math.pi, 0)), nil)
		end
	end
	sign(b, v(-7.5, 0.2, -29), "STAR TRAILERS", P.Gold)
end

-- Food corner: a taco truck, a popcorn cart, and tables with umbrellas.
function TownSets.foodCorner(b: Builder)
	local truck = b:sub(v(8, 0.2, -2))
	truck:block("TruckBody", v(5.6, 6, 12), v(0, 4, 1), PINK)
	truck:block("TruckBand", v(5.7, 0.8, 12.1), v(0, 2, 1), P.OffWhite)
	truck:block("TruckCab", v(5.6, 4.6, 4), v(0, 3.3, -6.8), PINK)
	truck:block("TruckWindscreen", v(4.8, 1.8, 0.2), v(0, 4.6, -8.85), P.Glass, GLASS)
	truck:block("TruckBumper", v(5.8, 0.6, 0.4), v(0, 1.3, -8.9), P.Steel, METAL)
	for _, z in { -6.5, 4.5 } do
		truck:cylinder("TruckWheel", 0.9, 2, CFrame.new(-2.5, 1, z) * CFrame.Angles(0, 0, math.rad(90)), P.Charcoal)
	end
	truck:block("TruckHatch", v(0.2, 2.4, 6.4), v(-2.85, 4.6, 1.4), P.Navy)
	truck:block("TruckCounter", v(1, 0.3, 6.4), v(-3.3, 3.3, 1.4), P.OffWhite)
	for k = 0, 3 do
		truck:block("TruckAwning", v(2.4, 0.2, 1.6), CFrame.new(-3.8, 6.4, -1 + k * 1.6) * CFrame.Angles(0, 0, math.rad(-14)), if k % 2 == 0 then P.Gold else P.OffWhite)
	end
	local board = truck:block("TruckSign", v(0.4, 1.8, 8), v(-1.6, 8, 1), P.Gold)
	outlined(board, Enum.NormalId.Left, "TACOS", P.OffWhite, 4)
	truck:block("TruckSignBack", v(0.3, 1.8, 8), v(-1.2, 8, 1), PINK)

	-- The popcorn cart, with the menus' popcorn icon on top.
	local cart = b:sub(CFrame.new(-7.4, 0.2, -12) * CFrame.Angles(0, math.rad(90), 0))
	cart:block("CartBody", v(4, 2.4, 2.2), v(0, 2, 0), P.Carpet)
	cart:block("CartTrim", v(4.1, 0.4, 2.3), v(0, 3.3, 0), P.OffWhite)
	for _, x in { -1.4, 1.4 } do
		cart:cylinder("CartWheel", 0.4, 1.6, CFrame.new(x, 0.8, -1.2) * CFrame.Angles(math.rad(90), 0, 0), P.Charcoal)
	end
	cart:block("CartCanopy", v(4.6, 0.3, 2.8), v(0, 6.4, 0), P.OffWhite)
	for _, x in { -1.9, 1.9 } do
		cart:block("CartPole", v(0.2, 3, 0.2), v(x, 5, 0), P.Gold, METAL)
	end
	IconModels.build(b.parent, "popcorn", cart:at(v(0, 3.5, 0)), 0.75)

	-- Tables with umbrellas.
	for k, z in { 2, 10, 18 } do
		local t = b:sub(v(-7.4, 0.2, z))
		t:cylinder("CafeTable", 0.25, 2.6, v(0, 2.1, 0), P.OffWhite)
		t:cylinder("CafePole", 5.6, 0.25, v(0, 2.9, 0), P.Steel, METAL)
		t:cylinder("Umbrella", 0.5, 5.6, v(0, 5.6, 0), if k % 2 == 0 then TEAL else P.Gold, FABRIC)
		t:cylinder("UmbrellaTop", 0.5, 2.6, v(0, 6.05, 0), P.OffWhite, FABRIC)
		for _, dz in { -1.9, 1.9 } do
			t:cylinder("Stool", 1.2, 1.2, v(0, 0.6, dz), P.Carpet)
		end
	end
	sign(b, v(-7.5, 0.2, -29), "FOOD CORNER", PINK)
end

-- Sidewalk and skyline ---------------------------------------------------------------------------

-- A round poster column with a gold dome, its poster facing front.
function TownSets.posterColumn(b: Builder, title: string, color: Color3)
	b:cylinder("ColumnBase", 0.8, 3.4, v(0, 0.4, 0), P.Burgundy)
	b:cylinder("PosterColumn", 6.4, 2.8, v(0, 4, 0), P.Cream)
	b:cylinder("ColumnBand", 0.5, 3.1, v(0, 7.4, 0), P.Burgundy)
	b:cylinder("ColumnDome", 1, 2.4, v(0, 8.1, 0), P.Gold, METAL)
	b:ball("ColumnKnob", 0.8, v(0, 8.8, 0), P.Gold, METAL)
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
	local colors = { P.Carpet, P.Gold, PINK, P.OffWhite }
	local n = 0
	for x = -size.X / 2 + 1.5, size.X / 2 - 1.5, 3 do
		n += 1
		b:ball("Flower", 1, v(x, 0.6, if n % 2 == 0 then -1 else 1), colors[n % #colors + 1])
	end
end

-- Street life (pass 2) ---------------------------------------------------------------------------

-- A rounded vintage convertible, about 4.4 wide and 9.6 long, nose toward -Z.
function TownSets.car(b: Builder, color: Color3)
	local chrome = Color3.fromRGB(215, 218, 225)
	b:block("CarBody", v(4.2, 1.5, 9), v(0, 1.45, 0), color)
	b:block("CarHood", v(3.8, 0.5, 3.2), v(0, 2.35, -2.6), color)
	b:block("CarTrunk", v(3.8, 0.5, 2.2), v(0, 2.35, 3.2), color)
	for _, z in { -2.9, 2.9 } do
		b:block("CarFender", v(4.5, 0.9, 2.6), v(0, 1.75, z), color)
	end
	b:block("CarSeats", v(3.4, 1, 2.6), v(0, 2.4, 0.6), P.OffWhite, FABRIC)
	b:block("CarWindscreen", v(3.6, 1.3, 0.15), CFrame.new(0, 3.1, -0.95) * CFrame.Angles(math.rad(-20), 0, 0), P.Glass, GLASS)
	b:block("CarStripe", v(4.25, 0.25, 9.05), v(0, 1.4, 0), P.OffWhite)
	for _, z in { -4.6, 4.6 } do
		b:block("CarBumper", v(4.4, 0.45, 0.3), v(0, 1, z), chrome, METAL)
	end
	for _, x in { -1.4, 1.4 } do
		b:cylinder("CarHeadlight", 0.15, 0.7, CFrame.new(x, 1.75, -4.55) * CFrame.Angles(math.rad(90), 0, 0), P.Light, NEON)
	end
	for _, x in { -1.95, 1.95 } do
		for _, z in { -2.9, 2.9 } do
			b:cylinder("CarWheel", 0.6, 1.7, CFrame.new(x, 0.85, z) * CFrame.Angles(0, 0, math.rad(90)), P.Charcoal)
			b:cylinder("CarHubcap", 0.62, 0.7, CFrame.new(x, 0.85, z) * CFrame.Angles(0, 0, math.rad(90)), chrome, METAL)
		end
	end
end

-- A bus stop: a roof on two posts, a bench, a back panel with a poster, and a round sign.
function TownSets.busStop(b: Builder)
	b:block("ShelterRoof", v(8.4, 0.4, 3.6), v(0, 7.2, 0.2), P.Burgundy)
	b:block("ShelterRoofTrim", v(8.6, 0.25, 3.8), v(0, 6.9, 0.2), P.Gold, METAL)
	for _, x in { -3.9, 3.9 } do
		b:block("ShelterPost", v(0.35, 6.8, 0.35), v(x, 3.4, -1.3), P.Charcoal, METAL)
	end
	b:block("ShelterBack", v(8, 5.6, 0.3), v(0, 3.6, 1.6), P.Glass, GLASS).Transparency = 0.4
	local poster = b:block("ShelterPoster", v(3, 4.2, 0.1), v(1.8, 3.6, 1.42), Color3.fromRGB(110, 190, 80))
	local label = Build.sign(poster, Enum.NormalId.Front, "MONSTER\nISLAND\nNOW SHOWING", P.OffWhite)
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = 2
	stroke.Parent = label
	b:block("ShelterBench", v(4.6, 0.35, 1.2), v(-1.6, 1.5, 0.8), P.Wood)
	for _, x in { -3.4, 0.2 } do
		b:block("ShelterBenchLeg", v(0.3, 1.3, 1), v(x, 0.65, 0.8), P.Charcoal, METAL)
	end
	b:cylinder("BusSignPole", 7.5, 0.3, v(5.2, 3.75, -1.3), P.Charcoal, METAL)
	local sign = b:cylinder("BusSign", 0.3, 2.2, CFrame.new(5.2, 7.6, -1.3) * CFrame.Angles(math.rad(90), 0, 0), P.Blue)
	Build.sign(sign, Enum.NormalId.Top, "BUS", P.OffWhite)
end

function TownSets.hydrant(b: Builder)
	b:cylinder("HydrantBase", 0.3, 1.3, v(0, 0.15, 0), P.Carpet)
	b:cylinder("Hydrant", 1.6, 0.9, v(0, 1.1, 0), P.Carpet)
	b:ball("HydrantTop", 0.95, v(0, 1.9, 0), P.Carpet)
	b:cylinder("HydrantNozzle", 0.9, 0.4, CFrame.new(0, 1.3, 0) * CFrame.Angles(0, 0, math.rad(90)), P.Gold, METAL)
end

function TownSets.trashBin(b: Builder)
	b:cylinder("Bin", 2.2, 1.6, v(0, 1.1, 0), Color3.fromRGB(56, 140, 70))
	b:cylinder("BinBand", 0.3, 1.7, v(0, 1.8, 0), P.Gold, METAL)
	b:cylinder("BinLid", 0.3, 1.8, v(0, 2.35, 0), P.Charcoal, METAL)
end

-- A newspaper stand: a green kiosk with stacks of papers and a striped roof.
function TownSets.newsStand(b: Builder)
	b:block("NewsBody", v(4.4, 3.4, 2.6), v(0, 1.7, 0), Color3.fromRGB(56, 140, 70))
	b:block("NewsCounter", v(4.6, 0.3, 1.2), v(0, 2.3, -1.8), P.Wood)
	for i = 0, 2 do
		b:block("NewsPapers", v(1.1, 0.4, 0.9), v(-1.4 + i * 1.4, 2.65, -1.8), P.OffWhite)
	end
	for k = 0, 3 do
		b:block("NewsRoof", v(1.2, 0.25, 3.6), CFrame.new(-1.8 + k * 1.2, 4.5, -0.5) * CFrame.Angles(math.rad(-12), 0, 0), if k % 2 == 0 then P.Carpet else P.OffWhite)
	end
	local board = b:block("NewsSign", v(4, 0.9, 0.2), v(0, 3.2, -1.35), P.Navy)
	Build.sign(board, Enum.NormalId.Front, "DAILY STAR", P.Gold)
end

return TownSets
