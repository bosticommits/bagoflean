--!strict
-- Small helpers shared by the screens: colors, labels, buttons, panels, toasts, layout.
-- The look follows the design kit (ART_STYLE.md section 10): navy panels with colored title bars,
-- thick dark outlines, chunky bright buttons and outlined white display text.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Actors = require(ReplicatedStorage.Shared.Actors)
local Icon3D = require(script.Parent.Icon3D)
local Sfx = require(script.Parent.Sfx)

local UiKit = {}

-- Palette from the design kit and ART_STYLE.md: navy panels, near-black outlines, bright fills.
UiKit.INK = Color3.fromRGB(11, 15, 31) -- every outline and text stroke
UiKit.NAVY = Color3.fromRGB(27, 35, 64)
UiKit.DARK = Color3.fromRGB(20, 26, 51)
UiKit.PANEL = UiKit.NAVY
UiKit.ROW = Color3.fromRGB(42, 50, 85)
UiKit.WHITE = Color3.new(1, 1, 1)
UiKit.MUTED = Color3.fromRGB(169, 177, 204)
UiKit.FAINT = Color3.fromRGB(107, 115, 147) -- locked and unknown text
UiKit.GOLD = Color3.fromRGB(255, 210, 63) -- Cash, rewards and highlights
UiKit.AWARD_GOLD = Color3.fromRGB(245, 184, 46)
UiKit.GREEN = Color3.fromRGB(63, 203, 69) -- go / claim buttons
UiKit.CASH_GREEN = Color3.fromRGB(124, 240, 138) -- "+$X" pops
UiKit.RED = Color3.fromRGB(200, 32, 47) -- carpet red
UiKit.CLOSE_RED = Color3.fromRGB(229, 38, 47)
UiKit.WARN = Color3.fromRGB(255, 138, 102) -- "needs Fame" text
UiKit.BLUE = Color3.fromRGB(46, 134, 222)
UiKit.PURPLE = Color3.fromRGB(160, 77, 255)
UiKit.TEAL = Color3.fromRGB(32, 178, 190)
UiKit.BURGUNDY = Color3.fromRGB(122, 31, 43)
UiKit.CREAM = Color3.fromRGB(244, 231, 207)
UiKit.FRESH_GREEN = Color3.fromRGB(91, 191, 90)
UiKit.DISABLED = Color3.fromRGB(74, 82, 114)
UiKit.TAB_OFF = Color3.fromRGB(52, 64, 106)

UiKit.DISPLAY_FONT = Enum.Font.FredokaOne -- titles, numbers, buttons
UiKit.BODY_FONT = Enum.Font.GothamBold -- labels and help text

UiKit.GENRE_COLORS = {
	Action = Color3.fromRGB(235, 120, 60),
	Comedy = Color3.fromRGB(240, 205, 60),
	Horror = Color3.fromRGB(150, 90, 200),
	Romance = Color3.fromRGB(235, 100, 150),
	["Sci-Fi"] = Color3.fromRGB(70, 190, 230),
} :: { [string]: Color3 }

-- The Icon tier is prismatic: a rainbow for gradients, strokes and banners.
UiKit.RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 46)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 194, 26)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(76, 199, 100)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(58, 141, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(160, 77, 255)),
})

function UiKit.corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

-- Caps scaled text size. Calling it again updates the cap instead of stacking a second constraint.
function UiKit.textConstraint(label: TextLabel | TextButton, maxSize: number)
	local c = label:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
	c.MaxTextSize = maxSize
	c.Parent = label
end

-- Thick dark outline around an object's edge (frames, buttons, rows).
function UiKit.border(parent: GuiObject, thickness: number?, color: Color3?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Outline"
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = color or UiKit.INK
	stroke.Thickness = thickness or 3
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = parent
	return stroke
end

-- Cartoon outlined text: the dark stroke around the letters that keeps them readable on any color.
function UiKit.outline(label: TextLabel | TextButton, thickness: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Name = "TextOutline"
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Color = UiKit.INK
	stroke.Thickness = thickness or 2
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label
	return stroke
end

function UiKit.makeLabel(parent: Instance, text: string, color: Color3, size: UDim2, position: UDim2?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = size
	label.Position = position or UDim2.new()
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Font = UiKit.BODY_FONT
	label.Parent = parent
	UiKit.textConstraint(label, 28)
	return label
end

-- Big outlined display text (titles, Cash, results).
function UiKit.makeTitle(parent: Instance, text: string, color: Color3, size: UDim2, position: UDim2?, strokeThickness: number?): TextLabel
	local label = UiKit.makeLabel(parent, text, color, size, position)
	label.Font = UiKit.DISPLAY_FONT
	UiKit.outline(label, strokeThickness or 2.5)
	return label
end

-- Chunky button: bright fill, dark outline, outlined white label and a darker lower band.
function UiKit.makeButton(parent: Instance, text: string, color: Color3, size: UDim2, position: UDim2?): TextButton
	local button = Instance.new("TextButton")
	button.AutoButtonColor = true
	button.BackgroundColor3 = color
	button.Size = size
	button.Position = position or UDim2.new()
	button.Text = text
	button.TextColor3 = UiKit.WHITE
	button.TextScaled = true
	button.Font = UiKit.DISPLAY_FONT
	button.Parent = parent
	UiKit.corner(button, 12)
	UiKit.textConstraint(button, 26)
	UiKit.border(button, 3)
	UiKit.outline(button, 2)
	-- Shading: full color on top, a slightly darker lower band (the kit's "chunky" bevel).
	local shade = Instance.new("UIGradient")
	shade.Name = "Shade"
	shade.Rotation = 90
	shade.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.7, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.74, Color3.fromRGB(205, 205, 205)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(205, 205, 205)),
	})
	shade.Parent = button
	-- Every button clicks, unless it plays its own sound (set the "Silent" attribute).
	button.Activated:Connect(function()
		if not button:GetAttribute("Silent") then
			Sfx.play("click")
		end
	end)
	return button
end

-- Grows a little under the pointer and dips when pressed, like the reference games' buttons.
-- `onHover` runs with true/false as the pointer enters and leaves.
function UiKit.bounce(button: GuiButton, onHover: ((boolean) -> ())?)
	local scale = Instance.new("UIScale")
	scale.Parent = button
	local function to(value: number)
		TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = value }):Play()
	end
	button.MouseEnter:Connect(function()
		to(1.08)
		if onHover then
			onHover(true)
		end
	end)
	button.MouseLeave:Connect(function()
		to(1)
		if onHover then
			onHover(false)
		end
	end)
	button.MouseButton1Down:Connect(function()
		to(0.92)
	end)
	button.MouseButton1Up:Connect(function()
		to(1.04)
	end)
end

-- Floating picture button, like the reference games: a big outlined 3D icon (IconModels id)
-- with no box behind it, and a chunky outlined white label overlapping its bottom edge. Badges
-- and chips go on it like on any button.
function UiKit.makeIconTile(parent: Instance, iconId: string, text: string, size: UDim2, position: UDim2?): TextButton
	local tile = Instance.new("TextButton")
	tile.Name = text .. "Button"
	tile.AutoButtonColor = false
	tile.BackgroundTransparency = 1
	tile.Size = size
	tile.Position = position or UDim2.new()
	tile.Text = ""
	tile.Parent = parent
	UiKit.corner(tile, 18) -- rounds the tutorial's highlight ring

	local art = Instance.new("Frame")
	art.Name = "Art"
	art.BackgroundTransparency = 1
	art.AnchorPoint = Vector2.new(0.5, 0)
	art.Position = UDim2.fromScale(0.5, 0)
	art.Size = UDim2.fromScale(0.86, 0.8)
	art.Parent = tile
	local viewport = Icon3D.outlined(art, iconId)

	local label = UiKit.makeTitle(tile, text, UiKit.WHITE, UDim2.fromScale(1.3, 0.34), UDim2.fromScale(-0.15, 0.64), 3)
	label.Name = "Label"
	label.ZIndex = tile.ZIndex + 5
	UiKit.textConstraint(label, 24)

	local stopWobble: (() -> ())? = nil
	UiKit.bounce(tile, function(hovered)
		if stopWobble ~= nil then
			stopWobble()
			stopWobble = nil
		end
		if hovered then
			stopWobble = Icon3D.wobble(viewport)
		end
	end)
	tile.Activated:Connect(function()
		if not tile:GetAttribute("Silent") then
			Sfx.play("click")
		end
	end)
	return tile
end

-- Small green pill on a button's top corner ("6/63", "86%"), like the reference Rebirth chip.
-- Pass nil to hide it.
function UiKit.chip(button: GuiObject, text: string?)
	local chip = button:FindFirstChild("Chip") :: TextLabel?
	if text == nil then
		if chip ~= nil then
			chip.Visible = false
		end
		return
	end
	if chip == nil then
		local created = UiKit.makeTitle(button, "", UiKit.WHITE, UDim2.fromOffset(52, 22), UDim2.new(1, -30, 0, -6), 1.5)
		created.Name = "Chip"
		created.BackgroundTransparency = 0
		created.BackgroundColor3 = UiKit.GREEN
		created.ZIndex = button.ZIndex + 6
		UiKit.corner(created, 8)
		UiKit.border(created, 2)
		UiKit.textConstraint(created, 16)
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 4)
		pad.PaddingRight = UDim.new(0, 4)
		pad.Parent = created
		chip = created
	end
	assert(chip ~= nil)
	chip.Text = text
	chip.Visible = true
end

-- Green square "+" button (next to a currency, opens the shop).
function UiKit.makePlusButton(parent: Instance, size: number, position: UDim2): TextButton
	local plus = UiKit.makeButton(parent, "+", UiKit.GREEN, UDim2.fromOffset(size, size), position)
	plus.Name = "Plus"
	UiKit.corner(plus, 6)
	UiKit.textConstraint(plus, math.floor(size * 0.8))
	return plus
end

-- Breathing scale on something that wants a tap (a CLAIM button, today's reward). Stops when the
-- object is destroyed.
function UiKit.pulse(object: GuiObject, to: number?)
	local scale = Instance.new("UIScale")
	scale.Name = "Pulse"
	scale.Parent = object
	local tween = TweenService:Create(scale, TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = to or 1.06 })
	tween:Play()
	scale.Destroying:Connect(function()
		tween:Cancel()
	end)
end

-- Green tick drawn from two outlined bars (claimed days, finished requests), filling `parent`'s
-- middle.
function UiKit.tick(parent: GuiObject, zIndex: number): Frame
	local holder = Instance.new("Frame")
	holder.Name = "Tick"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromScale(0.62, 0.62)
	holder.ZIndex = zIndex
	holder.Parent = parent
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.Parent = holder
	local function bar(x: number, y: number, length: number, rotation: number)
		local piece = Instance.new("Frame")
		piece.AnchorPoint = Vector2.new(0.5, 0.5)
		piece.Position = UDim2.fromScale(x, y)
		piece.Size = UDim2.fromScale(length, 0.2)
		piece.Rotation = rotation
		piece.BackgroundColor3 = UiKit.GREEN
		piece.ZIndex = zIndex
		piece.Parent = holder
		UiKit.corner(piece, 4)
		UiKit.border(piece, 3)
	end
	bar(0.28, 0.63, 0.44, 45) -- short stroke, down to the corner
	bar(0.62, 0.49, 0.8, -50) -- long stroke, up to the right
	return holder
end

-- Outlined 3D icon at the left edge of a list row, vertically centred; the row's text starts after
-- it (at size + 16).
function UiKit.rowIcon(row: GuiObject, iconId: string, size: number): Frame
	local art = Instance.new("Frame")
	art.Name = "Icon"
	art.BackgroundTransparency = 1
	art.AnchorPoint = Vector2.new(0, 0.5)
	art.Position = UDim2.new(0, 8, 0.5, 0)
	art.Size = UDim2.fromOffset(size, size)
	art.ZIndex = row.ZIndex + 1
	art.Parent = row
	Icon3D.outlined(art, iconId)
	return art
end

-- Rarity look for anything showing an actor (key "ActorId:VariantId"): fill and edge in its tier
-- color with a soft top-down shade, and the rainbow edge for the Icon tier, like the Collection.
function UiKit.rarityStyle(frame: GuiObject, key: string, thickness: number)
	local actor = Actors.getActor(string.split(key, ":")[1] or "")
	local tier = if actor ~= nil then Actors.getTier(actor.tier) else nil
	frame.BackgroundColor3 = if tier ~= nil then tier.color:Lerp(UiKit.NAVY, 0.45) else UiKit.DARK
	local outline = UiKit.border(frame, thickness, if tier ~= nil then tier.color else UiKit.INK)
	if tier ~= nil and tier.id == "Icon" then
		outline.Color = UiKit.WHITE
		local rainbow = Instance.new("UIGradient")
		rainbow.Color = UiKit.RAINBOW
		rainbow.Parent = outline
	end
	local shade = Instance.new("UIGradient")
	shade.Rotation = 90
	shade.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(120, 120, 140))
	shade.Parent = frame
end

-- Small portrait tile for an actor key: the 3D figure on its rarity color.
function UiKit.portrait(parent: Instance, key: string, size: UDim2, position: UDim2?): Frame
	local parts = string.split(key, ":")
	local tile = Instance.new("Frame")
	tile.Name = "Portrait"
	tile.Size = size
	tile.Position = position or UDim2.new()
	tile.Parent = parent
	UiKit.corner(tile, 8)
	UiKit.rarityStyle(tile, key, 2)
	if Actors.getActor(parts[1] or "") ~= nil then
		Icon3D.actor(tile, parts[1], parts[2])
	end
	return tile
end

-- Grey a button out (still tappable, so it can explain why) or give it back its color.
function UiKit.setEnabled(button: TextButton, enabled: boolean, color: Color3)
	button.BackgroundColor3 = if enabled then color else UiKit.DISABLED
	button.TextColor3 = if enabled then UiKit.WHITE else UiKit.MUTED
end

-- Tab look: the selected tab is a white chip with navy text, the others dark.
function UiKit.styleTab(button: TextButton, selected: boolean)
	button.BackgroundColor3 = if selected then UiKit.WHITE else UiKit.TAB_OFF
	button.TextColor3 = if selected then UiKit.NAVY else UiKit.WHITE
	local stroke = button:FindFirstChild("TextOutline")
	if stroke ~= nil and stroke:IsA("UIStroke") then
		stroke.Enabled = not selected
	end
end

-- Red notification badge on a button's top corner ("3" or "!"). Pass nil to hide it.
function UiKit.badge(button: GuiObject, text: string?)
	local badge = button:FindFirstChild("Badge") :: TextLabel?
	if text == nil then
		if badge ~= nil then
			badge.Visible = false
		end
		return
	end
	if badge == nil then
		local created = UiKit.makeTitle(button, "", UiKit.WHITE, UDim2.fromOffset(24, 24), UDim2.new(1, -14, 0, -10), 1.5)
		created.Name = "Badge"
		created.BackgroundTransparency = 0
		created.BackgroundColor3 = UiKit.CLOSE_RED
		created.ZIndex = button.ZIndex + 6
		UiKit.corner(created, 12)
		UiKit.border(created, 2)
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 3)
		pad.PaddingBottom = UDim.new(0, 3)
		pad.Parent = created
		badge = created
	end
	assert(badge ~= nil)
	badge.Text = text
	badge.Visible = true
end

-- Bottom-of-screen message that fades after two seconds.
local toastLabel: TextLabel? = nil
local toastToken = 0
function UiKit.toast(gui: ScreenGui, text: string)
	local label = toastLabel
	if label == nil then
		local created = UiKit.makeTitle(gui, "", UiKit.WHITE, UDim2.fromOffset(340, 44), UDim2.new(0.5, -170, 1, -144))
		created.Name = "Toast"
		created.BackgroundTransparency = 0.05
		created.BackgroundColor3 = UiKit.NAVY
		created.ZIndex = 20
		UiKit.corner(created, 12)
		UiKit.border(created, 3)
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 6)
		pad.PaddingBottom = UDim.new(0, 6)
		pad.PaddingLeft = UDim.new(0, 10)
		pad.PaddingRight = UDim.new(0, 10)
		pad.Parent = created
		toastLabel = created
		label = created
	end
	assert(label ~= nil)
	toastToken += 1
	local mine = toastToken
	label.Text = text
	label.Visible = true
	task.delay(2, function()
		if toastToken == mine then
			label.Visible = false
		end
	end)
end

-- Layout ---------------------------------------------------------------------------------------
-- Short screens (phones in landscape) get taller panels so lists have room to breathe.
local COMPACT_HEIGHT = 500

function UiKit.viewport(): Vector2
	local camera = workspace.CurrentCamera
	return if camera ~= nil then camera.ViewportSize else Vector2.new(1280, 720)
end

function UiKit.isCompact(): boolean
	return UiKit.viewport().Y < COMPACT_HEIGHT
end

local function panelSize(): UDim2
	if UiKit.isCompact() then
		return UDim2.fromScale(0.96, 0.92)
	end
	return UDim2.fromScale(0.92, 0.72)
end

-- Calls `apply` now and whenever the screen size changes (rotation, device simulator, window resize).
function UiKit.onViewportChanged(apply: () -> ())
	apply()
	local function hook(camera: Camera?)
		if camera ~= nil then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(apply)
		end
	end
	hook(workspace.CurrentCamera)
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		hook(workspace.CurrentCamera)
		apply()
	end)
end

-- Panels --------------------------------------------------------------------------------------
local exclusivePanels: { Frame } = {}

function UiKit.closePanels()
	for _, panel in exclusivePanels do
		panel.Visible = false
	end
end

-- Opens `panel` (building it first) and closes the other panels; opens nothing if it was open.
function UiKit.togglePanel(panel: Frame, build: () -> ())
	local willOpen = not panel.Visible
	UiKit.closePanels()
	if willOpen then
		build()
		panel.Visible = true
	end
end

-- A centered window with a colored title bar, close button and scrolling list.
-- `topOffset` leaves room under the header for a tab row; `modal` panels sit above the others and
-- are not closed by togglePanel; `bottomReserve` leaves room under the list for a footer;
-- `accent` colors the title bar (burgundy by default).
function UiKit.makePanel(gui: ScreenGui, name: string, title: string, topOffset: number?, modal: boolean?, bottomReserve: number?, accent: Color3?): (Frame, ScrollingFrame, TextLabel)
	local top = topOffset or 60
	local bottom = bottomReserve or 10
	local panel = Instance.new("Frame")
	panel.Name = name
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.BackgroundColor3 = UiKit.PANEL
	panel.BackgroundTransparency = 0.06 -- a hint of the world behind, like the reference games
	panel.Visible = false
	panel.ZIndex = if modal then 5 else 1
	panel.Parent = gui
	UiKit.corner(panel, 16)
	UiKit.border(panel, 4)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(560, 640)
	limit.Parent = panel
	if not modal then
		table.insert(exclusivePanels, panel)
	end

	-- Title bar: rounded on top, square at the bottom, with a dark line under it.
	local titleBar = Instance.new("Frame")
	titleBar.Name = "TitleBar"
	titleBar.BackgroundColor3 = accent or UiKit.BURGUNDY
	titleBar.BorderSizePixel = 0
	titleBar.Size = UDim2.new(1, 0, 0, 54)
	titleBar.Parent = panel
	UiKit.corner(titleBar, 16)
	local squareBottom = Instance.new("Frame")
	squareBottom.Name = "SquareBottom"
	squareBottom.BackgroundColor3 = titleBar.BackgroundColor3
	squareBottom.BorderSizePixel = 0
	squareBottom.AnchorPoint = Vector2.new(0, 1)
	squareBottom.Position = UDim2.fromScale(0, 1)
	squareBottom.Size = UDim2.new(1, 0, 0, 16)
	squareBottom.Parent = titleBar
	titleBar:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
		squareBottom.BackgroundColor3 = titleBar.BackgroundColor3
	end)
	local edge = Instance.new("Frame")
	edge.Name = "Edge"
	edge.BackgroundColor3 = UiKit.INK
	edge.BorderSizePixel = 0
	edge.AnchorPoint = Vector2.new(0, 1)
	edge.Position = UDim2.fromScale(0, 1)
	edge.Size = UDim2.new(1, 0, 0, 4)
	edge.Parent = titleBar

	local header = UiKit.makeTitle(panel, title, UiKit.WHITE, UDim2.new(1, -70, 0, 40), UDim2.fromOffset(16, 6))
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.ZIndex = 2
	local close = UiKit.makeButton(panel, "X", UiKit.CLOSE_RED, UDim2.fromOffset(40, 40), UDim2.new(1, -50, 0, 6))
	close.Name = "Close"
	close.ZIndex = 2
	close.Activated:Connect(function()
		panel.Visible = false
	end)

	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(10, top)
	list.Size = UDim2.new(1, -20, 1, -(top + bottom))
	list.ScrollBarThickness = 6
	list.ScrollBarImageColor3 = UiKit.MUTED
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	-- Room for the row outlines, which draw outside each row.
	local inset = Instance.new("UIPadding")
	inset.PaddingTop = UDim.new(0, 4)
	inset.PaddingLeft = UDim.new(0, 3)
	inset.PaddingBottom = UDim.new(0, 4)
	inset.Parent = list

	-- Slimmer chrome on short screens: smaller header, close button and tab row give the list room.
	-- Re-applied on every open too, because callers add their tab row ("Tabs" or "Agencies") after us.
	local function applyLayout()
		local compact = UiKit.isCompact()
		panel.Size = panelSize()
		local barHeight = if compact then 40 else 54
		titleBar.Size = UDim2.new(1, 0, 0, barHeight)
		-- With a corner icon (UiKit.panelIcon) the title starts after it.
		local headerX = 16
		local icon = panel:FindFirstChild("PanelIcon")
		if icon ~= nil and icon:IsA("Frame") then
			local iconSize = if compact then 58 else 76
			local left = if compact then -10 else -14
			icon.Size = UDim2.fromOffset(iconSize, iconSize)
			icon.Position = UDim2.fromOffset(left, (barHeight - 4) // 2 - iconSize // 2 - 3)
			headerX = left + iconSize + 6
		end
		header.Size = UDim2.new(1, -(54 + headerX), 0, if compact then 30 else 40)
		header.Position = UDim2.fromOffset(headerX, if compact then 5 else 6)
		local closeSize = if compact then 32 else 40
		close.Size = UDim2.fromOffset(closeSize, closeSize)
		close.Position = UDim2.new(1, -(closeSize + 10), 0, (barHeight - 4 - closeSize) // 2)
		local listTop = top
		local tabs = panel:FindFirstChild("Tabs") or panel:FindFirstChild("Agencies")
		if tabs ~= nil and tabs:IsA("Frame") then
			tabs.Position = UDim2.fromOffset(12, if compact then 46 else 62)
			tabs.Size = UDim2.new(1, -24, 0, if compact then 30 else 40)
			listTop = if compact then top - 26 else top
		elseif compact then
			listTop = top - 12
		end
		list.Position = UDim2.fromOffset(10, listTop)
		list.Size = UDim2.new(1, -20, 1, -(listTop + bottom))
	end
	UiKit.onViewportChanged(applyLayout)
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if panel.Visible then
			applyLayout()
		end
	end)
	return panel, list, header
end

-- Big outlined 3D icon poking out of a panel's top-left corner, like the reference games' window
-- art. makePanel's layout sizes it and moves the title to its right.
function UiKit.panelIcon(panel: Frame, header: TextLabel, iconId: string): ViewportFrame
	local old = panel:FindFirstChild("PanelIcon")
	if old ~= nil then
		old:Destroy()
	end
	local holder = Instance.new("Frame")
	holder.Name = "PanelIcon"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(76, 76)
	holder.Position = UDim2.fromOffset(-14, -16)
	holder.ZIndex = header.ZIndex + 1
	holder.Parent = panel
	local viewport = Icon3D.outlined(holder, iconId)
	header.Position = UDim2.fromOffset(68, header.Position.Y.Offset)
	header.Size = UDim2.new(1, -122, 0, header.Size.Y.Offset)
	return viewport
end

function UiKit.clear(list: ScrollingFrame)
	for _, child in list:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
end

-- Turns a row into a plain heading or note: no fill, no outline.
function UiKit.plainRow(row: Frame)
	row.BackgroundTransparency = 1
	local outline = row:FindFirstChild("Outline")
	if outline ~= nil and outline:IsA("UIStroke") then
		outline.Enabled = false
	end
end

function UiKit.addRow(list: ScrollingFrame, order: number, height: number): Frame
	local row = Instance.new("Frame")
	row.LayoutOrder = order
	row.Size = UDim2.new(1, -8, 0, height)
	row.BackgroundColor3 = UiKit.ROW
	row.Parent = list
	UiKit.corner(row, 10)
	UiKit.border(row, 2)
	return row
end

return UiKit
