--!strict
-- 3D pictures for the UI: a ViewportFrame showing one of the part-built icons (IconModels) or an
-- actor figure (ActorModels), framed to fill it (IconFraming). Each model, its framing and its
-- outline are worked out once and cloned after that, so a full Index of portraits stays cheap to
-- rebuild, and every picture is a single viewport (each extra viewport is one more picture for
-- Roblox to draw before it shows).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ActorModels = require(ReplicatedStorage.Shared.Models.ActorModels)
local IconModels = require(ReplicatedStorage.Shared.Models.IconModels)
local IconFraming = require(script.Parent.IconFraming)

local Icon3D = {}

-- Share of the picture the model fills (1 touches the edges).
local ICON_FILL = 0.94
local ACTOR_FILL = 0.9

type Entry = {
	model: Model,
	shot: IconFraming.Shot,
	outline: Model?,
	outlineTan: number,
	outlineSpinTan: number,
}

local entries: { [string]: Entry } = {}
local holder = Instance.new("Folder")
holder.Name = "Icon3DTemplates"

local function entry(key: string, build: () -> Model): Entry
	local existing = entries[key]
	if existing ~= nil then
		return existing
	end
	local model = build()
	local shot = IconFraming.shoot(model)
	-- Spin and wobble turn the model about its centre.
	model.WorldPivot = CFrame.new(shot.pivot)
	local made: Entry = { model = model, shot = shot, outline = nil, outlineTan = shot.tan, outlineSpinTan = shot.spinTan }
	entries[key] = made
	return made
end

local function outlineOf(made: Entry): Model
	local existing = made.outline
	if existing ~= nil then
		return existing
	end
	local copy, pivot, tan, spinTan = IconFraming.outline(made.model, made.shot)
	copy.WorldPivot = CFrame.new(pivot)
	copy.Parent = holder
	made.outline = copy
	made.outlineTan = tan
	made.outlineSpinTan = spinTan
	return copy
end

-- The framing is for a square picture: a picture taller than it is wide widens the view until the
-- sides fit too. A spinning model gets room for a full turn.
local function applyView(viewport: ViewportFrame)
	local camera = viewport:FindFirstChildOfClass("Camera")
	if camera == nil then
		return
	end
	local tan = viewport:GetAttribute(if viewport:GetAttribute("Spinning") then "SpinTan" else "Tan")
	if typeof(tan) ~= "number" then
		return
	end
	local size = viewport.AbsoluteSize
	local aspect = if size.X > 0 and size.Y > 0 then size.X / size.Y else 1
	camera.FieldOfView = math.clamp(math.deg(2 * math.atan(tan / math.min(1, aspect))), 1, 120)
end

-- A ViewportFrame filling `parent`, lit like a bright toy box, showing `made` (with its outline
-- behind it when `outlined`).
local function show(parent: GuiObject, made: Entry, fill: number, outlined: boolean): ViewportFrame
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Icon3D"
	viewport.BackgroundTransparency = 1
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.Ambient = Color3.fromRGB(175, 175, 185)
	viewport.LightColor = Color3.fromRGB(255, 250, 240)
	viewport.LightDirection = Vector3.new(-0.4, -1, 0.7)
	viewport.ZIndex = parent.ZIndex + 1
	local camera = Instance.new("Camera")
	camera.CFrame = made.shot.camera
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local tan, spinTan = made.shot.tan, made.shot.spinTan
	if outlined then
		outlineOf(made):Clone().Parent = viewport
		tan, spinTan = made.outlineTan, made.outlineSpinTan
	end
	made.model:Clone().Parent = viewport
	viewport:SetAttribute("Tan", tan / fill)
	viewport:SetAttribute("SpinTan", spinTan / fill)
	applyView(viewport)
	viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		applyView(viewport)
	end)
	viewport.Parent = parent
	return viewport
end

local function iconEntry(id: string): Entry
	return entry("icon:" .. id, function()
		return IconModels.build(holder, id)
	end)
end

-- A menu icon ("clapper", "gift", "popcorn"...; see IconModels.Ids) filling `parent`. `fill` is
-- the share of the picture it fills.
function Icon3D.icon(parent: GuiObject, id: string, fill: number?): ViewportFrame
	return show(parent, iconEntry(id), fill or ICON_FILL, false)
end

-- A floating icon with a dark cartoon outline, like the reference games' button art.
function Icon3D.outlined(parent: GuiObject, id: string, fill: number?): ViewportFrame
	return show(parent, iconEntry(id), fill or ICON_FILL, true)
end

-- An actor's figure filling `parent`. `silhouette` paints it solid black for undiscovered actors.
function Icon3D.actor(parent: GuiObject, actorId: string, variantId: string?, silhouette: boolean?): ViewportFrame
	local variant = variantId or "Normal"
	local made = entry(`actor:{actorId}:{variant}`, function()
		return ActorModels.build(holder, CFrame.identity, actorId, variant)
	end)
	local viewport = show(parent, made, ACTOR_FILL, false)
	if silhouette then
		viewport.ImageColor3 = Color3.new(0, 0, 0)
		viewport.ImageTransparency = 0.1
	end
	return viewport
end

-- Director Lucien Vale, the tutorial's host: his whole figure, or with `bust` his head and
-- shoulders for a portrait.
function Icon3D.director(parent: GuiObject, bust: boolean?, outlined: boolean?): ViewportFrame
	local made = entry(if bust then "director:bust" else "director:full", function()
		return ActorModels.buildDirector(holder, CFrame.identity, bust)
	end)
	return show(parent, made, ACTOR_FILL, outlined == true)
end

-- A soft light behind a picture, like a spotlight on the item: two faint discs, the inner one
-- brighter. Screens that open and close use it on their picture cards, because Roblox redraws a
-- picture each time its screen shows again and the spot would otherwise sit empty for a moment.
function Icon3D.glow(viewport: ViewportFrame, color: Color3?, strength: number?)
	local parent = viewport.Parent
	if parent == nil then
		return
	end
	local amount = strength or 1
	for _, ring in { { size = 0.92, transparency = 0.86 }, { size = 0.6, transparency = 0.8 } } do
		local disc = Instance.new("Frame")
		disc.Name = "Glow"
		disc.AnchorPoint = Vector2.new(0.5, 0.5)
		disc.Position = UDim2.fromScale(0.5, 0.5)
		disc.Size = UDim2.fromScale(ring.size, ring.size)
		disc.BackgroundColor3 = color or Color3.new(1, 1, 1)
		disc.BackgroundTransparency = 1 - (1 - ring.transparency) * amount
		disc.BorderSizePixel = 0
		disc.ZIndex = viewport.ZIndex - 1
		disc.Parent = parent
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(0.5, 0)
		round.Parent = disc
		local square = Instance.new("UIAspectRatioConstraint")
		square.Parent = disc
	end
end

-- Turns the viewport's models (the picture and its outline) by `angleAt(dt)` each frame until the
-- viewport is destroyed or the returned stop function runs.
local function animate(viewport: ViewportFrame, angleAt: (number) -> number): () -> ()
	local models: { Model } = {}
	local pivots: { CFrame } = {}
	for _, child in viewport:GetChildren() do
		if child:IsA("Model") then
			table.insert(models, child)
			table.insert(pivots, child:GetPivot())
		end
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
	viewport:SetAttribute("Spinning", true)
	applyView(viewport)
	local angle = 0
	local stop = animate(viewport, function(dt)
		angle += dt * rpm / 60 * 2 * math.pi
		return angle
	end)
	return function()
		stop()
		viewport:SetAttribute("Spinning", nil)
		applyView(viewport)
	end
end

-- Gentle back-and-forth sway (for a hovered button). The framing already leaves room for it.
function Icon3D.wobble(viewport: ViewportFrame): () -> ()
	local t = 0
	return animate(viewport, function(dt)
		t += dt
		return math.sin(t * 5) * math.rad(14)
	end)
end

return Icon3D
