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

-- The outer ring (pass 3) ------------------------------------------------------------------------
-- Two big walkable areas out through gaps in the hedge (MapModels.Layout.sideGap): Dusty Gulch, a
-- western film town behind the front row, and Starlight Park behind the back row. Chunky shapes,
-- bold colors and thick trims, like the Roblox front page. Each is laid out with its entrance at
-- z = 0 and the area running toward +Z.

local WATER = Color3.fromRGB(64, 196, 240)
local WATER_LIGHT = Color3.fromRGB(130, 222, 250)
local SAND = Color3.fromRGB(240, 205, 140)
local DUST = Color3.fromRGB(222, 170, 110)
local ROCK = Color3.fromRGB(214, 124, 72)
local STONE = Color3.fromRGB(176, 182, 194)
local CACTUS = Color3.fromRGB(70, 175, 80)
local BLOSSOM = Color3.fromRGB(255, 160, 205)
local DUCK = Color3.fromRGB(255, 214, 60)

local function shade(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

local function tint(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(1, 1, 1), amount)
end

-- Dusty Gulch ------------------------------------------------------------------------------------

type WesternInfo = { title: string, w: number, h: number, color: Color3, balcony: boolean? }

-- A false-front western building, about w wide and 15 deep, front toward -Z: board front in two
-- shades, thick corner posts, a stepped top, a big outlined sign, a framed door and windows, and
-- a porch roof (or a balcony with a railing) over the boardwalk.
local function westernBuilding(b: Builder, info: WesternInfo)
	local w, h, color = info.w, info.h, info.color
	local dark = shade(color, 0.15)
	local depth = 14
	b:block("WesternBox", v(w - 0.4, h * 0.72, depth), v(0, h * 0.36, depth / 2 + 0.4), dark)
	b:block("WesternRoof", v(w + 0.4, 0.8, depth + 0.4), v(0, h * 0.72 + 0.4, depth / 2 + 0.4), P.Bark)
	local boards = 4
	for i = 0, boards - 1 do
		local bh = h / boards
		b:block("WesternBoard", v(w, bh, 0.8), v(0, bh * (i + 0.5), 0), if i % 2 == 0 then color else dark)
	end
	b:block("WesternTrim", v(w + 1, 0.8, 1.2), v(0, h, 0), P.Cream)
	b:block("WesternCrown", v(w * 0.5, 2.6, 0.8), v(0, h + 1.7, 0), color)
	b:block("WesternCap", v(w * 0.5 + 1, 0.8, 1.2), v(0, h + 3.2, 0), P.Cream)
	for _, x in { -1, 1 } do
		b:block("WesternCorner", v(1.4, h + 0.4, 1.4), v(x * w / 2, (h + 0.4) / 2, 0), P.Bark)
	end
	local signY = h - 3.2
	b:block("WesternSignFrame", v(w - 3, 4, 0.5), v(0, signY, -0.55), P.Bark)
	local board = b:block("WesternSign", v(w - 4, 3.2, 0.4), v(0, signY, -0.75), P.Cream)
	outlined(board, Enum.NormalId.Front, info.title, color, 3)

	b:block("WesternDoorFrame", v(4.6, 7.6, 0.5), v(0, 3.8, -0.55), P.Cream)
	b:block("WesternDoor", v(3.6, 7, 0.5), v(0, 3.5, -0.65), P.Bark)
	b:ball("WesternKnob", 0.5, v(1.2, 3.4, -0.95), P.Gold, METAL)
	local function window(x: number, y: number)
		b:block("WesternWindowFrame", v(4, 4, 0.5), v(x, y, -0.55), P.Cream)
		b:block("WesternWindow", v(3.2, 3.2, 0.5), v(x, y, -0.65), P.Navy, GLASS)
		b:block("WesternWindowBar", v(0.35, 3.2, 0.6), v(x, y, -0.7), P.Cream)
		b:block("WesternWindowBar", v(3.2, 0.35, 0.6), v(x, y, -0.7), P.Cream)
	end
	for _, x in { -w / 2 + 3.6, w / 2 - 3.6 } do
		window(x, 4.6)
	end

	for _, x in { -1, 1 } do
		b:block("PorchPost", v(0.9, 8.4, 0.9), v(x * (w / 2 - 0.2), 4.2, -5.2), P.Bark)
	end
	if info.balcony then
		b:block("Balcony", v(w + 1, 0.8, 5.6), v(0, 8.8, -2.8), P.Wood)
		b:block("BalconyRail", v(w + 1, 0.6, 0.6), v(0, 11.8, -5.3), P.Cream)
		local count = math.floor(w / 2)
		for i = 0, count do
			b:block("BalconyBaluster", v(0.45, 2.6, 0.45), v(-w / 2 + i * w / count, 10.5, -5.3), P.Wood)
		end
		for _, x in { -w / 4, w / 4 } do
			window(x, 12.8)
		end
	else
		b:block("PorchRoof", v(w + 1.2, 0.7, 5.8), CFrame.new(0, 8.8, -2.8) * CFrame.Angles(math.rad(-10), 0, 0), P.Cream)
		b:block("PorchRoofEdge", v(w + 1.4, 0.5, 0.5), v(0, 8.3, -5.6), color)
	end
end

local function cactus(b: Builder, height: number)
	b:block("Cactus", v(2, height, 2), v(0, height / 2, 0), CACTUS)
	b:block("CactusTop", v(1.4, 0.6, 1.4), v(0, height + 0.3, 0), tint(CACTUS, 0.2))
	b:block("CactusArm", v(2.2, 1.3, 1.3), v(2, height * 0.45, 0), CACTUS)
	b:block("CactusArm", v(1.3, 3, 1.3), v(2.7, height * 0.45 + 2, 0), CACTUS)
	b:block("CactusArm", v(1.8, 1.2, 1.2), v(-1.8, height * 0.65, 0), CACTUS)
	b:block("CactusArm", v(1.2, 2.2, 1.2), v(-2.3, height * 0.65 + 1.5, 0), CACTUS)
	b:block("CactusFlower", v(0.9, 0.6, 0.9), v(0, height + 0.9, 0), PINK)
end

local function barrel(b: Builder)
	b:cylinder("Barrel", 2.6, 2, v(0, 1.3, 0), P.Wood)
	for _, y in { 0.5, 2.1 } do
		b:cylinder("BarrelBand", 0.25, 2.1, v(0, y, 0), P.Charcoal, METAL)
	end
end

local function hayBale(b: Builder)
	b:block("HayBale", v(3.4, 2, 2.2), v(0, 1, 0), SAND)
	for _, x in { -0.9, 0.9 } do
		b:block("HayString", v(0.2, 2.05, 2.25), v(x, 1, 0), P.Bark)
	end
end

-- A blocky mesa rock: three stacked slabs, each smaller than the last.
local function mesa(b: Builder, size: number)
	local y = 0
	for i, k in { 1, 0.75, 0.5 } do
		local h = size * 0.35
		b:block("Mesa", v(size * k, h, size * k * 0.8), v((i - 2) * size * 0.06, y + h / 2, 0), if i % 2 == 0 then shade(ROCK, 0.1) else ROCK)
		y += h
	end
end

local function wagon(b: Builder)
	b:block("WagonBed", v(5, 2, 9), v(0, 2.4, 0), P.Wood)
	b:block("WagonTrim", v(5.2, 0.4, 9.2), v(0, 3.5, 0), P.Carpet)
	b:cylinder("WagonCover", 8, 5.4, CFrame.new(0, 3.6, 0) * CFrame.Angles(math.rad(90), 0, 0), P.OffWhite, FABRIC)
	for _, x in { -2.8, 2.8 } do
		for _, z in { -3, 3 } do
			b:cylinder("WagonWheel", 0.5, 3.4, CFrame.new(x, 1.7, z) * CFrame.Angles(0, 0, math.rad(90)), P.Bark)
			b:cylinder("WagonHub", 0.6, 1, CFrame.new(x, 1.7, z) * CFrame.Angles(0, 0, math.rad(90)), P.Gold, METAL)
		end
	end
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

	-- The welcome arch.
	for _, x in { -16, 16 } do
		b:block("ArchLog", v(2.2, 17, 2.2), v(x, 8.5, 6), P.Bark)
		b:block("ArchLogCap", v(2.8, 0.8, 2.8), v(x, 17.4, 6), P.Wood)
	end
	b:block("ArchBeam", v(36, 2, 2.2), v(0, 15.6, 6), P.Wood)
	for _, x in { -6, 6 } do
		b:block("ArchChain", v(0.3, 2.4, 0.3), v(x, 13.4, 6), P.Charcoal, METAL)
	end
	b:block("ArchSignFrame", v(22, 5.4, 0.6), v(0, 10, 6), P.Bark)
	local archSign = b:block("ArchSign", v(20.6, 4.4, 0.5), v(0, 10, 5.8), Color3.fromRGB(196, 70, 50))
	outlined(archSign, Enum.NormalId.Front, "DUSTY GULCH", P.Gold, 4)
	outlined(archSign, Enum.NormalId.Back, "DUSTY GULCH", P.Gold, 4)
	IconModels.build(b.parent, "star", b:at(CFrame.new(0, 19, 6)), 0.8)

	-- The buildings, fronts on the boardwalks facing the street.
	local west: { WesternInfo } = {
		{ title = "SALOON", w = 20, h = 20, color = Color3.fromRGB(205, 70, 50), balcony = true },
		{ title = "BANK", w = 18, h = 16, color = Color3.fromRGB(60, 130, 215) },
		{ title = "BARBER", w = 16, h = 14, color = Color3.fromRGB(235, 115, 165) },
		{ title = "HOTEL", w = 20, h = 20, color = Color3.fromRGB(145, 95, 205), balcony = true },
	}
	local east: { WesternInfo } = {
		{ title = "SHERIFF", w = 18, h = 15, color = Color3.fromRGB(240, 175, 50) },
		{ title = "GENERAL STORE", w = 22, h = 16, color = Color3.fromRGB(100, 175, 75) },
		{ title = "POST OFFICE", w = 18, h = 14, color = TEAL },
		{ title = "BLACKSMITH", w = 18, h = 15, color = Color3.fromRGB(150, 105, 80) },
	}
	for i = 1, 4 do
		local z = 10 + i * 26
		westernBuilding(b:sub(CFrame.new(-20, 0.8, z) * CFrame.Angles(0, math.rad(-90), 0)), west[i])
		westernBuilding(b:sub(CFrame.new(20, 0.8, z) * CFrame.Angles(0, math.rad(90), 0)), east[i])
	end
	-- Saloon swing doors; the sheriff's star and wanted posters.
	-- (The first building on each side stands at z = 36, its front at |x| = 19.6.)
	for _, z in { 35, 37 } do
		b:block("SwingDoor", v(0.3, 3, 1.8), v(-18.7, 4.6, z), P.Gold)
	end
	b:block("SheriffStar", v(0.5, 2.4, 2.4), CFrame.new(19.2, 17.3, 36) * CFrame.Angles(math.rad(45), 0, 0), P.Gold, METAL)
	for _, z in { 27.2, 44.8 } do
		local poster = b:block("WantedPoster", v(0.2, 2.8, 2.2), v(14.25, 5.6, z), P.Cream)
		Build.sign(poster, Enum.NormalId.Left, "WANTED", P.Burgundy)
	end

	-- Street life: hitching rails, troughs, barrels, crates and hay along the boardwalks.
	for _, s in { -1, 1 } do
		for _, z in { 48, 100 } do
			b:block("HitchRail", v(0.5, 0.5, 8), v(s * 12.6, 2.8, z), P.Wood)
			for _, dz in { -3.6, 3.6 } do
				b:block("HitchPost", v(0.6, 3, 0.6), v(s * 12.6, 1.5, z + dz), P.Bark)
			end
		end
		b:block("Trough", v(2.2, 1.6, 6), v(s * 12.6, 0.9, 74), P.Bark)
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
	for _, at in { v(-4, 0.2, 60), v(6, 0.2, 112) } do
		b:ball("Tumbleweed", 2.6, at + v(0, 1.3, 0), Color3.fromRGB(190, 150, 95))
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
	corral:block("Trough", v(6, 1.6, 2.2), v(-4, 0.8, -8), P.Bark)
	corral:block("TroughWater", v(5.4, 0.1, 1.6), v(-4, 1.65, -8), WATER)

	-- A covered wagon, west behind the buildings, and a water tank on stilts.
	wagon(b:sub(CFrame.new(-50, 0.1, 58) * CFrame.Angles(0, math.rad(20), 0)))
	local tank = b:sub(v(-48, 0.1, 104))
	for _, x in { -4, 4 } do
		for _, z in { -4, 4 } do
			tank:block("TankLeg", v(1.2, 16, 1.2), v(x, 8, z), P.Bark)
		end
	end
	tank:block("TankBrace", v(9.2, 0.6, 0.6), v(0, 8, -4), P.Wood)
	tank:block("TankBrace", v(9.2, 0.6, 0.6), v(0, 8, 4), P.Wood)
	tank:cylinder("Tank", 9, 12, v(0, 20.5, 0), P.Wood)
	for _, y in { 17, 24 } do
		tank:cylinder("TankBand", 0.5, 12.3, v(0, y, 0), P.Charcoal, METAL)
	end
	tank:cylinder("TankRoof", 1.2, 13, v(0, 25.6, 0), P.Carpet)
	tank:cylinder("TankRoof", 1.2, 8, v(0, 26.8, 0), P.Carpet)

	-- Cacti and mesas round the edges.
	local cacti = { v(-34, 0, 20), v(34, 0, 22), v(-62, 0, 30), v(-30, 0, 132), v(36, 0, 140), v(70, 0, 104), v(-72, 0, 80), v(52, 0, 30) }
	for i, at in cacti do
		cactus(b:sub(CFrame.new(at) * CFrame.Angles(0, math.rad(i * 47), 0)), 6 + (i % 3) * 2)
	end
	for i, info in { { at = v(-70, 0, 130), size = 22 }, { at = v(72, 0, 135), size = 26 }, { at = v(-74, 0, 18), size = 16 }, { at = v(76, 0, 24), size = 18 } } do
		mesa(b:sub(CFrame.new(info.at) * CFrame.Angles(0, math.rad(i * 33), 0)), info.size)
	end

	-- At the far end, a film crew shoots a showdown: a camera on a crane, a light and chairs.
	local crew = b:sub(CFrame.new(0, 0.2, 140) * CFrame.Angles(0, math.pi, 0))
	crew:block("CraneDolly", v(4, 1.2, 6), v(0, 0.8, 0), P.Charcoal, METAL)
	crew:cylinder("CranePost", 6, 1, v(0, 4.4, 0), P.Steel, METAL)
	local arm = CFrame.new(0, 7.4, 0) * CFrame.Angles(math.rad(-14), 0, 0)
	crew:block("CraneArm", v(0.8, 0.8, 14), arm * CFrame.new(0, 0, -3), P.Gold, METAL)
	crew:block("CraneWeight", v(2, 2, 2), arm * CFrame.new(0, -0.6, 4), P.Charcoal, METAL)
	crew:block("CraneCamera", v(2, 1.8, 2.6), arm * CFrame.new(0, -1.2, -10), P.Charcoal)
	crew:cylinder("CraneLens", 1.2, 1.1, arm * CFrame.new(0, -1.2, -11.8) * CFrame.Angles(math.rad(90), 0, 0), P.Steel, METAL)
	for _, x in { -7, 7 } do
		directorChair(crew:sub(CFrame.new(x, 0, 4) * CFrame.Angles(0, math.pi, 0)), if x < 0 then "DIRECTOR" else nil)
	end
	lightStand(crew:sub(CFrame.new(-10, 0, -2) * CFrame.Angles(0, math.rad(20), 0)), P.Light)
end

-- Starlight Park ---------------------------------------------------------------------------------

local function voxelTree(b: Builder, height: number, color: Color3)
	b:block("TreeTrunk", v(1.8, height, 1.8), v(0, height / 2, 0), P.Bark)
	b:block("TreeTop", v(8, 6, 8), v(0, height + 1.5, 0), color, GRASS)
	b:block("TreeTop", v(5.6, 4, 5.6), v(0.8, height + 5.5, -0.6), tint(color, 0.15), GRASS)
	b:block("TreeTop", v(5, 4, 5), v(-3, height, 2.4), shade(color, 0.08), GRASS)
end

local function parkBench(b: Builder)
	b:block("BenchSeat", v(6, 0.6, 2), v(0, 1.5, 0), P.Wood)
	b:block("BenchBack", v(6, 1.8, 0.5), v(0, 2.7, 0.8), P.Wood)
	for _, x in { -2.5, 2.5 } do
		b:block("BenchLeg", v(0.6, 1.2, 2), v(x, 0.6, 0), P.Charcoal, METAL)
	end
end

local function parkLamp(b: Builder)
	b:block("LampFoot", v(1.4, 0.6, 1.4), v(0, 0.3, 0), P.Charcoal, METAL)
	b:cylinder("LampPole", 8, 0.5, v(0, 4.4, 0), P.Charcoal, METAL)
	b:ball("LampBulb", 1.6, v(0, 8.9, 0), P.Light, NEON)
	b:block("LampCap", v(1.8, 0.4, 1.8), v(0, 9.8, 0), P.Charcoal, METAL)
end

local function duck(b: Builder, scale: number)
	local d = b
	d:block("DuckBody", v(1.8, 1.4, 2.4) * scale, v(0, 0.7, 0) * scale, DUCK)
	d:block("DuckTail", v(1, 0.6, 0.8) * scale, v(0, 1.3, 1.3) * scale, DUCK)
	d:block("DuckHead", v(1.3, 1.3, 1.3) * scale, v(0, 1.9, -0.9) * scale, DUCK)
	d:block("DuckBeak", v(0.8, 0.35, 0.7) * scale, v(0, 1.75, -1.85) * scale, Color3.fromRGB(255, 140, 40))
	for _, x in { -0.66, 0.66 } do
		d:block("DuckEye", v(0.1, 0.3, 0.3) * scale, v(x, 2.1, -1.1) * scale, P.Charcoal)
	end
end

local function picnicBlanket(b: Builder)
	for i = 0, 2 do
		for k = 0, 2 do
			b:block("Blanket", v(2.4, 0.08, 2.4), v((i - 1) * 2.4, 0.24, (k - 1) * 2.4), if (i + k) % 2 == 0 then P.Carpet else P.OffWhite, FABRIC)
		end
	end
	b:block("Basket", v(1.8, 1.2, 1.2), v(0.8, 0.8, 0.4), P.Wood)
	b:block("BasketHandle", v(1.4, 0.3, 0.3), v(0.8, 1.6, 0.4), P.Bark)
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

	-- The entrance arch.
	for _, x in { -10, 10 } do
		b:block("ParkPillar", v(3.4, 11, 3.4), v(x, 5.5, 4), P.Cream)
		b:block("ParkPillarCap", v(4, 1, 4), v(x, 11.5, 4), P.DarkGreen)
		b:ball("ParkPillarBall", 1.8, v(x, 12.9, 4), P.Gold, METAL)
	end
	b:block("ParkArchBeam", v(24, 2, 2.4), v(0, 11.5, 4), P.DarkGreen)
	b:block("ParkSignFrame", v(19, 4.4, 0.6), v(0, 15, 4), P.Gold, METAL)
	local sign = b:block("ParkSign", v(18, 3.6, 0.6), v(0, 15, 3.8), P.Green)
	outlined(sign, Enum.NormalId.Front, "STARLIGHT PARK", P.OffWhite, 4)
	outlined(sign, Enum.NormalId.Back, "STARLIGHT PARK", P.OffWhite, 4)
	IconModels.build(b.parent, "star", b:at(CFrame.new(0, 19, 4)), 0.8)

	-- The fountain plaza where the paths cross.
	local plaza = v(0, 0, 50)
	b:cylinder("FountainPlaza", 0.24, 26, plaza + v(0, 0.12, 0), P.Paving)
	b:cylinder("FountainPlazaRing", 0.28, 22, plaza + v(0, 0.14, 0), P.Cream)
	b:cylinder("FountainPlazaInner", 0.3, 20, plaza + v(0, 0.15, 0), P.Paving)
	b:cylinder("FountainRim", 1.6, 12, plaza + v(0, 0.8, 0), STONE)
	b:cylinder("FountainWater", 1.62, 10.4, plaza + v(0, 0.82, 0), WATER)
	b:cylinder("FountainColumn", 3.4, 1.6, plaza + v(0, 2.5, 0), STONE)
	b:cylinder("FountainBowl", 0.8, 5, plaza + v(0, 4.2, 0), STONE)
	b:cylinder("FountainBowlWater", 0.82, 4, plaza + v(0, 4.25, 0), WATER_LIGHT)
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
	voxelTree(b:sub(island + v(0, 1, 0)), 8, BLOSSOM)
	-- The bridge from the east shore to the island, with fence rails like a ranch fence.
	local fromX, toX = pond.X + radius + 3, island.X + 7
	local bridgeLength = fromX - toX
	local mid = v((fromX + toX) / 2, 0, island.Z)
	b:block("Bridge", v(bridgeLength, 0.8, 5), mid + v(0, 1.8, 0), P.Wood)
	for i = 0, math.floor(bridgeLength / 2.5) do
		b:block("BridgePlank", v(0.3, 0.1, 5), mid + v(-bridgeLength / 2 + i * 2.5, 2.25, 0), P.Bark)
	end
	for _, s in { -1, 1 } do
		b:block("BridgeRail", v(bridgeLength, 0.5, 0.5), mid + v(0, 4.2, s * 2.3), P.Bark)
		for i = 0, 4 do
			b:block("BridgePost", v(0.7, 3, 0.7), mid + v(-bridgeLength / 2 + i * bridgeLength / 4, 2.9, s * 2.3), P.Bark)
		end
	end
	b:wedge("BridgeRamp", v(5, 2.2, 3), CFrame.new(fromX + 1.5, 1.1, island.Z) * CFrame.Angles(0, math.rad(-90), 0), P.Wood)
	for _, at in { v(8, 0, -10), v(-14, 0, -12), v(12, 0, 12), v(-4, 0, 16), v(16, 0, -2) } do
		b:cylinder("LilyPad", 0.12, 3, pond + at + v(0, 0.56, 0), P.DarkGreen)
	end
	b:block("LilyFlower", v(1, 0.8, 1), pond + v(12, 1, 12), PINK)
	duck(b:sub(CFrame.new(pond + v(10, 0.5, -4)) * CFrame.Angles(0, math.rad(30), 0)), 1.6)
	duck(b:sub(CFrame.new(pond + v(13, 0.5, -1)) * CFrame.Angles(0, math.rad(40), 0)), 0.9)
	duck(b:sub(CFrame.new(pond + v(-16, 0.5, -10)) * CFrame.Angles(0, math.rad(200), 0)), 1.4)

	-- The bandstand, east of the main path.
	local stand = b:sub(v(60, 0, 86))
	stand:block("BandstandBase", v(18, 1.6, 18), v(0, 0.8, 0), P.Cream)
	stand:block("BandstandFloor", v(16.4, 0.3, 16.4), v(0, 1.75, 0), P.Wood)
	stand:block("BandstandStep", v(6, 0.8, 2), v(0, 0.4, -10), P.Cream)
	for _, x in { -7.4, 7.4 } do
		for _, z in { -7.4, 7.4 } do
			stand:block("BandstandPost", v(1, 8, 1), v(x, 5.6, z), P.OffWhite)
		end
	end
	for _, side in { { v(0, 0, 7.4), v(15, 0.5, 0.5) }, { v(-7.4, 0, 0), v(0.5, 0.5, 15) }, { v(7.4, 0, 0), v(0.5, 0.5, 15) } } do
		stand:block("BandstandRail", side[2], side[1] + v(0, 4, 0), P.OffWhite)
	end
	stand:block("BandstandRoof", v(19, 1, 19), v(0, 10, 0), P.Carpet)
	stand:block("BandstandRoof", v(14, 1, 14), v(0, 11, 0), P.OffWhite)
	stand:block("BandstandRoof", v(9, 1, 9), v(0, 12, 0), P.Carpet)
	stand:block("BandstandRoof", v(4, 1, 4), v(0, 13, 0), P.OffWhite)
	stand:ball("BandstandTop", 2, v(0, 14.3, 0), P.Gold, METAL)

	-- The open-air movie screen at the far end, with picnic blankets on the lawn in front.
	local screen = b:sub(v(0, 0, 112))
	for _, x in { -24, 24 } do
		screen:block("ScreenPost", v(2.4, 30, 2.4), v(x, 15, 1), P.Charcoal, METAL)
	end
	screen:block("ScreenFrame", v(46, 24, 1), v(0, 17, 1), P.Charcoal)
	local film = screen:block("Screen", v(43, 21, 0.4), v(0, 17, 0.4), P.OffWhite)
	outlined(film, Enum.NormalId.Front, "NOW SHOWING\nHOLLYWOOD RNG", P.Gold, 5)
	local marquee = screen:block("ScreenMarquee", v(30, 3.6, 0.8), v(0, 31, 1), P.Carpet)
	outlined(marquee, Enum.NormalId.Front, "MOVIES UNDER THE STARS", P.Gold, 3)
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
		v(88, 0, 110), v(34, 0, 112), v(28, 0, 72), v(-20, 0, 70),
	}
	for i, at in trees do
		local color = if i % 4 == 0 then BLOSSOM elseif i % 2 == 0 then P.DarkGreen else P.Green
		voxelTree(b:sub(CFrame.new(at) * CFrame.Angles(0, math.rad(i * 37), 0)), 7 + (i % 3) * 1.5, color)
	end
	for _, info in { { at = v(-16, 0, 38), size = v(10, 0, 6) }, { at = v(16, 0, 38), size = v(10, 0, 6) }, { at = v(-16, 0, 62), size = v(10, 0, 6) }, { at = v(16, 0, 62), size = v(10, 0, 6) }, { at = v(40, 0, 60), size = v(14, 0, 6) } } do
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
