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

IconModels.Ids = table.freeze({ "clapper", "dice", "arrow", "gift", "popcorn", "ticket", "coin", "trophy", "camera", "star" })

-- Build icon `id` into a new Model under `parent`. Unknown ids build an empty model. `scale`
-- enlarges it (the store stands on the map wear their icon about 2x).
function IconModels.build(parent: Instance, id: string, base: CFrame?, scale: number?): Model
	local model = Instance.new("Model")
	model.Name = "Icon_" .. id
	local builder = BUILDERS[id]
	if builder ~= nil then
		builder(Build.new(model, base or CFrame.identity, scale))
	end
	Build.decorative(model)
	model.Parent = parent
	return model
end

return IconModels
