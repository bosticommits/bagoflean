--!strict
-- The "Lucien stage": a full-screen theatre that the intro (IntroScene) and the tutorial's step
-- scenes put on. Built to the Figma storyboard (https://www.figma.com/design/UgevrNkTl6lvragsvDCfmm,
-- frames 5:74 to 5:229 and 6:74): velvet curtains with a gold hem under a scalloped valance, two
-- spotlights that sweep in and cross, a wooden stage floor, a title, Director Lucien Vale (the
-- R15 rig from LucienRig, in a ViewportFrame) and his dialogue box with a button.
--
--   local scene = StageScene.new()       -- curtains closed
--   scene:curtains("peek")               -- "closed", "peek" (a narrow gap) or "open" (tied back)
--   scene:spotlights()                   -- the two cones sweep in and cross
--   scene:title("HOLLYWOOD RNG")
--   scene:enter(true)                    -- Lucien walks in from the right (false: just there)
--   scene:gesture("wave")                -- a one-shot clip (wave, twirl), then back to his loop
--   local how = scene:say(lines, "Let's begin!")  -- yields; "done", or "closed" if destroyed
--   scene:close()                        -- fades out and cleans everything up
--
-- `scene.content` is an empty full-stage layer above the backdrop and under Lucien, for a step's
-- own pictures (the intro's logo). The art sits in a full-bleed ScreenGui (ScreenInsets None,
-- covering the top bar); the dialogue, Skip and the button sit in a second one inside the safe
-- area, so no notch hides them. With reduced motion on, nothing sweeps, spins or walks: things
-- just appear in place.
--
-- Text is never cut off: each line is fitted to its box (Shared/Dialogue) with an exact text
-- size, and split into pages (tap for the next) when it still would not fit.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")

local Dialogue = require(ReplicatedStorage.Shared.Dialogue)
local LucienRig = require(ReplicatedStorage.Shared.Models.LucienRig)
local Music = require(script.Parent.Music)
local Sfx = require(script.Parent.Sfx)
local UiKit = require(script.Parent.UiKit)

-- Image textures made from the Figma art (art/blender/intro_textures.py, art/ui/intro/).
local ART = {
	curtain = 0,
	valance = 0,
	spot = 0,
}

-- Figma colors.
local BACKDROP_TOP = Color3.fromRGB(32, 34, 74)
local BACKDROP_BOTTOM = Color3.fromRGB(10, 12, 26)
local FLOOR_TOP = Color3.fromRGB(110, 70, 34)
local FLOOR_BOTTOM = Color3.fromRGB(40, 24, 14)
local VELVET = Color3.fromRGB(176, 30, 52)
local VALANCE = Color3.fromRGB(128, 20, 40)
local GOLD = Color3.fromRGB(245, 184, 46)
local CREAM = Color3.fromRGB(255, 244, 200)
local DIALOGUE_BG = Color3.fromRGB(22, 26, 52)

-- Stage geometry, as fractions of the screen (Figma 1280 x 720).
local FLOOR_Y = 550 / 720
local VALANCE_H = 92 / 720
local CURTAIN_WIDTH = { closed = 0.5, peek = 310 / 1280, open = 150 / 1280 }
local TIEBACK_Y = 0.55
local CHARS_PER_SECOND = 42
local WALK_SPEED = 4 -- studs a second
local FADE = 0.25 -- seconds between two of Lucien's clips

-- Lucien in his viewport: the camera looks at him from the front, framing this much of the stage.
local VIEW_HEIGHT = 9 -- studs from the floor to the top of the viewport
local CAMERA_FOV = 30

export type Line = { text: string, voice: string?, gesture: string? }

local StageScene = {}
StageScene.__index = StageScene

export type Scene = typeof(setmetatable(
	{} :: {
		art: ScreenGui,
		ui: ScreenGui,
		content: Frame,
		_still: boolean,
		_alive: boolean,
		_curtains: { Frame },
		_curtainState: string,
		_tiebacks: { Frame },
		_cones: { Frame },
		_title: TextLabel,
		_view: ViewportFrame,
		_camera: Camera,
		_rig: LucienRig.Rig?,
		_loop: string,
		_oneShot: string?,
		_oneShotAt: number,
		_previous: LucienRig.Pose?,
		_blendAt: number,
		_clock: number,
		_x: number,
		_yaw: number,
		_box: Frame,
		_name: TextLabel,
		_speech: TextLabel,
		_hint: TextLabel,
		_button: TextButton,
		_skip: TextButton,
		_tap: TextButton,
		_k: number,
		_onTap: (() -> ())?,
		_onSkip: (() -> ())?,
		_voice: Sound?,
		_connections: { RBXScriptConnection },
		_restoreHud: () -> (),
	},
	StageScene
))

-- Hides the game HUD while the stage plays: every other ScreenGui under the player's PlayerGui
-- that is on (the HUD, side buttons, timers, gift timers) and Roblox's own leaderboard, backpack
-- and chat. Returns a function that puts back exactly what was on. Fx's confetti (order 20) and
-- the stage's own guis stay. shortcut: a ScreenGui added mid-intro is not hidden; fine for ~30 s.
local function hideHud(stageGui: ScreenGui): () -> ()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local hidden: { ScreenGui } = {}
	for _, child in playerGui:GetChildren() do
		if child:IsA("ScreenGui") and child ~= stageGui and child.Enabled and child.DisplayOrder < stageGui.DisplayOrder then
			child.Enabled = false
			table.insert(hidden, child)
		end
	end
	local core: { [Enum.CoreGuiType]: boolean } = {}
	for _, kind in { Enum.CoreGuiType.PlayerList, Enum.CoreGuiType.Backpack, Enum.CoreGuiType.Chat } do
		local ok, was = pcall(StarterGui.GetCoreGuiEnabled, StarterGui, kind)
		if ok and was then
			core[kind] = true
			pcall(StarterGui.SetCoreGuiEnabled, StarterGui, kind, false)
		end
	end
	return function()
		for _, gui in hidden do
			if gui.Parent ~= nil then
				gui.Enabled = true
			end
		end
		for kind in core do
			pcall(StarterGui.SetCoreGuiEnabled, StarterGui, kind, true)
		end
	end
end

local function reducedMotion(): boolean
	local ok, value = pcall(function()
		return (GuiService :: any).ReducedMotionEnabled
	end)
	return ok and value == true
end

local function frame(parent: Instance, name: string, color: Color3?, z: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color or Color3.new(1, 1, 1)
	f.BackgroundTransparency = if color ~= nil then 0 else 1
	f.ZIndex = z
	f.Parent = parent
	return f
end

local function gradient(parent: GuiObject, top: Color3, bottom: Color3)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(top, bottom)
	g.Rotation = 90
	g.Parent = parent
end

local function tween(object: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?, delay: number?): Tween
	local t = TweenService:Create(object, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out, 0, false, delay or 0), goal)
	t:Play()
	return t
end
StageScene.tween = tween
StageScene.reducedMotion = reducedMotion

-- A tiled texture filling `parent`, or nothing when its art is not uploaded yet.
local function tiled(parent: GuiObject, id: number, z: number): ImageLabel?
	if id == 0 then
		return nil
	end
	local image = Instance.new("ImageLabel")
	image.Name = "Texture"
	image.BackgroundTransparency = 1
	image.Size = UDim2.fromScale(1, 1)
	image.Image = "rbxassetid://" .. id
	image.ScaleType = Enum.ScaleType.Tile
	image.ZIndex = z
	image.Parent = parent
	return image
end

-- One curtain panel: tiled velvet folds (or banded gradient folds until the art is uploaded) and
-- a gold hem. `side` 0 is the left panel, 1 the right.
local function curtain(parent: Instance, side: number, z: number): Frame
	local panel = frame(parent, if side == 0 then "CurtainL" else "CurtainR", VELVET, z)
	panel.AnchorPoint = Vector2.new(side, 0)
	panel.Position = UDim2.fromScale(side, 0)
	panel.Size = UDim2.fromScale(0.5, 1)
	panel.ClipsDescendants = true
	if tiled(panel, ART.curtain, z) == nil then
		local folds = Instance.new("UIGradient")
		local keys = {}
		for i = 0, 12 do
			table.insert(keys, ColorSequenceKeypoint.new(i / 12, if i % 2 == 0 then Color3.fromRGB(110, 110, 110) else Color3.new(1, 1, 1)))
		end
		folds.Color = ColorSequence.new(keys)
		folds.Parent = panel
	end
	local hem = frame(panel, "Hem", GOLD, z + 1)
	hem.AnchorPoint = Vector2.new(0, 1)
	hem.Position = UDim2.fromScale(0, 1)
	hem.Size = UDim2.new(1, 0, 14 / 720, 0)
	-- The inner edge's shadow, so the two panels read as separate drapes when closed.
	local edge = frame(panel, "Edge", Color3.fromRGB(60, 6, 18), z + 1)
	edge.AnchorPoint = Vector2.new(1 - side, 0)
	edge.Position = UDim2.fromScale(1 - side, 0)
	edge.Size = UDim2.new(0, 6, 1, 0)
	edge.BackgroundTransparency = 0.35
	return panel
end

function StageScene.new(): Scene
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local still = reducedMotion()

	local art = Instance.new("ScreenGui")
	art.Name = "LucienStage"
	art.IgnoreGuiInset = true
	art.ScreenInsets = Enum.ScreenInsets.None
	art.ResetOnSpawn = false
	art.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	art.DisplayOrder = 15 -- over the game UI, under Fx's confetti (20)

	local root = frame(art, "Stage", BACKDROP_BOTTOM, 1)
	root.Size = UDim2.fromScale(1, 1)
	root.Active = true -- the world under it takes no clicks
	gradient(root, BACKDROP_TOP, BACKDROP_BOTTOM)

	local floor = frame(root, "Floor", FLOOR_TOP, 2)
	floor.Position = UDim2.fromScale(0, FLOOR_Y)
	floor.Size = UDim2.fromScale(1, 1 - FLOOR_Y)
	gradient(floor, FLOOR_TOP, FLOOR_BOTTOM)
	local lip = frame(floor, "Lip", GOLD, 3)
	lip.Size = UDim2.new(1, 0, 0, 5)

	-- Spotlights: a cone hanging from each top corner, turned round its tip.
	local cones: { Frame } = {}
	for _, side in { -1, 1 } do
		local pivot = frame(root, "Spotlight", nil, 3)
		pivot.AnchorPoint = Vector2.new(0.5, 0.5)
		pivot.Position = UDim2.fromScale(0.5 + side * 0.24, -0.02)
		pivot.Size = UDim2.fromOffset(2, 2)
		pivot.Visible = false
		local cone: GuiObject
		if ART.spot ~= 0 then
			local image = Instance.new("ImageLabel")
			image.BackgroundTransparency = 1
			image.Image = "rbxassetid://" .. ART.spot
			image.ImageColor3 = CREAM
			image.ImageTransparency = 0.25
			cone = image
		else
			local f = frame(pivot, "Cone", CREAM, 3)
			f.BackgroundTransparency = 0.82
			local fade = Instance.new("UIGradient")
			fade.Rotation = 90
			fade.Transparency = NumberSequence.new(0, 0.9)
			fade.Parent = f
			cone = f
		end
		cone.Name = "Cone"
		cone.AnchorPoint = Vector2.new(0.5, 0)
		cone.Position = UDim2.fromScale(0.5, 0.5)
		cone.Size = UDim2.fromScale(0, 0) -- set by layout
		cone.ZIndex = 3
		cone.Parent = pivot
		local pool = frame(root, "Pool", CREAM, 3)
		pool.AnchorPoint = Vector2.new(0.5, 0.5)
		pool.Position = UDim2.fromScale(0.5, FLOOR_Y + 0.07)
		pool.Size = UDim2.fromScale(0.19, 0.07)
		pool.BackgroundTransparency = 1
		UiKit.corner(pool, 999)
		pivot:SetAttribute("Side", side)
		table.insert(cones, pivot)
	end

	local content = frame(root, "Content", nil, 4)
	content.Size = UDim2.fromScale(1, 1)

	-- Lucien. The viewport covers the stage up to the valance; its bottom sits a little under
	-- the floor's front edge so his feet land on the boards.
	local view = Instance.new("ViewportFrame")
	view.Name = "Lucien"
	view.BackgroundTransparency = 1
	view.BorderSizePixel = 0
	view.BackgroundColor3 = BACKDROP_BOTTOM -- never a pale box if it ever shows
	view.AnchorPoint = Vector2.new(0.5, 1)
	view.Position = UDim2.fromScale(0.5, FLOOR_Y + 0.06)
	view.Size = UDim2.fromScale(1, FLOOR_Y)
	view.Ambient = Color3.fromRGB(150, 140, 160)
	view.LightColor = Color3.fromRGB(255, 240, 215)
	view.LightDirection = Vector3.new(-0.35, -1, 0.55)
	view.ZIndex = 5
	view.Parent = root
	local camera = Instance.new("Camera")
	camera.FieldOfView = CAMERA_FOV
	camera.Parent = view
	view.CurrentCamera = camera

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.Position = UDim2.fromScale(0.5, 92 / 720)
	title.Size = UDim2.fromScale(0.8, 41 / 720)
	title.Font = UiKit.DISPLAY_FONT
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 214, 64)
	title.Text = ""
	title.ZIndex = 6
	title.Parent = root
	UiKit.outline(title, 2.5)

	-- Curtains and valance over everything on the stage.
	local curtains = { curtain(root, 0, 8), curtain(root, 1, 8) }
	local tiebacks: { Frame } = {}
	for side = 0, 1 do
		-- Figma 5:245-5:248: a gold bar with a drop-shaped tassel, at the curtain's inner edge.
		local hook = frame(root, "Tieback", nil, 10)
		hook.AnchorPoint = Vector2.new(0.5, 0.5)
		hook.Size = UDim2.fromScale(40 / 1280, 44 / 720)
		hook.Visible = false
		local bar = frame(hook, "Bar", GOLD, 10)
		bar.Size = UDim2.fromScale(1, 14 / 44)
		UiKit.corner(bar, 6)
		local tassel = frame(hook, "Tassel", Color3.fromRGB(255, 214, 64), 10)
		tassel.AnchorPoint = Vector2.new(0.5, 0)
		tassel.Position = UDim2.fromScale(if side == 0 then 0.8 else 0.2, 12 / 44)
		tassel.Size = UDim2.fromScale(22 / 40, 30 / 44)
		UiKit.corner(tassel, 999)
		hook:SetAttribute("Side", side)
		table.insert(tiebacks, hook)
	end
	local valance = frame(root, "Valance", VALANCE, 11)
	valance.Size = UDim2.fromScale(1, VALANCE_H)
	valance.BackgroundTransparency = if ART.valance ~= 0 then 1 else 0
	local valanceTexture = tiled(valance, ART.valance, 11)
	if valanceTexture == nil then
		local rail = frame(valance, "Rail", GOLD, 12)
		rail.Position = UDim2.fromScale(0, 58 / 92)
		rail.Size = UDim2.fromScale(1, 8 / 92)
		gradient(valance, Color3.fromRGB(150, 26, 46), VALANCE)
	end

	-- Controls, in the safe area.
	local ui = Instance.new("ScreenGui")
	ui.Name = "LucienStageUi"
	ui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	ui.ResetOnSpawn = false
	ui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	ui.DisplayOrder = 16

	-- Tapping anywhere moves the dialogue on.
	local tap = Instance.new("TextButton")
	tap.Name = "Tap"
	tap.Text = ""
	tap.BackgroundTransparency = 1
	tap.Size = UDim2.fromScale(1, 1)
	tap.ZIndex = 1
	tap.Parent = ui

	local box = frame(ui, "Dialogue", DIALOGUE_BG, 2)
	box.AnchorPoint = Vector2.new(0.5, 1)
	box.Visible = false
	box.BackgroundTransparency = 0.04
	UiKit.corner(box, 18)
	UiKit.border(box, 4, GOLD)
	local name = Instance.new("TextLabel")
	name.Name = "Name"
	name.BackgroundTransparency = 1
	name.Font = UiKit.DISPLAY_FONT
	name.TextColor3 = GOLD
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Text = "Director Lucien Vale"
	name.ZIndex = 3
	name.Parent = box
	local speech = Instance.new("TextLabel")
	speech.Name = "Speech"
	speech.BackgroundTransparency = 1
	speech.Font = UiKit.BODY_FONT
	speech.TextColor3 = UiKit.WHITE
	speech.TextXAlignment = Enum.TextXAlignment.Left
	speech.TextYAlignment = Enum.TextYAlignment.Top
	speech.TextWrapped = true
	speech.Text = ""
	speech.ZIndex = 3
	speech.Parent = box
	local hint = Instance.new("TextLabel")
	hint.Name = "TapHint"
	hint.BackgroundTransparency = 1
	hint.Font = UiKit.DISPLAY_FONT
	hint.TextColor3 = GOLD
	hint.Text = "▶"
	hint.AnchorPoint = Vector2.new(1, 1)
	hint.Visible = false
	hint.ZIndex = 3
	hint.Parent = box

	local button = UiKit.makeButton(ui, "", UiKit.GREEN, UDim2.fromOffset(200, 64))
	button.Name = "Next"
	button.AnchorPoint = Vector2.new(1, 1)
	button.Visible = false
	button.ZIndex = 4
	local skip = UiKit.makeButton(ui, "Skip", UiKit.NAVY, UDim2.fromOffset(96, 44))
	skip.Name = "Skip"
	skip.AnchorPoint = Vector2.new(1, 0)
	skip.ZIndex = 4

	local self = setmetatable({
		art = art,
		ui = ui,
		content = content,
		_still = still,
		_alive = true,
		_curtains = curtains,
		_curtainState = "closed",
		_tiebacks = tiebacks,
		_cones = cones,
		_title = title,
		_view = view,
		_camera = camera,
		_rig = nil,
		_loop = "idle",
		_oneShot = nil,
		_oneShotAt = 0,
		_previous = nil,
		_blendAt = -math.huge,
		_clock = 0,
		_x = 0,
		_yaw = 0,
		_box = box,
		_name = name,
		_speech = speech,
		_hint = hint,
		_button = button,
		_skip = skip,
		_tap = tap,
		_k = 1,
		_onTap = nil,
		_onSkip = nil,
		_voice = nil,
		_connections = {},
		_restoreHud = hideHud(art),
	}, StageScene)

	tap.Activated:Connect(function()
		local fn = self._onTap
		if fn ~= nil then
			fn()
		end
	end)
	skip.Activated:Connect(function()
		local fn = self._onSkip or self._onTap
		if fn ~= nil then
			fn()
		end
	end)

	art.Parent = playerGui
	ui.Parent = playerGui
	table.insert(self._connections, art:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:_layout()
	end))
	table.insert(self._connections, RunService.RenderStepped:Connect(function(dt: number)
		self:_step(dt)
	end))
	self:_layout()
	return self
end

-- Sizes everything that needs pixels: valance tiles, cones, the dialogue and its buttons.
function StageScene._layout(self: Scene)
	local area = self.art.AbsoluteSize
	if area.X < 1 then
		return
	end
	local safe = self.ui.AbsoluteSize
	if safe.X < 1 then
		safe = area
	end
	-- UI scale: Figma's 720-high frame, never smaller than phones can read.
	local k = math.clamp(area.Y / 720, 0.72, 1.4)
	self._k = k

	local valanceH = area.Y * VALANCE_H
	local valance = self.art:FindFirstChild("Valance", true)
	local texture = if valance ~= nil then valance:FindFirstChild("Texture") :: ImageLabel? else nil
	if texture ~= nil then
		texture.TileSize = UDim2.fromOffset(valanceH * 80 / 92, valanceH)
	end
	for _, panel in self._curtains do
		local folds = panel:FindFirstChild("Texture") :: ImageLabel?
		if folds ~= nil then
			folds.TileSize = UDim2.fromOffset(math.max(24, area.Y * 50 / 706), area.Y)
		end
	end
	local coneH = area.Y * 0.92
	for _, pivot in self._cones do
		local cone = pivot:FindFirstChild("Cone") :: GuiObject
		cone.Size = UDim2.fromOffset(coneH * 240 / 640, coneH)
	end

	-- Dialogue: Figma 760 x 137 at the bottom middle, the button to its right.
	local buttonW, buttonH = math.floor(229 * k), math.floor(72 * k)
	local gap = math.floor(16 * k)
	local narrow = safe.X < 700 -- phone portrait: the box takes the full width, the button sits above it
	local boxW = if narrow then safe.X - gap * 2 else math.min(math.floor(760 * k), safe.X - buttonW - gap * 3)
	local boxH = math.floor((if narrow then 170 else 137) * k)
	local boxCentre = if narrow then safe.X / 2 else (safe.X - buttonW - gap) / 2
	if boxCentre - boxW / 2 < gap then
		boxCentre = gap + boxW / 2
	end
	self._box.Position = UDim2.fromOffset(boxCentre, safe.Y - math.floor(14 * k))
	self._box.Size = UDim2.fromOffset(boxW, boxH)
	local pad = math.floor(30 * k)
	self._name.Position = UDim2.fromOffset(pad, math.floor(16 * k))
	self._name.Size = UDim2.fromOffset(boxW - pad * 2, math.floor(30 * k))
	self._name.TextSize = math.floor(24 * k)
	self._speech.Position = UDim2.fromOffset(pad, math.floor(52 * k))
	self._speech.Size = UDim2.fromOffset(boxW - pad * 2, boxH - math.floor(64 * k))
	self._hint.Position = UDim2.new(1, -math.floor(12 * k), 1, -math.floor(6 * k))
	self._hint.Size = UDim2.fromOffset(math.floor(24 * k), math.floor(24 * k))
	self._hint.TextSize = math.floor(20 * k)
	self._button.Size = UDim2.fromOffset(buttonW, buttonH)
	self._button.Position = UDim2.new(1, -gap, 1, -(if narrow then boxH + math.floor(28 * k) else math.floor(48 * k)))
	UiKit.textConstraint(self._button, math.floor(34 * k))
	self._skip.Size = UDim2.fromOffset(math.floor(96 * k), math.floor(44 * k))
	self._skip.Position = UDim2.new(1, -math.floor(24 * k), 0, valanceH - math.max(0, area.Y - safe.Y) / 2 - math.floor(6 * k))
	UiKit.textConstraint(self._skip, math.floor(22 * k))

	-- The camera keeps Lucien's height the same share of the screen on any shape.
	local distance = (VIEW_HEIGHT / 2) / math.tan(math.rad(CAMERA_FOV / 2))
	self._camera.CFrame = CFrame.lookAt(Vector3.new(0, VIEW_HEIGHT / 2 - 0.4, -distance), Vector3.new(0, VIEW_HEIGHT / 2 - 0.4, 0))
	self:_placeCurtains(self._curtainState)
end

-- Where the curtains' tiebacks hang for a state.
function StageScene._placeCurtains(self: Scene, state: string)
	local width = CURTAIN_WIDTH[state] or 0.5
	for i, hook in self._tiebacks do
		local side = i - 1
		hook.Position = UDim2.fromScale(if side == 0 then width else 1 - width, TIEBACK_Y)
		hook.Visible = state == "open"
	end
end

-- Opens or closes the curtains: "closed", "peek" (a narrow gap, Figma 5:121) or "open" (tied
-- back, Figma 5:166). Opening overshoots a little and settles. Returns how long it takes.
function StageScene.curtains(self: Scene, state: string): number
	local width = CURTAIN_WIDTH[state] or 0.5
	local opening = width < (CURTAIN_WIDTH[self._curtainState] or 0.5)
	self._curtainState = state
	local seconds = if self._still then 0 else (if opening then 1.1 else 0.7)
	for _, panel in self._curtains do
		if seconds == 0 then
			panel.Size = UDim2.fromScale(width, 1)
		else
			tween(panel, seconds, { Size = UDim2.fromScale(width, 1) }, if opening then Enum.EasingStyle.Back else Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		end
	end
	if opening then
		Sfx.play("introCurtain")
	end
	-- Tiebacks show once the drapes are gathered.
	for _, hook in self._tiebacks do
		hook.Visible = false
	end
	if state == "open" then
		task.delay(seconds * 0.7, function()
			if self._alive and self._curtainState == "open" then
				self:_placeCurtains("open")
			end
		end)
	end
	return seconds
end

-- The spotlights sweep in from outside and cross on the stage, then sway gently.
function StageScene.spotlights(self: Scene)
	for _, pivot in self._cones do
		local side = pivot:GetAttribute("Side") :: number
		-- Without the cone art the fallback is a plain pale rectangle, so there is no cone at all.
		local cone = pivot:FindFirstChild("Cone")
		if cone ~= nil and cone:IsA("ImageLabel") then
			pivot.Visible = true
		end
		-- Figma: each cone leans 27 degrees in toward the middle.
		local rest = side * 27
		if self._still then
			pivot.Rotation = rest
		else
			pivot.Rotation = -side * 40
			tween(pivot, 1.1, { Rotation = rest }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		end
	end
	local pools = (self.art:FindFirstChild("Stage") :: Frame):GetChildren()
	for _, pool in pools do
		if pool.Name == "Pool" and pool:IsA("Frame") then
			tween(pool, 0.6, { BackgroundTransparency = 0.78 }, nil, nil, if self._still then 0 else 0.8)
		end
	end
end

function StageScene.title(self: Scene, text: string)
	self._title.Text = text
end

-- Lucien comes on stage: walks in from the right and turns to the front (or, with `walk` false
-- or reduced motion, is simply there).
function StageScene.enter(self: Scene, walk: boolean)
	if self._rig == nil then
		self._rig = LucienRig.build(self._view)
	end
	if not walk or self._still then
		self._x, self._yaw = 0, 0
		self:lucien("idle")
		return
	end
	-- From just inside the right curtain (screen right is the world's -X, seen from the front).
	-- The camera shows VIEW_HEIGHT studs top to bottom, so half the width is that times the
	-- viewport's shape.
	local area = self.art.AbsoluteSize
	local halfWidth = VIEW_HEIGHT / 2 * area.X / math.max(1, area.Y * FLOOR_Y)
	local startX = -math.min(halfWidth * 0.75, 9)
	self._x, self._yaw = startX, -90
	self:lucien("walk")
	local seconds = math.abs(startX) / WALK_SPEED
	local started = os.clock()
	while self._alive and os.clock() - started < seconds do
		self._x = startX * (1 - (os.clock() - started) / seconds)
		task.wait()
	end
	self._x = 0
	self:lucien("idle")
	-- Turn to face the audience.
	local turnStart = os.clock()
	while self._alive and os.clock() - turnStart < 0.35 do
		self._yaw = -90 * (1 - (os.clock() - turnStart) / 0.35)
		task.wait()
	end
	self._yaw = 0
end

-- His looping clip: "idle", "talk" or "walk".
function StageScene.lucien(self: Scene, clip: string)
	if self._loop == clip then
		return
	end
	self._previous = self:_pose()
	self._blendAt = self._clock
	self._loop = clip
end

-- A one-shot clip ("wave", "twirl"); his loop carries on after it.
function StageScene.gesture(self: Scene, clip: string)
	if LucienRig.Clips[clip] == nil then
		return
	end
	self._previous = self:_pose()
	self._blendAt = self._clock
	self._oneShot = clip
	self._oneShotAt = self._clock
end

function StageScene._pose(self: Scene): LucienRig.Pose
	local clips = LucienRig.Clips :: { [string]: LucienRig.Clip }
	local shot = self._oneShot
	local pose: LucienRig.Pose
	if shot ~= nil then
		local clip = clips[shot]
		local t = self._clock - self._oneShotAt
		if t >= clip.duration then
			self._oneShot = nil
			self._previous = LucienRig.sample(clip, clip.duration)
			self._blendAt = self._clock
			pose = LucienRig.sample(clips[self._loop], self._clock)
		else
			pose = LucienRig.sample(clip, t)
		end
	else
		pose = LucienRig.sample(clips[self._loop], self._clock)
	end
	local previous = self._previous
	local w = (self._clock - self._blendAt) / FADE
	if previous ~= nil and w < 1 then
		pose = LucienRig.blend(previous, pose, math.max(w, 0))
	end
	return pose
end

function StageScene._step(self: Scene, dt: number)
	self._clock += dt
	local rig = self._rig
	if rig ~= nil then
		local base = CFrame.new(self._x, 0, 0) * CFrame.Angles(0, math.rad(self._yaw), 0)
		LucienRig.apply(rig, base, self:_pose())
	end
	if not self._still then
		for _, pivot in self._cones do
			if pivot.Visible and self._clock > 2 then
				-- Once the sweep has landed, a slow sway that fades in.
				local side = pivot:GetAttribute("Side") :: number
				local amount = math.clamp((self._clock - 2) / 2, 0, 1) * 3
				pivot.Rotation = side * 27 + math.sin(self._clock * 0.9 + side) * amount
			end
		end
	end
end

local function measure(font: Enum.Font): Dialogue.Measure
	return function(text: string, size: number, width: number): Vector2
		return TextService:GetTextSize(text, size, font, Vector2.new(width, 10000))
	end
end

-- Lucien says `lines`, one at a time: each types out (with his voice, and his `gesture` if it has
-- one) and waits for a tap; a line too long for the box goes over several pages. With `final`, the
-- last line shows a button with that text instead, and `say` returns once it is pressed. Skip
-- skips the current line. Returns "done", or "closed" if the scene was closed meanwhile.
function StageScene.say(self: Scene, lines: { Line }, final: string?): string
	local box, speech = self._box, self._speech
	if not box.Visible then
		box.Visible = true
		if not self._still then
			local pop = Instance.new("UIScale")
			pop.Scale = 0.85
			pop.Parent = box
			tween(pop, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
			task.delay(0.35, function()
				pop:Destroy()
			end)
		end
	end
	local k = self._k
	for index, line in lines do
		if not self._alive then
			return "closed"
		end
		local last = index == #lines
		local pages, size = Dialogue.fit(line.text, speech.AbsoluteSize, math.floor(22 * k), math.max(13, math.floor(15 * k)), measure(speech.Font))
		speech.TextSize = size
		local voice = self._voice
		if voice ~= nil then
			voice:Stop()
		end
		self._voice = if line.voice ~= nil then Sfx.play(line.voice) else nil
		if line.voice ~= nil then
			Music.duck(9)
		end
		if line.gesture ~= nil then
			self:gesture(line.gesture)
		end
		self:lucien("talk")
		for page, text in pages do
			local finalPage = last and page == #pages
			speech.Text = text
			speech.MaxVisibleGraphemes = 0
			self._hint.Visible = false
			self._button.Visible = false
			local total = utf8.len(text) or #text
			local typed = 0
			local done = false
			local advance = false
			self._onTap = function()
				if not done then
					done = true
				elseif not finalPage or final == nil then
					advance = true
				end
			end
			self._onSkip = function()
				done, advance = true, true
			end
			while self._alive and not done do
				typed += task.wait() * CHARS_PER_SECOND
				if typed >= total then
					done = true
				else
					speech.MaxVisibleGraphemes = math.floor(typed)
				end
			end
			speech.MaxVisibleGraphemes = -1
			if finalPage and final ~= nil then
				local pressed = false
				self._button.Text = final
				self._button.Visible = true
				local connection = self._button.Activated:Connect(function()
					pressed = true
				end)
				self._onSkip = function()
					pressed = true
				end
				if not self._still then
					local pop = Instance.new("UIScale")
					pop.Scale = 0.6
					pop.Parent = self._button
					tween(pop, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
				end
				while self._alive and not pressed do
					task.wait()
					-- He finishes talking before he goes quiet.
					local playing = self._voice
					if playing == nil or not playing.IsPlaying then
						self:lucien("idle")
					end
				end
				connection:Disconnect()
				advance = true
			end
			self._hint.Visible = not finalPage
			while self._alive and not advance do
				task.wait()
				local playing = self._voice
				if playing == nil or not playing.IsPlaying then
					self:lucien("idle")
				end
			end
			if not self._alive then
				return "closed"
			end
		end
	end
	self._onTap, self._onSkip = nil, nil
	self._hint.Visible = false
	self._button.Visible = false
	self:lucien("idle")
	return "done"
end

-- While no dialogue runs, Skip and taps call `fn` (the intro skips its logo with it).
function StageScene.onSkip(self: Scene, fn: (() -> ())?)
	self._onSkip = fn
	self._onTap = nil
end

function StageScene.isOpen(self: Scene): boolean
	return self._alive
end

-- Fades the stage out and removes it.
function StageScene.close(self: Scene)
	if not self._alive then
		return
	end
	self._alive = false
	self._restoreHud()
	local voice = self._voice
	if voice ~= nil then
		voice:Stop()
	end
	self.ui:Destroy()
	local seconds = if self._still then 0 else 0.45
	for _, panel in self._curtains do
		if seconds > 0 then
			tween(panel, seconds, { Size = UDim2.fromScale(0, 1) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end
	end
	task.delay(seconds, function()
		for _, connection in self._connections do
			connection:Disconnect()
		end
		self.art:Destroy()
	end)
	if seconds > 0 then
		local root = self.art:FindFirstChild("Stage") :: Frame
		tween(root, seconds, { BackgroundTransparency = 1 })
		for _, d in root:GetDescendants() do
			if d:IsA("GuiObject") then
				if d:IsA("ImageLabel") then
					tween(d, seconds, { ImageTransparency = 1 })
				elseif d:IsA("TextLabel") then
					tween(d, seconds, { TextTransparency = 1 })
				elseif d:IsA("ViewportFrame") then
					tween(d, seconds, { ImageTransparency = 1 })
				end
				if d.BackgroundTransparency < 1 then
					tween(d, seconds, { BackgroundTransparency = 1 })
				end
			end
		end
	end
end

return StageScene
