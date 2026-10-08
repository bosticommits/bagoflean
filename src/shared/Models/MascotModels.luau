--!strict
-- Builds a studio mascot (Shared/Mascots). The designs are made in Blender (art/blender/mascots.py):
-- once the owner imports a mascot's mesh into ReplicatedStorage.LotMeshes (art/README.md), the game
-- shows that mesh, with its outline built in. Until then it builds the same Blender shapes from
-- parts (MascotShapes, written by the Blender script), and the caller adds an outline.
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

-- True when the Blender mesh for `id` has been imported.
function MascotModels.hasMesh(id: string): boolean
	local dataModel = (game :: any) :: DataModel?
	if dataModel == nil then
		return false
	end
	local folder = dataModel:GetService("ReplicatedStorage"):FindFirstChild("LotMeshes")
	local found = if folder ~= nil then folder:FindFirstChild(id) else nil
	if found ~= nil and found:IsA("Model") then
		found = found:FindFirstChildWhichIsA("MeshPart", true)
	end
	return found ~= nil and found:IsA("BasePart")
end

-- A Model named `id` under `parent`, every part anchored with no collisions, touches or queries.
function MascotModels.build(parent: Instance, id: string, base: CFrame?, scale: number?): Model?
	local shapes = MascotShapes.Shapes[id]
	local bounds = MascotShapes.Bounds[id]
	if shapes == nil or bounds == nil then
		return nil
	end
	local where = base or CFrame.identity
	local k = scale or 1
	local model = Instance.new("Model")
	model.Name = id
	local b = Build.new(model, where, k)
	local mesh = Build.mesh(b, id, CFrame.new(bounds.center.X, 0, bounds.center.Z), bounds.size.Y)
	if mesh ~= nil then
		mesh.Name = "Mesh"
		model:SetAttribute("Meshed", true)
	else
		for i, shape in shapes do
			local p = partFor(shape)
			p.Name = shape.kind .. i
			p.Size *= k
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
