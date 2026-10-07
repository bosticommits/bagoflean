--!strict
-- A tiny part builder for the code-built models (lots, buildings, actors).
-- Every model is laid out in its own local space: origin at the bottom centre, front facing -Z
-- (the way a Roblox part's Front face points), +Y up. A builder places that local space at a base
-- CFrame, so the same code builds a piece anywhere and facing any way.
-- Colors follow ART_STYLE.md section 3.
local Build = {}

Build.Palette = table.freeze({
	Cream = Color3.fromRGB(244, 231, 207),
	Burgundy = Color3.fromRGB(122, 31, 43),
	Carpet = Color3.fromRGB(200, 32, 47),
	Gold = Color3.fromRGB(245, 184, 46),
	Blue = Color3.fromRGB(46, 134, 222),
	Navy = Color3.fromRGB(27, 35, 64),
	Green = Color3.fromRGB(91, 191, 90),
	Asphalt = Color3.fromRGB(140, 138, 134),
	-- Supporting shades of the same palette.
	DarkGreen = Color3.fromRGB(56, 140, 70),
	Paving = Color3.fromRGB(214, 200, 176),
	Charcoal = Color3.fromRGB(46, 44, 52), -- "black" without being pure black
	OffWhite = Color3.fromRGB(250, 246, 236),
	Glass = Color3.fromRGB(150, 205, 240),
	Wood = Color3.fromRGB(150, 98, 60),
	Bark = Color3.fromRGB(122, 84, 52),
	Grey = Color3.fromRGB(167, 169, 172), -- unowned / Newcomer grey
	Steel = Color3.fromRGB(110, 112, 120),
	Light = Color3.fromRGB(255, 236, 190), -- warm bulb
})

export type Builder = {
	parent: Instance,
	base: CFrame,
	scale: number,
	-- Local position or CFrame -> world CFrame.
	at: (self: Builder, at: CFrame | Vector3) -> CFrame,
	-- A child builder: same parent, local space moved by `offset`.
	sub: (self: Builder, offset: CFrame | Vector3) -> Builder,
	-- A child builder that puts its parts in a new Model under this builder's parent.
	group: (self: Builder, name: string, offset: (CFrame | Vector3)?) -> (Builder, Model),
	block: (self: Builder, name: string, size: Vector3, at: CFrame | Vector3, color: Color3, material: Enum.Material?) -> Part,
	-- Like a Roblox WedgePart: tall side at local +Z (back), slope facing -Z (front) and up.
	wedge: (self: Builder, name: string, size: Vector3, at: CFrame | Vector3, color: Color3, material: Enum.Material?) -> WedgePart,
	-- Upright cylinder (axis along local Y).
	cylinder: (self: Builder, name: string, height: number, diameter: number, at: CFrame | Vector3, color: Color3, material: Enum.Material?) -> Part,
	ball: (self: Builder, name: string, diameter: number, at: CFrame | Vector3, color: Color3, material: Enum.Material?) -> Part,
}

local Methods = {}
Methods.__index = Methods

local function toCFrame(at: CFrame | Vector3): CFrame
	if typeof(at) == "Vector3" then
		return CFrame.new(at)
	end
	return at
end

function Build.new(parent: Instance, base: CFrame, scale: number?): Builder
	local self = setmetatable({ parent = parent, base = base, scale = scale or 1 }, Methods)
	return (self :: any) :: Builder
end

function Methods.at(self: Builder, at: CFrame | Vector3): CFrame
	local cf = toCFrame(at)
	if self.scale ~= 1 then
		cf = (cf - cf.Position) + cf.Position * self.scale
	end
	return self.base * cf
end

function Methods.sub(self: Builder, offset: CFrame | Vector3): Builder
	return Build.new(self.parent, self:at(offset), self.scale)
end

function Methods.group(self: Builder, name: string, offset: (CFrame | Vector3)?): (Builder, Model)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = self.parent
	return Build.new(model, self:at(offset or CFrame.identity), self.scale), model
end

local function finish(self: Builder, p: BasePart, name: string, size: Vector3, at: CFrame | Vector3, color: Color3, material: Enum.Material?)
	p.Name = name
	p.Size = size * self.scale
	p.CFrame = self:at(at)
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if material == Enum.Material.Neon or material == Enum.Material.Glass then
		p.CastShadow = false
	end
	p.Parent = self.parent
end

function Methods.block(self: Builder, name: string, size: Vector3, at: CFrame | Vector3, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	finish(self, p, name, size, at, color, material)
	return p
end

function Methods.wedge(self: Builder, name: string, size: Vector3, at: CFrame | Vector3, color: Color3, material: Enum.Material?): WedgePart
	local p = Instance.new("WedgePart")
	finish(self, p, name, size, at, color, material)
	return p
end

function Methods.cylinder(self: Builder, name: string, height: number, diameter: number, at: CFrame | Vector3, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	-- A Roblox cylinder's axis is its X axis; turn it upright.
	finish(self, p, name, Vector3.new(height, diameter, diameter), toCFrame(at) * CFrame.Angles(0, 0, math.rad(90)), color, material)
	return p
end

function Methods.ball(self: Builder, name: string, diameter: number, at: CFrame | Vector3, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	finish(self, p, name, Vector3.new(diameter, diameter, diameter), at, color, material)
	return p
end

-- Text on one face of a part (signs, marquees, stage numbers). Returns the label to update later.
function Build.sign(target: BasePart, face: Enum.NormalId, text: string, textColor: Color3, background: Color3?): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = target
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = background or Color3.new(0, 0, 0)
	label.BackgroundTransparency = if background ~= nil then 0 else 1
	label.TextColor3 = textColor
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.Parent = gui
	return label
end

-- A Blender mesh the owner imported into ReplicatedStorage.LotMeshes (art/README.md says how),
-- placed standing on `at` and scaled to `height` studs if given. Returns nil when that mesh has
-- not been imported (or outside Roblox, in the preview tool) so callers fall back to parts.
function Build.mesh(b: Builder, name: string, at: CFrame | Vector3, height: number?): BasePart?
	local dataModel = (game :: any) :: DataModel?
	if dataModel == nil then
		return nil
	end
	local folder = dataModel:GetService("ReplicatedStorage"):FindFirstChild("LotMeshes")
	local template: Instance? = if folder ~= nil then folder:FindFirstChild(name) else nil
	if template ~= nil and template:IsA("Model") then
		template = template:FindFirstChildWhichIsA("MeshPart", true)
	end
	if template == nil or not template:IsA("BasePart") then
		return nil
	end
	local p = template:Clone()
	local scale = b.scale * (if height ~= nil then height / p.Size.Y else 1)
	p.Size *= scale
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CFrame = b:at(at) * CFrame.new(0, p.Size.Y / 2, 0)
	p.Parent = b.parent
	return p
end

-- Turn off collisions and touches for decoration players never need to stand on.
function Build.decorative(root: Instance)
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanTouch = false
		end
	end
end

return Build
