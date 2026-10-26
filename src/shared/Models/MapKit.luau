--!strict
-- Places a piece of the Blender map kit (art/blender/map_kit.py and town_kit.py): every model on
-- the map, from lamps, trees and rocks to the store stands, the theatre, the film sets, Dusty
-- Gulch and Starlight Park. Once the owner imports map_kit.fbx into ReplicatedStorage.LotMeshes
-- (art/README.md), the game shows the Blender meshes. Until then it builds the same shapes from
-- parts (MapKitShapes, written by the Blender script), so the map looks the same, only blockier.
-- Words are never part of a model: signs have named spots, and `labels` letters them.
local Build = require(script.Parent.Build)
local HalloweenShapes = require(script.Parent.HalloweenShapes)
local MapKitShapes = require(script.Parent.MapKitShapes)

type Builder = Build.Builder

local MapKit = {}

export type Options = {
	scale: number?, -- 1 = the size it was modelled at
	solid: boolean?, -- players bump into it (default: yes, unless it is far scenery)
	light: { range: number, brightness: number, color: Color3 }?, -- a PointLight where it glows
	far: boolean?, -- far scenery: no shadow, never collides or blocks clicks
	-- Players walk on or through it (steps, a bridge, a stand's floor): the mesh doesn't collide;
	-- invisible boxes in the shapes of its blocks do, so walking on it is smooth.
	hitbox: boolean?,
	-- Text lettered on the model's sign spots (MapKitShapes.Spots), keyed by spot name.
	labels: { [string]: Label }?,
}

export type Label = {
	text: string,
	color: Color3,
	stroke: number?, -- dark outline thickness (0 for none; default 3)
}

local INK = Color3.fromRGB(11, 15, 31) -- the menus' outline color (UiKit.INK)

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
	elseif shape.kind == "star" then
		-- Two crossed squares standing up: an eight-point star from the front.
		local square = Vector3.new(size.X * 0.6, size.Y * 0.6, size.Z)
		table.insert(parts, b:block("Kit", square, cf, shape.color, material))
		table.insert(parts, b:block("Kit", square, cf * CFrame.Angles(0, 0, math.rad(45)), shape.color, material))
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
	-- The Fright Night decor (art/blender/halloween_kit.py) has its own shapes file.
	local kit: typeof(MapKitShapes) = if MapKitShapes.Shapes[name] ~= nil then MapKitShapes else HalloweenShapes :: any
	local shapes = kit.Shapes[name]
	local bounds = kit.Bounds[name]
	assert(shapes ~= nil and bounds ~= nil, `no map kit model called {name}`)
	local g, model = b:group(name, at)
	-- Its pivot is its feet, so code that moves it (MapLife) knows where it stands; the preview
	-- renders (art/preview) read which kit model it is.
	model.WorldPivot = g:at(CFrame.identity)
	model:SetAttribute("Kit", name)
	model:SetAttribute("KitScale", scale * b.scale)

	-- The mesh's bottom goes where the shapes' bottom is: on the ground for most models, below the
	-- joint for rig pieces that hang from it (art/blender/crew_kit.py).
	local bottom = bounds.center.Y - bounds.size.Y / 2
	local mesh = Build.mesh(g, name, CFrame.new(bounds.center.X * scale, bottom * scale, bounds.center.Z * scale), bounds.size.Y * scale)
	local parts: { BasePart } = {}
	local hitboxes: { BasePart } = {}
	if mesh ~= nil then
		mesh.Name = "Mesh"
		-- The baked vertex colors show on white.
		mesh.Color = Color3.new(1, 1, 1)
		mesh.Material = Enum.Material.SmoothPlastic
		model:SetAttribute("Meshed", true)
		table.insert(parts, mesh)
		if opts.hitbox and not opts.far then
			for _, shape in shapes do
				-- Anything wider than a rod or a rail (a thin floor board still counts: it is
				-- what players stand on).
				local dims = { shape.size.X, shape.size.Y, shape.size.Z }
				table.sort(dims)
				local big = dims[2] * scale >= 1
				if big and (shape.kind == "box" or shape.kind == "wedge" or shape.kind == "cyl") then
					for _, p in partFor(shape, g, scale, true) do
						p.Name = "Hitbox"
						p.Transparency = 1
						p.CastShadow = false
						p.CanTouch = false
						p.CanCollide = true
						table.insert(hitboxes, p)
					end
				end
			end
		end
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
			p.CanCollide = opts.solid ~= false and not (opts.hitbox and #hitboxes > 0)
			p.CanTouch = false
		end
	end

	-- Sign text on the model's spots: an invisible board with the words on its front.
	if opts.labels ~= nil then
		local spots = kit.Spots[name]
		for spotName, label in opts.labels do
			local spot = if spots ~= nil then spots[spotName] else nil
			assert(spot ~= nil, `map kit model {name} has no spot called {spotName}`)
			local cf = spot.cf - spot.cf.Position + spot.cf.Position * scale
			local board = g:block("SignText", spot.size * scale, cf, Color3.new(1, 1, 1))
			board.Transparency = 1
			board.CanCollide = false
			board.CanQuery = false
			board.CanTouch = false
			board.CastShadow = false
			local text = Build.sign(board, Enum.NormalId.Front, label.text, label.color)
			local thickness = label.stroke or 3
			if thickness > 0 then
				local stroke = Instance.new("UIStroke")
				stroke.Color = INK
				stroke.Thickness = thickness
				stroke.Parent = text
			end
		end
	end

	-- One light per model, in the middle of its glowing spots (a lamp with three globes still
	-- gets one light: dozens of lights cost phones frame rate for little).
	local glow = kit.Glow[name]
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

-- Where spot `spotName` of kit model `name` sits in the model's own space (standing on y = 0,
-- facing -Z), at `scale`. Errors if there is no such spot.
function MapKit.spot(name: string, spotName: string, scale: number?): CFrame
	local spots = MapKitShapes.Spots[name]
	local spot = if spots ~= nil then spots[spotName] else nil
	assert(spot ~= nil, `map kit model {name} has no spot called {spotName}`)
	local k = scale or 1
	return spot.cf - spot.cf.Position + spot.cf.Position * k
end

-- The size of kit model `name` and where its middle sits above its feet, at scale 1.
function MapKit.bounds(name: string): { size: Vector3, center: Vector3 }
	local bounds = MapKitShapes.Bounds[name]
	assert(bounds ~= nil, `no map kit model called {name}`)
	return bounds
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
