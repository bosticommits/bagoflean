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

-- The Mystery Crate: a wooden crate with gold corners and a big "?" on every side, `CRATE` studs
-- across, its bottom centre (and pivot) at `base`. Returns the crate and its lid, a model of its
-- own hinged at the back edge so it can flip open.
local CRATE = 5
function EventModels.crate(parent: Instance, base: CFrame): (Model, Model)
	local model = Instance.new("Model")
	model.Name = "MysteryCrate"
	model.Parent = parent
	local b = Build.new(model, base)
	local h = CRATE - 0.6
	local box = b:block("CrateBox", v(CRATE, h, CRATE), v(0, h / 2, 0), P.Wood)
	for _, y in { 0.9, 2.5 } do
		b:block("CratePlank", v(CRATE + 0.12, 0.4, CRATE + 0.12), v(0, y, 0), P.Bark)
	end
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			b:block("CrateCorner", v(0.7, h + 0.1, 0.7), v(x * (CRATE / 2 - 0.25), h / 2, z * (CRATE / 2 - 0.25)), P.Gold, METAL)
		end
	end
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right } do
		local mark = Build.sign(box, face, "?", P.Gold)
		local stroke = Instance.new("UIStroke")
		stroke.Color = P.Charcoal
		stroke.Thickness = 6
		stroke.Parent = mark
	end

	local lid = Instance.new("Model")
	lid.Name = "Lid"
	lid.Parent = model
	local l = Build.new(lid, base)
	l:block("CrateLid", v(CRATE + 0.4, 0.6, CRATE + 0.4), v(0, h + 0.3, 0), P.Wood)
	l:block("CrateLidTrim", v(CRATE + 0.5, 0.2, CRATE + 0.5), v(0, h + 0.1, 0), P.Gold, METAL)
	-- A glowing gold star on the lid, lying flat.
	for _, yaw in { 0, 36 } do
		l:block("CrateStar", v(1.6, 0.2, 1.6), CFrame.new(0, h + 0.7, 0) * CFrame.Angles(0, math.rad(yaw + 45), 0), P.Gold, NEON)
	end

	ghost(model)
	model.WorldPivot = base
	lid.WorldPivot = base * CFrame.new(0, h + 0.3, CRATE / 2 + 0.2)
	return model, lid
end

-- A red and white parachute: a stepped dome with four cords down to the crate's top corners.
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
	local y = top + 9
	for i, ring in rings do
		b:cylinder("Canopy", ring.height, ring.diameter, v(0, y + ring.height / 2, 0), if i % 2 == 1 then P.Carpet else P.OffWhite)
		y += ring.height
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
