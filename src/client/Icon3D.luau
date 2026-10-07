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

-- Turntable: spins the viewport's model around its own vertical axis (`rpm` turns per minute)
-- until the viewport is destroyed. Returns a function that stops it early.
function Icon3D.spin(viewport: ViewportFrame, rpm: number): () -> ()
	local model = viewport:FindFirstChildOfClass("Model")
	if model == nil then
		return function() end
	end
	local pivot = model:GetPivot()
	local angle = 0
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function(dt: number)
		if viewport.Parent == nil then
			connection:Disconnect()
			return
		end
		angle += dt * rpm / 60 * 2 * math.pi
		model:PivotTo(pivot * CFrame.Angles(0, angle, 0))
	end)
	return function()
		connection:Disconnect()
		model:PivotTo(pivot)
	end
end

-- Gentle back-and-forth sway (for a hovered button). Returns a function that stops it.
function Icon3D.wobble(viewport: ViewportFrame): () -> ()
	local model = viewport:FindFirstChildOfClass("Model")
	if model == nil then
		return function() end
	end
	local pivot = model:GetPivot()
	local t = 0
	local connection = RunService.RenderStepped:Connect(function(dt: number)
		t += dt
		model:PivotTo(pivot * CFrame.Angles(0, math.sin(t * 5) * math.rad(14), 0))
	end)
	return function()
		connection:Disconnect()
		model:PivotTo(pivot)
	end
end

return Icon3D
