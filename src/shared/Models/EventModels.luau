--!strict
-- Props for the special events (SpecialEvents), built from parts in the toy style of the town:
-- the giant Lucky Star, the Cash Rain coins, the Mystery Crate on its parachute, and beams of
-- light that show from across town where something is. Clients build and animate them
-- (src/client/EventWorld.luau); none of them collide or can be touched. art/preview draws them
-- (scene "events").
local Build = require(script.Parent.Build)
local IconModels = require(script.Parent.IconModels)

type Builder = Build.Builder

local P = Build.Palette
local NEON = Enum.Material.Neon
local METAL = Enum.Material.Metal

local EventModels = {}

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

-- Effects only: nothing to stand on, bump into or click.
local function ghost(model: Instance)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
		end
	end
end

-- The Lucky Star: the menus' gold star (IconModels "star"), `height` studs from tip to tip, with
-- its centre (and pivot) at `center`.
function EventModels.star(parent: Instance, center: CFrame, height: number): Model
	-- The icon's star is 3.4 studs tall with its centre 1.7 studs above the icon's origin.
	local scale = height / 3.4
	local model = IconModels.build(parent, "star", center * CFrame.new(0, -1.7 * scale, 0), scale)
	model.Name = "LuckyStar"
	ghost(model)
	model.WorldPivot = center
	return model
end

-- A Cash Rain coin: the menus' gold coin standing up, `diameter` studs across, its centre (and
-- pivot) at `center`.
function EventModels.coin(parent: Instance, center: CFrame, diameter: number): Model
	local scale = diameter / 2.8
	local model = IconModels.build(parent, "coin", center * CFrame.new(0, -1.4 * scale, 0), scale)
	model.Name = "EventCoin"
	ghost(model)
	model.WorldPivot = center
	return model
end

-- A thin rod between two points in the builder's space (parachute cords). Built with fromMatrix
-- rather than CFrame.lookAt, which Lune (the previews and tests) gets wrong.
local function rod(b: Builder, name: string, from: Vector3, to: Vector3, thickness: number, color: Color3)
	local length = (to - from).Magnitude
	local back = (from - to).Unit
	local side = Vector3.yAxis:Cross(back)
	local right = if side.Magnitude > 1e-3 then side.Unit else Vector3.xAxis
	b:block(name, v(thickness, thickness, length), CFrame.fromMatrix((from + to) / 2, right, back:Cross(right), back), color)
end

-- The Mystery Crate: a purple loot crate with a gold frame, chunky gold corners and a big gold "?"
-- on every side, `CRATE` studs across, its bottom centre (and pivot) at `base`. Returns the crate
-- and its lid, a model of its own hinged at the back edge so it can flip open. Uses the Blender
-- meshes MysteryCrate and MysteryCrateLid once imported (art/blender/mystery_crate.py), and
-- builds the same look from parts until then.
local CRATE = 5
local CRATE_HEIGHT = CRATE - 0.6
local LID_HEIGHT = 1.6 -- the Blender lid, gold star included
local VIOLET = Color3.fromRGB(160, 77, 255) -- the event purple
local VIOLET_LIGHT = Color3.fromRGB(180, 107, 255)
local VIOLET_DEEP = Color3.fromRGB(58, 29, 120)
local GOLD_LIGHT = Color3.fromRGB(255, 212, 71)
local INK = Color3.fromRGB(27, 18, 64)

local function crateBox(b: Builder)
	local h = CRATE_HEIGHT
	local half = CRATE / 2
	b:block("CrateSkid", v(CRATE + 0.1, 0.35, CRATE + 0.1), v(0, 0.175, 0), VIOLET_DEEP)
	b:block("CrateCore", v(CRATE - 0.5, h - 0.42, CRATE - 0.5), v(0, 0.3 + (h - 0.42) / 2, 0), VIOLET_DEEP)
	b:block("CrateBand", v(CRATE, 0.4, CRATE), v(0, 0.55, 0), P.Gold, METAL)
	local rows, from, to, gap = 3, 0.8, h - 0.42, 0.14
	local plank = (to - from - gap * (rows - 1)) / rows
	for side = 0, 3 do
		local turn = CFrame.Angles(0, math.rad(side * 90), 0)
		b:block("CrateRim", v(CRATE - 0.9, 0.4, 0.45), turn * CFrame.new(0, h - 0.2, -(half - 0.225)), P.Gold, METAL)
		for i = 0, rows - 1 do
			local shade = if (i + side) % 2 == 0 then VIOLET else VIOLET_LIGHT
			b:block("CratePlank", v(CRATE - 1.3, plank, 0.3), turn * CFrame.new(0, from + plank / 2 + i * (plank + gap), -(half - 0.25)), shade)
		end
		-- The "?" sits on a see-through panel just off the planks.
		local panel = b:block("CrateMark", v(CRATE - 1.6, to - from, 0.05), turn * CFrame.new(0, (from + to) / 2, -(half - 0.08)), VIOLET)
		panel.Transparency = 1
		local mark = Build.sign(panel, Enum.NormalId.Front, "?", GOLD_LIGHT)
		local stroke = Instance.new("UIStroke")
		stroke.Color = INK
		stroke.Thickness = 6
		stroke.Parent = mark
	end
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			b:block("CrateCorner", v(0.85, h - 0.1, 0.85), v(x * (half - 0.32), h / 2, z * (half - 0.32)), P.Gold, METAL)
		end
	end
end

local function crateLid(l: Builder)
	local w = CRATE + 0.4
	l:block("CrateLidTrim", v(w + 0.1, 0.28, w + 0.1), v(0, 0.14, 0), P.Gold, METAL)
	l:block("CrateLid", v(w, 0.7, w), v(0, 0.58, 0), VIOLET)
	l:block("CrateLidPanel", v(w - 1.4, 0.24, w - 1.4), v(0, 0.98, 0), Color3.fromRGB(91, 43, 181))
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			l:block("CrateLidCorner", v(1, 1.05, 1), v(x * (w / 2 - 0.45), 0.545, z * (w / 2 - 0.45)), P.Gold, METAL)
		end
	end
	-- A glowing gold star on the lid, lying flat on a dark outline.
	for _, yaw in { 0, 36 } do
		l:block("CrateStarEdge", v(2.3, 0.2, 2.3), CFrame.new(0, 1.18, 0) * CFrame.Angles(0, math.rad(yaw + 45), 0), INK)
		l:block("CrateStar", v(1.9, 0.24, 1.9), CFrame.new(0, 1.3, 0) * CFrame.Angles(0, math.rad(yaw + 45), 0), GOLD_LIGHT, NEON)
	end
end

function EventModels.crate(parent: Instance, base: CFrame): (Model, Model)
	local model = Instance.new("Model")
	model.Name = "MysteryCrate"
	model.Parent = parent
	local b = Build.new(model, base)
	local h = CRATE_HEIGHT
	if Build.mesh(b, "MysteryCrate", v(0, 0, 0), h) == nil then
		crateBox(b)
	end

	local lid = Instance.new("Model")
	lid.Name = "Lid"
	lid.Parent = model
	local l = Build.new(lid, base * CFrame.new(0, h, 0))
	if Build.mesh(l, "MysteryCrateLid", v(0, 0, 0), LID_HEIGHT) == nil then
		crateLid(l)
	end

	ghost(model)
	model.WorldPivot = base
	-- The lid hinges on its bottom back edge.
	lid.WorldPivot = base * CFrame.new(0, h, CRATE / 2 + 0.45)
	return model, lid
end

-- A red and white parachute: a dome with four cords down to the crate's top corners.
-- `base` is the crate's bottom centre, and the pivot, so the two can move together.
function EventModels.parachute(parent: Instance, base: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "Parachute"
	model.Parent = parent
	local b = Build.new(model, base)
	local top = CRATE
	local rings = {
		{ diameter = 15, height = 1.4 },
		{ diameter = 12, height = 1.3 },
		{ diameter = 8, height = 1.2 },
		{ diameter = 3.5, height = 0.9 },
	}
	-- The Blender canopy (CrateParachute) once imported, or stepped rings of parts.
	if Build.mesh(b, "CrateParachute", v(0, top + 9, 0), 5.2) == nil then
		local y = top + 9
		for i, ring in rings do
			b:cylinder("Canopy", ring.height, ring.diameter, v(0, y + ring.height / 2, 0), if i % 2 == 1 then P.Carpet else P.OffWhite)
			y += ring.height
		end
	end
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			rod(b, "Cord", v(x * 2.2, top, z * 2.2), v(x * 5.3, top + 9, z * 5.3), 0.18, P.OffWhite)
		end
	end
	ghost(model)
	model.WorldPivot = base
	return model
end

-- A beam of light standing on `ground`, `height` studs tall and `width` across, to show from
-- across town where something is.
function EventModels.beam(parent: Instance, ground: Vector3, height: number, width: number, color: Color3): BasePart
	local b = Build.new(parent, CFrame.new(ground))
	local beam = b:cylinder("EventBeam", height, width, v(0, height / 2, 0), color, NEON)
	beam.Transparency = 0.6
	beam.CanCollide = false
	beam.CanTouch = false
	beam.CanQuery = false
	beam.CastShadow = false
	return beam
end

-- A glowing ring lying on the ground at `ground`, `diameter` across.
function EventModels.ring(parent: Instance, ground: Vector3, diameter: number, color: Color3): BasePart
	local b = Build.new(parent, CFrame.new(ground))
	local ring = b:cylinder("EventRing", 0.12, diameter, v(0, 0.06, 0), color, NEON)
	ring.Transparency = 0.25
	ring.CanCollide = false
	ring.CanTouch = false
	ring.CanQuery = false
	ring.CastShadow = false
	return ring
end

return EventModels
