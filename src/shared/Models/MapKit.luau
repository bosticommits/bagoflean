--!strict
-- Places a piece of the Blender map kit (art/blender/map_kit.py): street and park lamps, trees,
-- cacti and rocks, the water towers, the bandstand, benches and Dusty Gulch's buildings. Once the
-- owner imports map_kit.fbx into ReplicatedStorage.LotMeshes (art/README.md), the game shows the
-- Blender meshes. Until then it builds the same shapes from parts (MapKitShapes, written by the
-- Blender script), so the map looks the same, only less smooth.
local Build = require(script.Parent.Build)
local MapKitShapes = require(script.Parent.MapKitShapes)

type Builder = Build.Builder

local MapKit = {}

export type Options = {
	scale: number?, -- 1 = the size it was modelled at
	solid: boolean?, -- players bump into it (default: yes, unless it is far scenery)
	light: { range: number, brightness: number, color: Color3 }?, -- a PointLight where it glows
	far: boolean?, -- far scenery: no shadow, never collides or blocks clicks
}

local function partFor(shape: MapKitShapes.Shape, b: Builder, scale: number, lite: boolean): { BasePart }
	local parts: { BasePart } = {}
	local material = if shape.neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	local cf = shape.cf - shape.cf.Position + shape.cf.Position * scale
	local size = shape.size * scale
	if shape.kind == "ball" then
		local p = b:block("Kit", size, cf, shape.color, material)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
		table.insert(parts, p)
	elseif shape.kind == "cyl" then
		table.insert(parts, b:cylinder("Kit", size.Y, size.X, cf, shape.color, material))
	elseif shape.kind == "cone" then
		-- Roblox has no cone: three stacked cylinders, each narrower than the last (one for far
		-- scenery, where nobody sees the steps).
		local top = shape.top or 1
		local tiers = if top < 0.95 and not lite then 3 else 1
		for i = 0, tiers - 1 do
			local t = (i + 0.5) / tiers
			local width = size.X * (1 + (top - 1) * t)
			local y = -size.Y / 2 + size.Y * t
			table.insert(parts, b:cylinder("Kit", size.Y / tiers, width, cf * CFrame.new(0, y, 0), shape.color, material))
		end
	elseif shape.kind == "wedge" then
		table.insert(parts, b:wedge("Kit", size, cf, shape.color, material))
	else
		table.insert(parts, b:block("Kit", size, cf, shape.color, material))
	end
	return parts
end

-- Puts kit model `name` standing on `at` (in the builder's space), facing the builder's -Z.
-- Returns a Model holding it (the mesh, or the parts), named `name`.
function MapKit.place(b: Builder, name: string, at: CFrame | Vector3, options: Options?): Model
	local opts: Options = options or {}
	local scale = opts.scale or 1
	local shapes = MapKitShapes.Shapes[name]
	local bounds = MapKitShapes.Bounds[name]
	assert(shapes ~= nil and bounds ~= nil, `no map kit model called {name}`)
	local g, model = b:group(name, at)

	local mesh = Build.mesh(g, name, CFrame.new(bounds.center.X * scale, 0, bounds.center.Z * scale), bounds.size.Y * scale)
	local parts: { BasePart } = {}
	if mesh ~= nil then
		mesh.Name = "Mesh"
		-- The baked vertex colors show on white.
		mesh.Color = Color3.new(1, 1, 1)
		mesh.Material = Enum.Material.SmoothPlastic
		model:SetAttribute("Meshed", true)
		table.insert(parts, mesh)
	else
		for _, shape in shapes do
			-- Far away, thin details (ribs, rails, flowers) can't be seen: skip them to save parts.
			local thin = math.min(shape.size.X, shape.size.Y, shape.size.Z) * scale < 0.6
			if not (opts.far and thin) then
				for _, p in partFor(shape, g, scale, opts.far == true) do
					table.insert(parts, p)
				end
			end
		end
	end

	for _, p in parts do
		if opts.far then
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
		else
			p.CanCollide = opts.solid ~= false
			p.CanTouch = false
		end
	end

	-- One light per model, in the middle of its glowing spots (a lamp with three globes still
	-- gets one light: dozens of lights cost phones frame rate for little).
	local glow = MapKitShapes.Glow[name]
	if opts.light ~= nil and glow ~= nil then
		local sum = Vector3.zero
		for _, spot in glow do
			sum += spot
		end
		local holder = Instance.new("Part")
		holder.Name = "LightSpot"
		holder.Size = Vector3.new(0.2, 0.2, 0.2)
		holder.CFrame = g:at(sum / #glow * scale)
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.CastShadow = false
		holder.Transparency = 1
		holder.Parent = model
		local light = Instance.new("PointLight")
		light.Range = opts.light.range
		light.Brightness = opts.light.brightness
		light.Color = opts.light.color
		light.Shadows = false
		light.Parent = holder
	end
	return model
end

-- Kit model names, for tests and previews.
function MapKit.names(): { string }
	local names = {}
	for name in MapKitShapes.Shapes do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

return MapKit
