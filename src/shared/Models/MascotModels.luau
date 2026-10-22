--!strict
-- Builds a studio mascot (Shared/Mascots). The designs are made in Blender (art/blender/mascots.py),
-- split into moving pieces (body, legs, tail, head...) that MascotRig animates. Once the owner
-- imports mascots.fbx into ReplicatedStorage.LotMeshes (art/README.md), the game shows those meshes
-- (one per piece, named <id>_<piece>), with their outlines built in. Until then it builds the same
-- Blender shapes from parts (MascotShapes, written by the Blender script), and the caller adds an
-- outline. Every part carries a "Piece" attribute: its index in MascotShapes.Pieces[id].
-- The model stands on `base` (feet at its origin) facing its -Z, like every other model.
local Build = require(script.Parent.Build)
local MascotShapes = require(script.Parent.MascotShapes)

local MascotModels = {}

local function partFor(shape: MascotShapes.Shape): BasePart
	local p = Instance.new("Part")
	p.Color = shape.color
	p.Material = if shape.neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape.kind == "ball" then
		-- An ellipsoid: a block wearing a sphere mesh stretched to the block's size.
		p.Size = shape.size
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	elseif shape.kind == "cyl" then
		-- Length first: a Roblox cylinder's axis is its X axis (build turns it onto the shape's Y).
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(shape.size.Y, shape.size.X, shape.size.Z)
	else
		p.Size = shape.size
	end
	return p
end

-- The imported Blender mesh called `name` in ReplicatedStorage.LotMeshes (straight inside, or
-- inside the model mascots.fbx imports as), or nil.
local function meshNamed(name: string): BasePart?
	local dataModel = (game :: any) :: DataModel?
	if dataModel == nil then
		return nil
	end
	local folder = dataModel:GetService("ReplicatedStorage"):FindFirstChild("LotMeshes")
	local found = if folder ~= nil then folder:FindFirstChild(name, true) else nil
	if found ~= nil and found:IsA("Model") then
		found = found:FindFirstChildWhichIsA("MeshPart", true)
	end
	return if found ~= nil and found:IsA("BasePart") then found else nil
end

-- Every piece's mesh for `id`, in MascotShapes.Pieces order, or nil unless all are imported.
local function meshesFor(id: string): { BasePart }?
	local pieces = MascotShapes.Pieces[id]
	if pieces == nil then
		return nil
	end
	local meshes = {}
	for i, piece in pieces do
		local mesh = meshNamed(id .. "_" .. piece.name)
		if mesh == nil then
			return nil
		end
		meshes[i] = mesh
	end
	return meshes
end

-- True when the Blender meshes for `id` have been imported.
function MascotModels.hasMesh(id: string): boolean
	return meshesFor(id) ~= nil
end

-- Puts a Blender design into builder `b`: the mesh named `id` if it has been imported, otherwise
-- its shapes as parts (`shapes` and `bounds` from a generated module such as MascotShapes or
-- SeasonalShapes). Sets the "Meshed" attribute on the builder's parent when the mesh is used.
function MascotModels.fill(b: Build.Builder, id: string, shapes: { MascotShapes.Shape }, bounds: { size: Vector3, center: Vector3 })
	local k = b.scale
	local mesh = Build.mesh(b, id, CFrame.new(bounds.center.X, 0, bounds.center.Z), bounds.size.Y)
	if mesh ~= nil then
		mesh.Name = "Mesh"
		b.parent:SetAttribute("Meshed", true)
		return
	end
	for i, shape in shapes do
		local p = partFor(shape)
		p.Name = shape.kind .. i
		p.Size *= k
		-- A cylinder part lies along its X axis: turn it onto the shape's Y axis.
		p.CFrame = b:at(if shape.kind == "cyl" then shape.cf * CFrame.Angles(0, 0, math.rad(90)) else shape.cf)
		p.Anchored = true
		p.Parent = b.parent
	end
end

-- A Model named `id` under `parent`, every part anchored with no collisions, touches or queries.
function MascotModels.build(parent: Instance, id: string, base: CFrame?, scale: number?): Model?
	local shapes = MascotShapes.Shapes[id]
	local bounds = MascotShapes.Bounds[id]
	if shapes == nil or bounds == nil then
		return nil
	end
	local where = base or CFrame.identity
	local model = Instance.new("Model")
	model.Name = id
	local k = scale or 1
	local b = Build.new(model, where, k)
	local meshes = meshesFor(id)
	local pieces = MascotShapes.Pieces[id]
	if meshes ~= nil and pieces ~= nil then
		for i, template in meshes do
			local piece = pieces[i]
			local p = template:Clone()
			-- Sized by its longest side, so a flat piece (the film tape) still comes out right.
			local want, got = piece.size, p.Size
			p.Size = got * (math.max(want.X, want.Y, want.Z) / math.max(got.X, got.Y, got.Z)) * k
			p.CFrame = b:at(CFrame.new(piece.center))
			p.Name = piece.name
			-- White and plain, so the colors baked into the mesh show.
			p.Color = Color3.new(1, 1, 1)
			p.Material = Enum.Material.SmoothPlastic
			p.Anchored = true
			p:SetAttribute("Piece", i)
			p.Parent = model
		end
		model:SetAttribute("Meshed", true)
	else
		for i, shape in shapes do
			local p = partFor(shape)
			p.Name = shape.kind .. i
			p.Size *= k
			p:SetAttribute("Piece", shape.piece)
			-- A cylinder part lies along its X axis: turn it onto the shape's Y axis.
			p.CFrame = b:at(if shape.kind == "cyl" then shape.cf * CFrame.Angles(0, 0, math.rad(90)) else shape.cf)
			p.Anchored = true
			p.Parent = model
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.Massless = true
		end
	end
	model.WorldPivot = where
	model.Parent = parent
	return model
end

return MascotModels
