--!strict
-- First-time tutorial, hosted by Director Lucien Vale (an original character, see
-- ActorModels.buildDirector): claim a lot, cast, find the Movies stand, buy a script, film,
-- premiere, collect.
--
-- New players meet Lucien on an intro screen (curtains open on him in a spotlight). After that his
-- dialogue stays at the top of the screen, panels included (panels start below it, see
-- UiKit.makePanel's "PanelTop"), with a separate yellow instruction under it for what to do now.
-- Yellow arrows point at the real control (a menu button, a tab, a row) and, where there is one,
-- at the stand in the plaza, with a glow on the target, a big glossy arrow over it, and a trail of
-- yellow chevrons on the ground flowing from the player to it. There is no Casting Call stand:
-- CAST rolls, and the Casting Odds stand only shows the chances, so step 2 points at CAST and just
-- outlines that stand.
--
-- Each step completes from real game state (not from button presses), so a player who already did
-- something skips it, and nothing here can grant anything. Finishing or skipping tells the server
-- once (TutorialDone), and it never shows again. The first Short Film is shortened server-side.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local ClientState = require(script.Parent.ClientState)
local Fx = require(script.Parent.Fx)
local Icon3D = require(script.Parent.Icon3D)
local Sfx = require(script.Parent.Sfx)
local UiKit = require(script.Parent.UiKit)

-- The guide color: brighter and yellower than the UI's gold, so directions read as directions.
local GUIDE = Color3.fromRGB(255, 222, 26)
local HINT_BLUE = Color3.fromRGB(110, 190, 255)
local CURTAIN = Color3.fromRGB(122, 18, 36)

-- The chevron trail on the ground (studs). Each chevron is two arms meeting at a tip that points
-- at the target, tipped up off the ground so it reads from behind the player, with a slightly
-- bigger dark copy behind for the outline. They flow along the path at TRAIL_SPEED, TRAIL_SPACING apart.
local TRAIL_SPACING = 4.5
local TRAIL_SPEED = 6
local TRAIL_START = 3.5 -- the first chevron's distance ahead of the player
local TRAIL_END = 2.5 -- the last one stops this far short of the target
local TRAIL_FADE = 2 -- chevrons fade in and out over this distance at each end
local CHEVRON_ARM = 3.2
local CHEVRON_ANGLE = math.rad(40) -- each arm's angle off the path
local CHEVRON_LEAN = math.rad(50) -- tip raised off the ground, toward the target
local LEAN = CFrame.Angles(CHEVRON_LEAN, 0, 0)
local CHEVRON_LIFT = math.cos(CHEVRON_ANGLE) * CHEVRON_ARM / 2 * math.sin(CHEVRON_LEAN) + 0.2
type ChevronArm = { offset: CFrame, size: Vector3, ink: boolean }
local CHEVRON_ARMS: { ChevronArm } = {}
do
	-- In the chevron's own frame -Z points at the target. Each arm's centre sits beside the path,
	-- turned so the two meet at the tip, and nudged toward the tip so they close it off.
	local thick, depth, rim = 0.8, 0.25, 0.42
	for _, ink in { true, false } do
		for _, side in { 1, -1 } do
			local turn = side * CHEVRON_ANGLE
			local along = CFrame.Angles(0, turn, 0)
			local centre = Vector3.new(side * math.sin(CHEVRON_ANGLE) * CHEVRON_ARM / 2, if ink then -0.1 else 0.02, 0)
			local grow = if ink then rim else 0
			table.insert(CHEVRON_ARMS, {
				offset = CFrame.new(centre) * along * CFrame.new(0, 0, -thick * 0.3),
				size = Vector3.new(thick + grow, depth, CHEVRON_ARM + thick * 0.6 + grow),
				ink = ink,
			})
		end
	end
end

-- Dialogue layout (pixels). Regular: the card, then the instruction under it. Compact (phones in
-- landscape): one row, the card on the left and the instruction on the right.
local MAX_WIDTH = 640
local CARD_HEIGHT = 92
local PILL_HEIGHT = 38
local TIP_HEIGHT = 22
local GAP = 6
local TOP_PAD = 14 -- room above the card for the Skip tab
local ROW_HEIGHT = 56
local COMPACT_TIP = 18

local CHARS_PER_SECOND = 48
local FINALE_SECONDS = 8 -- the last line stays this long before the tutorial clears away

-- Lucien's lines (Bosti's script, 2026-10-08).
local LINES = {
	arrival = {
		"Welcome to the lot, producer. I'm Director Lucien Vale. I've spent a lifetime turning brave ideas into films audiences remember.",
		"Now this studio is yours. Let's make your first picture.",
	},
	cast = { "Good. Every great production needs a home. Now we need a cast." },
	movies = { "A promising first signing! Check your actor's specialty when you choose a script. The right fit earns more." },
	script = { "Every good cast needs a story. Let's start with a Short Film." },
	film = {
		"Now bring the story to life. Open Stages and tap Start Movie.",
		"Choose your Short Film and the actor you just signed. One actor is enough to begin.",
	},
	filming = { "Cameras are rolling! Your first short finishes quickly." },
	ready = { "The audience is waiting. Let's see what they think." },
	collect = "Your cinema is earning now. Let's collect your box office.",
	finale = {
		"Excellent work, producer. Finished films keep earning royalties while you're away.",
		"Make another movie, discover more actors, and grow this lot into a studio everyone remembers.",
	},
}

-- What Lucien says after the first premiere's reveal, by result.
local RESULT_LINES: { [string]: string } = {
	Flop = "A difficult opening. Every great director has one. We'll learn from it and make the next film.",
	Hit = "A solid premiere! The audience came out to see your work.",
	Blockbuster = "Look at that crowd! Your first picture has made a splash.",
	Cult = "They found something special in it. Some films only grow more beloved with time.",
	Masterpiece = "A masterpiece on your first premiere! The whole lot will remember this one.",
}

local INSTRUCTIONS = {
	claim = "Step onto a glowing green CLAIM pad to choose your lot.",
	cast = "Press CAST to hold your first Casting Call.",
	movies = "Find the MOVIES stand in the plaza, or open Studio from the menu.",
	script = "In Studio, open Scripts and buy a Short Film script.",
	film = "Choose your script and actor, then start filming.",
	filming = "Tap CLAP to speed up filming. When the stage says Ready, press PREMIERE.",
	ready = "Your film is Ready. Press PREMIERE!",
	collect = "Follow the yellow guide to the gold collection pad on your lot and step on it.",
	finale = "Your next step is yours. Visit Movies, Upgrades, Casting Odds, or the Talent Index around town.",
}

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
	lines: { string },
	instruction: string,
	tip: string?,
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

-- Splits a line into sentences of a readable length, for small screens.
local function sentences(text: string): { string }
	local out: { string } = {}
	local current = ""
	for sentence in string.gmatch(text, "[^%.!%?]+[%.!%?]*%s*") do
		local trimmed = string.gsub(sentence, "%s+$", "")
		if current == "" then
			current = trimmed
		elseif #current < 40 then
			current ..= " " .. trimmed
		else
			table.insert(out, current)
			current = trimmed
		end
	end
	if current ~= "" then
		table.insert(out, current)
	end
	return if #out > 0 then out else { text }
end

local function reducedMotion(): boolean
	local ok, value = pcall(function()
		return (GuiService :: any).ReducedMotionEnabled
	end)
	return ok and value == true
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
		for _, name in { "Reveal", "PremiereReveal" } do
			local overlay = gui:FindFirstChild(name)
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
			label = if kind == "claim" then "CLAIM HERE" else "COLLECT HERE",
			height = 4,
			kind = "primary",
		}
	end

	-- Dialogue -----------------------------------------------------------------------------------
	local container = Instance.new("Frame")
	container.Name = "Tutorial"
	container.AnchorPoint = Vector2.new(0.5, 0)
	container.BackgroundTransparency = 1
	container.Visible = false
	container.ZIndex = 8 -- above panels and the intro screen, below the reveal overlays
	container.Parent = gui

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.BackgroundColor3 = UiKit.NAVY
	card.BackgroundTransparency = 0.04
	card.ZIndex = 8
	card.Parent = container
	UiKit.corner(card, 14)
	UiKit.border(card, 3, UiKit.GOLD)

	-- Lucien's portrait: head and shoulders in a burgundy medallion ringed in gold.
	local portrait = Instance.new("Frame")
	portrait.Name = "Portrait"
	portrait.BackgroundColor3 = CURTAIN
	portrait.ZIndex = 9
	portrait.Parent = card
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = portrait
	UiKit.border(portrait, 3, UiKit.GOLD)
	Icon3D.director(portrait, true)

	local nameLabel = UiKit.makeTitle(card, "Director Lucien Vale", UiKit.GOLD, UDim2.new(), nil, 2)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.ZIndex = 9
	local speech = UiKit.makeLabel(card, "", UiKit.WHITE, UDim2.new())
	speech.Name = "Speech"
	speech.TextXAlignment = Enum.TextXAlignment.Left
	speech.TextYAlignment = Enum.TextYAlignment.Top
	speech.TextWrapped = true
	speech.ZIndex = 9
	UiKit.textConstraint(speech, 20)

	-- Tapping the card shows the whole line at once, or the next line.
	local tapper = Instance.new("TextButton")
	tapper.Name = "Next"
	tapper.Text = ""
	tapper.BackgroundTransparency = 1
	tapper.Size = UDim2.fromScale(1, 1)
	tapper.ZIndex = 10
	tapper.Parent = card

	local skip = UiKit.makeButton(card, "Skip", UiKit.TAB_OFF, UDim2.fromOffset(72, 32))
	skip.Name = "Skip"
	skip.AnchorPoint = Vector2.new(1, 0)
	skip.ZIndex = 11
	UiKit.textConstraint(skip, 18)

	-- The yellow instruction: what to do right now, with how far along the tutorial is.
	local pill = Instance.new("Frame")
	pill.Name = "Instruction"
	pill.BackgroundColor3 = GUIDE
	pill.ZIndex = 8
	pill.Parent = container
	UiKit.corner(pill, 12)
	UiKit.border(pill, 3, UiKit.INK)
	local stepChip = UiKit.makeTitle(pill, "", UiKit.WHITE, UDim2.new(), nil, 1.5)
	stepChip.Name = "Step"
	stepChip.BackgroundColor3 = UiKit.INK
	stepChip.BackgroundTransparency = 0
	stepChip.ZIndex = 9
	UiKit.corner(stepChip, 10)
	UiKit.textConstraint(stepChip, 18)
	local pillText = UiKit.makeLabel(pill, "", UiKit.INK, UDim2.new())
	pillText.Font = UiKit.DISPLAY_FONT
	pillText.TextWrapped = true
	pillText.TextXAlignment = Enum.TextXAlignment.Left
	pillText.ZIndex = 9
	UiKit.textConstraint(pillText, 22)

	local tipLabel = UiKit.makeTitle(container, "", UiKit.WHITE, UDim2.new(), nil, 2)
	tipLabel.Name = "Tip"
	tipLabel.ZIndex = 8
	UiKit.textConstraint(tipLabel, 18)

	-- State --------------------------------------------------------------------------------------
	local active = false
	local finished = false
	local finale = false
	local splash: Frame? = nil
	local tipText: string? = nil
	local studioOpened = false
	local collected = false
	local resultId: string? = nil
	local nearMovies: ProximityPrompt? = nil

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
		local area = gui.AbsoluteSize
		if area.X < 1 then
			area = UiKit.viewport()
		end
		local small = compact()
		local touch = gui:GetAttribute("HudRight") == true
		local hudTop = gui:GetAttribute("HudTop")
		local top = if typeof(hudTop) == "number" then hudTop else 8
		local menuRight = gui:GetAttribute("MenuRight")
		-- Width: centred on the screen when that clears the side menu, else in the room beside it.
		local left = 8
		if typeof(menuRight) == "number" and area.X - menuRight - 16 >= 420 then
			left = menuRight + 8
		end
		local width = math.min(MAX_WIDTH, area.X - left - 8)
		local centre = if area.X / 2 - width / 2 >= left then area.X / 2 else left + width / 2
		local splashOpen = splash ~= nil
		local showPill = not splashOpen and pillText.Text ~= ""
		local panelOpen = anyPanelOpen()
		local showTip = tipText ~= nil and showPill and not (small and panelOpen)

		-- Pieces inside the container.
		local height
		if small then
			local cardWidth = if showPill then math.floor(width * 0.56) else width
			card.Position = UDim2.fromOffset(0, TOP_PAD)
			card.Size = UDim2.fromOffset(cardWidth, ROW_HEIGHT)
			local face = ROW_HEIGHT - 8
			portrait.Position = UDim2.fromOffset(4, 4)
			portrait.Size = UDim2.fromOffset(face, face)
			nameLabel.Position = UDim2.fromOffset(face + 12, 3)
			nameLabel.Size = UDim2.new(1, -(face + 20), 0, 16)
			speech.Position = UDim2.fromOffset(face + 12, 20)
			speech.Size = UDim2.new(1, -(face + 18), 0, ROW_HEIGHT - 24)
			UiKit.textConstraint(speech, 16)
			pill.Position = UDim2.fromOffset(cardWidth + GAP, TOP_PAD)
			pill.Size = UDim2.fromOffset(width - cardWidth - GAP, ROW_HEIGHT)
			stepChip.Size = UDim2.fromOffset(38, 22)
			stepChip.Position = UDim2.fromOffset(6, (ROW_HEIGHT - 22) // 2)
			local textX = if stepChip.Visible then 50 else 8
			pillText.Position = UDim2.fromOffset(textX, 3)
			pillText.Size = UDim2.new(1, -(textX + 6), 1, -6)
			UiKit.textConstraint(pillText, 16)
			height = TOP_PAD + ROW_HEIGHT
			tipLabel.Position = UDim2.fromOffset(0, height + 3)
			tipLabel.Size = UDim2.new(1, 0, 0, COMPACT_TIP)
			if showTip then
				height += 3 + COMPACT_TIP
			end
		else
			card.Position = UDim2.fromOffset(0, TOP_PAD)
			card.Size = UDim2.fromOffset(width, CARD_HEIGHT)
			local face = CARD_HEIGHT - 12
			portrait.Position = UDim2.fromOffset(6, 6)
			portrait.Size = UDim2.fromOffset(face, face)
			nameLabel.Position = UDim2.fromOffset(face + 18, 8)
			nameLabel.Size = UDim2.new(1, -(face + 90), 0, 22)
			speech.Position = UDim2.fromOffset(face + 18, 34)
			speech.Size = UDim2.new(1, -(face + 30), 0, CARD_HEIGHT - 40)
			UiKit.textConstraint(speech, 20)
			pill.Position = UDim2.fromOffset(0, TOP_PAD + CARD_HEIGHT + GAP)
			pill.Size = UDim2.fromOffset(width, PILL_HEIGHT)
			stepChip.Size = UDim2.fromOffset(46, PILL_HEIGHT - 12)
			stepChip.Position = UDim2.fromOffset(6, 6)
			local textX = if stepChip.Visible then 60 else 12
			pillText.Position = UDim2.fromOffset(textX, 4)
			pillText.Size = UDim2.new(1, -(textX + 8), 1, -8)
			UiKit.textConstraint(pillText, 22)
			height = TOP_PAD + CARD_HEIGHT
			if showPill then
				height += GAP + PILL_HEIGHT
			end
			tipLabel.Position = UDim2.fromOffset(0, height + 4)
			tipLabel.Size = UDim2.new(1, 0, 0, TIP_HEIGHT)
			if showTip then
				height += 4 + TIP_HEIGHT
			end
		end
		skip.Position = UDim2.new(1, 4, 0, -TOP_PAD)
		pill.Visible = showPill
		tipLabel.Visible = showTip
		tipLabel.Text = tipText or ""
		container.Size = UDim2.fromOffset(width, height)

		-- Where it sits. With a panel (or the intro) open it goes to the very top: on touch screens
		-- that covers the wallet, which the panel hides anyway. Otherwise on touch screens it goes
		-- under the wallet and the event lines; on desktop at the top, with the HUD under it.
		local panelY = if touch then -2 else math.max(0, top - 8)
		local y = panelY
		if not panelOpen and not splashOpen and touch then
			y = math.max(top - 6, hudBottom(centre - width / 2, centre + width / 2) - 4)
		end
		container.Position = UDim2.fromOffset(centre, y)
		-- Panels start under the dialogue as it sits while one is open (no tip on small screens).
		local panelHeight = height - (if showTip and small then 3 + COMPACT_TIP else 0)
		-- Only on a change: panels and the HUD re-lay themselves out when these change.
		local panelTop = panelY + panelHeight + 6
		if gui:GetAttribute("PanelTop") ~= panelTop then
			gui:SetAttribute("PanelTop", panelTop)
		end
		local bottom = if touch then nil else y + height + 4
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

	local function showLine(index: number)
		lineIndex = index
		speech.Text = queue[index] or ""
		speech.MaxVisibleGraphemes = 0
		typed = 0
		typing = true
	end

	local function playLines(lines: { string })
		local chunks: { string } = {}
		for _, line in lines do
			if compact() then
				for _, part in sentences(line) do
					table.insert(chunks, part)
				end
			else
				table.insert(chunks, line)
			end
		end
		queue = chunks
		showLine(1)
	end

	-- How long a finished line stays before the next one.
	local function holdTime(text: string): number
		return math.max(2.2, #text * 0.045)
	end

	tapper.Activated:Connect(function()
		if typing then
			typing = false
			speech.MaxVisibleGraphemes = -1
			lineDoneAt = os.clock()
		elseif lineIndex < #queue then
			Sfx.play("click")
			showLine(lineIndex + 1)
		end
	end)

	-- Guides --------------------------------------------------------------------------------------
	type UiGuide = { target: GuiObject, arrow: Frame, cleanup: () -> () }
	type Trail = { folder: Folder, parts: { BasePart }, fades: { number } }
	type WorldGuide = { target: WorldTarget, cleanup: () -> (), trail: Trail?, edge: Frame? }
	local uiGuides: { UiGuide } = {}
	local worldGuides: { WorldGuide } = {}

	local function pulseTween(object: Instance, seconds: number, goal: { [string]: any }): Tween
		local tween = TweenService:Create(object, TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), goal)
		tween:Play()
		return tween
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
		local arrow = makeArrow(gui, if compact() then 44 else 58, 9)
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
			-- A big glossy arrow (and its label) bouncing over the target, seen from anywhere.
			local primary = target.kind == "primary"
			local board = Instance.new("BillboardGui")
			board.Name = "TutorialArrow"
			board.Adornee = target.adornee
			board.AlwaysOnTop = true
			board.LightInfluence = 0
			board.Size = if primary then UDim2.fromOffset(180, 150) else UDim2.fromOffset(100, 104)
			board.StudsOffsetWorldSpace = Vector3.new(0, target.height, 0)
			-- BillboardGuis do not render inside a ScreenGui; they live directly under PlayerGui.
			board.Parent = playerGui
			if target.label ~= "" then
				local label = Instance.new("TextLabel")
				label.BackgroundTransparency = 1
				label.Size = UDim2.new(1, 0, 0, 40)
				label.TextColor3 = GUIDE
				label.Font = UiKit.DISPLAY_FONT
				label.TextScaled = true
				label.Text = target.label
				UiKit.outline(label, 3.5)
				label.Parent = board
			end
			local size = if primary then 100 else 64
			local arrow = makeArrow(board, size, 1)
			arrow.Position = UDim2.new(0.5, 0, 1, -size / 2)
			table.insert(tweens, pulseTween(board, 0.5, { StudsOffset = Vector3.new(0, 1.4, 0) }))
			table.insert(made, board)
		end

		if target.kind == "primary" then
			-- A trail of outlined yellow chevrons along the ground from the player to the target,
			-- flowing toward it (animateGuides places them each frame).
			local folder = Instance.new("Folder")
			folder.Name = "TutorialTrail"
			local parts: { BasePart } = {}
			for _ = 1, trailCount() do
				for _, arm in CHEVRON_ARMS do
					local part = Instance.new("Part")
					part.Name = if arm.ink then "ChevronOutline" else "Chevron"
					part.Anchored = true
					part.CanCollide = false
					part.CanQuery = false
					part.CanTouch = false
					part.CastShadow = false
					part.Locked = true
					part.Material = Enum.Material.SmoothPlastic
					part.Color = if arm.ink then UiKit.INK else GUIDE
					part.Size = arm.size
					part.Transparency = 1
					part.Parent = folder
					table.insert(parts, part)
				end
			end
			guide.trail = { folder = folder, parts = parts, fades = table.create(#parts // #CHEVRON_ARMS, 1) }
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
		for index = 1, #trail.fades do
			local along = TRAIL_START + phase + (index - 1) * TRAIL_SPACING
			local room = distance - TRAIL_END - along
			local fade = if room < 0 then 1 else 1 - math.min(1, (along - TRAIL_START) / TRAIL_FADE, room / TRAIL_FADE)
			local first = (index - 1) * arms
			if math.abs(trail.fades[index] - fade) > 0.02 then
				trail.fades[index] = fade
				for arm = 1, arms do
					trail.parts[first + arm].Transparency = fade
				end
			end
			if fade < 1 then
				local at = fromFeet + toward * along + Vector3.new(0, CHEVRON_LIFT, 0)
				local frame = CFrame.fromMatrix(at, side, Vector3.yAxis) * LEAN
				for arm = 1, arms do
					table.insert(trailParts, trail.parts[first + arm])
					table.insert(trailFrames, frame * CHEVRON_ARMS[arm].offset)
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
		for _, guide in uiGuides do
			local target, arrow = guide.target, guide.arrow
			if target.Parent == nil or not shown(target) or revealShowing() then
				arrow.Visible = false
				continue
			end
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
	local function toStudio(lines: { string }, key: string, instruction: string, tip: string?): View
		local ui = {}
		local studioButton = sideButton("StudioButton")
		if studioButton ~= nil then
			table.insert(ui, studioButton)
		end
		local world = {}
		local stand = standTarget("Studio", "MAKE A MOVIE", "primary")
		if stand ~= nil then
			table.insert(world, stand)
		end
		return { linesKey = key, lines = lines, instruction = instruction, tip = tip, ui = ui, world = world }
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
	local function promptHint(): string?
		local prompt = nearMovies
		if prompt == nil then
			return nil
		end
		if UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
			return `Press {prompt.GamepadKeyCode.Name} to Make a Movie.`
		elseif UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
			return "Tap Make a Movie on the stand."
		end
		return `Press {prompt.KeyboardKeyCode.Name} to Make a Movie.`
	end

	local steps: { Step } = {
		{
			done = function()
				return player:GetAttribute("LotIndex") ~= nil
			end,
			view = function()
				local pad = padTarget("claim")
				return { linesKey = "arrival", lines = LINES.arrival, instruction = INSTRUCTIONS.claim, ui = {}, world = if pad ~= nil then { pad } else {} }
			end,
		},
		{
			done = function()
				return count(ClientState.roster) > 0
			end,
			view = function()
				local odds = standTarget("Odds", "", "hint")
				return {
					linesKey = "cast",
					lines = LINES.cast,
					instruction = INSTRUCTIONS.cast,
					tip = "The blue CASTING ODDS stand shows the chances before a roll.",
					ui = only(findGui(gui:FindFirstChild("CastingBar"), "CastButton")),
					world = if odds ~= nil then { odds } else {},
				}
			end,
		},
		{
			done = function()
				return studioOpened or hasScripts()
			end,
			view = function()
				return toStudio(LINES.movies, "movies", INSTRUCTIONS.movies, promptHint())
			end,
		},
		{
			done = hasScripts,
			view = function()
				if not isOpen("StudioPanel") then
					return toStudio(LINES.script, "script", INSTRUCTIONS.script, promptHint())
				end
				local studioPanel = panel("StudioPanel")
				local target = if studioTab() ~= "Scripts" then findGui(studioPanel, "ScriptsTab") else findGui(studioPanel, "Script_Short")
				return { linesKey = "script", lines = LINES.script, instruction = INSTRUCTIONS.script, ui = only(target), world = {} }
			end,
		},
		{
			done = hasFilm,
			view = function()
				local view: View = { linesKey = "film", lines = LINES.film, instruction = INSTRUCTIONS.film, ui = {}, world = {} }
				local picker = panel("PickerPanel")
				if picker ~= nil and picker.Visible then
					view.tip = "Actors with a genre tag match the script's specialty and earn more."
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
						view.ui = only(any)
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
						view.ui = only(first)
					else
						view.ui = only(findGui(picker, "StartFilming"))
					end
					return view
				end
				if not isOpen("StudioPanel") then
					return toStudio(LINES.film, "film", INSTRUCTIONS.film, promptHint())
				end
				local studioPanel = panel("StudioPanel")
				view.ui = only(if studioTab() ~= "Stages" then findGui(studioPanel, "StagesTab") else findGui(studioPanel, "StartMovie"))
				return view
			end,
		},
		{
			done = hasPremiered,
			view = function()
				local s = studio()
				local film = if s ~= nil then s.films[1] else nil
				local ready = film ~= nil and film.endTime - ClientState.serverNow() <= 0
				local key = if ready then "ready" else "filming"
				local lines = if ready then LINES.ready else LINES.filming
				local instruction = if ready then INSTRUCTIONS.ready else INSTRUCTIONS.filming
				if not isOpen("StudioPanel") then
					return toStudio(lines, key, instruction, promptHint())
				end
				local studioPanel = panel("StudioPanel")
				local target
				if studioTab() ~= "Stages" then
					target = findGui(studioPanel, "StagesTab")
				else
					local row = if film ~= nil then findGui(studioPanel, `Stage{film.stage}`) else nil
					target = findGui(row or studioPanel, "StageAction")
				end
				return { linesKey = key, lines = lines, instruction = instruction, ui = only(target), world = {} }
			end,
		},
		{
			done = function()
				return collected
			end,
			view = function()
				-- The premiere's own line first, once its reveal is over.
				local lines = { LINES.collect }
				local line = if resultId ~= nil then RESULT_LINES[resultId] else nil
				if line ~= nil then
					table.insert(lines, 1, line)
				end
				local pad = padTarget("collect")
				return { linesKey = "collect:" .. (resultId or ""), lines = lines, instruction = INSTRUCTIONS.collect, ui = {}, world = if pad ~= nil then { pad } else {} }
			end,
		},
	}

	-- Intro screen ---------------------------------------------------------------------------------
	-- The one big moment: red curtains open on Lucien in a spotlight, with his name on a plate.
	-- His lines play in the dialogue at the top as usual.
	local function closeSplash()
		local open = splash
		if open == nil then
			return
		end
		splash = nil
		open:Destroy()
		layout()
	end

	local function openSplash()
		local still = reducedMotion()
		local overlay = Instance.new("Frame")
		overlay.Name = "DirectorPanel" -- a "Panel": special events wait for it to close
		overlay.Size = UDim2.fromScale(1, 1)
		overlay.BackgroundColor3 = UiKit.DARK
		overlay.BackgroundTransparency = 0.15
		overlay.Active = true
		overlay.ZIndex = 7
		overlay.Parent = gui
		splash = overlay

		-- Spotlight, the floor it lands on, and Lucien.
		local stage = Instance.new("Frame")
		stage.Name = "Stage"
		stage.BackgroundTransparency = 1
		stage.AnchorPoint = Vector2.new(0.5, 0)
		stage.ZIndex = 7
		stage.Parent = overlay
		local beamOfLight = Instance.new("Frame")
		beamOfLight.Name = "Spotlight"
		beamOfLight.AnchorPoint = Vector2.new(0.5, 0)
		beamOfLight.Position = UDim2.fromScale(0.5, -0.1)
		beamOfLight.Size = UDim2.fromScale(0.42, 0.78)
		beamOfLight.BackgroundColor3 = UiKit.CREAM
		beamOfLight.BorderSizePixel = 0
		beamOfLight.ZIndex = 7
		beamOfLight.Parent = stage
		local fade = Instance.new("UIGradient")
		fade.Rotation = 90
		fade.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.95), NumberSequenceKeypoint.new(1, 0.72) })
		fade.Parent = beamOfLight
		local floor = Instance.new("Frame")
		floor.Name = "Floor"
		floor.AnchorPoint = Vector2.new(0.5, 0.5)
		floor.Position = UDim2.fromScale(0.5, 0.64)
		floor.Size = UDim2.fromScale(0.5, 0.07)
		floor.BackgroundColor3 = UiKit.GOLD
		floor.BackgroundTransparency = 0.55
		floor.BorderSizePixel = 0
		floor.ZIndex = 7
		floor.Parent = stage
		local oval = Instance.new("UICorner")
		oval.CornerRadius = UDim.new(0.5, 0)
		oval.Parent = floor

		local figure = Instance.new("Frame")
		figure.Name = "Lucien"
		figure.BackgroundTransparency = 1
		figure.AnchorPoint = Vector2.new(0.5, 1)
		figure.Position = UDim2.fromScale(0.5, 0.66)
		figure.Size = UDim2.fromScale(0.62, 0.64)
		figure.ZIndex = 8
		figure.Parent = stage
		local square = Instance.new("UIAspectRatioConstraint")
		square.Parent = figure
		local view = Icon3D.director(figure, false, true)
		local stopSway = Icon3D.wobble(view)
		overlay.Destroying:Connect(stopSway)
		local rise = Instance.new("UIScale")
		rise.Scale = if still then 1 else 0.7
		rise.Parent = figure

		-- Name plate.
		local plate = Instance.new("Frame")
		plate.Name = "NamePlate"
		plate.AnchorPoint = Vector2.new(0.5, 0)
		plate.Position = UDim2.fromScale(0.5, 0.69)
		plate.Size = UDim2.new(0.9, 0, 0.15, 0)
		plate.BackgroundColor3 = UiKit.NAVY
		plate.ZIndex = 8
		plate.Parent = stage
		UiKit.corner(plate, 12)
		UiKit.border(plate, 3, UiKit.GOLD)
		local plateLimit = Instance.new("UISizeConstraint")
		plateLimit.MaxSize = Vector2.new(400, 80)
		plateLimit.Parent = plate
		local plateName = UiKit.makeTitle(plate, "Director Lucien Vale", UiKit.GOLD, UDim2.fromScale(0.92, 0.56), UDim2.fromScale(0.04, 0.06), 2.5)
		plateName.ZIndex = 9
		UiKit.textConstraint(plateName, 34)
		local plateRole = UiKit.makeLabel(plate, "World-renowned film director", UiKit.MUTED, UDim2.fromScale(0.92, 0.3), UDim2.fromScale(0.04, 0.64))
		plateRole.ZIndex = 9
		UiKit.textConstraint(plateRole, 18)

		local begin = UiKit.makeButton(stage, "Let's begin", UiKit.GREEN, UDim2.new(0.5, 0, 0.12, 0))
		begin.Name = "Begin"
		begin.AnchorPoint = Vector2.new(0.5, 0)
		begin.Position = UDim2.fromScale(0.5, 0.87)
		begin.ZIndex = 8
		begin.Activated:Connect(closeSplash)

		-- The stage fills the room under the dialogue: the button (at least 56 px tall, for
		-- thumbs) and the name plate at the bottom, Lucien in the space above them.
		local function place()
			local area = gui.AbsoluteSize
			local topEdge = gui:GetAttribute("PanelTop")
			local y = if typeof(topEdge) == "number" then topEdge else 120
			local width = math.min(area.X, 560)
			local height = math.max(200, area.Y - y - 8)
			stage.Position = UDim2.new(0.5, 0, 0, y)
			stage.Size = UDim2.fromOffset(width, height)
			local buttonHeight = math.clamp(math.floor(height * 0.14), 56, 64)
			local plateHeight = math.clamp(math.floor(height * 0.15), 44, 80)
			begin.Size = UDim2.fromOffset(math.clamp(math.floor(width * 0.5), 200, 280), buttonHeight)
			begin.Position = UDim2.fromOffset(width / 2, height - buttonHeight)
			plate.Size = UDim2.fromOffset(math.min(math.floor(width * 0.9), 400), plateHeight)
			plate.Position = UDim2.fromOffset(width / 2, height - buttonHeight - 10 - plateHeight)
			local figureBottom = height - buttonHeight - plateHeight - 16
			figure.Size = UDim2.fromOffset(figureBottom, figureBottom)
			figure.Position = UDim2.fromOffset(width / 2, figureBottom)
			floor.Position = UDim2.fromOffset(width / 2, figureBottom - 4)
			floor.Size = UDim2.fromOffset(math.floor(width * 0.5), math.max(12, math.floor(figureBottom * 0.1)))
		end
		place()
		local placing = gui:GetAttributeChangedSignal("PanelTop"):Connect(place)
		overlay.Destroying:Connect(function()
			placing:Disconnect()
		end)

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
			curtain.Parent = overlay
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
		Sfx.play("welcome")
		if not still then
			local open = TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			for _, curtain in curtains do
				TweenService:Create(curtain, open, { Size = UDim2.fromScale(0.16, 1) }):Play()
			end
			TweenService:Create(rise, TweenInfo.new(0.9, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0.3), { Scale = 1 }):Play()
			task.delay(0.5, function()
				if splash == overlay then
					Fx.confetti(30, { UiKit.GOLD, UiKit.CREAM, GUIDE })
				end
			end)
		end
	end

	-- Driver ----------------------------------------------------------------------------------------
	local currentStep = 0
	local finaleEndsAt: number? = nil
	local renderConnection: RBXScriptConnection? = nil

	local function teardown()
		active = false
		clearGuides()
		closeSplash()
		if renderConnection ~= nil then
			renderConnection:Disconnect()
			renderConnection = nil
		end
		container.Visible = false
		gui:SetAttribute("PanelTop", nil)
		gui:SetAttribute("TutorialBottom", nil)
	end

	local function setInstruction(text: string, step: number?)
		if pillText.Text ~= text then
			pillText.Text = text
			stepChip.Visible = step ~= nil
			stepChip.Text = if step ~= nil then `{step}/{#steps}` else ""
			if not reducedMotion() then
				local pop = pill:FindFirstChild("Pop") :: UIScale?
				if pop == nil then
					local made = Instance.new("UIScale")
					made.Name = "Pop"
					made.Parent = pill
					pop = made
				end
				assert(pop ~= nil)
				pop.Scale = 1.06
				TweenService:Create(pop, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			end
		end
	end

	local function startFinale()
		finale = true
		closeSplash()
		tutorialDone:FireServer()
		Sfx.play("welcome")
		Fx.confetti(40, { UiKit.GOLD, UiKit.CREAM, GUIDE })
		playLines(LINES.finale)
		setInstruction(INSTRUCTIONS.finale, nil)
		tipText = nil
		local world = {}
		for _, screen in { "Studio", "Upgrades", "Odds", "Actors" } do
			local stand = standTarget(screen, "", "secondary")
			if stand ~= nil then
				table.insert(world, stand)
			end
		end
		syncGuides({}, world)
		layout()
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
		startFinale()
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
		end
		local view = steps[index].view()
		if view.linesKey ~= linesKey then
			linesKey = view.linesKey
			playLines(view.lines)
		end
		setInstruction(view.instruction, index)
		if tipText ~= view.tip then
			tipText = view.tip
			layout()
		end
		if splash ~= nil then
			syncGuides({}, {})
		else
			syncGuides(view.ui, view.world)
		end
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
				else
					speech.MaxVisibleGraphemes = math.floor(typed)
				end
			elseif lineIndex < #queue and os.clock() - lineDoneAt > holdTime(speech.Text) then
				showLine(lineIndex + 1)
			elseif finale and lineIndex >= #queue then
				local ends = finaleEndsAt
				if ends == nil then
					finaleEndsAt = os.clock() + FINALE_SECONDS
				elseif os.clock() > ends then
					teardown()
					return
				end
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
