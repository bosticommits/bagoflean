--!strict
-- Premiere night: the premiere result as a movie poster (title, genre, cast portraits, billing)
-- under two sweeping spotlights, with camera flashes and a big result stamp that slams onto the
-- poster in the result's color. Beside it, the payout counts up, then Fame and any unlock.
-- How big each result feels is in PremiereNight (shared). Client-only presentation: everything is
-- plain frames and tweens (no particles), and the only pictures are the cast portraits and the
-- result icon, so it stays light on phones. A tap during "The reviews are in..." skips to the stamp.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Movies = require(ReplicatedStorage.Shared.Movies)
local PremiereNight = require(ReplicatedStorage.Shared.PremiereNight)
local Fx = require(script.Parent.Fx)
local Hud = require(script.Parent.Hud)
local Icon3D = require(script.Parent.Icon3D)
local Sfx = require(script.Parent.Sfx)
local UiKit = require(script.Parent.UiKit)

local WHITE = UiKit.WHITE
local POSTER_ASPECT = 0.7 -- width / height, a one-sheet movie poster
local BEAM_WARM = Color3.fromRGB(255, 244, 214)

local PremiereReveal = {}

export type Format = {
	actorLabel: (key: string) -> string,
	power: (power: number) -> string,
}

local random = Random.new()

local function tween(object: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	local t = TweenService:Create(object, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

local function round(object: GuiObject, radius: UDim)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = object
end

-- Builds the overlay once (hidden) and returns the function that shows a PremiereResult on it.
function PremiereReveal.start(gui: ScreenGui, format: Format): (result: any) -> ()
	-- The tutorial looks for "PremiereReveal" to wait while it shows.
	local overlay = Instance.new("Frame")
	overlay.Name = "PremiereReveal"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = UiKit.INK
	overlay.BackgroundTransparency = 0.18
	overlay.BorderSizePixel = 0
	overlay.Active = true
	overlay.Visible = false
	overlay.ZIndex = 12
	overlay.Parent = gui

	-- Tapping anywhere during the drumroll skips to the result.
	local tapCatcher = Instance.new("TextButton")
	tapCatcher.Name = "Skip"
	tapCatcher.Text = ""
	tapCatcher.AutoButtonColor = false
	tapCatcher.BackgroundTransparency = 1
	tapCatcher.Size = UDim2.fromScale(1, 1)
	tapCatcher.ZIndex = 12
	tapCatcher.Parent = overlay

	-- Spotlights ------------------------------------------------------------------------------
	-- Each beam is twice its visible length and centred on its base, with the lower half
	-- transparent, so turning it (Roblox turns frames about their centre) swings it from the base.
	local beams: { Frame } = {}
	for index, x in { 0.08, 0.92 } do
		local beam = Instance.new("Frame")
		beam.Name = "Spotlight" .. index
		beam.AnchorPoint = Vector2.new(0.5, 0.5)
		beam.Position = UDim2.fromScale(x, 1.02)
		beam.Size = UDim2.fromScale(0.2, 2.4)
		beam.BackgroundColor3 = BEAM_WARM
		beam.BorderSizePixel = 0
		beam.ZIndex = 12
		beam.Parent = overlay
		local fade = Instance.new("UIGradient")
		fade.Rotation = 90
		fade.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, 0.93),
			NumberSequenceKeypoint.new(0.499, 0.62),
			NumberSequenceKeypoint.new(0.5, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
		fade.Parent = beam
		table.insert(beams, beam)
	end
	local flashLayer = Instance.new("Frame")
	flashLayer.Name = "Flashes"
	flashLayer.BackgroundTransparency = 1
	flashLayer.Size = UDim2.fromScale(1, 1)
	flashLayer.ZIndex = 12
	flashLayer.Parent = overlay

	-- The stage holds the poster (left, or top on a tall screen) and the results card.
	local stage = Instance.new("Frame")
	stage.Name = "Stage"
	stage.AnchorPoint = Vector2.new(0.5, 0.5)
	stage.Position = UDim2.fromScale(0.5, 0.52)
	stage.Size = UDim2.fromScale(0.94, 0.84)
	stage.BackgroundTransparency = 1
	stage.ZIndex = 13
	stage.Parent = overlay
	local stageLimit = Instance.new("UISizeConstraint")
	stageLimit.Parent = stage
	local stageScale = Instance.new("UIScale")
	stageScale.Parent = stage

	-- Poster ----------------------------------------------------------------------------------
	local poster = Instance.new("Frame")
	poster.Name = "Poster"
	poster.BackgroundColor3 = UiKit.NAVY
	poster.ClipsDescendants = true -- keeps the light sweep on the poster
	poster.ZIndex = 13
	poster.Parent = stage
	UiKit.corner(poster, 10)
	local posterEdge = UiKit.border(poster, 4)
	local posterShade = Instance.new("UIGradient")
	posterShade.Rotation = 90
	posterShade.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(70, 70, 95))
	posterShade.Parent = poster
	local trim = Instance.new("Frame")
	trim.Name = "Trim"
	trim.BackgroundTransparency = 1
	trim.Position = UDim2.fromScale(0.04, 0.03)
	trim.Size = UDim2.fromScale(0.92, 0.94)
	trim.ZIndex = 14
	trim.Parent = poster
	round(trim, UDim.new(0, 6))
	local trimLine = UiKit.border(trim, 2, UiKit.CREAM)
	trimLine.Transparency = 0.45

	local function posterText(y: number, h: number, color: Color3, maxSize: number, display: boolean): TextLabel
		local label = if display
			then UiKit.makeTitle(poster, "", color, UDim2.fromScale(0.84, h), UDim2.fromScale(0.08, y), 2.5)
			else UiKit.makeLabel(poster, "", color, UDim2.fromScale(0.84, h), UDim2.fromScale(0.08, y))
		label.ZIndex = 15
		UiKit.textConstraint(label, maxSize)
		return label
	end
	local presents = posterText(0.055, 0.045, UiKit.CREAM, 14, false)
	presents.Name = "Presents"
	local genreTag = Instance.new("TextLabel")
	genreTag.Name = "Genre"
	genreTag.AnchorPoint = Vector2.new(0.5, 0)
	genreTag.Position = UDim2.fromScale(0.5, 0.115)
	genreTag.Size = UDim2.fromScale(0.42, 0.06)
	genreTag.Font = UiKit.DISPLAY_FONT
	genreTag.TextScaled = true
	genreTag.TextColor3 = WHITE
	genreTag.ZIndex = 15
	genreTag.Parent = poster
	round(genreTag, UDim.new(0.5, 0))
	UiKit.border(genreTag, 2)
	UiKit.outline(genreTag, 1.5)
	UiKit.textConstraint(genreTag, 18)
	local genrePad = Instance.new("UIPadding")
	genrePad.PaddingTop = UDim.new(0.14, 0)
	genrePad.PaddingBottom = UDim.new(0.14, 0)
	genrePad.Parent = genreTag
	-- A soft spot of light behind the cast.
	local castGlow = Instance.new("Frame")
	castGlow.Name = "CastGlow"
	castGlow.AnchorPoint = Vector2.new(0.5, 0.5)
	castGlow.Position = UDim2.fromScale(0.5, 0.37)
	castGlow.Size = UDim2.fromScale(1.1, 0.42)
	castGlow.BackgroundColor3 = WHITE
	castGlow.BackgroundTransparency = 0.82
	castGlow.ZIndex = 14
	castGlow.Parent = poster
	round(castGlow, UDim.new(0.5, 0))
	local castRow = Instance.new("Frame")
	castRow.Name = "Cast"
	castRow.BackgroundTransparency = 1
	castRow.Position = UDim2.fromScale(0.06, 0.2)
	castRow.Size = UDim2.fromScale(0.88, 0.36)
	castRow.ZIndex = 15
	castRow.Parent = poster
	local titleLabel = posterText(0.585, 0.17, UiKit.CREAM, 40, true)
	titleLabel.Name = "Title"
	titleLabel.TextWrapped = true
	local billingLabel = posterText(0.765, 0.085, UiKit.CREAM, 14, false)
	billingLabel.Name = "Billing"
	billingLabel.TextWrapped = true
	billingLabel.TextTransparency = 0.1
	local lengthLabel = posterText(0.875, 0.05, UiKit.GOLD, 14, true)
	lengthLabel.Name = "NowShowing"
	-- The light sweep: a bright band slid across once for big results.
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.BackgroundColor3 = WHITE
	shine.BorderSizePixel = 0
	shine.Size = UDim2.fromScale(1, 1)
	shine.ZIndex = 16
	shine.Visible = false
	shine.Parent = poster
	local shineBand = Instance.new("UIGradient")
	shineBand.Rotation = 25
	shineBand.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.42, 1),
		NumberSequenceKeypoint.new(0.5, 0.55),
		NumberSequenceKeypoint.new(0.58, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	shineBand.Parent = shine
	-- A Flop dims the poster.
	local dim = Instance.new("Frame")
	dim.Name = "Dim"
	dim.BackgroundColor3 = UiKit.INK
	dim.BorderSizePixel = 0
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundTransparency = 1
	dim.ZIndex = 16
	dim.Parent = poster

	-- The stamp: lands across the cast (below their faces, above the title), tilted like a rubber stamp.
	local stamp = Instance.new("TextLabel")
	stamp.Name = "Stamp"
	stamp.AnchorPoint = Vector2.new(0.5, 0.5)
	stamp.BackgroundColor3 = UiKit.INK
	stamp.BackgroundTransparency = 0.12
	stamp.Font = UiKit.DISPLAY_FONT
	stamp.TextScaled = true
	stamp.ZIndex = 20
	stamp.Visible = false
	stamp.Parent = stage
	round(stamp, UDim.new(0, 10))
	local stampEdge = UiKit.border(stamp, 5)
	local stampRainbow = Instance.new("UIGradient")
	stampRainbow.Color = UiKit.RAINBOW
	stampRainbow.Enabled = false
	stampRainbow.Parent = stampEdge
	UiKit.outline(stamp, 3)
	UiKit.textConstraint(stamp, 64)
	local stampPad = Instance.new("UIPadding")
	stampPad.PaddingTop = UDim.new(0.12, 0)
	stampPad.PaddingBottom = UDim.new(0.12, 0)
	stampPad.PaddingLeft = UDim.new(0.05, 0)
	stampPad.PaddingRight = UDim.new(0.05, 0)
	stampPad.Parent = stamp
	local stampScale = Instance.new("UIScale")
	stampScale.Parent = stamp

	-- Results card ----------------------------------------------------------------------------
	local card = Instance.new("Frame")
	card.Name = "Results"
	card.BackgroundColor3 = UiKit.PANEL
	card.ZIndex = 13
	card.Parent = stage
	UiKit.corner(card, 18)
	local cardEdge = UiKit.border(card, 5)
	local function cardText(y: number, h: number, color: Color3, maxSize: number, stroke: number?): TextLabel
		local label = UiKit.makeTitle(card, "", color, UDim2.fromScale(0.9, h), UDim2.fromScale(0.05, y), stroke)
		label.ZIndex = 14
		UiKit.textConstraint(label, maxSize)
		return label
	end
	local header = cardText(0.04, 0.085, UiKit.GOLD, 22)
	header.Name = "Header"
	header.Text = "PREMIERE NIGHT"
	local resultArt = Instance.new("Frame")
	resultArt.Name = "ResultArt"
	resultArt.BackgroundTransparency = 1
	resultArt.AnchorPoint = Vector2.new(0.5, 0)
	resultArt.Position = UDim2.fromScale(0.5, 0.13)
	resultArt.Size = UDim2.fromScale(0.5, 0.25)
	resultArt.ZIndex = 15
	resultArt.Parent = card
	local resultAspect = Instance.new("UIAspectRatioConstraint")
	resultAspect.Parent = resultArt
	local waitingLabel = cardText(0.2, 0.12, WHITE, 30)
	waitingLabel.Name = "Waiting"
	waitingLabel.Text = "The reviews are in..."
	local payoutLabel = cardText(0.39, 0.15, UiKit.CASH_GREEN, 48, 3)
	payoutLabel.Name = "Payout"
	local bonusLabel = cardText(0.54, 0.065, UiKit.GOLD, 18, 2)
	bonusLabel.Name = "Bonus"
	local fameLabel = cardText(0.615, 0.075, UiKit.GOLD, 22)
	fameLabel.Name = "Fame"
	-- "NEW: Talent Agency": what this premiere's Fame just opened. Empty on most premieres.
	local unlockLabel = cardText(0.7, 0.075, UiKit.GOLD, 20)
	unlockLabel.Name = "Unlocked"
	local unlockScale = Instance.new("UIScale")
	unlockScale.Parent = unlockLabel
	local continueButton = UiKit.makeButton(card, "Continue", UiKit.GREEN, UDim2.fromScale(0.6, 0.14), UDim2.fromScale(0.2, 0.81))
	continueButton.Name = "Continue"
	continueButton.ZIndex = 14
	local resultParts: { GuiObject } = { resultArt, payoutLabel, bonusLabel, fameLabel, unlockLabel, continueButton }

	-- Layout: poster beside the card on wide screens, above it on tall ones. Sizes are worked out
	-- in pixels from the stage so the poster keeps its shape and the stamp sits on it.
	local function layout()
		local tall = UiKit.viewport().X < UiKit.viewport().Y
		stageLimit.MaxSize = if tall then Vector2.new(520, 820) else Vector2.new(860, 540)
		local size = stage.AbsoluteSize
		if size.X < 1 or size.Y < 1 then
			return
		end
		local gap = math.max(10, math.floor(size.X * 0.03))
		local posterH: number, posterW: number
		if tall then
			posterH = size.Y * 0.56
			posterW = math.min(posterH * POSTER_ASPECT, size.X)
			posterH = posterW / POSTER_ASPECT
			poster.Position = UDim2.fromOffset((size.X - posterW) / 2, 0)
			card.Position = UDim2.fromOffset(0, posterH + gap)
			card.Size = UDim2.fromOffset(size.X, size.Y - posterH - gap)
		else
			posterH = size.Y
			posterW = math.min(posterH * POSTER_ASPECT, size.X * 0.46)
			posterH = posterW / POSTER_ASPECT
			poster.Position = UDim2.fromOffset(0, (size.Y - posterH) / 2)
			card.Position = UDim2.fromOffset(posterW + gap, 0)
			card.Size = UDim2.fromOffset(size.X - posterW - gap, size.Y)
		end
		poster.Size = UDim2.fromOffset(posterW, posterH)
		stamp.Size = UDim2.fromOffset(posterW * 1.04, posterH * 0.17)
		stamp.Position = UDim2.fromOffset(poster.Position.X.Offset + posterW / 2, poster.Position.Y.Offset + posterH * 0.47)
	end
	stage:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	UiKit.onViewportChanged(layout)

	-- Effects ---------------------------------------------------------------------------------
	local running: { Tween } = {}
	local stopResultSpin: (() -> ())? = nil
	local premiereToken = 0

	local function keep(t: Tween)
		table.insert(running, t)
	end

	-- A camera flash: a white pop with a soft halo at a random spot beside the stage.
	local function flash()
		local left = random:NextNumber() < 0.5
		local x = if left then random:NextNumber(0.02, 0.24) else random:NextNumber(0.76, 0.98)
		local y = random:NextNumber(0.12, 0.92)
		for _, ring in { { size = 14, grow = 64, alpha = 0 }, { size = 30, grow = 150, alpha = 0.6 } } do
			local pop = Instance.new("Frame")
			pop.AnchorPoint = Vector2.new(0.5, 0.5)
			pop.Position = UDim2.fromScale(x, y)
			pop.Size = UDim2.fromOffset(ring.size, ring.size)
			pop.BackgroundColor3 = WHITE
			pop.BackgroundTransparency = ring.alpha
			pop.BorderSizePixel = 0
			pop.ZIndex = 12
			pop.Parent = flashLayer
			round(pop, UDim.new(0.5, 0))
			tween(pop, 0.28, { Size = UDim2.fromOffset(ring.grow, ring.grow), BackgroundTransparency = 1 })
			task.delay(0.3, function()
				pop:Destroy()
			end)
		end
	end
	local function flashes(count: number, seconds: number, mine: number)
		for i = 1, count do
			task.delay(random:NextNumber(0, seconds), function()
				if premiereToken == mine and overlay.Visible then
					flash()
					if i % 3 == 1 then
						Sfx.play("premiereFlash", random:NextNumber(0.9, 1.15))
					end
				end
			end)
		end
	end

	local function stopEffects()
		for _, t in running do
			t:Cancel()
		end
		table.clear(running)
		if stopResultSpin ~= nil then
			stopResultSpin()
			stopResultSpin = nil
		end
		for _, holder in { resultArt :: Instance, castRow, flashLayer } do
			for _, child in holder:GetChildren() do
				if not child:IsA("UIAspectRatioConstraint") then
					child:Destroy()
				end
			end
		end
	end

	-- Spotlights sweep back and forth; `speed` 1 is the calm sweep before the result.
	local function sweep(speed: number, color: Color3)
		for index, beam in beams do
			local side = if index == 1 then 1 else -1
			beam.Rotation = side * -22
			beam.BackgroundColor3 = color
			beam.BackgroundTransparency = 0
			local info = TweenInfo.new((2.4 + index * 0.35) / speed, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
			local t = TweenService:Create(beam, info, { Rotation = side * 24 })
			t:Play()
			keep(t)
		end
	end

	continueButton.Activated:Connect(function()
		premiereToken += 1
		overlay.Visible = false
		stopEffects()
	end)

	local function countUp(label: TextLabel, to: number, seconds: number, mine: number)
		local start = os.clock()
		local connection: RBXScriptConnection
		connection = RunService.RenderStepped:Connect(function()
			local t = math.clamp((os.clock() - start) / seconds, 0, 1)
			if premiereToken ~= mine then
				connection:Disconnect()
				return
			end
			local eased = 1 - (1 - t) ^ 3
			label.Text = `+${Hud.comma(math.floor(to * eased + 0.5))}`
			if t >= 1 then
				connection:Disconnect()
			end
		end)
	end

	local function reveal(result: any, mine: number)
		if premiereToken ~= mine or tapCatcher:GetAttribute("Revealed") then
			return
		end
		tapCatcher:SetAttribute("Revealed", true)
		local res = Movies.getResult(result.result)
		if res == nil then
			return
		end
		local style = PremiereNight.style(res.id)
		local big = style.beams == "party"

		-- The stamp slams down.
		stamp.Text = PremiereNight.stampText(res.id)
		stamp.TextColor3 = res.color
		stampEdge.Color = if style.rainbow then WHITE else res.color
		stampRainbow.Enabled = style.rainbow
		stamp.Rotation = style.tilt
		stampScale.Scale = 2.6
		stamp.Visible = true
		tween(stampScale, 0.2, { Scale = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.2, function()
			if premiereToken ~= mine then
				return
			end
			Sfx.play("premiereStamp")
			-- A thump: the whole stage jolts a little as the stamp lands.
			stageScale.Scale = if big then 1.05 else 1.025
			tween(stageScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
			Fx.premiere(res.id, res.color)
			flashes(style.flashes, if big then 1.6 else 0.9, mine)
		end)

		-- Spotlights: a Flop drops them to the floor; big results sweep faster in the result color.
		for _, t in running do
			t:Cancel()
		end
		table.clear(running)
		if style.beams == "down" then
			for index, beam in beams do
				local side = if index == 1 then 1 else -1
				keep(tween(beam, 0.8, { Rotation = side * 62, BackgroundTransparency = 0.6, BackgroundColor3 = UiKit.FAINT }, Enum.EasingStyle.Bounce))
			end
			keep(tween(dim, 0.6, { BackgroundTransparency = 0.45 }))
		else
			sweep(if big then 2.2 else 1.2, BEAM_WARM:Lerp(res.color, if big then 0.55 else 0.3))
		end
		posterEdge.Color = if style.beams == "down" then UiKit.INK else res.color
		cardEdge.Color = res.color
		if style.shine then
			shine.Visible = true
			shineBand.Offset = Vector2.new(-1, 0)
			keep(tween(shineBand, 0.9, { Offset = Vector2.new(1, 0) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut))
		end

		-- The results card.
		waitingLabel.Visible = false
		for _, part in resultParts do
			part.Visible = true
		end
		stopResultSpin = Icon3D.spin(Icon3D.outlined(resultArt, style.icon), 24)
		local payout = if type(result.payout) == "number" then result.payout else 0
		payoutLabel.Text = "+$0"
		countUp(payoutLabel, payout, if big then 0.9 else 0.6, mine)
		bonusLabel.Text = PremiereNight.bonusLine(
			if type(result.genreBonus) == "number" then result.genreBonus else nil,
			if result.awardNight then Config.AwardNightPayoutMultiplier else nil,
			if type(result.rebirthBonus) == "number" then result.rebirthBonus else nil
		)
		local fame = if type(result.fame) == "number" then result.fame else 0
		local power = if type(result.power) == "number" then result.power else 0
		fameLabel.Text = `+{Hud.comma(fame)} Fame  -  Star Power {format.power(power)}`
		local unlocked = {}
		if type(result.unlocked) == "table" then
			for _, name in result.unlocked do
				if type(name) == "string" then
					table.insert(unlocked, name)
				end
			end
		end
		unlockLabel.Text = if #unlocked > 0 then `NEW: {table.concat(unlocked, ", ")} unlocked!` else ""
		if #unlocked > 0 then
			task.delay(0.6, function()
				if premiereToken == mine and overlay.Visible then
					-- One pop, not UiKit.pulse: the card is reused, so a looping pulse would pile up.
					unlockScale.Scale = 1.25
					tween(unlockScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
					Sfx.play("notify")
				end
			end)
		end
	end

	local current: any = nil
	tapCatcher.Activated:Connect(function()
		if current ~= nil and overlay.Visible then
			reveal(current, premiereToken)
		end
	end)

	return function(result: any)
		local res = Movies.getResult(result.result)
		if res == nil then
			return
		end
		premiereToken += 1
		local mine = premiereToken
		current = result
		stopEffects()
		tapCatcher:SetAttribute("Revealed", nil)
		overlay.Visible = true
		layout()

		-- The poster: genre colors, the cast, the title and the billing.
		local genre = if type(result.genre) == "string" then result.genre else ""
		local genreColor = UiKit.GENRE_COLORS[genre] or UiKit.BLUE
		poster.BackgroundColor3 = genreColor:Lerp(UiKit.INK, 0.4)
		posterEdge.Color = UiKit.INK
		genreTag.Text = string.upper(genre)
		genreTag.BackgroundColor3 = genreColor
		genreTag.Visible = genre ~= ""
		presents.Text = `A {string.upper(Players.LocalPlayer.DisplayName)} STUDIOS PICTURE`
		titleLabel.Text = if type(result.title) == "string" then result.title else ""
		lengthLabel.Text = PremiereNight.lengthLine(if type(result.length) == "string" then result.length else "")
		local names = {}
		local cast = if type(result.cast) == "table" then result.cast else {}
		local count = math.min(#cast, Config.MaxCast)
		-- Portraits: square and centred, billed in casting order.
		local width = if count >= 3 then 0.3 elseif count == 2 then 0.38 else 0.46
		local gap = 0.035
		local total = count * width + (count - 1) * gap
		for slot = 1, count do
			local key = cast[slot]
			if type(key) == "string" then
				table.insert(names, format.actorLabel(key))
				local tile = UiKit.portrait(castRow, key, UDim2.fromScale(width, 1), UDim2.fromScale((1 - total) / 2 + (slot - 1) * (width + gap), 0.5))
				tile.AnchorPoint = Vector2.new(0, 0.5)
				tile.ZIndex = 15
				for _, child in tile:GetDescendants() do
					if child:IsA("GuiObject") then
						child.ZIndex = 16
					end
				end
				local square = Instance.new("UIAspectRatioConstraint")
				square.Parent = tile
			end
		end
		billingLabel.Text = PremiereNight.billing(names)
		shine.Visible = false
		dim.BackgroundTransparency = 1

		-- Before the result: the poster rises in under calm spotlights, flashes going off.
		stamp.Visible = false
		waitingLabel.Visible = true
		for _, part in resultParts do
			part.Visible = false
		end
		cardEdge.Color = UiKit.FAINT
		sweep(1, BEAM_WARM)
		poster.Position += UDim2.fromOffset(0, 40)
		-- Not kept with the spotlight tweens: the reveal cancels those, and this must always finish.
		tween(poster, 0.45, { Position = poster.Position - UDim2.fromOffset(0, 40) }, Enum.EasingStyle.Back)
		Sfx.play("premiereDrumroll")
		flashes(PremiereNight.DRUMROLL_FLASHES, PremiereNight.DRUMROLL_SECONDS * 0.8, mine)
		task.delay(PremiereNight.DRUMROLL_SECONDS, function()
			reveal(result, mine)
		end)
	end
end

return PremiereReveal
