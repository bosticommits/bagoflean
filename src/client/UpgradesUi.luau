--!strict
-- Upgrade tree: spend Cash on stages, cinema size, offline earnings, Luck, and the clapperboard.
-- A hex tree over the dimmed world (Figma "Upgrade Tree (hex)", frame 3:2): a blue START hex in the
-- middle with one ray per upgrade, a hex per level (UpgradeTree has the layout). Owned levels are
-- blue with a white rim, the next level glows gold (or pulses green when you can afford it), later
-- levels are grey with a padlock, and a crown sits on a maxed ray's last hex. Tapping a hex opens
-- the side card with what it gives and the Buy button. Drag to move around, zoom with the
-- magnifier buttons. The server prices, gates and applies every purchase; this only shows them.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Rebirth = require(ReplicatedStorage.Shared.Rebirth)
local UpgradeTree = require(ReplicatedStorage.Shared.UpgradeTree)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
local ClientState = require(script.Parent.ClientState)
local Hud = require(script.Parent.Hud)
local Icon3D = require(script.Parent.Icon3D)
local Screens = require(script.Parent.Screens)
local Sfx = require(script.Parent.Sfx)
local SideMenu = require(script.Parent.SideMenu)
local UiKit = require(script.Parent.UiKit)

local makeLabel, makeTitle, makeButton = UiKit.makeLabel, UiKit.makeTitle, UiKit.makeButton
local nodeState = UpgradeTree.nodeState
type NodeState = UpgradeTree.NodeState

local UpgradesUi = {}

-- 3D icon for each upgrade chain (IconModels ids).
local ICONS: { [string]: string } = {
	Stages = "stage",
	Cinema = "popcorn",
	Offline = "moneybag",
	Luck = "clover",
	Clap = "clapper",
}

-- Each ray's name (hexes read "Luck III") and the colour of its label at the ray's end.
local RAY_NAMES: { [string]: string } = {
	Stages = "Sound Stage",
	Cinema = "Cinema",
	Offline = "Offline",
	Luck = "Luck",
	Clap = "Clapper",
}
local RAY_COLORS: { [string]: Color3 } = {
	Stages = Color3.fromRGB(255, 156, 82),
	Cinema = Color3.fromRGB(255, 96, 128),
	Offline = Color3.fromRGB(132, 240, 120),
	Luck = Color3.fromRGB(110, 230, 130),
	Clap = Color3.fromRGB(196, 166, 255),
}

-- Colours from the mockup's HexNode component set (2:19).
local OWNED = Color3.fromRGB(44, 140, 240)
local START_BLUE = Color3.fromRGB(36, 116, 228)
local NEXT_FILL = Color3.fromRGB(24, 30, 62)
local LOCKED_FILL = Color3.fromRGB(66, 68, 80)
local LOCKED_RIM = Color3.fromRGB(48, 50, 60)
local LOCK_INK = Color3.fromRGB(34, 36, 44)
local LINK_ON = UiKit.AWARD_GOLD
local LINK_OFF = Color3.fromRGB(58, 60, 72)
local SILHOUETTE = Color3.fromRGB(64, 84, 160)
local TITLE_GREEN = Color3.fromRGB(132, 236, 72)
local TITLE_GREEN_DEEP = Color3.fromRGB(58, 176, 40)
local PRICE_RED = Color3.fromRGB(255, 128, 116)

-- Board geometry, in unzoomed pixels. Hex sizes are circumradii (a hex is sqrt(3) * r wide).
local HEX_R = 50
local START_R = 64
local RIM = 5
local GLOW = 15
local PAD = 340 -- empty board around the tree, so any hex can be dragged out from under the card
local MIN_ZOOM, MAX_ZOOM, ZOOM_STEP = 0.45, 1.4, 0.15
local SQRT3 = math.sqrt(3)

-- Right-hand column (Cash and Fame pills over the card), unscaled.
local SIDE_W, PILLS_H, CARD_H = 300, 43, 252
local SIDE_H = PILLS_H + 16 + CARD_H

-- "$600", "$25K", "$1.5M": node prices have to fit inside the hex.
local function shortCash(amount: number): string
	local function trim(value: number, suffix: string): string
		local text = string.format("%.1f", value)
		text = string.gsub(text, "%.0$", "")
		return "$" .. text .. suffix
	end
	if amount >= 1e9 then
		return trim(amount / 1e9, "B")
	elseif amount >= 1e6 then
		return trim(amount / 1e6, "M")
	elseif amount >= 1e3 then
		return trim(amount / 1e3, "K")
	end
	return "$" .. tostring(amount)
end

local function reducedMotion(): boolean
	local ok, value = pcall(function()
		return (GuiService :: any).ReducedMotionEnabled
	end)
	return ok and value == true
end

-- A pointy-top hexagon of circumradius `r`, centred in `parent`: three opaque bars turned 0, 60
-- and 120 degrees overlap into the hex (no image asset). Never make the bars see-through, or the
-- overlaps show; fade a whole hex inside a CanvasGroup instead.
local function hexShape(parent: Instance, r: number, color: Color3, name: string, z: number): Frame
	local hex = Instance.new("Frame")
	hex.Name = name
	hex.BackgroundTransparency = 1
	hex.AnchorPoint = Vector2.new(0.5, 0.5)
	hex.Position = UDim2.fromScale(0.5, 0.5)
	hex.Size = UDim2.fromOffset(r * 2, r * 2)
	hex.ZIndex = z
	for _, angle in { 0, 60, 120 } do
		local bar = Instance.new("Frame")
		bar.BorderSizePixel = 0
		bar.BackgroundColor3 = color
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.fromScale(0.5, 0.5)
		bar.Size = UDim2.fromOffset(SQRT3 * r, r)
		bar.Rotation = angle
		bar.Parent = hex
	end
	hex.Parent = parent
	return hex
end

local function paintHex(hex: Instance, color: Color3)
	for _, bar in hex:GetChildren() do
		if bar:IsA("Frame") then
			bar.BackgroundColor3 = color
		end
	end
end

-- Straight bar from (x1, y1) to (x2, y2): the links between hexes and the studio silhouette.
local function bar(parent: Instance, x1: number, y1: number, x2: number, y2: number, thickness: number, color: Color3, z: number): Frame
	local dx, dy = x2 - x1, y2 - y1
	local frame = Instance.new("Frame")
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = color
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromOffset((x1 + x2) / 2, (y1 + y2) / 2)
	frame.Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy) + thickness, thickness)
	frame.Rotation = math.deg(math.atan2(dy, dx))
	frame.ZIndex = z
	frame.Parent = parent
	UiKit.corner(frame, thickness / 2)
	return frame
end

-- Flat grey padlock for locked hexes, drawn from frames (cheaper than a 3D icon per hex).
local function padlock(parent: Instance, z: number): Frame
	local lock = Instance.new("Frame")
	lock.Name = "Lock"
	lock.BackgroundTransparency = 1
	lock.AnchorPoint = Vector2.new(0.5, 0.5)
	lock.Position = UDim2.fromScale(0.5, 0.5)
	lock.Size = UDim2.fromOffset(32, 36)
	lock.ZIndex = z
	lock.Parent = parent
	local shackle = Instance.new("Frame")
	shackle.BackgroundTransparency = 1
	shackle.AnchorPoint = Vector2.new(0.5, 0)
	shackle.Position = UDim2.fromScale(0.5, 0)
	shackle.Size = UDim2.fromOffset(20, 26)
	shackle.Parent = lock
	UiKit.corner(shackle, 10)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = LOCK_INK
	stroke.Parent = shackle
	local body = Instance.new("Frame")
	body.BorderSizePixel = 0
	body.BackgroundColor3 = LOCK_INK
	body.AnchorPoint = Vector2.new(0.5, 1)
	body.Position = UDim2.fromScale(0.5, 1)
	body.Size = UDim2.fromOffset(32, 22)
	body.ZIndex = 2
	body.Parent = lock
	UiKit.corner(body, 5)
	local keyhole = Instance.new("Frame")
	keyhole.BorderSizePixel = 0
	keyhole.BackgroundColor3 = LOCKED_FILL
	keyhole.AnchorPoint = Vector2.new(0.5, 0.5)
	keyhole.Position = UDim2.fromScale(0.5, 0.5)
	keyhole.Size = UDim2.fromOffset(5, 9)
	keyhole.Parent = body
	UiKit.corner(keyhole, 2)
	return lock
end

type Node = {
	holder: Frame,
	scale: UIScale,
	glow: CanvasGroup,
	ring: Frame,
	rim: Frame,
	fill: Frame,
	art: Frame,
	lock: Frame,
	name: TextLabel,
	price: TextLabel,
	hit: TextButton,
	link: Frame?,
	crown: Frame?,
	state: NodeState?,
	hasIcon: boolean,
	tweens: { Tween },
	x: number,
	y: number,
}

function UpgradesUi.start(gui: ScreenGui, upgradesButton: TextButton)
	local player = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 15)
	if remotes == nil then
		warn("[UpgradesUi] Remotes folder never arrived")
		return
	end
	local buyUpgrade = remotes:WaitForChild("BuyUpgrade") :: RemoteEvent

	-- Two ScreenGuis above the game UI: the board edge to edge under the top bar and notch
	-- (ScreenInsets None), and the title, card and buttons over it inside the safe area.
	local function layer(name: string, order: number, insets: Enum.ScreenInsets): ScreenGui
		local layerGui = Instance.new("ScreenGui")
		layerGui.Name = name
		layerGui.ResetOnSpawn = false
		layerGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		layerGui.ScreenInsets = insets
		layerGui.DisplayOrder = order
		layerGui.Parent = gui.Parent
		return layerGui
	end
	local treeGui = layer("UpgradeTreeGui", 10, Enum.ScreenInsets.None)
	local chromeGui = layer("UpgradeTreeChrome", 11, Enum.ScreenInsets.CoreUISafeInsets)

	-- Full-screen board over the darkened world (no window box). It is one of the exclusive
	-- screens: opening another screen closes it and the other way round.
	local screen = Instance.new("Frame")
	screen.Name = "UpgradeTree"
	screen.BackgroundColor3 = Color3.fromRGB(10, 13, 30)
	screen.BackgroundTransparency = 0.15
	screen.BorderSizePixel = 0
	screen.Size = UDim2.fromScale(1, 1)
	screen.Visible = false
	screen.Active = true -- taps on the board don't reach the world
	screen.Parent = treeGui
	UiKit.addExclusive(screen)
	local chrome = Instance.new("Frame")
	chrome.Name = "Chrome"
	chrome.BackgroundTransparency = 1
	chrome.Size = UDim2.fromScale(1, 1)
	chrome.Visible = false
	chrome.Parent = chromeGui
	-- Darker at the edges, so the tree in the middle stands out.
	local vignette = Instance.new("UIGradient")
	vignette.Rotation = 90
	vignette.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.3, 0.05),
		NumberSequenceKeypoint.new(0.7, 0.05),
		NumberSequenceKeypoint.new(1, 0),
	})
	vignette.Parent = screen

	-- The board fills the screen; the title, pills, card and buttons float over it.
	local board = Instance.new("ScrollingFrame")
	board.Name = "Board"
	board.BackgroundTransparency = 1
	board.BorderSizePixel = 0
	board.Size = UDim2.fromScale(1, 1)
	board.ScrollingDirection = Enum.ScrollingDirection.XY
	board.ScrollBarThickness = 0
	board.ElasticBehavior = Enum.ElasticBehavior.Always
	board.ZIndex = 1
	board.Parent = screen

	-- Where a ray's name sits: past its last hex, further out on the near-horizontal rays so the
	-- wide text clears the hex.
	local function labelOffset(upgrade: Upgrades.Upgrade): (number, number)
		local cosine = math.abs(math.cos(math.rad(UpgradeTree.ANGLES[upgrade.id] or 90)))
		return UpgradeTree.offset(upgrade.id, upgrade.maxLevel + 0.7 + 0.6 * cosine)
	end

	-- Board size: every hex and ray label, plus PAD all round. START sits at (startX, startY).
	local minX, maxX, minY, maxY = -START_R, START_R, -START_R, START_R
	for _, upgrade in Upgrades.List do
		local x, y = labelOffset(upgrade)
		minX, maxX = math.min(minX, x - 100), math.max(maxX, x + 100)
		minY, maxY = math.min(minY, y - 40), math.max(maxY, y + 40)
	end
	local width, height = maxX - minX + PAD * 2, maxY - minY + PAD * 2
	local startX, startY = PAD - minX, PAD - minY

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Size = UDim2.fromOffset(width, height)
	content.Parent = board
	local zoomScale = Instance.new("UIScale")
	zoomScale.Parent = content
	local zoom = 1

	-- Title: light-to-deep green letters with a thick outline and a drop shadow.
	local titleShadow = makeTitle(chrome, "UPGRADES", UiKit.INK, UDim2.fromOffset(SIDE_W, 56), nil, 5)
	titleShadow.ZIndex = 3
	UiKit.textConstraint(titleShadow, 60)
	local title = makeTitle(chrome, "UPGRADES", Color3.new(1, 1, 1), UDim2.fromOffset(SIDE_W, 56), nil, 5)
	title.ZIndex = 4
	UiKit.textConstraint(title, 60)
	local titleFill = Instance.new("UIGradient")
	titleFill.Rotation = 90
	titleFill.Color = ColorSequence.new(TITLE_GREEN, TITLE_GREEN_DEEP)
	titleFill.Parent = title

	local close = makeButton(chrome, "X", UiKit.CLOSE_RED, UDim2.fromOffset(56, 56))
	close.Name = "Close"
	close.ZIndex = 5
	UiKit.textConstraint(close, 34)
	close.Activated:Connect(function()
		screen.Visible = false
	end)

	-- Right-hand column: Cash and Fame pills, then the card. Shrinks as one on short screens.
	local side = Instance.new("Frame")
	side.Name = "Side"
	side.BackgroundTransparency = 1
	side.AnchorPoint = Vector2.new(1, 0)
	side.Size = UDim2.fromOffset(SIDE_W, SIDE_H)
	side.ZIndex = 4
	side.Parent = chrome
	local sideScale = Instance.new("UIScale")
	sideScale.Parent = side

	local pill = Instance.new("Frame")
	pill.Name = "Cash"
	pill.Position = UDim2.fromOffset(30, 0)
	pill.Size = UDim2.fromOffset(150, PILLS_H)
	pill.BackgroundColor3 = UiKit.DARK
	pill.BackgroundTransparency = 0.15
	pill.Parent = side
	UiKit.corner(pill, PILLS_H / 2)
	UiKit.border(pill, 3)
	local cashArt = Instance.new("Frame")
	cashArt.BackgroundTransparency = 1
	cashArt.AnchorPoint = Vector2.new(0, 0.5)
	cashArt.Position = UDim2.new(0, -18, 0.5, 0)
	cashArt.Size = UDim2.fromOffset(52, 52)
	cashArt.ZIndex = 2
	cashArt.Parent = pill
	Icon3D.outlined(cashArt, "moneybag")
	local cashLabel = makeTitle(pill, "", UiKit.CASH_GREEN, UDim2.new(1, -46, 1, -10), UDim2.fromOffset(38, 5))
	cashLabel.TextXAlignment = Enum.TextXAlignment.Left
	cashLabel.ZIndex = 2
	local famePill = makeTitle(side, "", UiKit.GOLD, UDim2.fromOffset(110, PILLS_H - 6), UDim2.fromOffset(190, 3), 2)
	famePill.BackgroundColor3 = UiKit.DARK
	famePill.BackgroundTransparency = 0.15
	UiKit.corner(famePill, (PILLS_H - 6) / 2)
	UiKit.border(famePill, 3)

	-- The card for the tapped hex: icon and name, what it gives, the level step and Buy.
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Position = UDim2.fromOffset(0, PILLS_H + 16)
	card.Size = UDim2.fromOffset(SIDE_W, CARD_H)
	card.BackgroundColor3 = Color3.fromRGB(22, 28, 58)
	card.Visible = false
	card.Active = true
	card.Parent = side
	UiKit.corner(card, 18)
	UiKit.border(card, 4, UiKit.AWARD_GOLD)
	local cardArt = Instance.new("Frame")
	cardArt.Name = "Art"
	cardArt.BackgroundTransparency = 1
	cardArt.Position = UDim2.fromOffset(22, 14)
	cardArt.Size = UDim2.fromOffset(48, 48)
	cardArt.Parent = card
	local cardTitle = makeTitle(card, "", UiKit.WHITE, UDim2.new(1, -96, 0, 36), UDim2.fromOffset(78, 20), 3)
	cardTitle.TextXAlignment = Enum.TextXAlignment.Left
	local cardText = makeLabel(card, "", UiKit.WHITE, UDim2.new(1, -44, 0, 66), UDim2.fromOffset(22, 68))
	UiKit.textConstraint(cardText, 17)
	local cardLevel = makeLabel(card, "", UiKit.GOLD, UDim2.new(1, -44, 0, 22), UDim2.fromOffset(22, 138))
	UiKit.textConstraint(cardLevel, 18)
	local cardButton = makeButton(card, "", UiKit.GREEN, UDim2.new(1, -52, 0, 62), UDim2.fromOffset(26, 172))
	cardButton.Name = "Buy"
	UiKit.textConstraint(cardButton, 30)

	-- Bottom: zoom buttons and the stats line on the left, the hint on the right.
	local zoomIn = makeButton(chrome, "+", UiKit.BLUE, UDim2.fromOffset(46, 46))
	local zoomOut = makeButton(chrome, "-", UiKit.BLUE, UDim2.fromOffset(46, 46))
	for _, button in { zoomIn, zoomOut } do
		button.ZIndex = 5
		button.AnchorPoint = Vector2.new(0, 1)
		UiKit.textConstraint(button, 32)
	end
	local statsLabel = makeLabel(chrome, "", UiKit.MUTED, UDim2.fromScale(0.42, 0), nil)
	statsLabel.AnchorPoint = Vector2.new(0, 1)
	statsLabel.TextXAlignment = Enum.TextXAlignment.Left
	statsLabel.ZIndex = 3
	UiKit.outline(statsLabel, 1.5)
	local hint = makeLabel(chrome, "Drag to look around  •  Tap a hex to see what it gives", UiKit.MUTED, UDim2.fromScale(0.42, 0), nil)
	hint.AnchorPoint = Vector2.new(1, 1)
	hint.TextXAlignment = Enum.TextXAlignment.Right
	hint.ZIndex = 3
	UiKit.outline(hint, 1.5)

	local function setZoom(value: number)
		local view = board.AbsoluteSize
		-- Keep the middle of the view in place while zooming.
		local centre = (board.CanvasPosition + view / 2) / zoom
		zoom = math.clamp(value, MIN_ZOOM, MAX_ZOOM)
		zoomScale.Scale = zoom
		board.CanvasSize = UDim2.fromOffset(width * zoom, height * zoom)
		board.CanvasPosition = centre * zoom - view / 2
	end
	zoomIn.Activated:Connect(function()
		setZoom(zoom + ZOOM_STEP)
	end)
	zoomOut.Activated:Connect(function()
		setZoom(zoom - ZOOM_STEP)
	end)

	-- Phones (short screens): the title moves top-left and the right column shrinks to fit.
	local function layout()
		local compact = UiKit.isCompact()
		local screenHeight = math.max(chromeGui.AbsoluteSize.Y, 200)
		local closeSize = if compact then 42 else 56
		close.Size = UDim2.fromOffset(closeSize, closeSize)
		close.Position = UDim2.new(1, -(closeSize + (if compact then 10 else 28)), 0, if compact then 6 else 28)
		local sideTop
		if compact then
			title.AnchorPoint = Vector2.new(0, 0)
			title.Size = UDim2.fromOffset(220, 38)
			title.Position = UDim2.fromOffset(14, 4)
			title.TextXAlignment = Enum.TextXAlignment.Left
			sideTop = 56
		else
			title.AnchorPoint = Vector2.new(1, 0)
			title.Size = UDim2.fromOffset(SIDE_W, 56)
			title.Position = UDim2.new(1, -30, 0, 100)
			title.TextXAlignment = Enum.TextXAlignment.Center
			sideTop = 172
		end
		titleShadow.AnchorPoint = title.AnchorPoint
		titleShadow.Size = title.Size
		titleShadow.Position = title.Position + UDim2.fromOffset(0, if compact then 3 else 5)
		titleShadow.TextXAlignment = title.TextXAlignment
		local bottomRoom = if compact then 34 else 64
		sideScale.Scale = math.clamp((screenHeight - sideTop - bottomRoom) / SIDE_H, 0.6, 1)
		side.Position = UDim2.new(1, if compact then -10 else -30, 0, sideTop)
		local edge = if compact then 8 else 14
		local buttonSize = if compact then 38 else 46
		zoomIn.Size = UDim2.fromOffset(buttonSize, buttonSize)
		zoomOut.Size = zoomIn.Size
		zoomIn.Position = UDim2.new(0, edge, 1, -edge)
		zoomOut.Position = UDim2.new(0, edge + buttonSize + 6, 1, -edge)
		local lineHeight = if compact then 14 else 20
		statsLabel.Size = UDim2.new(0.42, 0, 0, lineHeight)
		statsLabel.Position = UDim2.new(0, edge + buttonSize * 2 + 18, 1, -edge - 4)
		hint.Size = UDim2.new(0.4, 0, 0, lineHeight)
		hint.Position = UDim2.new(1, -edge - 6, 1, -edge - 4)
	end
	UiKit.onViewportChanged(layout)

	local openView: () -> () -- defined once the hexes exist

	-- Tree -------------------------------------------------------------------------------------

	-- The studio silhouette behind the tree, as in the mockup: a roof and walls in faint blue.
	for _, edge in { { 0, -270, -350, -100 }, { 0, -270, 350, -100 }, { -350, -100, -350, 250 }, { 350, -100, 350, 250 }, { -350, 250, 350, 250 } } do
		local line = bar(content, startX + edge[1], startY + edge[2], startX + edge[3], startY + edge[4], 6, SILHOUETTE, 1)
		line.Name = "Silhouette"
		line.BackgroundTransparency = 0.55
	end

	local selected: { id: string, n: number }? = nil
	-- Set when a press lands on a hex or the card, so releasing it doesn't count as a tap on the
	-- empty board (which closes the card).
	local itemPressed = false
	local function marksPress(object: GuiObject)
		object.InputBegan:Connect(function(input)
			local kind = input.UserInputType
			if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
				itemPressed = true
			end
		end)
	end
	marksPress(card)
	marksPress(cardButton)
	local nodes: { [string]: { Node } } = {}
	local refresh: () -> ()

	-- One hex centred on (x, y): glow, selection ring, rim, fill, icon or padlock, its name over the
	-- top point and its price along the bottom.
	local function makeNode(x: number, y: number, r: number): Node
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.AnchorPoint = Vector2.new(0.5, 0.5)
		holder.Position = UDim2.fromOffset(x, y)
		holder.Size = UDim2.fromOffset(r * 2, r * 2)
		holder.ZIndex = 3
		holder.Parent = content
		local scale = Instance.new("UIScale")
		scale.Parent = holder
		local glow = Instance.new("CanvasGroup")
		glow.Name = "Glow"
		glow.BackgroundTransparency = 1
		glow.AnchorPoint = Vector2.new(0.5, 0.5)
		glow.Position = UDim2.fromScale(0.5, 0.5)
		glow.Size = UDim2.fromOffset((r + GLOW) * 2, (r + GLOW) * 2)
		glow.GroupTransparency = 0.5
		glow.Visible = false
		glow.ZIndex = 1
		glow.Parent = holder
		hexShape(glow, r + GLOW, UiKit.GOLD, "Hex", 1)
		local ring = hexShape(holder, r + RIM + 4, UiKit.WHITE, "Ring", 2)
		ring.Visible = false
		local rim = hexShape(holder, r + RIM, LOCKED_RIM, "Rim", 3)
		local fill = hexShape(holder, r, LOCKED_FILL, "Fill", 4)
		local art = Instance.new("Frame")
		art.Name = "Art"
		art.BackgroundTransparency = 1
		art.AnchorPoint = Vector2.new(0.5, 0.5)
		art.Position = UDim2.new(0.5, 0, 0.5, -4)
		art.Size = UDim2.fromOffset(r * 1.05, r * 1.05)
		art.ZIndex = 5
		art.Parent = holder
		local lock = padlock(holder, 5)
		local price = makeTitle(holder, "", UiKit.CASH_GREEN, UDim2.fromOffset(r * 1.7, 22), UDim2.new(0.5, -r * 0.85, 1, -32), 2.5)
		price.ZIndex = 6
		UiKit.textConstraint(price, 19)
		local name = makeTitle(holder, "", UiKit.WHITE, UDim2.fromOffset(170, 20), UDim2.new(0.5, -85, 0, -12), 2.5)
		name.ZIndex = 7
		UiKit.textConstraint(name, 17)
		local hit = Instance.new("TextButton")
		hit.Name = "Hit"
		hit.Text = ""
		hit.AutoButtonColor = false
		hit.BackgroundTransparency = 1
		hit.AnchorPoint = Vector2.new(0.5, 0.5)
		hit.Position = UDim2.fromScale(0.5, 0.5)
		hit.Size = UDim2.fromOffset(SQRT3 * r, r * 2)
		hit.ZIndex = 8
		hit.Parent = holder
		marksPress(hit)
		return {
			holder = holder,
			scale = scale,
			glow = glow,
			ring = ring,
			rim = rim,
			fill = fill,
			art = art,
			lock = lock,
			name = name,
			price = price,
			hit = hit,
			hasIcon = false,
			tweens = {},
			x = x,
			y = y,
		}
	end

	-- START: the blue hex every ray grows from.
	local root = makeNode(startX, startY, START_R)
	root.holder.Name = "Start"
	paintHex(root.fill, START_BLUE)
	paintHex(root.rim, UiKit.WHITE)
	root.lock.Visible = false
	root.name.Visible = false
	root.hit.Visible = false
	root.art.Position = UDim2.new(0.5, 0, 0.5, -12)
	Icon3D.outlined(root.art, "movieCamera")
	root.price.Text = "START"
	root.price.TextColor3 = UiKit.WHITE
	root.price.Size = UDim2.fromOffset(START_R * 1.7, 30)
	root.price.Position = UDim2.new(0.5, -START_R * 0.85, 1, -46)
	UiKit.textConstraint(root.price, 28)

	-- Sends the gamepad selection to Buy after picking a hex, with Left going back to the hex.
	local function usingGamepad(): boolean
		local last = UserInputService:GetLastInputType()
		return last.Name:sub(1, 7) == "Gamepad"
	end

	for _, upgrade in Upgrades.List do
		nodes[upgrade.id] = {}
		local px, py = startX, startY
		for n = 1, upgrade.maxLevel do
			local ox, oy = UpgradeTree.offset(upgrade.id, n)
			local node = makeNode(startX + ox, startY + oy, HEX_R)
			node.holder.Name = `{upgrade.id}{n}`
			node.name.Text = `{RAY_NAMES[upgrade.id]} {UpgradeTree.roman(n)}`
			node.link = bar(content, px, py, node.x, node.y, 10, LINK_OFF, 2)
			px, py = node.x, node.y
			nodes[upgrade.id][n] = node
			node.hit.Activated:Connect(function()
				local level = Upgrades.level(ClientState.stats(), upgrade.id)
				if n > level + 1 then
					UiKit.toast(chromeGui, "Buy the level before it first")
					return
				end
				selected = if selected ~= nil and selected.id == upgrade.id and selected.n == n then nil else { id = upgrade.id, n = n }
				Sfx.play("click")
				refresh()
				if selected ~= nil and usingGamepad() then
					cardButton.NextSelectionLeft = node.hit
					GuiService.SelectedObject = cardButton
				end
			end)
		end
		local lx, ly = labelOffset(upgrade)
		local label = makeTitle(content, string.upper(RAY_NAMES[upgrade.id]), RAY_COLORS[upgrade.id], UDim2.fromOffset(200, 26), UDim2.fromOffset(startX + lx - 100, startY + ly - 13), 3)
		label.Name = "RayLabel"
		label.ZIndex = 4
		UiKit.textConstraint(label, 24)
	end

	-- On open: fit the part of the tree you can act on (each ray up to two hexes past what you own,
	-- plus a ray's name once its end is that close) into the space left of the card and between the
	-- header and the bottom buttons, centred. Zoom stays between MIN_ZOOM and 1:1, so a 10-level ray
	-- is never shrunk to unreadable hexes; drag for the rest.
	openView = function()
		local view = board.AbsoluteSize
		if view.X <= 0 then
			return
		end
		local stats = ClientState.stats()
		local reach = HEX_R + GLOW
		local x0, x1, y0, y1 = startX - START_R, startX + START_R, startY - START_R, startY + START_R
		local function include(x: number, y: number, halfWidth: number, up: number, down: number)
			x0, x1 = math.min(x0, x - halfWidth), math.max(x1, x + halfWidth)
			y0, y1 = math.min(y0, y - up), math.max(y1, y + down)
		end
		for _, upgrade in Upgrades.List do
			local last = math.min(Upgrades.level(stats, upgrade.id) + 2, upgrade.maxLevel)
			for n = 1, last do
				local node = nodes[upgrade.id][n]
				include(node.x, node.y, reach, reach + 14, reach) -- the name sits over the top point
			end
			if last == upgrade.maxLevel then
				local lx, ly = labelOffset(upgrade)
				include(startX + lx, startY + ly, 100, 16, 16)
			end
		end
		-- Free area in board pixels: the chrome layer sits inside the safe area, the board doesn't.
		local inset = (treeGui.AbsoluteSize - chromeGui.AbsoluteSize)
		local origin = chrome.AbsolutePosition
		local left = 10 + inset.X / 2
		local right = side.AbsolutePosition.X - origin.X - 14 + inset.X / 2
		local top = (if UiKit.isCompact() then title.AbsolutePosition.Y + title.AbsoluteSize.Y - origin.Y else 16) + inset.Y
		local bottom = zoomIn.AbsolutePosition.Y - origin.Y - 8 + inset.Y
		local areaW, areaH = math.max(right - left, 100), math.max(bottom - top, 100)
		zoom = math.clamp(math.min(areaW / (x1 - x0), areaH / (y1 - y0)), MIN_ZOOM, 1)
		zoomScale.Scale = zoom
		board.CanvasSize = UDim2.fromOffset(width * zoom, height * zoom)
		board.CanvasPosition = Vector2.new((x0 + x1) / 2 * zoom - (left + areaW / 2), (y0 + y1) / 2 * zoom - (top + areaH / 2))
	end

	local function stopTweens(node: Node)
		for _, tween in node.tweens do
			tween:Cancel()
		end
		table.clear(node.tweens)
		node.scale.Scale = 1
	end

	-- Restyles a hex when its state changes (every Cash tick only updates the price text).
	local function paintNode(node: Node, state: NodeState, upgrade: Upgrades.Upgrade, n: number, isSelected: boolean)
		node.ring.Visible = isSelected
		if isSelected then
			paintHex(node.ring, if state == "owned" then UiKit.GOLD else UiKit.WHITE)
		end
		if state == "buy" then
			node.price.Text = shortCash(upgrade.costs[n])
			node.price.TextColor3 = UiKit.CASH_GREEN
		elseif state == "short" then
			node.price.Text = shortCash(upgrade.costs[n])
			node.price.TextColor3 = PRICE_RED
		elseif state == "fame" then
			node.price.Text = `Fame {shortCash(upgrade.fame[n]):sub(2)}`
			node.price.TextColor3 = UiKit.WARN
		end
		if node.state == state then
			return
		end
		node.state = state
		stopTweens(node)
		local locked = state == "locked"
		node.lock.Visible = locked
		node.name.Visible = not locked
		node.art.Visible = not locked
		node.price.Visible = not locked
		if not locked and not node.hasIcon then
			node.hasIcon = true
			Icon3D.outlined(node.art, ICONS[upgrade.id] or "arrow")
		end
		if node.link ~= nil then
			node.link.BackgroundColor3 = if locked then LINK_OFF else LINK_ON
		end
		node.glow.Visible = not locked and state ~= "owned"
		if state == "owned" then
			paintHex(node.fill, OWNED)
			paintHex(node.rim, UiKit.WHITE)
			node.price.Text = "Owned"
			node.price.TextColor3 = UiKit.CASH_GREEN
		elseif locked then
			paintHex(node.fill, LOCKED_FILL)
			paintHex(node.rim, LOCKED_RIM)
		else
			-- The next level: gold, or green and breathing when you can afford it.
			local color = if state == "buy" then UiKit.GREEN else UiKit.GOLD
			paintHex(node.fill, NEXT_FILL)
			paintHex(node.rim, color)
			paintHex(node.glow:FindFirstChild("Hex") :: Instance, color)
			node.glow.GroupTransparency = 0.5
			if state == "buy" and not reducedMotion() then
				local info = TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
				node.tweens = {
					TweenService:Create(node.glow, info, { GroupTransparency = 0.15 }),
					TweenService:Create(node.scale, info, { Scale = 1.06 }),
				}
				for _, tween in node.tweens do
					tween:Play()
				end
			end
		end
		-- A crown on the last hex of a maxed ray.
		if n == upgrade.maxLevel and state == "owned" and node.crown == nil then
			local crown = Instance.new("Frame")
			crown.Name = "Crown"
			crown.BackgroundTransparency = 1
			crown.AnchorPoint = Vector2.new(0.5, 1)
			crown.Position = UDim2.new(0.5, 0, 0, -6)
			crown.Size = UDim2.fromOffset(46, 46)
			crown.ZIndex = 9
			crown.Parent = node.holder
			Icon3D.outlined(crown, "crown")
			node.crown = crown
		end
	end

	-- After a purchase: the bought hex pops, a gold spark runs along the line, and the next hex
	-- unlocks with a little shake. Skipped under reduced motion.
	local function celebrate(id: string, level: number)
		local chain = nodes[id]
		local bought, nextNode = chain[level], chain[level + 1]
		if bought == nil or reducedMotion() then
			return
		end
		Sfx.play("goal")
		local up = TweenService:Create(bought.scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.25 })
		local down = TweenService:Create(bought.scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		up.Completed:Once(function()
			down:Play()
		end)
		up:Play()
		if nextNode == nil then
			return
		end
		local spark = Instance.new("Frame")
		spark.Name = "Spark"
		spark.BorderSizePixel = 0
		spark.BackgroundColor3 = UiKit.GOLD
		spark.AnchorPoint = Vector2.new(0.5, 0.5)
		spark.Position = bought.holder.Position
		spark.Size = UDim2.fromOffset(18, 18)
		spark.ZIndex = 5
		spark.Parent = content
		UiKit.corner(spark, 9)
		UiKit.border(spark, 3, UiKit.WHITE)
		local run = TweenService:Create(spark, TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Position = nextNode.holder.Position })
		run.Completed:Once(function()
			spark:Destroy()
			local home = UDim2.fromOffset(nextNode.x, nextNode.y)
			for _, dx in { -6, 6, -4, 4, -2, 0 } do
				nextNode.holder.Position = home + UDim2.fromOffset(dx, 0)
				task.wait(0.04)
			end
			nextNode.holder.Position = home
		end)
		run:Play()
	end

	cardButton.Activated:Connect(function()
		local pick = selected
		local upgrade = if pick ~= nil then Upgrades.get(pick.id) else nil
		if pick == nil or upgrade == nil then
			return
		end
		local level = Upgrades.level(ClientState.stats(), upgrade.id)
		if pick.n ~= level + 1 then
			return
		end
		local state = nodeState(upgrade, level, pick.n, player:GetAttribute("Cash") or 0, player:GetAttribute("Fame") or 0)
		if state == "fame" then
			UiKit.toast(chromeGui, `Needs Fame {Hud.comma(upgrade.fame[pick.n])}`)
		elseif state == "short" then
			UiKit.toast(chromeGui, "Not enough Cash")
		else
			buyUpgrade:FireServer(upgrade.id)
		end
	end)

	local cardFor = ""
	local function showCard(stats: any, cash: number, fame: number)
		local pick = selected
		local upgrade = if pick ~= nil then Upgrades.get(pick.id) else nil
		if pick == nil or upgrade == nil then
			card.Visible = false
			return
		end
		local level = Upgrades.level(stats, upgrade.id)
		if cardFor ~= upgrade.id then
			cardFor = upgrade.id
			cardArt:ClearAllChildren()
			Icon3D.outlined(cardArt, ICONS[upgrade.id] or "arrow")
		end
		cardTitle.Text = `{RAY_NAMES[upgrade.id]} {UpgradeTree.roman(pick.n)}`
		if pick.n <= level then
			cardText.Text = `Owned: {upgrade.effect(pick.n)}`
			cardLevel.Text = `Level {pick.n} of {upgrade.maxLevel}`
			cardButton.Text = "OWNED"
			cardButton.BackgroundColor3 = OWNED
			cardButton.TextColor3 = UiKit.WHITE
		else
			cardText.Text = `Now: {upgrade.effect(level)}\nNext: {upgrade.effect(pick.n)}`
			cardLevel.Text = `Level {level} → {pick.n}`
			local state = nodeState(upgrade, level, pick.n, cash, fame)
			-- Gold "locked", green "buy", grey "can't afford", as on the other screens.
			if state == "fame" then
				cardButton.Text = `Needs Fame {Hud.comma(upgrade.fame[pick.n])}`
				cardButton.BackgroundColor3 = UiKit.AWARD_GOLD
				cardButton.TextColor3 = UiKit.WHITE
			else
				cardButton.Text = `BUY {shortCash(upgrade.costs[pick.n])}`
				UiKit.setEnabled(cardButton, state == "buy", UiKit.GREEN)
			end
		end
		card.Visible = true
	end

	local lastLevels: { [string]: number } = {}
	refresh = function()
		local stats = ClientState.stats()
		local cash = player:GetAttribute("Cash") or 0
		local fame = player:GetAttribute("Fame") or 0

		local rate = if ClientState.studio ~= nil then ClientState.studio.rate else Config.CinemaIncomePerSecond
		local rebirths = stats.rebirths or 0
		local rebirthText = if rebirths > 0 then `  -  Rebirth {Rebirth.multiplierText(rebirths)} Cash` else ""
		statsLabel.Text = `Luck x{string.format("%.2f", Upgrades.luck(stats))}  -  Royalties ${string.format("%.2f", rate)}/s  -  Offline {Upgrades.offlineCap(stats) / 3600}h{rebirthText}`
		cashLabel.Text = shortCash(cash)
		famePill.Text = "Fame " .. shortCash(fame):sub(2)

		-- A bought level moves the selection on to the next one in its chain.
		local pick = selected
		if pick ~= nil then
			local upgrade = Upgrades.get(pick.id)
			if upgrade ~= nil and pick.n == Upgrades.level(stats, pick.id) and pick.n < upgrade.maxLevel then
				pick.n += 1
			end
		end

		for _, upgrade in Upgrades.List do
			local level = Upgrades.level(stats, upgrade.id)
			for n, node in nodes[upgrade.id] do
				paintNode(node, nodeState(upgrade, level, n, cash, fame), upgrade, n, pick ~= nil and pick.id == upgrade.id and pick.n == n)
			end
			local before = lastLevels[upgrade.id]
			if before ~= nil and level == before + 1 then
				celebrate(upgrade.id, level)
			end
			lastLevels[upgrade.id] = level
		end
		showCard(stats, cash, fame)
	end

	-- Mouse drag pans the board (touch drags it natively); a tap on empty board closes the card.
	local drag: { start: Vector2, canvas: Vector2, moved: boolean }? = nil
	board.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			drag = { start = Vector2.new(input.Position.X, input.Position.Y), canvas = board.CanvasPosition, moved = false }
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		local current = drag
		if current == nil then
			return
		end
		local delta = Vector2.new(input.Position.X, input.Position.Y) - current.start
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			if delta.Magnitude > 6 then
				current.moved = true
			end
			if current.moved then
				board.CanvasPosition = current.canvas - delta
			end
		elseif input.UserInputType == Enum.UserInputType.Touch and delta.Magnitude > 6 then
			current.moved = true
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		local kind = input.UserInputType
		local current = drag
		if current == nil or (kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch) then
			return
		end
		drag = nil
		local onItem = itemPressed
		itemPressed = false
		if not current.moved and not onItem and selected ~= nil then
			selected = nil
			refresh()
		end
	end)

	-- Red badge on the Upgrade button: how many upgrades can be bought right now.
	local function updateBadge()
		SideMenu.setBadge(upgradesButton, UpgradeTree.buyableCount(ClientState.stats(), player:GetAttribute("Cash") or 0, player:GetAttribute("Fame") or 0))
	end

	ClientState.changed:Connect(function()
		updateBadge()
		if screen.Visible then
			refresh()
		end
	end)
	player.AttributeChanged:Connect(function(name)
		if name == "Cash" or name == "Fame" then
			updateBadge()
			if screen.Visible then
				refresh()
			end
		end
	end)
	updateBadge()

	-- Closing hands the gamepad selection back to the game.
	screen:GetPropertyChangedSignal("Visible"):Connect(function()
		local current = GuiService.SelectedObject
		-- The game UI hides while the tree is open (it read through the backdrop) and comes back on close.
		chrome.Visible = screen.Visible
		gui.Enabled = not screen.Visible
		if not screen.Visible and current ~= nil and (current:IsDescendantOf(screen) or current:IsDescendantOf(chrome)) then
			GuiService.SelectedObject = nil
		end
	end)

	-- Select the next level of upgrade `id` (its card opens), if there is one.
	local function focusOn(id: string)
		local upgrade = Upgrades.get(id)
		local n = if upgrade ~= nil then Upgrades.level(ClientState.stats(), id) + 1 else 0
		if upgrade ~= nil and upgrade.costs[n] ~= nil then
			selected = { id = id, n = n }
		end
	end

	local function open(focus: string?)
		selected = nil
		if focus ~= nil then
			focusOn(focus)
		end
		table.clear(lastLevels) -- no celebration for levels bought while the tree was closed
		refresh()
		-- Sized once the screen is showing.
		task.defer(function()
			openView()
			if usingGamepad() then
				-- Start the gamepad on the cheapest next level the player can afford, else START's
				-- nearest next level.
				local best: Node?, bestCost = nil, math.huge
				local stats = ClientState.stats()
				for _, upgrade in Upgrades.List do
					local level = Upgrades.level(stats, upgrade.id)
					local node = nodes[upgrade.id][level + 1]
					if node ~= nil then
						local cost = upgrade.costs[level + 1] + (if node.state == "buy" then 0 else 1e15)
						if cost < bestCost then
							best, bestCost = node, cost
						end
					end
				end
				if best ~= nil then
					GuiService.SelectedObject = best.hit
				end
			end
		end)
	end
	upgradesButton.Activated:Connect(function()
		UiKit.togglePanel(screen, open)
	end)
	Screens.register("Upgrades", function(focus)
		if not screen.Visible then
			UiKit.togglePanel(screen, function()
				open(focus)
			end)
		elseif focus ~= nil then
			focusOn(focus)
			refresh()
		end
	end)
end

return UpgradesUi
