--!strict
-- The film-leader loading screen, built from frames, strokes, corners and text only (no images,
-- no ViewportFrames, no particles). `build` fills two parents that the caller owns: `cover` (full
-- screen, no insets) and `safe` (inside CoreUISafeInsets: title, countdown, strip, tip, Skip).
-- Four things move: the sweeping hand, the countdown number, the strip fill and the tip.
local TweenService = game:GetService("TweenService")

local Logic = require(script.Parent:WaitForChild("LoadingLogic"))

local View = {}

local BG = Color3.fromRGB(14, 16, 22)
local CREAM = Color3.fromRGB(244, 231, 207)
local GOLD = Color3.fromRGB(255, 210, 63)
local INK = Color3.fromRGB(11, 15, 31)
local DIAL = Color3.fromRGB(28, 32, 44)
local DISPLAY_FONT = Enum.Font.FredokaOne
local BODY_FONT = Enum.Font.GothamBold

export type Handles = {
	skip: TextButton,
	-- elapsed seconds, displayed progress 0..1, 1-based tip index
	update: (elapsed: number, progress: number, tip: number) -> (),
	-- A returning player: "Welcome back, <name>!" plus an optional live line (replaces the tips).
	showWelcome: (welcome: string, live: string?) -> (),
}

local function frame(parent: Instance, name: string, size: UDim2, position: UDim2, color: Color3): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = size
	f.Position = position
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

local function round(parent: Instance, radius: UDim)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = parent
end

local function stroke(parent: Instance, thickness: number, color: Color3, transparency: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Thickness = thickness
	s.Color = color
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function label(parent: Instance, name: string, text: string, font: Enum.Font, color: Color3, size: UDim2, position: UDim2, minSize: number, maxSize: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = position
	l.Font = font
	l.Text = text
	l.TextColor3 = color
	l.TextScaled = true
	l.TextWrapped = true
	l.Parent = parent
	local limit = Instance.new("UITextSizeConstraint")
	limit.MinTextSize = minSize
	limit.MaxTextSize = maxSize
	limit.Parent = l
	return l
end

function View.build(cover: GuiObject, safe: GuiObject, reduced: boolean): Handles
	cover.BackgroundColor3 = BG
	cover.BackgroundTransparency = 0
	-- Faint film-leader grey wash in the middle so the dial reads against the dark.
	local glow = frame(cover, "Wash", UDim2.fromScale(0.62, 1), UDim2.fromScale(0.5, 0.5), DIAL)
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.BackgroundTransparency = 0.55
	round(glow, UDim.new(0.5, 0))

	-- Title ------------------------------------------------------------------------------------
	local title = label(safe, "Title", "HOLLYWOOD RNG", DISPLAY_FONT, GOLD, UDim2.fromScale(0.7, 0.12), UDim2.fromScale(0.15, 0.015), 16, 34)
	stroke(title, 2, INK).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual

	-- Countdown circle -------------------------------------------------------------------------
	-- Square dial, 50% of the safe height, centred between the title and the strip.
	local dial = frame(safe, "Dial", UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.5, 0.43), DIAL)
	dial.AnchorPoint = Vector2.new(0.5, 0.5)
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 1
	ratio.DominantAxis = Enum.DominantAxis.Height
	ratio.Parent = dial
	round(dial, UDim.new(0.5, 0))
	stroke(dial, 3, CREAM)
	local inner = frame(dial, "InnerRing", UDim2.fromScale(0.72, 0.72), UDim2.fromScale(0.5, 0.5), DIAL)
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.BackgroundTransparency = 1
	round(inner, UDim.new(0.5, 0))
	stroke(inner, 2, CREAM, 0.35)
	-- Cross hair through the middle.
	local vertical = frame(dial, "CrossV", UDim2.new(0, 2, 1, 0), UDim2.fromScale(0.5, 0.5), CREAM)
	vertical.AnchorPoint = Vector2.new(0.5, 0.5)
	vertical.BackgroundTransparency = 0.7
	local horizontal = frame(dial, "CrossH", UDim2.new(1, 0, 0, 2), UDim2.fromScale(0.5, 0.5), CREAM)
	horizontal.AnchorPoint = Vector2.new(0.5, 0.5)
	horizontal.BackgroundTransparency = 0.7
	-- The big number.
	local number = label(dial, "Number", "3", DISPLAY_FONT, CREAM, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.5, 0.5), 24, 120)
	number.AnchorPoint = Vector2.new(0.5, 0.5)
	number.ZIndex = 3
	stroke(number, 3, INK).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	-- Sweeping hand: a bar from the centre to the rim, turning once a second.
	local pivot = frame(dial, "HandPivot", UDim2.fromScale(1, 1), UDim2.fromScale(0.5, 0.5), GOLD)
	pivot.AnchorPoint = Vector2.new(0.5, 0.5)
	pivot.BackgroundTransparency = 1
	pivot.ZIndex = 2
	local hand = frame(pivot, "Hand", UDim2.new(0, 3, 0.5, 0), UDim2.fromScale(0.5, 0.5), GOLD)
	hand.AnchorPoint = Vector2.new(0.5, 1)
	hand.BackgroundTransparency = 0.15
	hand.ZIndex = 2

	-- Film strip --------------------------------------------------------------------------------
	local strip = frame(safe, "Strip", UDim2.fromScale(0.43, 0.1), UDim2.fromScale(0.5, 0.735), Color3.fromRGB(8, 9, 13))
	strip.AnchorPoint = Vector2.new(0.5, 0)
	round(strip, UDim.new(0, 4))
	stroke(strip, 2, CREAM, 0.2)
	local frames = Logic.FRAMES
	local holes = frames * 2
	for edge = 0, 1 do
		for i = 0, holes - 1 do
			local hole = frame(strip, "Hole", UDim2.new(0.5 / holes, 0, 0, 3), UDim2.new((i + 0.25) / holes, 0, edge, if edge == 0 then 3 else -6), CREAM)
			hole.BackgroundTransparency = 0.25
			round(hole, UDim.new(0, 1))
		end
	end
	local cells = frame(strip, "Cells", UDim2.new(1, -8, 1, -18), UDim2.new(0, 4, 0, 9), Color3.fromRGB(8, 9, 13))
	cells.BackgroundTransparency = 1
	local fills: { Frame } = {}
	for i = 1, frames do
		local cell = frame(cells, "Cell", UDim2.new(1 / frames, -3, 1, 0), UDim2.new((i - 1) / frames, 1, 0, 0), Color3.fromRGB(32, 36, 50))
		round(cell, UDim.new(0, 2))
		local fill = frame(cell, "Fill", UDim2.fromScale(0, 1), UDim2.new(), GOLD)
		round(fill, UDim.new(0, 2))
		fills[i] = fill
	end

	-- Tip ---------------------------------------------------------------------------------------
	local tip = label(safe, "Tip", Logic.TIPS[1] or "", BODY_FONT, CREAM, UDim2.fromScale(0.56, 0.11), UDim2.fromScale(0.22, 0.865), 12, 18)
	tip.TextXAlignment = Enum.TextXAlignment.Center
	local welcome = label(safe, "Welcome", "", DISPLAY_FONT, CREAM, UDim2.fromScale(0.5, 0.06), UDim2.fromScale(0.25, 0.855), 14, 20)
	welcome.Visible = false
	local liveLine = label(safe, "LiveLine", "", BODY_FONT, GOLD, UDim2.fromScale(0.5, 0.055), UDim2.fromScale(0.25, 0.92), 12, 15)
	liveLine.Visible = false
	local welcomed = false
	local function showWelcome(text: string, live: string?)
		welcomed = true
		tip.Visible = false
		welcome.Text = text
		welcome.Visible = true
		liveLine.Text = live or ""
		liveLine.Visible = live ~= nil and live ~= ""
	end

	-- Skip: bottom right, inside the safe area, at least 44 px tall, always shown ---------------
	local skip = Instance.new("TextButton")
	skip.Name = "Skip"
	skip.AnchorPoint = Vector2.new(1, 1)
	skip.Size = UDim2.new(0, 104, 0, 44)
	skip.Position = UDim2.new(1, -12, 1, -8)
	skip.BackgroundColor3 = Color3.fromRGB(40, 46, 66)
	skip.AutoButtonColor = false
	skip.Font = DISPLAY_FONT
	skip.Text = "Skip"
	skip.TextColor3 = CREAM
	skip.TextSize = 20
	skip.Parent = safe
	round(skip, UDim.new(0, 10))
	stroke(skip, 2, CREAM, 0.3)

	-- Updates -----------------------------------------------------------------------------------
	pivot.Visible = not reduced -- fixed for the whole screen
	local fillWidths: { number } = {}
	local shownNumber = -1
	local shownTip = 1
	local function update(elapsed: number, progress: number, tipIndex: number)
		local count = if reduced then 1 else Logic.countNumber(elapsed)
		if count ~= shownNumber then
			shownNumber = count
			number.Text = tostring(count)
			if not reduced then
				number.Size = UDim2.fromScale(0.62, 0.62)
				TweenService:Create(number, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromScale(0.5, 0.5) }):Play()
			end
		end
		if not reduced then
			pivot.Rotation = Logic.handAngle(elapsed)
		end
		local whole, part = Logic.filled(progress, frames)
		for i, fill in fills do
			local width = if i <= whole then 1 elseif i == whole + 1 then (if reduced then 0 else part) else 0
			if fillWidths[i] ~= width then -- most cells are settled: write only what changed
				fillWidths[i] = width
				fill.Size = UDim2.fromScale(width, 1)
			end
		end
		if tipIndex ~= shownTip and not welcomed then
			shownTip = tipIndex
			tip.Text = Logic.TIPS[tipIndex] or ""
			if not reduced then
				tip.TextTransparency = 1
				TweenService:Create(tip, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
			end
		end
	end
	update(0, 0, 1)
	return { skip = skip, update = update, showWelcome = showWelcome }
end

return View
