--!strict
-- Upgrade tree: spend Cash on stages, cinema size, offline earnings, Luck, and the clapperboard.
-- Laid out like the reference games' upgrade trees: a full-screen board over the dimmed world, a
-- big green title, and chunky square nodes you drag around (and zoom with the magnifier buttons).
-- The studio sits at the top and branches into one chain per upgrade, a node per level. Owned
-- levels are blue, the next level is amber with its icon, name and price, and every level after
-- that is a "?". Tapping a node opens a card next to it with what it gives and the Buy button.
-- Shows what each level gives (from the shared Upgrades definitions); the server prices, gates and
-- applies every purchase.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Rebirth = require(ReplicatedStorage.Shared.Rebirth)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
local ClientState = require(script.Parent.ClientState)
local Hud = require(script.Parent.Hud)
local Icon3D = require(script.Parent.Icon3D)
local Screens = require(script.Parent.Screens)
local Sfx = require(script.Parent.Sfx)
local SideMenu = require(script.Parent.SideMenu)
local UiKit = require(script.Parent.UiKit)

local makeLabel, makeTitle, makeButton = UiKit.makeLabel, UiKit.makeTitle, UiKit.makeButton

local UpgradesUi = {}

-- 3D icon for each upgrade chain (IconModels ids).
local ICONS: { [string]: string } = {
	Stages = "stage",
	Cinema = "popcorn",
	Offline = "moneybag",
	Luck = "clover",
	Clap = "clapper",
}

-- Node name for level `n` of an upgrade: what you have once it's bought, short enough to sit
-- above a node like the reference games' "20% Luck".
local function nodeName(id: string, n: number): string
	if id == "Stages" then
		return `{Config.StartingStages + n} Stages`
	elseif id == "Cinema" then
		return `Royalties x{1 + Config.CinemaStep * n}`
	elseif id == "Offline" then
		return `{(Config.OfflineCapSeconds + Config.OfflineCapStepSeconds * n) / 3600}h Offline`
	elseif id == "Luck" then
		return `+{string.format("%.1f", Config.LuckStep * n)} Luck`
	elseif id == "Clap" then
		return `Tap -{Config.ClapSeconds + Config.ClapStep * n}s`
	end
	return `Level {n}`
end

-- Board colors, from the reference: amber nodes, deeper brown "?" nodes, blue owned nodes, orange
-- arrows and a green title.
-- Saturated on purpose: under the dimmed world, softer colors read as pale.
local AMBER_TOP = Color3.fromRGB(255, 188, 46)
local AMBER = Color3.fromRGB(232, 140, 28)
local HIDDEN = Color3.fromRGB(150, 88, 34)
local OWNED = Color3.fromRGB(76, 92, 242)
local ARROW = Color3.fromRGB(255, 152, 38)
local TITLE_GREEN = Color3.fromRGB(132, 236, 72)
local TITLE_GREEN_DEEP = Color3.fromRGB(58, 176, 40)
local PRICE_RED = Color3.fromRGB(255, 128, 116)

-- Board geometry, in unzoomed pixels.
local NODE = 92
local COLUMN = 156 -- distance between chains
local ROW = 150 -- node, the name above the next one, and the arrow between
local MARGIN = 44
local ROOT_Y = 40 -- top of the studio node
local FIRST_Y = ROOT_Y + NODE + 92 -- top of each chain's first node
local MIN_ZOOM, MAX_ZOOM, ZOOM_STEP = 0.45, 1.4, 0.15

-- "$600", "$25K", "$1.5M": node prices have to fit under the icon.
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

-- What a level node shows: "owned", "buy" (next level, affordable), "short" (next level, not
-- enough Cash), "fame" (next level, needs more Fame) or "hidden" (later levels, a "?").
type NodeState = string

local function nodeState(upgrade: Upgrades.Upgrade, level: number, n: number, cash: number, fame: number): NodeState
	if n <= level then
		return "owned"
	elseif n > level + 1 then
		return "hidden"
	elseif fame < upgrade.fame[n] then
		return "fame"
	elseif cash >= upgrade.costs[n] then
		return "buy"
	end
	return "short"
end

-- Upgrades whose next level the player can buy right now (for the menu badge).
local function buyableCount(stats: any, cash: number, fame: number): number
	local count = 0
	for _, upgrade in Upgrades.List do
		local level = Upgrades.level(stats, upgrade.id)
		if level < upgrade.maxLevel and nodeState(upgrade, level, level + 1, cash, fame) == "buy" then
			count += 1
		end
	end
	return count
end

-- Light top, darker bottom band: the chunky bevel the reference nodes have.
local function bevel(frame: GuiObject)
	local shade = Instance.new("UIGradient")
	shade.Name = "Bevel"
	shade.Rotation = 90
	shade.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.68, Color3.fromRGB(238, 238, 238)),
		ColorSequenceKeypoint.new(0.72, Color3.fromRGB(165, 165, 165)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(138, 138, 138)),
	})
	shade.Parent = frame
	-- A glossy strip along the top, like the reference buttons.
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.BorderSizePixel = 0
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.BackgroundTransparency = 0.68
	shine.Position = UDim2.new(0, 14, 0, 5)
	shine.Size = UDim2.new(1, -28, 0, 7)
	shine.ZIndex = frame.ZIndex + 1
	shine.Parent = frame
	UiKit.corner(shine, 4)
end

-- Orange connector line from (x1, y1) to (x2, y2) (straight across or straight down), with an
-- arrowhead at the end when `head` is set.
local function line(parent: Instance, x1: number, y1: number, x2: number, y2: number, head: boolean)
	local bar = Instance.new("Frame")
	bar.Name = "Arrow"
	bar.BorderSizePixel = 0
	bar.BackgroundColor3 = ARROW
	bar.Position = UDim2.fromOffset(math.min(x1, x2) - 4, math.min(y1, y2) - 4)
	bar.Size = UDim2.fromOffset(math.abs(x2 - x1) + 8, math.abs(y2 - y1) + 8)
	bar.Parent = parent
	UiKit.corner(bar, 3)
	UiKit.border(bar, 2)
	if head then
		local tip = Instance.new("Frame")
		tip.Name = "Head"
		tip.BorderSizePixel = 0
		tip.BackgroundColor3 = ARROW
		tip.AnchorPoint = Vector2.new(0.5, 0.5)
		tip.Position = UDim2.fromOffset(x2, y2 - 6)
		tip.Size = UDim2.fromOffset(16, 16)
		tip.Rotation = 45
		tip.Parent = parent
		UiKit.border(tip, 2)
	end
end

-- Film strip from (x1, y) to (x2, y): the studio's trunk across the top of the tree, a dark strip
-- with two rows of sprocket holes, so the tree reads as a movie studio's rather than a factory's.
local FILM = Color3.fromRGB(28, 26, 36)
local HOLE = Color3.fromRGB(236, 226, 200)
local function filmStrip(parent: Instance, x1: number, x2: number, y: number)
	local strip = Instance.new("Frame")
	strip.Name = "FilmStrip"
	strip.BackgroundColor3 = FILM
	strip.AnchorPoint = Vector2.new(0, 0.5)
	strip.Position = UDim2.fromOffset(x1 - 10, y)
	strip.Size = UDim2.fromOffset(x2 - x1 + 20, 22)
	strip.ZIndex = 2
	strip.Parent = parent
	UiKit.corner(strip, 4)
	UiKit.border(strip, 2)
	for hx = 6, x2 - x1 + 10, 16 do
		for _, hy in { 3, 14 } do
			local hole = Instance.new("Frame")
			hole.BorderSizePixel = 0
			hole.BackgroundColor3 = HOLE
			hole.Position = UDim2.fromOffset(hx, hy)
			hole.Size = UDim2.fromOffset(8, 5)
			hole.ZIndex = 3
			hole.Parent = strip
			UiKit.corner(hole, 2)
		end
	end
end

-- Sprocket holes down both sides of a node, so every node looks like a frame of film.
local function sprockets(tile: GuiObject)
	for _, x in { 4, NODE - 13 } do
		for row = 0, 3 do
			local hole = Instance.new("Frame")
			hole.Name = "Sprocket"
			hole.BorderSizePixel = 0
			hole.BackgroundColor3 = UiKit.INK
			hole.BackgroundTransparency = 0.45
			hole.Position = UDim2.fromOffset(x, 10 + row * 18)
			hole.Size = UDim2.fromOffset(6, 9)
			hole.ZIndex = tile.ZIndex + 1
			hole.Parent = tile
			UiKit.corner(hole, 2)
		end
	end
end

type Node = {
	tile: TextButton,
	name: TextLabel,
	price: TextLabel,
	unknown: TextLabel,
	art: Frame,
	halo: Frame,
	hasIcon: boolean,
}

function UpgradesUi.start(gui: ScreenGui, upgradesButton: TextButton)
	local player = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 15)
	if remotes == nil then
		warn("[UpgradesUi] Remotes folder never arrived")
		return
	end
	local buyUpgrade = remotes:WaitForChild("BuyUpgrade") :: RemoteEvent

	-- Full-screen board over the dimmed world (no window box), like the reference tree. It is one
	-- of the exclusive screens: opening another screen closes it and the other way round.
	local screen = Instance.new("Frame")
	screen.Name = "UpgradeTree"
	screen.BackgroundColor3 = Color3.fromRGB(8, 10, 22)
	screen.BackgroundTransparency = 0.18
	screen.BorderSizePixel = 0
	screen.Size = UDim2.fromScale(1, 1)
	screen.Visible = false
	screen.ZIndex = 6 -- over the side menu and panels, under the tutorial's dialogue
	screen.Active = true -- taps on the board don't reach the world
	screen.Parent = gui
	UiKit.addExclusive(screen)
	-- Darker at the top and bottom, so the board in the middle stands out.
	local vignette = Instance.new("UIGradient")
	vignette.Rotation = 90
	vignette.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.25, 0.25),
		NumberSequenceKeypoint.new(0.75, 0.25),
		NumberSequenceKeypoint.new(1, 0),
	})
	vignette.Parent = screen

	-- Chunky title: light-to-deep green letters, a thick dark outline and a drop shadow.
	local titleShadow = makeTitle(screen, "UPGRADE TREE", UiKit.INK, UDim2.new(0.7, 0, 0, 52), UDim2.new(0.15, 0, 0, 13), 5)
	titleShadow.ZIndex = 3
	UiKit.textConstraint(titleShadow, 58)
	local title = makeTitle(screen, "UPGRADE TREE", Color3.new(1, 1, 1), UDim2.new(0.7, 0, 0, 52), UDim2.new(0.15, 0, 0, 8), 5)
	title.ZIndex = 3
	UiKit.textConstraint(title, 58)
	local titleFill = Instance.new("UIGradient")
	titleFill.Rotation = 90
	titleFill.Color = ColorSequence.new(TITLE_GREEN, TITLE_GREEN_DEEP)
	titleFill.Parent = title
	-- Gold stars either side of the title, like a premiere marquee.
	local titleStars: { Frame } = {}
	for _, side in { -1, 1 } do
		local star = Instance.new("Frame")
		star.Name = "TitleStar"
		star.BackgroundTransparency = 1
		star.AnchorPoint = Vector2.new(0.5, 0)
		star.Size = UDim2.fromOffset(54, 54)
		star.ZIndex = 3
		star.Parent = screen
		star:SetAttribute("Side", side)
		Icon3D.outlined(star, "star")
		table.insert(titleStars, star)
	end
	local subtitle = makeTitle(screen, "Grow Your Studio to Boost Luck and Box Office", UiKit.WHITE, UDim2.new(0.7, 0, 0, 22), UDim2.new(0.15, 0, 0, 60), 3)
	subtitle.ZIndex = 3
	UiKit.textConstraint(subtitle, 22)
	local statsLabel = makeLabel(screen, "", UiKit.MUTED, UDim2.new(0.7, 0, 0, 18), UDim2.new(0.15, 0, 0, 84))
	statsLabel.ZIndex = 3
	UiKit.outline(statsLabel, 1.5)
	UiKit.textConstraint(statsLabel, 17)

	local close = makeButton(screen, "X", UiKit.CLOSE_RED, UDim2.fromOffset(56, 56), UDim2.new(1, -72, 0, 12))
	close.Name = "Close"
	close.ZIndex = 4
	UiKit.textConstraint(close, 34)
	close.Activated:Connect(function()
		screen.Visible = false
	end)

	-- The board: drag to move around (touch drags natively, the mouse below), zoom with the
	-- magnifier buttons.
	local board = Instance.new("ScrollingFrame")
	board.Name = "Board"
	board.BackgroundTransparency = 1
	board.BorderSizePixel = 0
	board.ScrollingDirection = Enum.ScrollingDirection.XY
	board.ScrollBarThickness = 6
	board.ScrollBarImageColor3 = UiKit.MUTED
	board.ElasticBehavior = Enum.ElasticBehavior.Always
	board.ZIndex = 2
	board.Parent = screen

	local tallest = 0
	for _, upgrade in Upgrades.List do
		tallest = math.max(tallest, upgrade.maxLevel)
	end
	local count = #Upgrades.List
	local width = MARGIN * 2 + COLUMN * count
	local height = FIRST_Y + tallest * ROW + 20

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Size = UDim2.fromOffset(width, height)
	content.ZIndex = 2
	content.Parent = board
	local zoomScale = Instance.new("UIScale")
	zoomScale.Parent = content
	local zoom = 1

	-- Footer: Cash and Fame pills in the middle, zoom buttons on the right.
	local footer = Instance.new("Frame")
	footer.Name = "Footer"
	footer.BackgroundTransparency = 1
	footer.AnchorPoint = Vector2.new(0.5, 1)
	footer.Position = UDim2.new(0.5, 0, 1, -10)
	footer.Size = UDim2.new(1, -24, 0, 54)
	footer.ZIndex = 4
	footer.Parent = screen
	local pill = Instance.new("Frame")
	pill.Name = "Cash"
	pill.AnchorPoint = Vector2.new(0.5, 0.5)
	pill.Position = UDim2.new(0.5, -60, 0.5, 0)
	pill.Size = UDim2.fromOffset(230, 42)
	pill.BackgroundColor3 = UiKit.DARK
	pill.BackgroundTransparency = 0.15
	pill.ZIndex = 4
	pill.Parent = footer
	UiKit.corner(pill, 21)
	UiKit.border(pill, 3)
	local cashArt = Instance.new("Frame")
	cashArt.BackgroundTransparency = 1
	cashArt.AnchorPoint = Vector2.new(0, 0.5)
	cashArt.Position = UDim2.new(0, -26, 0.5, 0)
	cashArt.Size = UDim2.fromOffset(64, 64)
	cashArt.ZIndex = 5
	cashArt.Parent = pill
	Icon3D.outlined(cashArt, "moneybag")
	local cashLabel = makeTitle(pill, "", UiKit.CASH_GREEN, UDim2.new(1, -54, 1, -8), UDim2.fromOffset(44, 4))
	cashLabel.TextXAlignment = Enum.TextXAlignment.Left
	cashLabel.ZIndex = 5
	local famePill = makeTitle(footer, "", UiKit.GOLD, UDim2.fromOffset(130, 34), UDim2.new(0.5, 70, 0.5, -17), 2)
	famePill.BackgroundColor3 = UiKit.DARK
	famePill.BackgroundTransparency = 0.15
	famePill.ZIndex = 4
	UiKit.corner(famePill, 17)
	UiKit.border(famePill, 3)

	local function setZoom(value: number)
		local view = board.AbsoluteSize
		-- Keep the middle of the view in place while zooming.
		local centre = (board.CanvasPosition + view / 2) / zoom
		zoom = math.clamp(value, MIN_ZOOM, MAX_ZOOM)
		zoomScale.Scale = zoom
		board.CanvasSize = UDim2.fromOffset(width * zoom, height * zoom)
		board.CanvasPosition = centre * zoom - view / 2
	end
	local zoomIn = makeButton(footer, "+", UiKit.BLUE, UDim2.fromOffset(46, 46), UDim2.new(1, -100, 0.5, -23))
	local zoomOut = makeButton(footer, "-", UiKit.BLUE, UDim2.fromOffset(46, 46), UDim2.new(1, -48, 0.5, -23))
	for _, button in { zoomIn, zoomOut } do
		button.ZIndex = 5
		UiKit.textConstraint(button, 32)
	end
	zoomIn.Activated:Connect(function()
		setZoom(zoom + ZOOM_STEP)
	end)
	zoomOut.Activated:Connect(function()
		setZoom(zoom - ZOOM_STEP)
	end)

	-- Header and footer heights follow the screen: slimmer on short (phone) screens.
	local function layout()
		local compact = UiKit.isCompact()
		local headerHeight = if compact then 70 else 108
		title.Size = UDim2.new(0.7, 0, 0, if compact then 36 else 52)
		title.Position = UDim2.new(0.15, 0, 0, if compact then 4 else 8)
		titleShadow.Size = title.Size
		titleShadow.Position = title.Position + UDim2.fromOffset(0, if compact then 3 else 5)
		local starSize = if compact then 36 else 54
		for _, star in titleStars do
			star.Size = UDim2.fromOffset(starSize, starSize)
			star.Position = UDim2.new(0.5, (star:GetAttribute("Side") :: number) * (if compact then 160 else 230), 0, if compact then 2 else 6)
		end
		subtitle.Size = UDim2.new(0.7, 0, 0, if compact then 16 else 22)
		subtitle.Position = UDim2.new(0.15, 0, 0, if compact then 40 else 60)
		statsLabel.Size = UDim2.new(0.7, 0, 0, if compact then 14 else 18)
		statsLabel.Position = UDim2.new(0.15, 0, 0, if compact then 56 else 84)
		local closeSize = if compact then 42 else 56
		close.Size = UDim2.fromOffset(closeSize, closeSize)
		close.Position = UDim2.new(1, -(closeSize + 12), 0, if compact then 6 else 12)
		board.Position = UDim2.fromOffset(0, headerHeight)
		board.Size = UDim2.new(1, 0, 1, -(headerHeight + 70))
	end
	UiKit.onViewportChanged(layout)
	layout()

	-- Fit the whole width on screen when it opens (never bigger than 1:1), scrolled to the top.
	local function fitZoom()
		local view = board.AbsoluteSize
		if view.X <= 0 then
			return
		end
		zoom = math.clamp((view.X - 16) / width, MIN_ZOOM, 1)
		zoomScale.Scale = zoom
		board.CanvasSize = UDim2.fromOffset(width * zoom, height * zoom)
		board.CanvasPosition = Vector2.new(math.max(0, (width * zoom - view.X) / 2), 0)
	end

	-- Tree -------------------------------------------------------------------------------------

	local selected: { id: string, n: number }? = nil
	-- Set when a press lands on a node or the card, so releasing it doesn't count as a tap on the
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
	local nodes: { [string]: { Node } } = {}
	local refresh: () -> ()

	local function columnX(i: number): number
		return MARGIN + COLUMN * (i - 0.5)
	end
	local function nodeY(n: number): number
		return FIRST_Y + (n - 1) * ROW
	end

	-- One square node with its name above it, centred on (x, y top).
	local function makeNode(x: number, y: number): Node
		local tile = Instance.new("TextButton")
		tile.Text = ""
		tile.AutoButtonColor = true
		tile.AnchorPoint = Vector2.new(0.5, 0)
		tile.Position = UDim2.fromOffset(x, y)
		tile.Size = UDim2.fromOffset(NODE, NODE)
		tile.BackgroundColor3 = HIDDEN
		tile.ZIndex = 3
		-- Soft drop shadow and (for nodes you can buy) a gold halo, both behind the node.
		local shadow = Instance.new("Frame")
		shadow.Name = "Shadow"
		shadow.BorderSizePixel = 0
		shadow.BackgroundColor3 = UiKit.INK
		shadow.BackgroundTransparency = 0.35
		shadow.AnchorPoint = Vector2.new(0.5, 0)
		shadow.Position = UDim2.fromOffset(x, y + 7)
		shadow.Size = UDim2.fromOffset(NODE, NODE)
		shadow.ZIndex = 2
		shadow.Parent = content
		UiKit.corner(shadow, 16)
		local halo = Instance.new("Frame")
		halo.Name = "Halo"
		halo.BorderSizePixel = 0
		halo.BackgroundColor3 = UiKit.GOLD
		halo.BackgroundTransparency = 0.45
		halo.AnchorPoint = Vector2.new(0.5, 0.5)
		halo.Position = UDim2.fromOffset(x, y + NODE / 2)
		halo.Size = UDim2.fromOffset(NODE + 18, NODE + 18)
		halo.Visible = false
		halo.ZIndex = 2
		halo.Parent = content
		UiKit.corner(halo, 22)
		tile.Parent = content
		UiKit.corner(tile, 14)
		UiKit.border(tile, 5)
		bevel(tile)
		sprockets(tile)
		local art = Instance.new("Frame")
		art.Name = "Art"
		art.BackgroundTransparency = 1
		art.AnchorPoint = Vector2.new(0.5, 0)
		art.Position = UDim2.new(0.5, 0, 0, 6)
		art.Size = UDim2.fromOffset(NODE - 26, NODE - 26)
		art.ZIndex = 4
		art.Parent = tile
		local price = makeTitle(tile, "", UiKit.CASH_GREEN, UDim2.new(1, -6, 0, 26), UDim2.new(0, 3, 1, -29), 2.5)
		price.ZIndex = 6
		local unknown = makeTitle(tile, "?", UiKit.WHITE, UDim2.fromScale(0.7, 0.7), UDim2.fromScale(0.15, 0.12), 4)
		unknown.ZIndex = 5
		UiKit.textConstraint(unknown, 64)
		local name = makeTitle(content, "", UiKit.WHITE, UDim2.fromOffset(COLUMN - 6, 28), UDim2.fromOffset(x - (COLUMN - 6) / 2, y - 24), 3)
		name.ZIndex = 6 -- overlaps the node's top edge, like the reference
		UiKit.textConstraint(name, 26)
		marksPress(tile)
		return { tile = tile, name = name, price = price, unknown = unknown, art = art, halo = halo, hasIcon = false }
	end

	-- The studio: the root every chain branches from.
	local root = makeNode(width / 2, ROOT_Y)
	root.name.Text = "Your Studio"
	root.unknown.Visible = false
	-- Red-carpet red with a gold rim: the studio is the star of the tree.
	root.tile.BackgroundColor3 = UiKit.RED
	local rim = root.tile:FindFirstChild("Outline")
	if rim ~= nil and rim:IsA("UIStroke") then
		rim.Color = UiKit.GOLD
	end
	root.tile.AutoButtonColor = false
	Icon3D.outlined(root.art, "movieCamera")
	-- Branches: down from the studio onto a film strip running across, then an arrow down into
	-- each chain.
	local branchY = ROOT_Y + NODE + 26
	line(content, width / 2, ROOT_Y + NODE + 4, width / 2, branchY, false)
	filmStrip(content, columnX(1), columnX(count), branchY)

	-- The card next to a tapped node: what that level gives and its Buy button.
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = UDim2.fromOffset(256, 172)
	card.BackgroundColor3 = UiKit.NAVY
	card.Visible = false
	card.ZIndex = 10
	card.Active = true
	card.Parent = content
	marksPress(card)
	UiKit.corner(card, 14)
	UiKit.border(card, 4)
	-- Burgundy title band across the top, like the other windows' title bars.
	local band = Instance.new("Frame")
	band.Name = "Band"
	band.BorderSizePixel = 0
	band.BackgroundColor3 = UiKit.BURGUNDY
	band.Size = UDim2.new(1, 0, 0, 40)
	band.ZIndex = 10
	band.Parent = card
	UiKit.corner(band, 12)
	local bandEdge = Instance.new("Frame")
	bandEdge.BorderSizePixel = 0
	bandEdge.BackgroundColor3 = UiKit.INK
	bandEdge.AnchorPoint = Vector2.new(0, 1)
	bandEdge.Position = UDim2.fromScale(0, 1)
	bandEdge.Size = UDim2.new(1, 0, 0, 3)
	bandEdge.ZIndex = 11
	bandEdge.Parent = band
	local cardTitle = makeTitle(card, "", UiKit.WHITE, UDim2.new(1, -20, 0, 30), UDim2.fromOffset(10, 5), 3)
	cardTitle.ZIndex = 12
	local cardNow = makeLabel(card, "", UiKit.MUTED, UDim2.new(1, -20, 0, 20), UDim2.fromOffset(10, 48))
	cardNow.ZIndex = 11
	local cardNext = makeLabel(card, "", UiKit.CASH_GREEN, UDim2.new(1, -20, 0, 20), UDim2.fromOffset(10, 72))
	cardNext.ZIndex = 11
	local cardButton = makeButton(card, "", UiKit.GREEN, UDim2.new(1, -20, 0, 50), UDim2.fromOffset(10, 108))
	cardButton.ZIndex = 11
	marksPress(cardButton)

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
			UiKit.toast(gui, `Needs Fame {Hud.comma(upgrade.fame[pick.n])}`)
		elseif state == "short" then
			UiKit.toast(gui, "Not enough Cash")
		else
			buyUpgrade:FireServer(upgrade.id)
		end
	end)

	for i, upgrade in Upgrades.List do
		local x = columnX(i)
		line(content, x, branchY, x, nodeY(1) - 22, true)
		nodes[upgrade.id] = {}
		for n = 1, upgrade.maxLevel do
			if n > 1 then
				line(content, x, nodeY(n - 1) + NODE + 6, x, nodeY(n) - 22, true)
			end
			local node = makeNode(x, nodeY(n))
			node.tile.Name = `{upgrade.id}{n}`
			nodes[upgrade.id][n] = node
			node.tile.Activated:Connect(function()
				local level = Upgrades.level(ClientState.stats(), upgrade.id)
				if n > level + 1 then
					UiKit.toast(gui, "Buy the level above first")
					return
				end
				selected = if selected ~= nil and selected.id == upgrade.id and selected.n == n then nil else { id = upgrade.id, n = n }
				Sfx.play("click")
				refresh()
			end)
		end
	end

	-- Paints one node for its state.
	local function paintNode(node: Node, state: NodeState, upgrade: Upgrades.Upgrade, n: number, isSelected: boolean)
		local tile = node.tile
		local pulse = tile:FindFirstChild("Pulse")
		if pulse ~= nil then
			pulse:Destroy()
			tile.AnchorPoint = Vector2.new(0.5, 0)
			tile.Position = UDim2.fromOffset(columnX(table.find(Upgrades.List, upgrade) or 1), nodeY(n))
		end
		local outline = tile:FindFirstChild("Outline")
		if outline ~= nil and outline:IsA("UIStroke") then
			outline.Color = if isSelected then UiKit.WHITE else UiKit.INK
		end
		local hidden = state == "hidden"
		node.unknown.Visible = hidden
		node.name.Visible = not hidden
		node.name.Text = nodeName(upgrade.id, n)
		node.art.Visible = not hidden
		if not hidden and not node.hasIcon then
			node.hasIcon = true
			Icon3D.outlined(node.art, ICONS[upgrade.id] or "arrow")
		end
		node.price.Visible = state ~= "owned" and not hidden
		if hidden then
			tile.BackgroundColor3 = HIDDEN
		elseif state == "owned" then
			tile.BackgroundColor3 = OWNED
		else
			tile.BackgroundColor3 = if state == "buy" then AMBER_TOP else AMBER
			if state == "fame" then
				node.price.Text = `Fame {shortCash(upgrade.fame[n]):sub(2)}`
				node.price.TextColor3 = UiKit.WARN
			else
				node.price.Text = shortCash(upgrade.costs[n])
				node.price.TextColor3 = if state == "buy" then UiKit.CASH_GREEN else PRICE_RED
			end
			if state == "buy" then
				UiKit.pulse(tile, 1.07)
			end
		end
		node.halo.Visible = state == "buy"
	end

	-- Places the card beside the selected node (on the left for the right-hand chains).
	local function showCard(stats: any, cash: number, fame: number)
		local pick = selected
		local upgrade = if pick ~= nil then Upgrades.get(pick.id) else nil
		if pick == nil or upgrade == nil then
			card.Visible = false
			return
		end
		local index = table.find(Upgrades.List, upgrade) or 1
		local level = Upgrades.level(stats, upgrade.id)
		local x = columnX(index)
		local left = index > count / 2
		local cardX = if left then x - NODE / 2 - 12 - card.Size.X.Offset else x + NODE / 2 + 12
		local cardY = math.clamp(nodeY(pick.n) - 30, 0, height - card.Size.Y.Offset)
		card.Position = UDim2.fromOffset(math.clamp(cardX, 4, width - card.Size.X.Offset - 4), cardY)
		cardTitle.Text = `{upgrade.name}  Lv {pick.n}`
		cardNow.Text = "Now: " .. upgrade.effect(level)
		if pick.n <= level then
			cardNext.Text = "Owned: " .. upgrade.effect(pick.n)
			cardNext.TextColor3 = UiKit.GOLD
			cardButton.Text = "OWNED"
			cardButton.BackgroundColor3 = OWNED
			cardButton.TextColor3 = UiKit.WHITE
		else
			cardNext.Text = "Next: " .. upgrade.effect(pick.n)
			cardNext.TextColor3 = UiKit.CASH_GREEN
			local state = nodeState(upgrade, level, pick.n, cash, fame)
			-- Gold "locked", green "buy", grey "can't afford", as on the other screens.
			if state == "fame" then
				cardButton.Text = `Needs Fame {Hud.comma(upgrade.fame[pick.n])}`
				cardButton.BackgroundColor3 = UiKit.AWARD_GOLD
				cardButton.TextColor3 = UiKit.WHITE
			else
				cardButton.Text = `BUY ${Hud.comma(upgrade.costs[pick.n])}`
				UiKit.setEnabled(cardButton, state == "buy", UiKit.GREEN)
			end
		end
		card.Visible = true
	end

	refresh = function()
		local stats = ClientState.stats()
		local cash = player:GetAttribute("Cash") or 0
		local fame = player:GetAttribute("Fame") or 0

		local rate = if ClientState.studio ~= nil then ClientState.studio.rate else Config.CinemaIncomePerSecond
		local rebirths = stats.rebirths or 0
		local rebirthText = if rebirths > 0 then `  -  Rebirth {Rebirth.multiplierText(rebirths)} Cash` else ""
		statsLabel.Text = `Luck x{string.format("%.2f", Upgrades.luck(stats))}  -  Royalties ${string.format("%.2f", rate)}/s  -  Offline {Upgrades.offlineCap(stats) / 3600}h{rebirthText}`
		cashLabel.Text = "$" .. Hud.comma(cash)
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
				local state = nodeState(upgrade, level, n, cash, fame)
				paintNode(node, state, upgrade, n, pick ~= nil and pick.id == upgrade.id and pick.n == n)
			end
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
		SideMenu.setBadge(upgradesButton, buyableCount(ClientState.stats(), player:GetAttribute("Cash") or 0, player:GetAttribute("Fame") or 0))
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

	local function open()
		selected = nil
		refresh()
		-- Sized once the screen is showing.
		task.defer(fitZoom)
	end
	upgradesButton.Activated:Connect(function()
		UiKit.togglePanel(screen, open)
	end)
	Screens.register("Upgrades", function()
		if not screen.Visible then
			UiKit.togglePanel(screen, open)
		end
	end)
end

return UpgradesUi
