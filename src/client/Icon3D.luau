--!strict
-- 3D pictures for the UI: a ViewportFrame showing one of the part-built icons (IconModels) or an
-- actor figure (ActorModels), framed automatically. Each model is built once and cloned after
-- that, so a full Index of portraits stays cheap to rebuild.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ActorModels = require(ReplicatedStorage.Shared.Models.ActorModels)
local IconModels = require(ReplicatedStorage.Shared.Models.IconModels)

local Icon3D = {}

-- Seen from the front (-Z), a little from the right and above: the same 3/4 view as the previews.
local VIEW_DIRECTION = Vector3.new(0.45, 0.35, -1).Unit
local FIELD_OF_VIEW = 30

local templates: { [string]: Model? } = {}
local holder = Instance.new("Folder")
holder.Name = "Icon3DTemplates"

local function template(key: string, build: () -> Model): Model
	local existing = templates[key]
	if existing ~= nil then
		return existing
	end
	local model = build()
	templates[key] = model
	return model
end

-- An empty ViewportFrame that fills `parent`, lit like a bright toy box.
local function makeViewport(parent: GuiObject): ViewportFrame
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Icon3D"
	viewport.BackgroundTransparency = 1
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.Ambient = Color3.fromRGB(175, 175, 185)
	viewport.LightColor = Color3.fromRGB(255, 250, 240)
	viewport.LightDirection = Vector3.new(-0.4, -1, 0.7)
	viewport.ZIndex = parent.ZIndex + 1
	viewport.Parent = parent
	return viewport
end

-- Points the viewport's camera at `model` so it fills the frame. `fill` < 1 leaves a margin.
local function frame(viewport: ViewportFrame, model: Model, fill: number)
	local camera = viewport.CurrentCamera or Instance.new("Camera")
	camera.FieldOfView = FIELD_OF_VIEW
	local box, size = model:GetBoundingBox()
	local radius = size.Magnitude / 2
	local distance = radius / math.sin(math.rad(FIELD_OF_VIEW / 2)) / fill
	camera.CFrame = CFrame.lookAt(box.Position + VIEW_DIRECTION * distance, box.Position)
	-- Spin and wobble turn the model about its centre.
	model.WorldPivot = CFrame.new(box.Position)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
end

-- A menu icon ("clapper", "gift", "popcorn"...; see IconModels.Ids) filling `parent`.
function Icon3D.icon(parent: GuiObject, id: string, fill: number?): ViewportFrame
	local viewport = makeViewport(parent)
	local model = template("icon:" .. id, function()
		return IconModels.build(holder, id)
	end):Clone()
	model.Parent = viewport
	frame(viewport, model, fill or 1.05)
	return viewport
end

-- A floating icon with a dark cartoon outline, like the reference games' button art: a black
-- silhouette copy drawn a little bigger behind the icon, plus a soft drop shadow. Returns the
-- front viewport; wobble and spin move the copies with it.
function Icon3D.outlined(parent: GuiObject, id: string, fill: number?): ViewportFrame
	local function copy(name: string, scale: number, offset: Vector2, transparency: number): ViewportFrame
		local holderFrame = Instance.new("Frame")
		holderFrame.Name = name
		holderFrame.BackgroundTransparency = 1
		holderFrame.AnchorPoint = Vector2.new(0.5, 0.5)
		holderFrame.Position = UDim2.new(0.5, offset.X, 0.5, offset.Y)
		holderFrame.Size = UDim2.fromScale(scale, scale)
		holderFrame.ZIndex = parent.ZIndex
		holderFrame.Parent = parent
		local view = Icon3D.icon(holderFrame, id, fill)
		view.ImageColor3 = Color3.fromRGB(11, 15, 31)
		view.ImageTransparency = transparency
		return view
	end
	copy("Shadow", 1.08, Vector2.new(3, 5), 0.55)
	copy("Outline", 1.1, Vector2.zero, 0)
	local front = Icon3D.icon(parent, id, fill)
	front.ZIndex = parent.ZIndex + 2
	return front
end

-- The models to move with `viewport`: its own, plus the outline and shadow copies next to it.
local function linkedModels(viewport: ViewportFrame): { Model }
	local models: { Model } = {}
	local own = viewport:FindFirstChildOfClass("Model")
	if own ~= nil then
		table.insert(models, own)
	end
	local parent = viewport.Parent
	if parent ~= nil then
		for _, name in { "Shadow", "Outline" } do
			local copyFrame = parent:FindFirstChild(name)
			local view = if copyFrame ~= nil then copyFrame:FindFirstChildOfClass("ViewportFrame") else nil
			local model = if view ~= nil then view:FindFirstChildOfClass("Model") else nil
			if model ~= nil then
				table.insert(models, model)
			end
		end
	end
	return models
end

-- An actor's figure filling `parent`. `silhouette` paints it solid black for undiscovered actors.
function Icon3D.actor(parent: GuiObject, actorId: string, variantId: string?, silhouette: boolean?): ViewportFrame
	local viewport = makeViewport(parent)
	local variant = variantId or "Normal"
	local model = template(`actor:{actorId}:{variant}`, function()
		return ActorModels.build(holder, CFrame.identity, actorId, variant)
	end):Clone()
	model.Parent = viewport
	frame(viewport, model, 1.15)
	if silhouette then
		viewport.ImageColor3 = Color3.new(0, 0, 0)
		viewport.ImageTransparency = 0.1
	end
	return viewport
end

-- Turns the viewport's model (and its outline copies) by `angleAt(dt)` each frame until the
-- viewport is destroyed or the returned stop function runs.
local function animate(viewport: ViewportFrame, angleAt: (number) -> number): () -> ()
	local models = linkedModels(viewport)
	local pivots: { CFrame } = {}
	for i, model in models do
		pivots[i] = model:GetPivot()
	end
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function(dt: number)
		if viewport.Parent == nil then
			connection:Disconnect()
			return
		end
		local turn = CFrame.Angles(0, angleAt(dt), 0)
		for i, model in models do
			model:PivotTo(pivots[i] * turn)
		end
	end)
	return function()
		connection:Disconnect()
		for i, model in models do
			model:PivotTo(pivots[i])
		end
	end
end

-- Turntable: spins the model around its own vertical axis, `rpm` turns per minute.
function Icon3D.spin(viewport: ViewportFrame, rpm: number): () -> ()
	local angle = 0
	return animate(viewport, function(dt)
		angle += dt * rpm / 60 * 2 * math.pi
		return angle
	end)
end

-- Gentle back-and-forth sway (for a hovered button).
function Icon3D.wobble(viewport: ViewportFrame): () -> ()
	local t = 0
	return animate(viewport, function(dt)
		t += dt
		return math.sin(t * 5) * math.rad(14)
	end)
end

return Icon3D
