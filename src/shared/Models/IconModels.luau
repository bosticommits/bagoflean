--!strict
-- Little 3D objects for the menu buttons (clapperboard, gift, popcorn, dice...), built from parts
-- like the rest of the game so they need no uploaded images. The client shows them in
-- ViewportFrames (src/client/Icon3D.luau); art/preview can render them too.
-- Each icon is built around its own origin, roughly 3-4 studs across, front facing -Z.
local Build = require(script.Parent.Build)
local LotModels = require(script.Parent.LotModels)

type Builder = Build.Builder

local P = Build.Palette
local NEON = Enum.Material.Neon
local METAL = Enum.Material.Metal

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- Faces of a die point the cylinder's flat side outward: Y faces need no turn, Z faces turn about X.
local FACE_Z = CFrame.Angles(math.rad(90), 0, 0)
local FACE_X = CFrame.Angles(0, 0, math.rad(90))

local BUILDERS: { [string]: (b: Builder) -> () } = {}

-- Clapperboard: the board with a striped clapper lifted open on top.
function BUILDERS.clapper(b: Builder)
	b:block("Board", v(3.4, 2.4, 0.35), v(0, 1.2, 0), P.Charcoal)
	for i = 0, 2 do
		b:block("Line", v(2.6, 0.12, 0.05), v(0, 0.5 + i * 0.5, -0.19), P.OffWhite)
	end
	b:block("Star", v(0.5, 0.5, 0.06), v(1.2, 1.9, -0.19), P.Gold, NEON)
	-- Fixed striped bar along the top of the board.
	for i = 0, 5 do
		b:block("Stripe", v(0.57, 0.45, 0.4), v(-1.43 + i * 0.57, 2.62, 0), if i % 2 == 0 then P.OffWhite else P.Charcoal)
	end
	-- Clapper arm, hinged at the left and lifted 22 degrees.
	local arm = b:sub(CFrame.new(-1.7, 2.85, 0) * CFrame.Angles(0, 0, math.rad(22)))
	for i = 0, 5 do
		arm:block("Clap", v(0.57, 0.45, 0.4), v(0.28 + i * 0.57, 0.22, 0), if i % 2 == 0 then P.Charcoal else P.OffWhite)
	end
	b:cylinder("Hinge", 0.5, 0.3, CFrame.new(-1.7, 2.85, 0) * FACE_Z, P.Gold, METAL)
end

-- A white die showing 5 on the front, 1 (red) on top and 3 on the side.
function BUILDERS.dice(b: Builder)
	local S = 2.6
	local h = S / 2
	local die = b:sub(CFrame.new(0, h, 0) * CFrame.Angles(0, math.rad(-12), 0))
	die:block("Die", v(S, S, S), v(0, 0, 0), P.OffWhite)
	local pip = 0.5
	local off = 0.7
	local function front(x: number, y: number)
		die:cylinder("Pip", 0.06, pip, CFrame.new(x, y, -h - 0.02) * FACE_Z, P.Charcoal)
	end
	front(0, 0)
	front(-off, -off)
	front(off, off)
	front(-off, off)
	front(off, -off)
	die:cylinder("Pip", 0.06, pip * 1.3, v(0, h + 0.02, 0), P.Carpet)
	for i = -1, 1 do
		die:cylinder("Pip", 0.06, pip, CFrame.new(h + 0.02, i * off, -i * off) * FACE_X, P.Charcoal)
	end
end

-- Chunky green up arrow, stepped like the voxel style of the world.
function BUILDERS.arrow(b: Builder)
	local green = rgb(76, 214, 84)
	b:block("Shaft", v(1.2, 1.9, 0.9), v(0, 0.95, 0), green)
	local widths = { 3.2, 2.4, 1.6, 0.8 }
	for i, w in widths do
		b:block("Head", v(w, 0.45, 0.9), v(0, 1.9 + (i - 0.5) * 0.45, 0), green)
	end
	b:block("Shine", v(0.3, 1.5, 0.05), v(-0.3, 1, -0.47), rgb(190, 255, 190), NEON)
end

-- Purple gift box with a gold ribbon and bow.
function BUILDERS.gift(b: Builder)
	local box = rgb(150, 70, 235)
	local lid = rgb(178, 106, 255)
	b:block("Box", v(2.6, 2.1, 2.6), v(0, 1.05, 0), box)
	b:block("Lid", v(2.9, 0.6, 2.9), v(0, 2.4, 0), lid)
	b:block("RibbonX", v(0.55, 2.75, 2.95), v(0, 1.4, 0), P.Gold, METAL)
	b:block("RibbonZ", v(2.95, 2.75, 0.55), v(0, 1.4, 0), P.Gold, METAL)
	for _, side in { -1, 1 } do
		b:block("Bow", v(0.9, 0.7, 0.35), CFrame.new(side * 0.5, 3.0, 0) * CFrame.Angles(0, 0, math.rad(side * -30)), P.Gold, METAL)
	end
	b:ball("Knot", 0.5, v(0, 2.85, 0), P.Gold, METAL)
end

-- Red and white striped popcorn bucket, heaped with popcorn.
function BUILDERS.popcorn(b: Builder)
	b:cylinder("Bucket", 2.6, 2.3, v(0, 1.3, 0), P.Carpet)
	for i = 0, 7 do
		local a = math.rad(i * 45 + 22.5)
		b:block("Stripe", v(0.42, 2.6, 0.1), CFrame.new(1.13 * math.sin(a), 1.3, -1.13 * math.cos(a)) * CFrame.Angles(0, -a, 0), P.OffWhite)
	end
	b:cylinder("Rim", 0.2, 2.45, v(0, 2.6, 0), P.OffWhite)
	local kernels = {
		v(0, 3.2, 0), v(-0.6, 2.9, -0.4), v(0.6, 2.95, -0.3), v(0.1, 2.9, -0.7), v(-0.5, 3.05, 0.5),
		v(0.55, 3.0, 0.5), v(-0.3, 3.4, -0.2), v(0.35, 3.35, 0.05), v(-0.9, 2.8, 0.1), v(0.9, 2.8, 0),
	}
	for i, p in kernels do
		b:ball("Kernel", 0.75, p, if i % 3 == 0 then rgb(255, 228, 140) else rgb(255, 248, 225))
	end
end

-- Golden ticket, tilted, with red ends and stub perforation.
function BUILDERS.ticket(b: Builder)
	local t = b:sub(CFrame.new(0, 1.6, 0) * CFrame.Angles(0, 0, math.rad(14)))
	t:block("Ticket", v(3.6, 1.9, 0.25), v(0, 0, 0), rgb(255, 205, 60))
	for _, x in { -1.55, 1.55 } do
		t:block("End", v(0.5, 1.9, 0.27), v(x, 0, 0), P.Carpet)
	end
	for i = -2, 2 do
		t:block("Perf", v(0.08, 0.2, 0.28), v(-0.95, i * 0.35, 0), P.Burgundy)
	end
	t:block("Line", v(1.5, 0.3, 0.05), v(0.3, 0.3, -0.15), P.Burgundy)
	t:block("Line", v(1.1, 0.2, 0.05), v(0.3, -0.25, -0.15), P.Burgundy)
end

-- A gold coin standing up and facing the camera, with a raised dollar sign. (Seen from the
-- front, local +X is on the viewer's left.)
function BUILDERS.coin(b: Builder)
	local gold = rgb(255, 196, 46)
	local dark = rgb(214, 150, 20)
	b:cylinder("Coin", 0.45, 2.8, CFrame.new(0, 1.4, 0) * FACE_Z, gold, METAL)
	b:cylinder("Face", 0.5, 2.1, CFrame.new(0, 1.4, 0) * FACE_Z, rgb(255, 222, 110), METAL)
	local d = b:sub(CFrame.new(0, 1.4, -0.22))
	for _, y in { 0.5, 0, -0.5 } do
		d:block("Dollar", v(0.85, 0.2, 0.15), v(0, y, 0), dark, METAL)
	end
	d:block("Dollar", v(0.2, 0.5, 0.15), v(0.33, 0.25, 0), dark, METAL)
	d:block("Dollar", v(0.2, 0.5, 0.15), v(-0.33, -0.25, 0), dark, METAL)
	d:block("Dollar", v(0.14, 1.5, 0.12), v(0, 0, 0.01), dark, METAL)
end

-- Chunky movie camera without the tripod (reads better at button size than the lot's camera).
function BUILDERS.movieCamera(b: Builder)
	b:block("Body", v(1.5, 1.8, 2.8), v(0, 1.2, 0), P.Charcoal)
	b:block("Trim", v(1.6, 0.25, 2.9), v(0, 0.55, 0), P.Gold, METAL)
	b:block("Handle", v(0.4, 0.3, 1.4), v(0, 2.25, 0.2), P.Charcoal)
	b:cylinder("LensHood", 1.0, 1.3, CFrame.new(0, 1.3, -1.8) * FACE_Z, P.Steel, METAL)
	b:cylinder("Glass", 0.08, 1.05, CFrame.new(0, 1.3, -2.32) * FACE_Z, P.Blue, Enum.Material.Glass)
	for _, z in { 0.8, -0.7 } do
		b:cylinder("Reel", 0.35, 1.6, CFrame.new(0, 3.05, z) * FACE_X, P.Gold, METAL)
		b:cylinder("Hub", 0.4, 0.4, CFrame.new(0, 3.05, z) * FACE_X, P.Charcoal)
	end
	b:block("Light", v(0.3, 0.3, 0.1), v(-0.45, 1.75, -1.42), P.Carpet, NEON)
end

-- Four-leaf clover for Luck.
function BUILDERS.clover(b: Builder)
	local green = rgb(70, 200, 80)
	local light = rgb(120, 230, 120)
	local leaves = b:sub(CFrame.new(0, 2.1, 0) * CFrame.Angles(math.rad(-80), 0, 0))
	-- Each leaf is a heart: two discs side by side, pointing in at the centre.
	for i = 0, 3 do
		local a = math.rad(i * 90 + 45)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local perp = Vector3.new(-dir.Z, 0, dir.X)
		for _, side in { -1, 1 } do
			leaves:cylinder("Leaf", 0.3, 1.05, dir * 0.85 + perp * 0.36 * side, if i % 2 == 0 then green else light)
		end
		leaves:cylinder("Vein", 0.32, 0.25, dir * 0.6, rgb(50, 160, 60))
	end
	leaves:cylinder("Centre", 0.34, 0.5, v(0, 0, 0), rgb(50, 160, 60))
	b:block("Stem", v(0.22, 1.5, 0.22), CFrame.new(0.3, 0.75, 0.2) * CFrame.Angles(0, 0, math.rad(-15)), rgb(50, 150, 60))
end

-- Red horseshoe magnet with silver tips, for Auto-Collect.
function BUILDERS.magnet(b: Builder)
	local red = rgb(225, 40, 50)
	for _, x in { -0.9, 0.9 } do
		b:block("Arm", v(0.8, 1.9, 0.8), v(x, 1.95, 0), red)
		b:block("Tip", v(0.82, 0.6, 0.82), v(x, 3.15, 0), rgb(220, 225, 235), METAL)
	end
	b:block("Bend", v(2.6, 0.8, 0.8), v(0, 0.75, 0), red)
	for _, x in { -0.9, 0.9 } do
		b:block("Spark", v(0.15, 0.5, 0.1), v(x, 3.85, -0.2), P.Gold, NEON)
	end
end

-- A small sound stage: grey arched hall with a big numbered door.
function BUILDERS.stage(b: Builder)
	b:block("Hall", v(3.2, 1.6, 2.6), v(0, 0.8, 0), rgb(205, 205, 210))
	b:cylinder("Roof", 2.6, 3.2, CFrame.new(0, 1.6, 0) * FACE_Z, rgb(185, 188, 196))
	b:block("Door", v(1.3, 1.3, 0.1), v(0, 0.65, -1.32), P.Charcoal)
	b:block("Sign", v(0.9, 0.45, 0.1), v(0, 1.75, -1.32), P.Carpet, NEON)
	b:block("Plus", v(0.5, 0.14, 0.12), v(0, 1.75, -1.38), P.OffWhite)
	b:block("Plus", v(0.14, 0.4, 0.12), v(0, 1.75, -1.38), P.OffWhite)
end

-- Yellow lightning bolt, for Faster Filming: three thick segments in a zigzag.
function BUILDERS.bolt(b: Builder)
	local yellow = rgb(255, 215, 40)
	local edge = rgb(230, 150, 20)
	-- Points are (x, y) in the bolt's plane; +X is the viewer's left, so the zigzag reads
	-- top-right to bottom-left like a classic bolt.
	local points = { v(-1.5, 3.8, 0), v(0.7, 2.1, 0), v(-0.7, 1.7, 0), v(1.5, 0, 0) }
	for i = 1, #points - 1 do
		local p1, p2 = points[i], points[i + 1]
		local length = (p2 - p1).Magnitude + 0.5
		local d = p2 - p1
		local cf = CFrame.new((p1 + p2) / 2) * CFrame.Angles(0, 0, math.atan2(d.Y, d.X))
		b:block("Bolt", v(length, 0.9, 0.6), cf, yellow, NEON)
		b:block("Edge", v(length, 0.95, 0.5), cf + v(0, 0, 0.12), edge)
	end
end

-- Gold crown with red gems, for VIP.
function BUILDERS.crown(b: Builder)
	local gold = rgb(255, 200, 50)
	b:cylinder("Band", 1.0, 2.6, v(0, 0.5, 0), gold, METAL)
	for i = 0, 4 do
		local a = math.rad(i * 72 + 90)
		local p = v(1.05 * math.cos(a), 1.5, -1.05 * math.sin(a))
		b:block("Point", v(0.5, 1.1, 0.5), CFrame.new(p) * CFrame.Angles(0, a, math.rad(45)), gold, METAL)
		b:ball("Pearl", 0.35, p + v(0, 0.7, 0), P.OffWhite)
	end
	b:block("Gem", v(0.45, 0.45, 0.1), CFrame.new(0, 0.55, -1.3) * CFrame.Angles(0, 0, math.rad(45)), P.Carpet, NEON)
end

-- Round green potion with a cork, for Lucky Casting.
function BUILDERS.potion(b: Builder)
	b:ball("Flask", 2.4, v(0, 1.2, 0), rgb(110, 225, 120), Enum.Material.Glass)
	b:ball("Liquid", 2.0, v(0, 1.15, 0), rgb(60, 200, 80), NEON)
	b:cylinder("Neck", 0.8, 0.8, v(0, 2.6, 0), rgb(150, 230, 160), Enum.Material.Glass)
	b:cylinder("Cork", 0.5, 0.75, v(0, 3.15, 0), P.Wood)
	b:block("Shine", v(0.3, 0.6, 0.1), v(0.55, 1.6, -1.1), P.OffWhite, NEON)
end

-- Fast-forward arrows, for Skip Filming.
function BUILDERS.skip(b: Builder)
	local purple = rgb(170, 90, 255)
	for _, x in { -0.75, 0.75 } do
		-- A stepped triangle pointing right (toward the viewer's right, local -X).
		local heights = { 2.4, 1.8, 1.2, 0.6 }
		for i, h in heights do
			b:block("Step", v(0.4, h, 0.8), v(x + 0.6 - (i - 1) * 0.4, 1.5, 0), purple)
		end
	end
end

-- Green money bag tied with gold, for Cash.
function BUILDERS.moneybag(b: Builder)
	local sack = rgb(90, 185, 85)
	b:ball("Sack", 2.6, v(0, 1.3, 0), sack)
	b:cylinder("Neck", 0.6, 0.9, v(0, 2.7, 0), sack)
	b:cylinder("Tie", 0.25, 1.0, v(0, 2.55, 0), P.Gold, METAL)
	for _, side in { -1, 1 } do
		b:block("Flap", v(0.5, 0.5, 0.4), CFrame.new(side * 0.35, 3.1, 0) * CFrame.Angles(0, 0, math.rad(side * -35)), sack)
	end
	local d = b:sub(CFrame.new(0, 1.25, -1.28))
	for _, y in { 0.42, 0, -0.42 } do
		d:block("Dollar", v(0.75, 0.17, 0.12), v(0, y, 0), P.Gold, METAL)
	end
	d:block("Dollar", v(0.17, 0.42, 0.12), v(0.29, 0.21, 0), P.Gold, METAL)
	d:block("Dollar", v(0.17, 0.42, 0.12), v(-0.29, -0.21, 0), P.Gold, METAL)
	d:block("Dollar", v(0.12, 1.25, 0.1), v(0, 0, 0.01), P.Gold, METAL)
end

-- Stacked gold bars and cash bundles, for the big Cash pack.
function BUILDERS.vault(b: Builder)
	local gold = rgb(255, 200, 50)
	local cash = rgb(110, 200, 100)
	for i, p in { v(-0.75, 0.3, 0), v(0.75, 0.3, 0), v(0, 0.9, 0) } do
		b:block("Bar", v(1.4, 0.6, 2.0), p, if i == 3 then gold else gold:Lerp(P.OffWhite, 0.1), METAL)
	end
	for i = 0, 2 do
		b:block("Bills", v(1.5, 0.35, 0.8), CFrame.new(0.2, 1.4 + i * 0.36, -0.2) * CFrame.Angles(0, math.rad(i * 9 - 8), 0), cash)
		b:block("Band", v(0.3, 0.37, 0.82), CFrame.new(0.2, 1.4 + i * 0.36, -0.2) * CFrame.Angles(0, math.rad(i * 9 - 8), 0), P.OffWhite)
	end
end

-- A screenplay: cream pages with a brass fastener and a title line.
function BUILDERS.script(b: Builder)
	local s = b:sub(CFrame.new(0, 1.7, 0) * CFrame.Angles(0, 0, math.rad(-10)))
	s:block("Pages", v(2.4, 3.2, 0.4), v(0.08, -0.06, 0.06), rgb(225, 210, 185))
	s:block("Cover", v(2.4, 3.2, 0.12), v(0, 0, -0.18), P.OffWhite)
	for _, y in { 1.1, -1.1 } do
		s:cylinder("Brad", 0.1, 0.25, CFrame.new(0.85, y, -0.26) * FACE_Z, P.Gold, METAL)
	end
	s:block("Title", v(1.4, 0.3, 0.05), v(-0.1, 0.5, -0.25), P.Carpet)
	for i = 0, 2 do
		s:block("Line", v(1.5 - i * 0.2, 0.12, 0.05), v(-0.1, -0.1 - i * 0.35, -0.25), P.Steel)
	end
end

-- Treasure chest with gold trim, for milestone rewards.
function BUILDERS.chest(b: Builder)
	local wood = rgb(160, 90, 220)
	b:block("Base", v(3.0, 1.5, 2.0), v(0, 0.75, 0), wood)
	b:cylinder("Lid", 3.0, 2.0, CFrame.new(0, 1.5, 0) * FACE_X, rgb(185, 115, 245))
	for _, x in { -1.2, 0, 1.2 } do
		b:block("Strap", v(0.3, 1.55, 2.05), v(x, 0.78, 0), P.Gold, METAL)
		b:cylinder("LidStrap", 0.3, 2.06, CFrame.new(x, 1.5, 0) * FACE_X, P.Gold, METAL)
	end
	b:block("Lock", v(0.55, 0.65, 0.15), v(0, 1.35, -1.06), P.Gold, METAL)
	b:block("Keyhole", v(0.12, 0.25, 0.05), v(0, 1.3, -1.15), P.Charcoal)
	b:block("Glow", v(2.6, 0.1, 1.6), v(0, 1.55, 0), rgb(255, 230, 120), NEON)
end

-- Padlock, for locked stages.
function BUILDERS.lock(b: Builder)
	local steel = rgb(170, 175, 190)
	b:block("Body", v(2.2, 1.8, 0.8), v(0, 0.9, 0), P.Gold, METAL)
	for _, x in { -0.65, 0.65 } do
		b:block("Shackle", v(0.32, 1.2, 0.32), v(x, 2.3, 0), steel, METAL)
	end
	b:block("Shackle", v(1.62, 0.32, 0.32), v(0, 2.9, 0), steel, METAL)
	b:cylinder("Keyhole", 0.1, 0.35, CFrame.new(0, 1.05, -0.42) * FACE_Z, P.Charcoal)
	b:block("Slot", v(0.14, 0.4, 0.06), v(0, 0.75, -0.42), P.Charcoal)
end

-- Gold trophy (the same one that stands in each lot's trophy case).
function BUILDERS.trophy(b: Builder)
	LotModels.trophy(b)
end

-- Film camera on its tripod.
function BUILDERS.camera(b: Builder)
	LotModels.filmCamera(b)
end

-- A chunky gold star standing up, for the actor collection.
function BUILDERS.star(b: Builder)
	local gold = rgb(255, 200, 50)
	-- Star frame: X is the star's normal, turned to face the camera (-Z), tilted a little.
	local star = b:sub(CFrame.new(0, 1.7, 0) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(math.rad(-10), 0, 0))
	star:cylinder("Centre", 0.6, 1.6, CFrame.Angles(0, 0, math.rad(90)), gold, METAL)
	local R0, L, W, T = 0.7, 1.15, 0.47, 0.6
	for i = 0, 4 do
		-- Each point is two mirrored wedges meeting on the point's centre line (its local Y).
		local point = star:sub(CFrame.Angles(math.rad(i * 72), 0, 0) * CFrame.new(0, R0, 0))
		point:wedge("Point", v(T, L, W), v(0, L / 2, -W / 2), gold, METAL)
		point:wedge("Point", v(T, L, W), CFrame.new(0, L / 2, W / 2) * CFrame.Angles(0, math.pi, 0), gold, METAL)
	end
	star:cylinder("Shine", 0.05, 0.5, CFrame.new(-0.32, 0.3, 0.3) * CFrame.Angles(0, 0, math.rad(90)), rgb(255, 250, 210), NEON)
end

local IconModels = {}

IconModels.Ids = table.freeze({
	"clapper", "dice", "arrow", "gift", "popcorn", "ticket", "coin", "trophy", "camera", "star",
	"movieCamera", "clover", "magnet", "stage", "bolt", "crown", "potion", "skip", "moneybag", "vault",
	"script", "chest", "lock",
})

-- Build icon `id` into a new Model under `parent`. Unknown ids build an empty model.
function IconModels.build(parent: Instance, id: string, base: CFrame?): Model
	local model = Instance.new("Model")
	model.Name = "Icon_" .. id
	local builder = BUILDERS[id]
	if builder ~= nil then
		builder(Build.new(model, base or CFrame.identity))
	end
	Build.decorative(model)
	model.Parent = parent
	return model
end

return IconModels
