--!strict
-- First-time tutorial, hosted by Director Lucien Vale (an original character, see
-- ActorModels.buildDirector): cast, claim a lot, find the Movies stand, buy a script, film,
-- premiere, collect.
--
-- New players meet Lucien on an intro screen: curtains open on him, big and cropped at the waist,
-- with a screenplay-page bubble beside him ("Let's roll!" appears after the last line). After that
-- his bust sits in the top-right corner with the bubble to its left (panels start below it, see
-- UiKit.makePanel's "PanelTop"). One short line per view (src/shared/TutorialLines.luau); the
-- yellow arrows point at the real control (a menu button, a tab, a row) and, where there is one,
-- at the stand in the plaza, with a glow on the target, a big glossy arrow over it, and a trail of
-- yellow chevrons on the ground flowing from the player to it.
--
-- Each step completes from real game state (not from button presses), so a player who already did
-- something skips it, and nothing here can grant anything. Finishing or skipping tells the server
-- once (TutorialDone), and it never shows again. The first Short Film is shortened server-side.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local ClientState = require(script.Parent.ClientState)
local CountUp = require(ReplicatedStorage.Shared.CountUp)
local Fx = require(script.Parent.Fx)
local Hud = require(script.Parent.Hud)
local Icon3D = require(script.Parent.Icon3D)
local Sfx = require(script.Parent.Sfx)
local UiKit = require(script.Parent.UiKit)
local Spotlight = require(ReplicatedStorage.Shared.Spotlight)
local TutorialLines = require(ReplicatedStorage.Shared.TutorialLines)

-- The guide color: brighter and yellower than the UI's gold, so directions read as directions.
local GUIDE = Color3.fromRGB(255, 222, 26)
local HINT_BLUE = Color3.fromRGB(110, 190, 255)
local CURTAIN = Color3.fromRGB(122, 18, 36)

-- The chevron trail on the ground (studs). Each chevron is two see-through neon arms lying flat,
-- meeting at a tip that points at the target. They flow along the path at TRAIL_SPEED,
-- TRAIL_SPACING apart, and a wave runs through them from the player toward the target, each
-- chevron popping a little bigger and brighter as it passes.
local TRAIL_SPACING = 4.5
local TRAIL_SPEED = 6
local TRAIL_START = 3.5 -- the first chevron's distance ahead of the player
local TRAIL_END = 2.5 -- the last one stops this far short of the target
local TRAIL_FADE = 2 -- chevrons fade in and out over this distance at each end
local CHEVRON_ARM = 3.2
local CHEVRON_ANGLE = math.rad(40) -- each arm's angle off the path
local CHEVRON_LIFT = 0.2
local CHEVRON_SEE = 0.35 -- the arms' resting transparency
local WAVE_SPEED = 24 -- studs per second
local WAVE_GAP = 30 -- studs between waves
local WAVE_WIDTH = 6 -- how far behind its front a wave fades out
local WAVE_GROW = 0.25 -- extra scale at the wave's front
local WAVE_GLOW = 0.3 -- transparency taken off at the wave's front
type ChevronArm = { offset: CFrame, size: Vector3 }
local CHEVRON_ARMS: { ChevronArm } = {}
do
	-- In the chevron's own frame -Z points at the target. Each arm's centre sits beside the path,
	-- turned so the two meet at the tip, and nudged toward the tip so they close it off.
	local thick, depth = 0.8, 0.25
	for _, side in { 1, -1 } do
		local along = CFrame.Angles(0, side * CHEVRON_ANGLE, 0)
		local centre = Vector3.new(side * math.sin(CHEVRON_ANGLE) * CHEVRON_ARM / 2, 0, 0)
		table.insert(CHEVRON_ARMS, {
			offset = CFrame.new(centre) * along * CFrame.new(0, 0, -thick * 0.3),
			size = Vector3.new(thick, depth, CHEVRON_ARM + thick * 0.6),
		})
	end
end

-- Dialogue layout (pixels). The speech bubble is a cream screenplay page; Lucien's bust sits in a
-- top-right corner after the intro, with the bubble to its left and Skip under the bust.
local BUBBLE_MAX_PHONE = 260
local BUBBLE_MAX_PC = 400
local BUST_PHONE = 76
local BUST_PC = 110
local EDGE = 8

local CHARS_PER_SECOND = 60

-- Spotlight: one UI target at a time gets a gold ring and a pointing hand. The dim around it is
-- optional (video research: arrow-only works too) and never blocks a tap.
local DIM_ENABLED = true
local DIM_TRANSPARENCY = 0.55
local DIM_PAD = 8 -- px of breathing room around the target's hole
local HAND_IMAGE_ID = 0 -- the white glove pointer's asset id; 0 = not uploaded yet, the arrow stands in
local IDLE_HINT_SECONDS = 9 -- no progress on a step for this long: pulse the target once

-- A place in the world to guide the player to. "primary" gets the arrow, glow, the chevron trail
-- on the ground and an arrow at the screen edge while it is out of view; "secondary" an arrow and
-- glow; "hint" only a soft blue outline.
type WorldTarget = {
	adornee: BasePart, -- the arrow floats over this
	glow: Instance, -- what glows (a pad, or a stand's whole model)
	ground: BasePart?, -- where the chevron trail on the ground ends
	label: string,
	height: number, -- studs above the adornee for the arrow
	kind: string,
}

type View = {
	linesKey: string, -- the dialogue restarts when this changes
	lines: { string }, -- keys of TutorialLines.LINES
	ui: { GuiObject },
	world: { WorldTarget },
}

type Step = {
	done: () -> boolean,
	view: () -> View,
}

local Tutorial = {}

-- A chunky, glossy yellow arrow with a dark outline, pointing down (turn it with Rotation: 90
-- points left, 180 up, 270 right). A shaft and a diamond, so the head's back edges sweep toward the
-- shaft; a top-to-bottom gold shade and a white shine down its left side make it read as glossy.
local GLOSS = ColorSequence.new(Color3.fromRGB(255, 242, 150), Color3.fromRGB(255, 178, 20))
local function makeArrow(parent: Instance, size: number, zIndex: number): Frame
	local holder = Instance.new("Frame")
	holder.Name = "GuideArrow"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Size = UDim2.fromOffset(size, size)
	holder.ZIndex = zIndex
	local outline = math.max(7, math.floor(size * 0.12))
	local function piece(name: string, color: Color3, grow: number, z: number, diamond: boolean): Frame
		local frame = Instance.new("Frame")
		frame.Name = name
		frame.BorderSizePixel = 0
		frame.BackgroundColor3 = color
		frame.ZIndex = z
		if diamond then
			frame.AnchorPoint = Vector2.new(0.5, 0.5)
			frame.Position = UDim2.fromScale(0.5, 0.6)
			frame.Size = UDim2.new(0.48, grow, 0.48, grow)
			frame.Rotation = 45
		else
			frame.Position = UDim2.new(0.35, -grow / 2, 0.04, -grow / 2)
			frame.Size = UDim2.new(0.3, grow, 0.5, grow)
		end
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(0, if diamond then 5 else 4)
		round.Parent = frame
		frame.Parent = holder
		return frame
	end
	piece("ShaftOutline", UiKit.INK, outline, zIndex, false)
	piece("HeadOutline", UiKit.INK, outline + 1, zIndex, true)
	local shaft = piece("Shaft", GUIDE, 0, zIndex + 1, false)
	local head = piece("Head", GUIDE, 0, zIndex + 1, true)
	for _, frame in { shaft, head } do
		frame.BackgroundColor3 = Color3.new(1, 1, 1)
		local shade = Instance.new("UIGradient")
		shade.Color = GLOSS
		-- Screen-vertical: the diamond is turned 45 degrees, so its gradient turns back by as much.
		shade.Rotation = if frame == head then 45 else 90
		shade.Parent = frame
	end
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.BorderSizePixel = 0
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.BackgroundTransparency = 0.25
	shine.Position = UDim2.fromScale(0.16, 0.12)
	shine.Size = UDim2.fromScale(0.2, 0.62)
	shine.ZIndex = zIndex + 2
	local shineRound = Instance.new("UICorner")
	shineRound.CornerRadius = UDim.new(1, 0)
	shineRound.Parent = shine
	shine.Parent = shaft
	holder.Parent = parent
	return holder
end

local function reducedMotion(): boolean
	local ok, value = pcall(function()
		return (GuiService :: any).ReducedMotionEnabled
	end)
	return ok and value == true
end

-- The pointer over a UI target: the white glove once HAND_IMAGE_ID is set, else the arrow. Same
-- turning rules as makeArrow (0 points down).
local function makeHand(parent: Instance, size: number, zIndex: number): GuiObject
	if HAND_IMAGE_ID == 0 then
		return makeArrow(parent, size, zIndex)
	end
	local hand = Instance.new("ImageLabel")
	hand.Name = "GuideHand"
	hand.BackgroundTransparency = 1
	hand.Image = `rbxassetid://{HAND_IMAGE_ID}`
	hand.AnchorPoint = Vector2.new(0.5, 0.5)
	hand.Size = UDim2.fromOffset(size, size)
	hand.ZIndex = zIndex
	hand.Parent = parent
	return hand
end

function Tutorial.start(gui: ScreenGui, remotes: Instance)
	local player = Players.LocalPlayer
	local tutorialDone = remotes:WaitForChild("TutorialDone", 10) :: RemoteEvent?
	if tutorialDone == nil then
		return
	end
	local premiereResult = remotes:FindFirstChild("PremiereResult") :: RemoteEvent?
	local playerGui = gui.Parent

	local function studio(): any
		return ClientState.studio
	end
	local function count(t: { [any]: any }?): number
		local n = 0
		if t ~= nil then
			for _ in t do
				n += 1
			end
		end
		return n
	end
	local function hasScripts(): boolean
		local s = studio()
		return s ~= nil and (count(s.scripts) > 0 or #s.films > 0 or #s.cinema > 0)
	end
	local function hasFilm(): boolean
		local s = studio()
		return s ~= nil and (#s.films > 0 or #s.cinema > 0)
	end
	local function hasPremiered(): boolean
		local s = studio()
		return s ~= nil and #s.cinema > 0
	end

	-- UI lookups --------------------------------------------------------------------------------
	local function panel(name: string): Frame?
		local found = gui:FindFirstChild(name)
		return if found ~= nil and found:IsA("Frame") then found else nil
	end
	local function isOpen(name: string): boolean
		local found = panel(name)
		return found ~= nil and found.Visible
	end
	local function findGui(parent: Instance?, name: string): GuiObject?
		if parent == nil then
			return nil
		end
		local found = parent:FindFirstChild(name, true)
		return if found ~= nil and found:IsA("GuiObject") then found else nil
	end
	local function anyPanelOpen(): boolean
		for _, child in gui:GetChildren() do
			if child:IsA("GuiObject") and child.Visible and string.sub(child.Name, -5) == "Panel" then
				return true
			end
		end
		return false
	end
	-- The casting and premiere reveals cover the screen; Lucien waits for them to finish.
	local function revealShowing(): boolean
		-- The premiere overlay lives in its own screen (PremiereReveal.start).
		local backdrop = if playerGui ~= nil then playerGui:FindFirstChild("PremiereRevealBackdrop") else nil
		for _, name in { "Reveal", "PremiereReveal" } do
			local overlay = gui:FindFirstChild(name) or (if backdrop ~= nil then backdrop:FindFirstChild(name) else nil)
			if overlay ~= nil and overlay:IsA("GuiObject") and overlay.Visible then
				return true
			end
		end
		return false
	end

	-- World lookups -----------------------------------------------------------------------------
	-- A store stand on the plaza (MapModels.stand), by the screen its prompt opens.
	local function standTarget(screen: string, label: string, kind: string): WorldTarget?
		local town = workspace:FindFirstChild("Town")
		local model = if town ~= nil then town:FindFirstChild("Stand_" .. screen) else nil
		local anchor = if model ~= nil then model:FindFirstChild("PromptAnchor") else nil
		if model == nil or anchor == nil or not anchor:IsA("BasePart") then
			return nil
		end
		local ring = model:FindFirstChild("PromptRing")
		return {
			adornee = anchor,
			glow = model,
			ground = if ring ~= nil and ring:IsA("BasePart") then ring else nil,
			label = label,
			height = 23, -- over the stand's floating name
			kind = kind,
		}
	end

	-- The player's own collect pad, or the nearest free claim pad (one behind the camera counts
	-- as twice as far). The claim pad is re-picked at most every two seconds, so the guide does
	-- not flick between two pads.
	local claimPad: BasePart? = nil
	local claimPickedAt = -math.huge
	local function findPad(kind: string): BasePart?
		local lots = workspace:FindFirstChild("Lots")
		if lots == nil then
			return nil
		end
		if kind == "collect" then
			local index = player:GetAttribute("LotIndex")
			local lot = if index ~= nil then lots:FindFirstChild("Lot" .. tostring(index)) else nil
			local pad = if lot ~= nil then lot:FindFirstChild("CollectPad", true) else nil
			return if pad ~= nil and pad:IsA("BasePart") then pad else nil
		end
		local current = claimPad
		if current ~= nil and current.Parent ~= nil and os.clock() - claimPickedAt < 2 then
			local lot = current:FindFirstAncestorWhichIsA("Model")
			if lot == nil or lot:GetAttribute("OwnerUserId") == nil then
				return current
			end
		end
		local character = player.Character
		local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		local camera = workspace.CurrentCamera
		local best: BasePart? = nil
		local bestScore = math.huge
		for _, lot in lots:GetChildren() do
			local pad = lot:FindFirstChild("ClaimPad", true)
			if pad ~= nil and pad:IsA("BasePart") and lot:GetAttribute("OwnerUserId") == nil then
				local distance = if root ~= nil and root:IsA("BasePart") then (root.Position - pad.Position).Magnitude else 0
				local facing = 1
				if camera ~= nil then
					local toPad = pad.Position - camera.CFrame.Position
					facing = if toPad.Magnitude > 0 then camera.CFrame.LookVector:Dot(toPad.Unit) else 1
				end
				local score = distance * (1.5 - 0.5 * facing)
				if score < bestScore then
					best, bestScore = pad, score
				end
			end
		end
		claimPad, claimPickedAt = best, os.clock()
		return best
	end
	local function padTarget(kind: string): WorldTarget?
		local pad = findPad(kind)
		if pad == nil then
			return nil
		end
		return {
			adornee = pad,
			glow = pad :: Instance,
			ground = pad,
			label = if kind == "claim" then "" else "COLLECT",
			height = 4,
			kind = "primary",
		}
	end

	-- Dialogue -----------------------------------------------------------------------------------
	-- A full-size transparent frame holding the bubble, Lucien's bust and Skip; layout() places them.
	local container = Instance.new("Frame")
	container.Name = "Tutorial"
	container.BackgroundTransparency = 1
	container.Size = UDim2.fromScale(1, 1)
	container.Visible = false
	container.ZIndex = 8
	-- Its own screen: above the HUD (0) and the spotlight dim (1), below the reveals (5+). Same
	-- insets as the HUD, so positions match. SpecialEventsUi finds it by this name.
	local dialogueMain = Instance.new("ScreenGui")
	dialogueMain.Name = "TutorialDialogue"
	dialogueMain.ResetOnSpawn = false
	dialogueMain.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	dialogueMain.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	dialogueMain.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None
	dialogueMain.DisplayOrder = 2
	dialogueMain.Parent = playerGui
	container.Parent = dialogueMain

	-- The speech bubble: a cream screenplay page with the cue "LUCIEN" over the line.
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.BackgroundColor3 = UiKit.CREAM
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.ZIndex = 8
	card.Parent = container
	UiKit.corner(card, 16)
	UiKit.border(card, 3, UiKit.INK)
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Size = UDim2.fromScale(1, 0)
	body.AutomaticSize = Enum.AutomaticSize.Y
	body.ZIndex = 11 -- above the tapper, which sits under the text and the button
	body.Parent = card
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 12), UDim.new(0, 12)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 8), UDim.new(0, 10)
	pad.Parent = body
	local stack = Instance.new("UIListLayout")
	stack.Padding = UDim.new(0, 4)
	stack.SortOrder = Enum.SortOrder.LayoutOrder
	stack.Parent = body

	local SCREENPLAY = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)
	local function typeLabel(name: string, order: number, color: Color3): TextLabel
		local label = Instance.new("TextLabel")
		label.Name = name
		label.LayoutOrder = order
		label.BackgroundTransparency = 1
		label.FontFace = SCREENPLAY
		label.TextColor3 = color
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Top
		label.TextWrapped = true
		label.Size = UDim2.fromScale(1, 0)
		label.AutomaticSize = Enum.AutomaticSize.Y
		label.ZIndex = 11
		label.Parent = body
		return label
	end
	local nameLabel = typeLabel("Cue", 1, CURTAIN)
	nameLabel.Text = "LUCIEN"
	local speech = typeLabel("Speech", 2, UiKit.INK)

	-- "Let's roll!" ends the intro; it only shows once the last intro line has been typed.
	local begin = UiKit.makeButton(body, "Let's roll!", UiKit.GREEN, UDim2.new(1, 0, 0, 44))
	begin.Name = "Begin"
	begin.LayoutOrder = 3
	begin.Visible = false
	begin.ZIndex = 12
	UiKit.textConstraint(begin, 24)

	-- Tapping the bubble shows the whole line at once, or the next line.
	local tapper = Instance.new("TextButton")
	tapper.Name = "Next"
	tapper.Text = ""
	tapper.BackgroundTransparency = 1
	tapper.Size = UDim2.fromScale(1, 1)
	tapper.ZIndex = 10
	tapper.Parent = card

	-- Lucien's bust in the corner (a sibling of the bubble, so the intro can hide it).
	local bust = Instance.new("Frame")
	bust.Name = "Portrait"
	bust.AnchorPoint = Vector2.new(1, 0)
	bust.BackgroundColor3 = CURTAIN
	bust.ZIndex = 9
	bust.Parent = container
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = bust
	UiKit.border(bust, 3, UiKit.INK)
	Icon3D.director(bust, true)

	local skip = UiKit.makeButton(container, "Skip", UiKit.TAB_OFF, UDim2.fromOffset(72, 32))
	skip.Name = "Skip"
	skip.ZIndex = 11
	UiKit.textConstraint(skip, 18)

	-- State --------------------------------------------------------------------------------------
	local active = false
	local finished = false
	local finale = false
	local splash: Frame? = nil -- the DirectorPanel marker in the HUD
	local studioOpened = false
	local collected = false
	local resultId: string? = nil
	local nearMovies: ProximityPrompt? = nil
	local introTyped = false -- the intro's last line has finished typing

	-- Layout -------------------------------------------------------------------------------------
	local function compact(): boolean
		return UiKit.isCompact()
	end

	-- The lowest bottom edge of the top HUD (wallet, event lines, the "while you were away" note)
	-- over the band [left, right], in the ScreenGui's space.
	local function hudBottom(left: number, right: number): number
		local origin = gui.AbsolutePosition
		local area = gui.AbsoluteSize
		local lowest = 0
		local function consider(object: Instance?)
			if object == nil or not object:IsA("GuiObject") or not object.Visible then
				return
			end
			local at, size = object.AbsolutePosition - origin, object.AbsoluteSize
			if size.Y <= 0 or at.Y > area.Y * 0.4 or at.X > right or at.X + size.X < left then
				return
			end
			lowest = math.max(lowest, at.Y + size.Y)
		end
		consider(gui:FindFirstChild("Wallet"))
		local hud = gui:FindFirstChild("Hud")
		if hud ~= nil and hud:IsA("GuiObject") and hud.Visible then
			for _, child in hud:GetChildren() do
				consider(child)
			end
		end
		return lowest
	end

	local function layout()
		if not container.Visible then
			return
		end
		local parent = container.Parent :: GuiBase2d?
		local area = if parent ~= nil then parent.AbsoluteSize else gui.AbsoluteSize
		if area.X < 1 then
			area = UiKit.viewport()
		end
		local small = compact()
		local touch = gui:GetAttribute("HudRight") == true
		local hudTop = gui:GetAttribute("HudTop")
		local top = if typeof(hudTop) == "number" then hudTop else 8
		local splashOpen = splash ~= nil
		local textSize = if small then 16 else 20
		nameLabel.TextSize = textSize
		speech.TextSize = textSize
		begin.Visible = splashOpen and introTyped
		skip.Size = if small then UDim2.fromOffset(64, 28) else UDim2.fromOffset(80, 34)

		local bustSize = if small then BUST_PHONE else BUST_PC
		local stackHeight = bustSize + 4 + skip.Size.Y.Offset
		local panelOpen = anyPanelOpen()

		if splashOpen then
			-- The intro: the bubble from the middle of the safe area, Skip bottom-right.
			bust.Visible = false
			card.AnchorPoint = Vector2.new(0, 0)
			card.Position = UDim2.fromOffset(math.floor(area.X * 0.5), math.floor(area.Y * 0.28))
			card.Size = UDim2.fromOffset(math.min(math.floor(area.X * 0.46), BUBBLE_MAX_PC + 40), 0)
			skip.AnchorPoint = Vector2.new(1, 1)
			skip.Position = UDim2.fromOffset(area.X - EDGE, area.Y - EDGE)
		else
			-- Corner: the bust at the top right, the bubble to its left, Skip under the bust. On
			-- touch screens it drops under the wallet and the event lines; a panel pulls it to the top.
			bust.Visible = true
			bust.Size = UDim2.fromOffset(bustSize, bustSize)
			local panelY = if touch then 0 else math.max(0, top - 8)
			local y = panelY
			local bubbleWidth = math.min(if small then BUBBLE_MAX_PHONE else BUBBLE_MAX_PC, area.X - bustSize - EDGE * 3)
			if not panelOpen and touch then
				local right = area.X - EDGE
				y = math.max(top - 6, hudBottom(right - bustSize - 8 - bubbleWidth, right) - 4)
			end
			local right = area.X - EDGE
			bust.Position = UDim2.fromOffset(right, y)
			card.AnchorPoint = Vector2.new(1, 0)
			card.Position = UDim2.fromOffset(right - bustSize - 8, y)
			card.Size = UDim2.fromOffset(bubbleWidth, 0)
			skip.AnchorPoint = Vector2.new(1, 0)
			skip.Position = UDim2.fromOffset(right, y + bustSize + 4)
		end

		-- Panels start under the bust and bubble as they sit while a panel is open. Only set on a
		-- change: panels and the HUD re-lay themselves out when these change.
		local panelY = if touch then 0 else math.max(0, top - 8)
		local panelTop = panelY + math.max(stackHeight, card.AbsoluteSize.Y) + 6
		if gui:GetAttribute("PanelTop") ~= panelTop then
			gui:SetAttribute("PanelTop", panelTop)
		end
		local bottom = if touch then nil else card.Position.Y.Offset + math.max(stackHeight, card.AbsoluteSize.Y) + 4
		if gui:GetAttribute("TutorialBottom") ~= bottom then
			gui:SetAttribute("TutorialBottom", bottom)
		end
	end

	-- Lines --------------------------------------------------------------------------------------
	local queue: { string } = {}
	local lineIndex = 0
	local typed = 0
	local typing = false
	local lineDoneAt = 0
	local linesKey = ""
	local stepStartedAt = os.clock() -- idle-hint clock: reset on a step, line change or splash close
	local hinted = false

	-- A line key's text. The Studio stand's line follows the player's own input.
	local promptHint: () -> string?
	local function lineText(key: string): string
		if key == "studioNear" then
			local hint = promptHint()
			if hint ~= nil then
				return hint
			end
		end
		return TutorialLines.LINES[key] or key
	end

	local function showLine(index: number)
		lineIndex = index
		local key = queue[index]
		speech.Text = if key ~= nil then lineText(key) else ""
		speech.MaxVisibleGraphemes = 0
		typed = 0
		typing = true
		local voice = if key ~= nil then TutorialLines.VOICE[key] else nil
		Sfx.cutVoice() -- a new line never talks over the last one
		if voice ~= nil then
			Sfx.play(voice)
		end
	end

	local function playLines(lines: { string })
		queue = lines
		showLine(1)
	end

	-- How long a finished line stays before the next one.
	local function holdTime(text: string): number
		return math.clamp(#text * 0.045, 2.2, 4)
	end

	tapper.Activated:Connect(function()
		if typing then
			typing = false
			speech.MaxVisibleGraphemes = -1
			lineDoneAt = os.clock()
			if splash ~= nil and lineIndex >= #queue then
				introTyped = true
				layout()
			end
		elseif lineIndex < #queue then
			Sfx.play("click")
			showLine(lineIndex + 1)
		end
	end)

	-- Guides --------------------------------------------------------------------------------------
	type UiGuide = { target: GuiObject, arrow: GuiObject, cleanup: () -> () }
	type Trail = { folder: Folder, parts: { BasePart }, fades: { number }, scales: { number } }
	type WorldGuide = { target: WorldTarget, cleanup: () -> (), trail: Trail?, edge: Frame? }
	local uiGuides: { UiGuide } = {}
	local worldGuides: { WorldGuide } = {}

	-- The dim: four black bands around a hole at the target, in its own screen above the HUD (0)
	-- and below the dialogue (2). Visual only: nothing in it takes input.
	local dimGui = Instance.new("ScreenGui")
	dimGui.Name = "TutorialDim"
	dimGui.ResetOnSpawn = false
	dimGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	dimGui.ScreenInsets = Enum.ScreenInsets.None
	dimGui.DisplayOrder = 1
	dimGui.Enabled = false
	dimGui.Parent = playerGui
	local dimBands: { Frame } = {}
	for index = 1, 4 do
		local band = Instance.new("Frame")
		band.Name = `Dim{index}`
		band.BackgroundColor3 = Color3.new(0, 0, 0)
		band.BackgroundTransparency = DIM_TRANSPARENCY
		band.BorderSizePixel = 0
		band.Active = false
		table.insert(dimBands, band)
		band.Parent = dimGui
	end
	local function placeDim(target: GuiObject?)
		dimGui.Enabled = DIM_ENABLED and target ~= nil
		if target == nil or not DIM_ENABLED then
			return
		end
		local at = target.AbsolutePosition - dimGui.AbsolutePosition
		local area = dimGui.AbsoluteSize
		local size = target.AbsoluteSize
		local r = Spotlight.rects(area.X, area.Y, at.X, at.Y, size.X, size.Y, DIM_PAD)
		-- Whole-pixel edges; the right and bottom bands are sized to the screen edge by scale.
		for index, rect in r do
			dimBands[index].Position = UDim2.fromOffset(rect.x, rect.y)
		end
		dimBands[1].Size = UDim2.new(1, 0, 0, r[1].h)
		dimBands[2].Size = UDim2.new(1, 0, 1, -r[2].y)
		dimBands[3].Size = UDim2.fromOffset(r[3].w, r[3].h)
		dimBands[4].Size = UDim2.new(1, -r[4].x, 0, r[4].h)
	end

	local function pulseTween(object: Instance, seconds: number, goal: { [string]: any }): Tween
		local tween = TweenService:Create(object, TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), goal)
		tween:Play()
		return tween
	end

	-- The idle hint: one ~1 s swell (out and back) of the target. A button never carries two
	-- UIScales (Juice.luau), so reuse its own and restore the value; add a temporary one only if
	-- there is none. Anchor and position are left alone, so it grows from the anchor point.
	local function idlePulse(target: GuiObject)
		local existing = target:FindFirstChildWhichIsA("UIScale")
		local temporary = existing == nil
		local object: UIScale
		if existing ~= nil then
			object = existing
		else
			object = Instance.new("UIScale")
			object.Name = "IdleHint"
			object.Parent = target
		end
		local original = object.Scale
		local tween = TweenService:Create(object, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 0, true), { Scale = original * 1.08 })
		tween.Completed:Once(function()
			if temporary then
				object:Destroy()
			else
				object.Scale = original
			end
		end)
		tween:Play()
	end

	-- A pulsing yellow ring on a control. A button keeps one border stroke ("Outline"), so the ring
	-- borrows it and puts its color and thickness back afterwards.
	local function guideGui(target: GuiObject): UiGuide
		local existing = target:FindFirstChild("Outline")
		local stroke: UIStroke
		local restore: { Color: Color3, Thickness: number, Transparency: number }? = nil
		if existing ~= nil and existing:IsA("UIStroke") then
			stroke = existing
			restore = { Color = stroke.Color, Thickness = stroke.Thickness, Transparency = stroke.Transparency }
		else
			stroke = Instance.new("UIStroke")
			stroke.Name = "TutorialPulse"
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		end
		stroke.Color = GUIDE
		stroke.Thickness = 4
		stroke.Parent = target
		local tween = pulseTween(stroke, 0.45, { Thickness = 8, Transparency = 0.4 })
		-- Scroll a list so the control is in view (once its layout has settled).
		task.delay(0.1, function()
			local list = target:FindFirstAncestorWhichIsA("ScrollingFrame")
			if list == nil or target.Parent == nil then
				return
			end
			local offset = target.AbsolutePosition.Y - list.AbsolutePosition.Y
			if offset < 0 or offset + target.AbsoluteSize.Y > list.AbsoluteSize.Y then
				list.CanvasPosition = Vector2.new(list.CanvasPosition.X, math.max(0, list.CanvasPosition.Y + offset - 8))
			end
		end)
		local arrow = makeHand(dialogueMain, if compact() then 44 else 58, 7) -- under the bubble (8)
		arrow.Visible = false
		return {
			target = target,
			arrow = arrow,
			cleanup = function()
				tween:Cancel()
				if restore ~= nil then
					-- If its screen restyled the outline meanwhile (a picked script turns gold), keep that.
					if stroke.Color == GUIDE then
						stroke.Color = restore.Color
						stroke.Thickness = restore.Thickness
					end
					stroke.Transparency = restore.Transparency
				else
					stroke:Destroy()
				end
				arrow:Destroy()
			end,
		}
	end

	-- Fewer chevrons on phones: the trail reaches less far ahead, for less to move each frame.
	local function trailCount(): number
		return if compact() then 9 else 13
	end

	local function guideWorld(target: WorldTarget): WorldGuide
		local made: { Instance } = {}
		local tweens: { Tween } = {}
		local guide: WorldGuide = { target = target, cleanup = function() end }

		-- Glow on the target, local to this player.
		local glow = Instance.new("Highlight")
		glow.Name = "TutorialGlow"
		glow.Adornee = target.glow
		if target.kind == "hint" then
			glow.FillTransparency = 1
			glow.OutlineColor = HINT_BLUE
			glow.DepthMode = Enum.HighlightDepthMode.Occluded
		else
			glow.FillColor = GUIDE
			glow.OutlineColor = GUIDE
			local pad = target.glow:IsA("BasePart")
			glow.FillTransparency = if pad then 0.6 else 0.8
			glow.DepthMode = if pad then Enum.HighlightDepthMode.AlwaysOnTop else Enum.HighlightDepthMode.Occluded
			table.insert(tweens, pulseTween(glow, 0.5, { FillTransparency = if pad then 0.15 else 0.55 }))
		end
		glow.Parent = target.glow
		table.insert(made, glow)

		if target.kind ~= "hint" then
			-- A glossy arrow bobbing over the target, sized in studs so it shrinks with distance and
			-- walls hide it (the ground chevron trail still leads around them).
			local primary = target.kind == "primary"
			local studs = math.max(3, target.height * 0.35) * (if primary then 1 else 0.65)
			local board = Instance.new("BillboardGui")
			board.Name = "TutorialArrow"
			board.Adornee = target.adornee
			board.AlwaysOnTop = false
			board.LightInfluence = 0
			board.MaxDistance = 220
			board.Size = UDim2.fromScale(studs * 1.3, studs * 1.3 + (if target.label ~= "" then studs * 0.5 else 0))
			board.StudsOffsetWorldSpace = Vector3.new(0, target.height, 0)
			-- BillboardGuis do not render inside a ScreenGui; they live directly under PlayerGui.
			board.Parent = playerGui
			local labelShare = if target.label ~= "" then studs * 0.5 / board.Size.Y.Scale else 0
			if target.label ~= "" then
				local label = Instance.new("TextLabel")
				label.BackgroundTransparency = 1
				label.Size = UDim2.fromScale(1, labelShare)
				label.TextColor3 = GUIDE
				label.Font = UiKit.DISPLAY_FONT
				label.TextScaled = true
				label.Text = target.label
				UiKit.outline(label, 3.5)
				label.Parent = board
			end
			local arrow = makeArrow(board, 10, 1)
			arrow.AnchorPoint = Vector2.new(0.5, 1)
			arrow.Position = UDim2.fromScale(0.5, 1)
			arrow.Size = UDim2.fromScale(studs / board.Size.X.Scale, studs / board.Size.Y.Scale)
			table.insert(tweens, pulseTween(board, 0.5, { StudsOffset = Vector3.new(0, studs * 0.3, 0) }))
			table.insert(made, board)
		end

		if target.kind == "primary" then
			-- A trail of see-through yellow chevrons along the ground from the player to the target,
			-- flowing toward it (animateGuides places them each frame).
			local folder = Instance.new("Folder")
			folder.Name = "TutorialTrail"
			local parts: { BasePart } = {}
			for _ = 1, trailCount() do
				for _, arm in CHEVRON_ARMS do
					local part = Instance.new("Part")
					part.Name = "Chevron"
					part.Anchored = true
					part.CanCollide = false
					part.CanQuery = false
					part.CanTouch = false
					part.CastShadow = false
					part.Locked = true
					part.Material = Enum.Material.Neon
					part.Color = GUIDE
					part.Size = arm.size
					part.Transparency = 1
					part.Parent = folder
					table.insert(parts, part)
				end
			end
			local count = #parts // #CHEVRON_ARMS
			guide.trail = { folder = folder, parts = parts, fades = table.create(count, 1), scales = table.create(count, 1) }
			table.insert(made, folder)
			-- An arrow at the edge of the screen while the target is out of view.
			local edge = makeArrow(gui, if compact() then 48 else 64, 9)
			edge.Visible = false
			guide.edge = edge
			table.insert(made, edge)
		end

		guide.cleanup = function()
			for _, tween in tweens do
				tween:Cancel()
			end
			for _, instance in made do
				instance:Destroy()
			end
		end
		return guide
	end

	local function clearGuides()
		for _, guide in uiGuides do
			guide.cleanup()
		end
		table.clear(uiGuides)
		for _, guide in worldGuides do
			guide.cleanup()
		end
		table.clear(worldGuides)
	end

	-- Makes the guides match `ui` and `world`, rebuilding only what changed.
	local function syncGuides(ui: { GuiObject }, world: { WorldTarget })
		local same = #ui == #uiGuides
		if same then
			for index, target in ui do
				if uiGuides[index].target ~= target or target.Parent == nil then
					same = false
					break
				end
			end
		end
		if not same then
			for _, guide in uiGuides do
				guide.cleanup()
			end
			table.clear(uiGuides)
			for _, target in ui do
				table.insert(uiGuides, guideGui(target))
			end
		end
		same = #world == #worldGuides
		if same then
			for index, target in world do
				local old = worldGuides[index].target
				if old.adornee ~= target.adornee or old.kind ~= target.kind or old.adornee.Parent == nil then
					same = false
					break
				end
			end
		end
		if not same then
			for _, guide in worldGuides do
				guide.cleanup()
			end
			table.clear(worldGuides)
			for _, target in world do
				table.insert(worldGuides, guideWorld(target))
			end
		end
	end

	-- Is `object` on screen: it and every frame above it up to the ScreenGui visible, and its
	-- middle not scrolled out of a list.
	local function shown(object: GuiObject): boolean
		local middle = object.AbsolutePosition + object.AbsoluteSize / 2
		local current: Instance? = object
		while current ~= nil and current ~= gui do
			if current:IsA("GuiObject") then
				if not current.Visible then
					return false
				end
				if current ~= object and current:IsA("ScrollingFrame") then
					local at, size = current.AbsolutePosition, current.AbsoluteSize
					if middle.Y < at.Y or middle.Y > at.Y + size.Y then
						return false
					end
				end
			end
			current = current.Parent
		end
		return current == gui and object.AbsoluteSize.X > 0
	end
	local function inPanel(object: GuiObject): boolean
		local current = object.Parent
		while current ~= nil and current ~= gui do
			if string.sub(current.Name, -5) == "Panel" then
				return true
			end
			current = current.Parent
		end
		return false
	end

	-- Moves the on-screen arrows every frame (targets slide, scale and scroll).
	local clock = 0
	local trailParts: { BasePart } = {}
	local trailFrames: { CFrame } = {}
	-- Lays the chevron trail from the player's feet to the target, sliding it forward over time.
	-- Hidden while a panel or the intro covers the world, and once the player is on top of it.
	local function placeTrail(trail: Trail, target: WorldTarget, root: BasePart?, character: Model?)
		local hide = root == nil or anyPanelOpen() or splash ~= nil or revealShowing()
		local fromFeet, toward, distance = Vector3.zero, Vector3.zero, 0
		local ground = target.ground or target.adornee
		if root ~= nil then
			local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
			local legs = if humanoid ~= nil then humanoid.HipHeight else 2
			fromFeet = root.Position - Vector3.new(0, root.Size.Y / 2 + legs, 0)
			local goal = ground.Position + Vector3.new(0, ground.Size.Y / 2, 0)
			local flat = Vector3.new(goal.X - fromFeet.X, 0, goal.Z - fromFeet.Z)
			distance = flat.Magnitude
			hide = hide or distance < TRAIL_START + TRAIL_END + 1
			if not hide then
				toward = flat / distance
				-- The rise from the feet to the goal, per stud along the ground.
				toward = Vector3.new(toward.X, (goal.Y - fromFeet.Y) / distance, toward.Z)
			end
		end
		local parent = if hide then nil else workspace
		if trail.folder.Parent ~= parent then
			trail.folder.Parent = parent
		end
		if hide then
			return
		end
		table.clear(trailParts)
		table.clear(trailFrames)
		local arms = #CHEVRON_ARMS
		local phase = (clock * TRAIL_SPEED) % TRAIL_SPACING
		-- The chevrons' right-hand side, so each one's front (-Z) faces along the path.
		local side = Vector3.new(toward.X, 0, toward.Z).Unit:Cross(Vector3.yAxis)
		local still = reducedMotion()
		for index = 1, #trail.fades do
			local along = TRAIL_START + phase + (index - 1) * TRAIL_SPACING
			local room = distance - TRAIL_END - along
			local fade = if room < 0 then 1 else 1 - math.min(1, (along - TRAIL_START) / TRAIL_FADE, room / TRAIL_FADE)
			-- How far the latest wave front has passed this chevron, so 0 means it is right on it.
			local behind = (clock * WAVE_SPEED - along) % WAVE_GAP
			local pop = if still then 0 else math.max(0, 1 - behind / WAVE_WIDTH)
			local look = math.max(fade, CHEVRON_SEE - WAVE_GLOW * pop)
			local scale = 1 + WAVE_GROW * pop
			local first = (index - 1) * arms
			local resize = math.abs(trail.scales[index] - scale) > 0.01
			if resize then
				trail.scales[index] = scale
			end
			if math.abs(trail.fades[index] - look) > 0.02 or resize then
				trail.fades[index] = look
				for arm = 1, arms do
					local part = trail.parts[first + arm]
					part.Transparency = look
					if resize then
						part.Size = CHEVRON_ARMS[arm].size * Vector3.new(scale, 1, scale)
					end
				end
			end
			if fade < 1 then
				local at = fromFeet + toward * along + Vector3.new(0, CHEVRON_LIFT, 0)
				local frame = CFrame.fromMatrix(at, side, Vector3.yAxis)
				for arm = 1, arms do
					local offset = CHEVRON_ARMS[arm].offset
					table.insert(trailParts, trail.parts[first + arm])
					table.insert(trailFrames, frame * CFrame.new(offset.Position * scale) * offset.Rotation)
				end
			end
		end
		workspace:BulkMoveTo(trailParts, trailFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end

	local function animateGuides(dt: number)
		clock += dt
		local origin = gui.AbsolutePosition
		local area = gui.AbsoluteSize
		local bob = math.sin(clock * 6) * 6
		local spot: GuiObject? = nil -- one UI target at a time
		for _, guide in uiGuides do
			local target, arrow = guide.target, guide.arrow
			if spot ~= nil or target.Parent == nil or not shown(target) or revealShowing() or splash ~= nil then
				arrow.Visible = false
				continue
			end
			spot = target
			arrow.Visible = true
			local at = target.AbsolutePosition - origin
			local size = target.AbsoluteSize
			local centre = at + size / 2
			local half = arrow.AbsoluteSize.X / 2 + 4
			if centre.X < area.X * 0.3 and not inPanel(target) then
				arrow.Rotation = 90 -- pointing left, at a side menu button
				arrow.Position = UDim2.fromOffset(at.X + size.X + half + bob, centre.Y)
			elseif centre.Y > area.Y * 0.45 then
				arrow.Rotation = 0 -- pointing down from above
				arrow.Position = UDim2.fromOffset(centre.X, at.Y - half - bob)
			else
				arrow.Rotation = 180 -- pointing up from below
				arrow.Position = UDim2.fromOffset(centre.X, at.Y + size.Y + half + bob)
			end
		end

		placeDim(spot)
		dialogueMain.Enabled = not revealShowing() -- Lucien waits behind a reveal

		local character = player.Character
		local rootPart = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		local root = if rootPart ~= nil and rootPart:IsA("BasePart") then rootPart else nil
		local camera = workspace.CurrentCamera
		for _, guide in worldGuides do
			local trail = guide.trail
			if trail ~= nil then
				placeTrail(trail, guide.target, root, character)
			end
			local edge = guide.edge
			if edge ~= nil and camera ~= nil then
				local point = guide.target.adornee.Position + Vector3.new(0, guide.target.height * 0.5, 0)
				local screen = camera:WorldToScreenPoint(point)
				local rel = Vector2.new(screen.X, screen.Y) - origin
				local margin = 40
				local visible = screen.Z > 0 and rel.X > margin and rel.Y > margin and rel.X < area.X - margin and rel.Y < area.Y - margin
				edge.Visible = not visible and not anyPanelOpen() and splash == nil and not revealShowing()
				if edge.Visible then
					local centre = area / 2
					local direction = rel - centre
					if screen.Z < 0 then
						direction = -direction
					end
					if direction.Magnitude < 1 then
						direction = Vector2.new(0, 1)
					end
					local inset = edge.AbsoluteSize.X / 2 + 16
					local scale = math.min((centre.X - inset) / math.max(math.abs(direction.X), 0.001), (centre.Y - inset) / math.max(math.abs(direction.Y), 0.001))
					local at = centre + direction * scale
					edge.Position = UDim2.fromOffset(at.X, at.Y)
					edge.Rotation = math.deg(math.atan2(direction.Y, direction.X)) - 90
				end
			end
		end
	end

	-- Steps ---------------------------------------------------------------------------------------
	local function sideButton(name: string): GuiObject?
		return findGui(gui:FindFirstChild("SideMenu"), name)
	end
	-- The way into the Studio screen: the menu button and the MOVIES stand.
	-- `key` says something else instead of the "Tap Studio" line (a later step with Studio closed).
	local function toStudio(key: string?): View
		local ui = {}
		local studioButton = sideButton("StudioButton")
		if studioButton ~= nil then
			table.insert(ui, studioButton)
		end
		local world = {}
		local stand = standTarget("Studio", "MAKE A MOVIE", "hint")
		if stand ~= nil then
			table.insert(world, stand)
		end
		local line = if nearMovies ~= nil then "studioNear" else key or "studio"
		return { linesKey = line, lines = { line }, ui = ui, world = world }
	end
	local function studioTab(): string?
		local found = panel("StudioPanel")
		local tab = if found ~= nil then found:GetAttribute("Tab") else nil
		return if typeof(tab) == "string" then tab else nil
	end
	local function only(object: GuiObject?): { GuiObject }
		return if object ~= nil then { object } else {}
	end
	-- What to say at the Movies stand's prompt, for the player's input.
	promptHint = function(): string?
		local prompt = nearMovies
		if prompt == nil then
			return nil
		end
		if UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
			return `Press {prompt.GamepadKeyCode.Name} to make a movie.`
		elseif UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
			return "Tap Make a Movie on the stand."
		end
		return `Press {prompt.KeyboardKeyCode.Name} to make a movie.`
	end

	local function one(key: string, ui: { GuiObject }, world: { WorldTarget }?): View
		return { linesKey = key, lines = { key }, ui = ui, world = world or {} }
	end

	-- Cast comes first: CastingService needs no lot, so the first star lands before a lot is claimed.
	local steps: { Step } = {
		{
			done = function()
				return count(ClientState.roster) > 0
			end,
			view = function()
				local odds = standTarget("Odds", "", "hint")
				return one("cast", only(findGui(gui:FindFirstChild("CastingBar"), "CastButton")), if odds ~= nil then { odds } else {})
			end,
		},
		{
			done = function()
				return player:GetAttribute("LotIndex") ~= nil
			end,
			view = function()
				local pad = padTarget("claim")
				return one("claim", {}, if pad ~= nil then { pad } else {})
			end,
		},
		{
			done = function()
				return studioOpened or hasScripts()
			end,
			view = function()
				return toStudio()
			end,
		},
		{
			done = hasScripts,
			view = function()
				if not isOpen("StudioPanel") then
					return toStudio()
				end
				local studioPanel = panel("StudioPanel")
				if studioTab() ~= "Scripts" then
					return one("scriptOpen", only(findGui(studioPanel, "ScriptsTab")))
				end
				return one("scriptBuy", only(findGui(studioPanel, "Script_Short")))
			end,
		},
		{
			done = hasFilm,
			view = function()
				local picker = panel("PickerPanel")
				if picker ~= nil and picker.Visible then
					local list = picker:FindFirstChild("List")
					if picker:GetAttribute("Script") == nil then
						-- A Short Film script if there is one, else any script.
						local any: GuiObject? = nil
						local children: { Instance } = if list ~= nil then list:GetChildren() else {}
						for _, child in children do
							if child:IsA("GuiObject") and string.sub(child.Name, 1, 11) == "PickScript_" then
								any = any or child
								if string.find(child.Name, ":Short", 1, true) then
									any = child
									break
								end
							end
						end
						return one("filmScript", only(any))
					elseif (picker:GetAttribute("Cast") or 0) == 0 then
						-- The first actor card shown (the best one sorts first).
						local grid = if list ~= nil then list:FindFirstChild("Actors") else nil
						local first: GuiObject? = nil
						local cards: { Instance } = if grid ~= nil then grid:GetChildren() else {}
						for _, card in cards do
							if card:IsA("GuiObject") and card.Visible and (first == nil or card.LayoutOrder < first.LayoutOrder) then
								first = card
							end
						end
						return one("filmActor", only(first))
					end
					return one("filmGo", only(findGui(picker, "StartFilming")))
				end
				if not isOpen("StudioPanel") then
					return toStudio("filmStages")
				end
				local studioPanel = panel("StudioPanel")
				if studioTab() ~= "Stages" then
					return one("filmStages", only(findGui(studioPanel, "StagesTab")))
				end
				return one("filmStart", only(findGui(studioPanel, "StartMovie")))
			end,
		},
		{
			done = hasPremiered,
			view = function()
				local s = studio()
				local film = if s ~= nil then s.films[1] else nil
				local ready = film ~= nil and film.endTime - ClientState.serverNow() <= 0
				local key = if ready then "ready" else "shoot"
				if not isOpen("StudioPanel") then
					return toStudio(key)
				end
				local studioPanel = panel("StudioPanel")
				local target
				if studioTab() ~= "Stages" then
					target = findGui(studioPanel, "StagesTab")
				else
					local row = if film ~= nil then findGui(studioPanel, `Stage{film.stage}`) else nil
					target = findGui(row or studioPanel, "StageAction")
				end
				return one(key, only(target))
			end,
		},
		{
			done = function()
				return collected
			end,
			view = function()
				-- The premiere's own line first, once its reveal is over.
				local lines = { "collect" }
				if resultId ~= nil and TutorialLines.LINES[TutorialLines.resultKey(resultId)] ~= nil then
					table.insert(lines, 1, TutorialLines.resultKey(resultId))
				end
				local pad = padTarget("collect")
				return { linesKey = "collect:" .. (resultId or ""), lines = lines, ui = {}, world = if pad ~= nil then { pad } else {} }
			end,
		},
	}

	-- Intro screen ---------------------------------------------------------------------------------
	-- The one big moment: red curtains open on Lucien in a spotlight, with his name on a plate.
	-- His lines play in the dialogue at the top as usual.
	local introScreens: { ScreenGui } = {}
	local function closeSplash()
		local open = splash
		if open == nil then
			return
		end
		splash = nil
		introTyped = false
		stepStartedAt = os.clock()
		begin.Visible = false
		container.Parent = dialogueMain -- back from the intro's safe-area screen before it is destroyed
		open:Destroy()
		for _, screen in introScreens do
			screen:Destroy()
		end
		table.clear(introScreens)
		layout()
	end

	local teardown: () -> ()

	-- The joy screen's right half: a spinning gold sunburst behind a cream ticket stub, "Your first
	-- box office" with the amount counting up, Lucien's wrap line and one Keep rolling button.
	-- Lucien and the dark backdrop come from openSplash.
	local function buildJoy(overlay: Frame, safeGui: ScreenGui, marker: Frame, amount: number, still: boolean)
		local small = compact()
		local burst = Instance.new("Frame")
		burst.Name = "Sunburst"
		burst.BackgroundTransparency = 1
		burst.AnchorPoint = Vector2.new(0.5, 0.5)
		burst.ZIndex = 7
		burst.Parent = overlay
		for index = 0, 5 do
			local ray = Instance.new("Frame")
			ray.Name = "Ray"
			ray.AnchorPoint = Vector2.new(0.5, 0.5)
			ray.Position = UDim2.fromScale(0.5, 0.5)
			ray.Size = UDim2.fromScale(0.1, 1)
			ray.Rotation = index * 30
			ray.BackgroundColor3 = UiKit.GOLD
			ray.BackgroundTransparency = 0.82
			ray.BorderSizePixel = 0
			ray.ZIndex = 7
			ray.Parent = burst
		end
		if not still then
			local spin = TweenService:Create(burst, TweenInfo.new(30, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), { Rotation = 360 })
			spin:Play()
			marker.Destroying:Connect(function()
				spin:Cancel()
			end)
		end

		local stub = Instance.new("Frame")
		stub.Name = "TicketStub"
		stub.AnchorPoint = Vector2.new(0.5, 0.5)
		stub.Position = UDim2.fromScale(0.74, 0.5)
		stub.Size = UDim2.fromScale(0.44, 0.84)
		stub.BackgroundColor3 = UiKit.CREAM
		stub.ZIndex = 9
		stub.Parent = overlay
		UiKit.corner(stub, 16)
		UiKit.border(stub, 4, UiKit.INK)
		local limit = Instance.new("UISizeConstraint")
		limit.MaxSize = Vector2.new(420, 330)
		limit.Parent = stub
		-- Ticket notches in the backdrop colour on both sides.
		for _, side in { 0, 1 } do
			local notch = Instance.new("Frame")
			notch.Name = "Notch"
			notch.AnchorPoint = Vector2.new(0.5, 0.5)
			notch.Position = UDim2.fromScale(side, 0.5)
			notch.Size = UDim2.fromOffset(22, 22)
			notch.BackgroundColor3 = UiKit.DARK
			notch.ZIndex = 10
			notch.Parent = stub
			UiKit.corner(notch, 11)
		end
		local body = Instance.new("Frame")
		body.Name = "Body"
		body.BackgroundTransparency = 1
		body.Size = UDim2.fromScale(1, 1)
		body.ZIndex = 10
		body.Parent = stub
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 16), UDim.new(0, 16)
		pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 10), UDim.new(0, 12)
		pad.Parent = body
		local list = Instance.new("UIListLayout")
		list.Padding = UDim.new(0, if small then 4 else 8)
		list.HorizontalAlignment = Enum.HorizontalAlignment.Center
		list.VerticalAlignment = Enum.VerticalAlignment.Center
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Parent = body

		local heading = UiKit.makeLabel(body, "Your first box office", UiKit.BURGUNDY, UDim2.new(1, 0, 0, if small then 22 else 28))
		heading.LayoutOrder = 1
		heading.ZIndex = 11
		local money = UiKit.makeTitle(body, "$0", UiKit.GOLD, UDim2.new(1, 0, 0, if small then 56 else 74), nil, 3)
		money.LayoutOrder = 2
		money.ZIndex = 11
		UiKit.textConstraint(money, 72)
		local wrap = UiKit.makeLabel(body, TutorialLines.LINES.joy, UiKit.INK, UDim2.new(1, 0, 0, if small then 40 else 52))
		wrap.LayoutOrder = 3
		wrap.TextWrapped = true
		wrap.ZIndex = 11
		UiKit.textConstraint(wrap, if small then 18 else 22)
		local keep = UiKit.makeButton(body, "Keep rolling", UiKit.GOLD, UDim2.new(1, 0, 0, if small then 44 else 52))
		keep.Name = "KeepRolling"
		keep.LayoutOrder = 4
		keep.ZIndex = 12
		keep.TextColor3 = UiKit.INK
		UiKit.textConstraint(keep, 26)
		keep.Activated:Connect(function()
			teardown()
		end)

		if still then
			money.Text = "$" .. Hud.comma(amount)
		else
			task.spawn(function()
				local started = os.clock()
				while marker.Parent ~= nil do
					local alpha = (os.clock() - started) / 1.4
					money.Text = "$" .. Hud.comma(CountUp.at(0, amount, alpha))
					if alpha >= 1 then
						break
					end
					task.wait()
				end
			end)
		end

		local function place()
			local area = safeGui.AbsoluteSize
			burst.Position = stub.Position
			burst.Size = UDim2.fromOffset(math.floor(area.Y * 1.3), math.floor(area.Y * 1.3))
		end
		place()
		local resizing = safeGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
		marker.Destroying:Connect(function()
			resizing:Disconnect()
		end)
	end

	local function openSplash(joyAmount: number?)
		local still = reducedMotion()
		-- Own screens above the HUD (order 0) and the panels, below the confetti (Fx, 20): an opaque
		-- full-bleed backdrop and curtains with no insets (hides the HUD and the strip under the
		-- Roblox buttons), and a safe-area screen for the stage and the dialogue.
		local function screen(name: string, order: number, insets: Enum.ScreenInsets): ScreenGui
			local made = Instance.new("ScreenGui")
			made.Name = name
			made.ResetOnSpawn = false
			made.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
			made.ScreenInsets = insets
			made.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None
			made.DisplayOrder = order
			made.Parent = playerGui
			table.insert(introScreens, made)
			return made
		end
		local backdropGui = screen("TutorialIntroBackdrop", 15, Enum.ScreenInsets.None)
		local safeGui = screen("TutorialIntroSafe", 16, Enum.ScreenInsets.CoreUISafeInsets)
		-- Curtains sit between the stage (16) and the dialogue (18), so they cover Lucien until they
		-- open, yet Skip stays tappable above them.
		local curtainGui = screen("TutorialIntroCurtains", 17, Enum.ScreenInsets.None)
		local dialogueGui = screen("TutorialIntroDialogue", 18, Enum.ScreenInsets.CoreUISafeInsets)
		local backdrop = Instance.new("Frame")
		backdrop.Name = "Backdrop"
		backdrop.Size = UDim2.fromScale(1, 1)
		backdrop.BackgroundColor3 = UiKit.DARK
		backdrop.BorderSizePixel = 0
		backdrop.Active = true
		backdrop.ZIndex = 1
		backdrop.Parent = backdropGui
		-- Zero-size marker in the HUD: a "Panel" that special events wait for.
		local marker = Instance.new("Frame")
		marker.Name = "DirectorPanel"
		marker.Size = UDim2.new()
		marker.BackgroundTransparency = 1
		marker.Parent = gui
		splash = marker
		local overlay = Instance.new("Frame")
		overlay.Name = "Intro"
		overlay.Size = UDim2.fromScale(1, 1)
		overlay.BackgroundTransparency = 1
		overlay.ZIndex = 7
		overlay.Parent = safeGui
		container.Parent = dialogueGui

		-- Lucien, big and whole, bottom-left and cropped at the waist by the screen edge, in a warm
		-- pool of light. The bubble with his lines (and "Let's roll!") sits to his right.
		local figure = Instance.new("Frame")
		figure.Name = "Lucien"
		figure.BackgroundTransparency = 1
		figure.ZIndex = 8
		figure.Parent = overlay
		local square = Instance.new("UIAspectRatioConstraint")
		square.Parent = figure
		local view = Icon3D.director(figure, false, true)
		Icon3D.glow(view, UiKit.GOLD, 0.8)
		local stopSway = Icon3D.wobble(view)
		marker.Destroying:Connect(stopSway)
		local rise = Instance.new("UIScale")
		rise.Scale = if still then 1 else 0.7
		rise.Parent = figure

		begin.Activated:Connect(closeSplash)

		local function place()
			-- Size from the safe-area screen the stage lives in: gui.AbsoluteSize is stale at open time.
			local area = safeGui.AbsoluteSize
			local side = math.floor(1.6 * 0.86 * area.Y)
			figure.AnchorPoint = Vector2.new(0, 0)
			figure.Size = UDim2.fromOffset(side, side)
			figure.Position = UDim2.fromOffset(math.floor(area.X * 0.08), math.floor(area.Y * 0.02))
			layout()
		end
		place()
		local resizing = safeGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
		marker.Destroying:Connect(function()
			resizing:Disconnect()
		end)

		if joyAmount ~= nil then
			rise.Scale = 1
			buildJoy(overlay, safeGui, marker, joyAmount, still)
			return
		end

		-- Curtains, opening from the middle.
		local curtains: { Frame } = {}
		for _, side in { 0, 1 } do
			local curtain = Instance.new("Frame")
			curtain.Name = "Curtain"
			curtain.AnchorPoint = Vector2.new(side, 0)
			curtain.Position = UDim2.fromScale(side, 0)
			curtain.Size = UDim2.fromScale(if still then 0.16 else 0.5, 1)
			curtain.BackgroundColor3 = CURTAIN
			curtain.BorderSizePixel = 0
			curtain.ZIndex = 9
			curtain.Parent = curtainGui
			-- Velvet folds: light and dark bands across the curtain.
			local folds = Instance.new("UIGradient")
			local keys = {}
			for i = 0, 8 do
				local shade = if i % 2 == 0 then Color3.new(1, 1, 1) else Color3.fromRGB(150, 150, 150)
				table.insert(keys, ColorSequenceKeypoint.new(i / 8, shade))
			end
			folds.Color = ColorSequence.new(keys)
			folds.Parent = curtain
			local trim = Instance.new("Frame")
			trim.Name = "GoldTrim"
			trim.AnchorPoint = Vector2.new(1 - side, 0)
			trim.Position = UDim2.fromScale(1 - side, 0)
			trim.Size = UDim2.new(0, 6, 1, 0)
			trim.BackgroundColor3 = UiKit.GOLD
			trim.BorderSizePixel = 0
			trim.ZIndex = 9
			trim.Parent = curtain
			table.insert(curtains, curtain)
		end
		if not still then
			local open = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			for _, curtain in curtains do
				TweenService:Create(curtain, open, { Size = UDim2.fromScale(0.16, 1) }):Play()
			end
			TweenService:Create(rise, TweenInfo.new(0.9, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0.3), { Scale = 1 }):Play()
			task.delay(0.5, function()
				if splash == marker then
					Fx.confetti(30, { UiKit.GOLD, UiKit.CREAM, GUIDE })
				end
			end)
		end
	end

	-- Driver ----------------------------------------------------------------------------------------
	local currentStep = 0
	local collectedAmount = 0 -- royalties the first collect paid out
	local renderConnection: RBXScriptConnection? = nil

	function teardown()
		active = false
		clearGuides()
		dimGui.Enabled = false
		Sfx.cutVoice()
		closeSplash()
		if renderConnection ~= nil then
			renderConnection:Disconnect()
			renderConnection = nil
		end
		container.Visible = false
		gui:SetAttribute("PanelTop", nil)
		gui:SetAttribute("TutorialBottom", nil)
	end

	-- The end: one moment of joy instead of a tip tour. Lucien's wrap line is voiced; the stub's
	-- button is the only way on. TutorialDone fires once, here.
	local function openJoy(amount: number)
		finale = true
		closeSplash()
		clearGuides()
		container.Visible = false -- the screen carries its own line; no corner bubble
		queue = {}
		lineIndex = 0
		typing = false
		tutorialDone:FireServer()
		openSplash(amount)
		Sfx.play("welcome")
		Sfx.play(TutorialLines.VOICE.joy)
		Fx.confetti(40, { UiKit.GOLD, UiKit.CREAM, GUIDE }, true)
	end

	local function finish(skipped: boolean)
		if finished then
			return
		end
		finished = true
		if skipped then
			tutorialDone:FireServer()
			teardown()
			return
		end
		openJoy(collectedAmount)
	end

	local function update()
		if not active or finished then
			return
		end
		local index: number? = nil
		for i, step in steps do
			if not step.done() then
				index = i
				break
			end
		end
		if index == nil then
			finish(false)
			return
		end
		if splash ~= nil and index > 1 then
			closeSplash()
		end
		if index ~= currentStep then
			if currentStep ~= 0 then
				Sfx.play("notify")
			end
			currentStep = index
			stepStartedAt = os.clock()
			hinted = false
		end
		local view = steps[index].view()
		-- Stuck for a while: pulse the target once (rule: one timed hint, after the idle wait).
		if not hinted and os.clock() - stepStartedAt > IDLE_HINT_SECONDS then
			local guide = uiGuides[1]
			if guide ~= nil and guide.arrow.Visible then
				hinted = true
				idlePulse(guide.target)
				Sfx.play("notify")
			end
		end
		if splash ~= nil then
			view = { linesKey = "intro", lines = { "intro1", "intro2" }, ui = {}, world = {} }
		end
		if view.linesKey ~= linesKey then
			linesKey = view.linesKey
			stepStartedAt = os.clock()
			hinted = false
			playLines(view.lines)
		end
		syncGuides(view.ui, view.world)
	end

	-- Every frame: the typewriter, the line timer, the moving arrows, the finale's end.
	local function onRender(dt: number)
		if not revealShowing() then
			if typing then
				typed += dt * CHARS_PER_SECOND
				local total = utf8.len(speech.Text) or #speech.Text
				if typed >= total then
					typing = false
					speech.MaxVisibleGraphemes = -1
					lineDoneAt = os.clock()
					if splash ~= nil and lineIndex >= #queue then
						introTyped = true
						layout()
					end
				else
					speech.MaxVisibleGraphemes = math.floor(typed)
				end
			elseif lineIndex < #queue and os.clock() - lineDoneAt > holdTime(speech.Text) then
				showLine(lineIndex + 1)
			end
		end
		animateGuides(dt)
	end

	local function activate()
		active = true
		container.Visible = true
		renderConnection = RunService.RenderStepped:Connect(onRender)
		-- A brand-new producer meets Lucien first; someone back mid-tutorial goes straight on.
		local s = studio()
		local fresh = player:GetAttribute("LotIndex") == nil and count(ClientState.roster) == 0 and s ~= nil and count(s.scripts) == 0 and #s.films == 0 and #s.cinema == 0
		if fresh then
			openSplash()
		end
		layout()
		update()
	end

	skip.Activated:Connect(function()
		if finale then
			teardown()
		else
			finish(true)
		end
	end)

	-- Signals ----------------------------------------------------------------------------------------
	-- A collect is the only thing that lowers pending royalties.
	local lastPending = player:GetAttribute("Pending") or 0
	player.AttributeChanged:Connect(function(name)
		if name == "Pending" then
			local pending = player:GetAttribute("Pending") or 0
			if pending < lastPending - 0.5 then
				collected = true
				collectedAmount = lastPending - pending
			end
			lastPending = pending
		end
		update()
	end)
	ClientState.changed:Connect(function()
		local s = studio()
		if s == nil then
			return
		end
		if not active and not finished then
			if s.tutorialDone then
				finished = true
				return
			end
			activate()
			return
		end
		update()
	end)
	if premiereResult ~= nil then
		premiereResult.OnClientEvent:Connect(function(result)
			if active and not finished and type(result) == "table" and type(result.result) == "string" and resultId == nil then
				resultId = result.result
				update()
			end
		end)
	end
	local studioPanel = panel("StudioPanel")
	if studioPanel ~= nil then
		studioPanel:GetPropertyChangedSignal("Visible"):Connect(function()
			if studioPanel.Visible and active then
				studioOpened = true
			end
		end)
	end
	ProximityPromptService.PromptShown:Connect(function(prompt)
		if prompt:GetAttribute("Screen") == "Studio" then
			nearMovies = prompt
			update()
		end
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt)
		if prompt == nearMovies then
			nearMovies = nil
			update()
		end
	end)

	-- Layout follows the screen, the HUD and panels opening and closing.
	UiKit.onViewportChanged(layout)
	for _, attribute in { "HudTop", "HudRight", "MenuRight" } do
		gui:GetAttributeChangedSignal(attribute):Connect(layout)
	end
	local lastPanelOpen = false
	task.spawn(function()
		while not finished or active do
			if active then
				local open = anyPanelOpen()
				if open ~= lastPanelOpen then
					lastPanelOpen = open
					layout()
				end
				-- Steps that move on without a sync (a film becoming ready, the Studio tab changing)
				-- and the guides following the screens.
				update()
				-- The "while you were away" note comes and goes under the wallet.
				layout()
			end
			task.wait(0.25)
		end
	end)
end

return Tutorial
