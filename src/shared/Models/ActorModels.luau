--!strict
-- The 21 castable actors and Director Lucien Vale. All original characters.
--
-- The actors are low-poly Blender models (art/blender/actors.py): a big-headed toy body shared by
-- the whole cast, props that say the role at a glance, and more flair the rarer they are. Each is
-- split into rig pieces (Body, Head, ArmL, ArmR and a Base in the rarity color) that ActorLife
-- moves on the client: an idle bob, a look round and now and then a wave. Once the owner imports
-- actors.fbx into ReplicatedStorage.LotMeshes (art/README.md) each piece is its mesh; until then
-- the same Blender shapes are built from parts (ActorShapes, written by the Blender script).
--
-- A figure is about 5.4 studs tall at scale 1, standing on its origin, facing -Z. Used for the
-- star on each lot's pedestal, the store keepers and the Top Studios wall; the same model can go
-- in a ViewportFrame. The director is his own R15 rig (LucienRig). The limited seasonal actors
-- (Actors.Limited) are one-piece Blender designs (art/blender/seasonal_actors.py), shown as their
-- meshes once imported and as SeasonalShapes parts until then.
local ActorShapes = require(script.Parent.ActorShapes)
local Build = require(script.Parent.Build)
local LucienRig = require(script.Parent.LucienRig)
local MascotModels = require(script.Parent.MascotModels)
local SeasonalShapes = require(script.Parent.SeasonalShapes)

type Builder = Build.Builder

local P = Build.Palette
local NEON = Enum.Material.Neon

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

local ActorModels = {}

export type Options = {
	-- Stand on a hex base in the rarity color (the menus' cards). Off where the figure already
	-- has something to stand on: a lot's pedestal, a store counter, the Top Studios plinths.
	base: boolean?,
}

-- Parts for one Blender shape. Roblox has no cone or oval cylinder: a cone is a few stacked
-- cylinders, each narrower than the last, and a flattened cylinder (a torso) is a block.
local function shapeParts(b: Builder, shape: ActorShapes.Shape): { BasePart }
	local material = if shape.neon then NEON else Enum.Material.SmoothPlastic
	local size = shape.size
	if shape.kind == "ball" then
		local p = b:block("Shape", size, shape.cf, shape.color, material)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
		return { p }
	elseif shape.kind == "cyl" and math.abs(size.X - size.Z) <= 0.15 * size.X then
		local top = shape.top or 1
		local tiers = if top < 0.95 then (if size.Y > 0.6 then 3 else 2) else 1
		local parts: { BasePart } = {}
		for i = 0, tiers - 1 do
			local t = (i + 0.5) / tiers
			local width = size.X * (1 + (top - 1) * t)
			local at = shape.cf * CFrame.new(0, -size.Y / 2 + size.Y * t, 0)
			table.insert(parts, b:cylinder("Shape", size.Y / tiers, math.max(width, 0.05), at, shape.color, material))
		end
		return parts
	elseif shape.kind == "cyl" then
		local top = shape.top or 1
		local k = (1 + top) / 2
		return { b:block("Shape", Vector3.new(size.X * k, size.Y, size.Z * k), shape.cf, shape.color, material) }
	end
	return { b:block("Shape", size, shape.cf, shape.color, material) }
end

-- Build an actor figure into a new Model under `parent`, standing at `base` (feet, or the
-- bottom of its base, at the origin, facing base.LookVector). Variants add effects: Shiny
-- sparkles, Award-Winning a gold medal and gold sparkles. Unknown ids build the Nervous Intern
-- so nothing breaks.
--
-- Every part carries a "Piece" attribute and the model the pivots ActorLife turns them round
-- ("Pivot<Piece>", in the model's own space, scaled), the arm that waves ("Wave") and whether
-- it hovers ("Float"). The model's pivot is its feet.
function ActorModels.build(parent: Instance, base: CFrame, actorId: string, variantId: string?, scale: number?, options: Options?): Model
	local rig = ActorShapes.Actors[actorId] or ActorShapes.Actors.NervousIntern
	local seasonal = SeasonalShapes.Shapes[actorId]
	local k = scale or 1
	local withBase = options ~= nil and options.base == true and seasonal == nil
	local lift = if withBase then ActorShapes.BaseHeight else 0
	local model = Instance.new("Model")
	model.Name = "Actor_" .. actorId
	model:SetAttribute("ActorId", actorId)
	model:SetAttribute("VariantId", variantId or "Normal")
	local feet = base * CFrame.new(0, lift * k, 0)
	local b = Build.new(model, feet, k)
	local meshed = false
	if seasonal ~= nil then
		-- A limited seasonal actor: one piece (its Blender mesh once imported, its shapes until then)
		-- that ActorLife only bobs.
		MascotModels.fill(b, actorId, seasonal, SeasonalShapes.Bounds[actorId])
		for _, p in model:GetChildren() do
			if p:IsA("BasePart") then
				p:SetAttribute("Piece", "Body")
			end
		end
	else
		for _, name in ActorShapes.Pieces do
			local piece = rig.pieces[name]
			if piece == nil or (name == "Base" and not withBase) then
				continue
			end
			local parts: { BasePart } = {}
			local mesh = Build.mesh(b, `{actorId}_{name}`, CFrame.new(piece.center.X, piece.center.Y - piece.size.Y / 2, piece.center.Z), piece.size.Y)
			if mesh ~= nil then
				mesh.Name = name
				-- The baked vertex colors show on white.
				mesh.Color = Color3.new(1, 1, 1)
				mesh.Material = Enum.Material.SmoothPlastic
				meshed = true
				table.insert(parts, mesh)
			else
				for _, shape in piece.shapes do
					for _, p in shapeParts(b, shape) do
						table.insert(parts, p)
					end
				end
			end
			for _, p in parts do
				p:SetAttribute("Piece", name)
			end
			model:SetAttribute("Pivot" .. name, piece.pivot * k)
		end
	end
	if variantId == "Award" then
		b:block("MedalRibbon", v(0.32, 0.45, 0.08), v(0.45, 2.3, -0.78), P.Carpet):SetAttribute("Piece", "Body")
		local medal = b:cylinder("Medal", 0.12, 0.5, CFrame.new(0.45, 1.95, -0.8) * CFrame.Angles(math.rad(90), 0, 0), P.Gold, NEON)
		medal:SetAttribute("Piece", "Body")
	end
	if variantId == "Shiny" or variantId == "Award" then
		local anchor = b:block("SparkleAnchor", v(1, 1, 1), v(0, 3, 0), P.OffWhite)
		anchor.Transparency = 1
		anchor:SetAttribute("Piece", "Body")
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = if variantId == "Award" then P.Gold else Color3.fromRGB(150, 235, 255)
		sparkles.Parent = anchor
	end
	if meshed then
		model:SetAttribute("Meshed", true)
	end
	if rig.wave ~= nil and seasonal == nil then
		model:SetAttribute("Wave", rig.wave)
	end
	if rig.float and seasonal == nil then
		model:SetAttribute("Float", true)
	end
	model:SetAttribute("RigScale", k)
	Build.decorative(model)
	model.WorldPivot = feet
	-- ActorLife finds the figures by this tag, and streams them in whole (not in the art
	-- previews, which run outside Roblox).
	pcall(function()
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		model:AddTag("ActorRig")
	end)
	model.Parent = parent
	return model
end

-- Director Lucien Vale (LucienRig, art/blender/lucien.py) standing at `base` in his idle pose.
-- `bust` keeps only the head and shoulders, for a portrait.
local BUST = { Head = true, UpperTorso = true, RightUpperArm = true, LeftUpperArm = true }
function ActorModels.buildDirector(parent: Instance, base: CFrame, bust: boolean?): Model
	local rig = LucienRig.build(parent, if bust then BUST else nil)
	LucienRig.apply(rig, base, LucienRig.sample(LucienRig.Clips.idle, 0))
	return rig.model
end

-- Rarity flair under the figure: a glowing ring for Star and up.
function ActorModels.aura(b: Builder, color: Color3)
	local glow = b:cylinder("AuraRing", 0.12, 3.6, v(0, 0.1, 0), color, NEON)
	glow.Transparency = 0.3
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 10
	light.Brightness = 1.5
	light.Parent = glow
end

return ActorModels
