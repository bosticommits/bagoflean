--!strict
-- Camera framing and the cartoon outline for the UI's 3D pictures (Icon3D). Plain geometry with
-- no services, so the preview tool can check it outside Roblox.
--
-- Framing: the camera looks along one fixed 3/4 direction and sits where the model's picture
-- (sampled from every part's corners, cylinder rims and ball edges) is centred and just fills a
-- square. Other fills are a change of field of view, which keeps the camera, and the outline
-- built for it, where they are.
--
-- Outline: a dark copy of the model with every part grown by the outline thickness, then scaled
-- up about the camera. Scaling about the camera leaves its picture the same size but puts it
-- behind the model, so inside the same viewport it only shows as a rim around the silhouette.
local IconFraming = {}

IconFraming.FIELD_OF_VIEW = 30
local TAN = math.tan(math.rad(IconFraming.FIELD_OF_VIEW / 2))

-- Seen from the front (-Z), a little from the right and above: the same 3/4 view as the previews.
local LOOK = -Vector3.new(0.45, 0.35, -1).Unit
local RIGHT = LOOK:Cross(Vector3.new(0, 1, 0)).Unit
local UP = RIGHT:Cross(LOOK).Unit

local INK = Color3.fromRGB(11, 15, 31)
-- Outline thickness as a share of the picture's height, and how much lower than the model it sits
-- (as a share of the thickness), for a heavier bottom edge like the reference games' stickers.
local OUTLINE = 0.055
local DROP = 0.3
-- Turns (degrees) the framing leaves room for: the hover wobble, and a full turn for spinners.
local WOBBLE = { -14, -7, 7, 14 }
local SPIN_STEPS = 16

export type Shot = {
	camera: CFrame,
	pivot: Vector3, -- spin and wobble turn the model about this point's vertical axis
	tan: number, -- tan of half the field of view that fits the model with the wobble (fill 1)
	spinTan: number, -- the same with room for a full turn
	depth: number, -- distance from the camera to the pivot along the view
	radius: number, -- the model's bounding sphere around the pivot
}

type Ball = { center: Vector3, radius: number }

-- Points that bound each part's picture from any side: box corners, 12 points round each end of
-- a cylinder, and balls kept as centre plus radius.
local function samples(model: Model): ({ Vector3 }, { Ball })
	local points: { Vector3 } = {}
	local balls: { Ball } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			local cf, size = d.CFrame, d.Size
			local shape = if d:IsA("Part") then d.Shape else Enum.PartType.Block
			if shape == Enum.PartType.Ball then
				table.insert(balls, { center = cf.Position, radius = math.min(size.X, size.Y, size.Z) / 2 })
			elseif shape == Enum.PartType.Cylinder then
				local h = size.X / 2
				local r = math.min(size.Y, size.Z) / 2
				for i = 0, 11 do
					local a = i * math.pi / 6
					local y, z = r * math.cos(a), r * math.sin(a)
					table.insert(points, cf * Vector3.new(-h, y, z))
					table.insert(points, cf * Vector3.new(h, y, z))
				end
			else
				local hs = size / 2
				for _, sx in { -1, 1 } do
					for _, sy in { -1, 1 } do
						for _, sz in { -1, 1 } do
							table.insert(points, cf * Vector3.new(sx * hs.X, sy * hs.Y, sz * hs.Z))
						end
					end
				end
			end
		end
	end
	return points, balls
end

-- The picture's edges seen from `eye`, in tan units (sideways offset over depth), with the model
-- turned by `turn` about `pivot`.
local function extents(points: { Vector3 }, balls: { Ball }, eye: Vector3, pivot: Vector3, turn: CFrame?): (number, number, number, number)
	local x0, x1, y0, y1 = math.huge, -math.huge, math.huge, -math.huge
	local function add(p: Vector3, r: number)
		local at = if turn ~= nil then pivot + turn * (p - pivot) else p
		local rel = at - eye
		local depth = rel:Dot(LOOK)
		local x, y = rel:Dot(RIGHT), rel:Dot(UP)
		x0 = math.min(x0, (x - r) / depth)
		x1 = math.max(x1, (x + r) / depth)
		y0 = math.min(y0, (y - r) / depth)
		y1 = math.max(y1, (y + r) / depth)
	end
	for _, p in points do
		add(p, 0)
	end
	for _, b in balls do
		add(b.center, b.radius)
	end
	return x0, x1, y0, y1
end

-- Where to put the camera for `model` (in the model's own space).
function IconFraming.shoot(model: Model): Shot
	local points, balls = samples(model)
	if #points == 0 and #balls == 0 then
		return { camera = CFrame.fromMatrix(-LOOK * 10, RIGHT, UP, -LOOK), pivot = Vector3.new(), tan = TAN, spinTan = TAN, depth = 10, radius = 1 }
	end
	local lo = Vector3.new(math.huge, math.huge, math.huge)
	local hi = -lo
	for _, p in points do
		lo, hi = lo:Min(p), hi:Max(p)
	end
	for _, b in balls do
		local r = Vector3.new(b.radius, b.radius, b.radius)
		lo, hi = lo:Min(b.center - r), hi:Max(b.center + r)
	end
	local pivot = (lo + hi) / 2
	local radius = 0
	for _, p in points do
		radius = math.max(radius, (p - pivot).Magnitude)
	end
	for _, b in balls do
		radius = math.max(radius, (b.center - pivot).Magnitude + b.radius)
	end

	-- Slide sideways until the picture is centred and back off until its larger side spans the
	-- field of view; each pass gets about four times closer.
	local depth = radius / TAN + radius
	local side, lift = 0, 0
	for _ = 1, 12 do
		local eye = pivot - LOOK * depth + RIGHT * side + UP * lift
		local x0, x1, y0, y1 = extents(points, balls, eye, pivot, nil)
		side += (x0 + x1) / 2 * depth
		lift += (y0 + y1) / 2 * depth
		depth *= math.max(x1 - x0, y1 - y0) / 2 / TAN
	end
	local eye = pivot - LOOK * depth + RIGHT * side + UP * lift
	local function reach(turn: CFrame?): number
		local x0, x1, y0, y1 = extents(points, balls, eye, pivot, turn)
		return math.max(-x0, x1, -y0, y1)
	end
	local tan = reach(nil)
	for _, angle in WOBBLE do
		tan = math.max(tan, reach(CFrame.Angles(0, math.rad(angle), 0)))
	end
	local spinTan = tan
	for i = 1, SPIN_STEPS - 1 do
		spinTan = math.max(spinTan, reach(CFrame.Angles(0, i * 2 * math.pi / SPIN_STEPS, 0)))
	end
	return {
		camera = CFrame.fromMatrix(eye, RIGHT, UP, -LOOK),
		pivot = pivot,
		tan = tan,
		spinTan = spinTan,
		depth = depth,
		radius = radius,
	}
end

-- The outline copy of `model` for `shot`, its pivot (turn it with the model), and the tans the
-- picture needs with the outline around it (still, and spinning).
function IconFraming.outline(model: Model, shot: Shot): (Model, Vector3, number, number)
	local eye = shot.camera.Position
	local thickness = OUTLINE * 2 * shot.depth * TAN
	local drop = -UP * (DROP * thickness)
	-- Push the copy back far enough that, turned any way, all of it stays behind the model.
	local reach = shot.radius + thickness * math.sqrt(3) + DROP * thickness
	local scale = (shot.depth + shot.radius) / (shot.depth - reach) * 1.02
	local grow = Vector3.new(2, 2, 2) * thickness
	local copy = Instance.new("Model")
	copy.Name = "Outline"
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.5 then
			local part = d:Clone()
			for _, child in part:GetChildren() do
				if not child:IsA("DataModelMesh") then
					child:Destroy()
				end
			end
			part.Color = INK
			part.Material = Enum.Material.Neon
			part.Transparency = 0
			part.CastShadow = false
			if part:IsA("MeshPart") then
				part.TextureID = ""
			elseif part:IsA("UnionOperation") then
				part.UsePartColor = true
			end
			local size = d.Size + grow
			local mesh = part:FindFirstChildWhichIsA("DataModelMesh")
			if mesh ~= nil then
				mesh.Offset *= scale
				if mesh:IsA("SpecialMesh") and mesh.MeshType == Enum.MeshType.FileMesh then
					mesh.Scale *= size / d.Size * scale
				end
			end
			part.Size = size * scale
			local cf = d.CFrame
			local at = eye + (cf.Position + drop - eye) * scale
			part.CFrame = (cf - cf.Position) + at
			part.Parent = copy
		end
	end
	local pivot = eye + (shot.pivot + drop - eye) * scale
	-- The rim adds its thickness on every side, and the drop more at the bottom.
	local extra = thickness * (1 + DROP) / shot.depth
	return copy, pivot, shot.tan + extra, shot.spinTan + extra
end

return IconFraming
