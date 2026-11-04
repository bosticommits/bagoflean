--!strict
-- The intro new producers see once (and anyone from Settings > Replay intro), on the Lucien stage
-- (StageScene), following the Figma storyboard (frames 5:74, 5:121, 8:74, 5:166, 5:229):
--
--   1. The curtains are closed, "HOLLYWOOD RNG" pressed faintly into the velvet.
--   2. They part a little; the spotlights sweep in and cross, a fanfare plays and the logo is
--      revealed: the starburst spins, the marquee board slams down with its bulbs chasing, the
--      HOLLYWOOD letters pop up one at a time, the R-N-G dice tumble in and land with a flash and
--      confetti, and a shine sweeps across.
--   3. The logo rises into the title, the curtains open to their tiebacks, and Lucien walks in
--      and waves.
--   4. He talks (voiced), with gestures and a cane twirl; "Let's begin!" ends it.
--
-- Skip skips the current beat: the logo, then each line. With reduced motion everything is shown
-- in place without sweeps, spins or tumbles.
local Fx = require(script.Parent.Fx)
local Music = require(script.Parent.Music)
local Sfx = require(script.Parent.Sfx)
local StageScene = require(script.Parent.StageScene)
local UiKit = require(script.Parent.UiKit)

local tween = StageScene.tween

-- Image textures made from the Figma art (art/blender/intro_textures.py, art/ui/intro/).
local ART = {
	starburst = 0,
	sparkle = 0,
}

-- Lucien's lines, short and warm (his voice lines are the Sounds slots named here).
local LINES: { StageScene.Line } = {
	{ text = "Ah, there you are! Welcome to Hollywood, my friend!", voice = "introLucien1", gesture = "wave" },
	{ text = "I'm Director Lucien Vale! Fifty years in film, and I still love a fresh face!", voice = "introLucien2", gesture = "twirl" },
	{ text = "This studio is yours now. Let's make your very first picture!", voice = "introLucien3" },
}

local GOLD = Color3.fromRGB(245, 184, 46)
local MARQUEE = Color3.fromRGB(142, 27, 46)
local BULB_ON = Color3.fromRGB(255, 243, 176)
local BULB_OFF = Color3.fromRGB(201, 138, 30)
local LETTER_TOP = Color3.fromRGB(255, 236, 128)
local LETTER_BOTTOM = Color3.fromRGB(245, 166, 35)
local LETTER_STROKE = Color3.fromRGB(90, 42, 0)
local DIE_STROKE = Color3.fromRGB(20, 26, 48)

-- The marquee's letters (Figma 8:145-8:207): x and width inside the 640 x 190 board.
local LETTERS = {
	{ char = "H", x = 40, w = 68 },
	{ char = "O", x = 106, w = 75 },
	{ char = "L", x = 179, w = 57 },
	{ char = "L", x = 234, w = 57 },
	{ char = "Y", x = 289, w = 66 },
	{ char = "W", x = 353, w = 96 },
	{ char = "O", x = 447, w = 75 },
	{ char = "O", x = 520, w = 75 },
	{ char = "D", x = 593, w = 68 },
}
-- The dice (Figma 8:209-8:226) in the 760 x 380 logo: letter, color, x, size, landing tilt.
local DICE = {
	{ char = "R", ink = Color3.fromRGB(46, 134, 222), pip = Color3.fromRGB(180, 214, 245), x = 200, size = 123, tilt = -12 },
	{ char = "N", ink = Color3.fromRGB(200, 32, 47), pip = Color3.fromRGB(235, 175, 185), x = 326, size = 111, tilt = -4 },
	{ char = "G", ink = Color3.fromRGB(91, 191, 90), pip = Color3.fromRGB(190, 230, 190), x = 452, size = 126, tilt = 12 },
}
-- Sparkles (Figma 8:227-8:231): x, y, size in the logo.
local SPARKLES = { { 40, 40, 46 }, { 690, 30, 38 }, { 720, 250, 30 }, { 20, 280, 34 }, { 380, 10, 26 } }

local IntroScene = {}

local playing = false

local function px(x: number, y: number, w: number, h: number, parentW: number, parentH: number): (UDim2, UDim2)
	return UDim2.fromScale(x / parentW, y / parentH), UDim2.fromScale(w / parentW, h / parentH)
end

local function roundFrame(parent: Instance, name: string, color: Color3, z: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color
	f.ZIndex = z
	f.Parent = parent
	UiKit.corner(f, 999)
	return f
end

type Logo = {
	holder: Frame,
	burst: GuiObject?,
	board: Frame,
	bulbs: { Frame },
	letters: { TextLabel },
	dice: { Frame },
	sparkles: { GuiObject },
	shine: Frame,
}

-- Builds the logo (Figma 8:74, 760 x 380) hidden, in the stage's content layer.
local function buildLogo(parent: Frame): Logo
	local holder = Instance.new("Frame")
	holder.Name = "Logo"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.44)
	holder.Size = UDim2.fromScale(0.62, 0.53)
	holder.ZIndex = 4
	holder.Parent = parent
	local shape = Instance.new("UIAspectRatioConstraint")
	shape.AspectRatio = 2
	shape.Parent = holder

	local burst: GuiObject? = nil
	if ART.starburst ~= 0 then
		local image = Instance.new("ImageLabel")
		image.Name = "Starburst"
		image.BackgroundTransparency = 1
		image.Image = "rbxassetid://" .. ART.starburst
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.Position = UDim2.fromScale(0.5, 0.5)
		image.Size = UDim2.fromScale(1040 / 760, 1040 / 380)
		image.ImageTransparency = 1
		image.ZIndex = 4
		image.Parent = holder
		burst = image
	end

	local board = Instance.new("Frame")
	board.Name = "Marquee"
	board.BackgroundColor3 = MARQUEE
	board.BorderSizePixel = 0
	board.Position, board.Size = px(60, 70, 640, 190, 760, 380)
	board.Visible = false
	board.ZIndex = 5
	board.Parent = holder
	UiKit.corner(board, 18)
	UiKit.border(board, 5, GOLD)
	local shade = Instance.new("UIGradient")
	shade.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(160, 150, 150))
	shade.Rotation = 90
	shade.Parent = board

	-- Bulbs round the edge (Figma: 44, 16 px, every ~38 px).
	local bulbs: { Frame } = {}
	local function bulb(x: number, y: number)
		local b = roundFrame(board, "Bulb", BULB_OFF, 7)
		b.AnchorPoint = Vector2.new(0.5, 0.5)
		b.Position = UDim2.fromScale(x / 640, y / 190)
		b.Size = UDim2.fromScale(16 / 640, 16 / 190)
		table.insert(bulbs, b)
	end
	for i = 0, 16 do
		bulb(i * 37.7, 0)
	end
	for i = 0, 4 do
		bulb(640, 38 * i + 1)
	end
	for i = 0, 16 do
		bulb(640 - i * 37.7, 190)
	end
	for i = 0, 4 do
		bulb(0, 190 - 38 * i - 1)
	end

	local letters: { TextLabel } = {}
	for _, spec in LETTERS do
		local letter = Instance.new("TextLabel")
		letter.Name = "Letter" .. spec.char
		letter.BackgroundTransparency = 1
		letter.AnchorPoint = Vector2.new(0.5, 1)
		local pos, size = px(spec.x, 24, spec.w, 116, 640, 190)
		letter.Position = pos + UDim2.fromScale(size.X.Scale / 2, size.Y.Scale)
		letter.Size = size
		letter.Font = UiKit.DISPLAY_FONT
		letter.TextScaled = true
		letter.Text = spec.char
		letter.TextColor3 = Color3.new(1, 1, 1)
		letter.ZIndex = 6
		letter.Parent = board
		local fill = Instance.new("UIGradient")
		fill.Color = ColorSequence.new(LETTER_TOP, LETTER_BOTTOM)
		fill.Rotation = 90
		fill.Parent = letter
		local stroke = UiKit.outline(letter, 4)
		stroke.Color = LETTER_STROKE
		local pop = Instance.new("UIScale")
		pop.Scale = 0
		pop.Parent = letter
		table.insert(letters, letter)
	end

	-- The shine: a soft white band that sweeps across the board.
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.BorderSizePixel = 0
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.BackgroundTransparency = 0.7
	shine.AnchorPoint = Vector2.new(0.5, 0.5)
	shine.Position = UDim2.fromScale(-0.2, 0.5)
	shine.Size = UDim2.fromScale(0.12, 1.6)
	shine.Rotation = 20
	shine.Visible = false
	shine.ZIndex = 8
	shine.Parent = board
	local soft = Instance.new("UIGradient")
	soft.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	soft.Parent = shine

	local dice: { Frame } = {}
	for _, spec in DICE do
		local die = Instance.new("Frame")
		die.Name = "Die" .. spec.char
		die.BackgroundColor3 = Color3.new(1, 1, 1)
		die.BorderSizePixel = 0
		die.AnchorPoint = Vector2.new(0.5, 0.5)
		local size = spec.size
		die.Position = UDim2.fromScale((spec.x + size / 2) / 760, (228 + size / 2) / 380)
		die.Size = UDim2.fromScale(size / 760, size / 380)
		die.Rotation = spec.tilt
		die.Visible = false
		die.ZIndex = 9
		die.Parent = holder
		UiKit.corner(die, 22)
		UiKit.border(die, 5, DIE_STROKE)
		local glyph = Instance.new("TextLabel")
		glyph.BackgroundTransparency = 1
		glyph.Size = UDim2.fromScale(0.8, 0.8)
		glyph.AnchorPoint = Vector2.new(0.5, 0.5)
		glyph.Position = UDim2.fromScale(0.5, 0.52)
		glyph.Font = UiKit.DISPLAY_FONT
		glyph.TextScaled = true
		glyph.Text = spec.char
		glyph.TextColor3 = spec.ink
		glyph.ZIndex = 10
		glyph.Parent = die
		for _, corner in { { 0.18, 0.18 }, { 0.82, 0.18 }, { 0.18, 0.82 }, { 0.82, 0.82 } } do
			local pip = roundFrame(die, "Pip", spec.pip, 10)
			pip.AnchorPoint = Vector2.new(0.5, 0.5)
			pip.Position = UDim2.fromScale(corner[1], corner[2])
			pip.Size = UDim2.fromScale(0.12, 0.12)
		end
		table.insert(dice, die)
	end

	local sparkles: { GuiObject } = {}
	for _, spec in SPARKLES do
		local sparkle: GuiObject
		if ART.sparkle ~= 0 then
			local image = Instance.new("ImageLabel")
			image.BackgroundTransparency = 1
			image.Image = "rbxassetid://" .. ART.sparkle
			sparkle = image
		else
			-- A four-point star from two thin crossed bars.
			local f = Instance.new("Frame")
			f.BackgroundTransparency = 1
			for _, rotation in { 0, 90 } do
				local bar = roundFrame(f, "Ray", Color3.fromRGB(255, 246, 216), 9)
				bar.AnchorPoint = Vector2.new(0.5, 0.5)
				bar.Position = UDim2.fromScale(0.5, 0.5)
				bar.Size = UDim2.fromScale(0.18, 1)
				bar.Rotation = rotation
			end
			sparkle = f
		end
		sparkle.Name = "Sparkle"
		sparkle.AnchorPoint = Vector2.new(0.5, 0.5)
		sparkle.Position = UDim2.fromScale((spec[1] + spec[3] / 2) / 760, (spec[2] + spec[3] / 2) / 380)
		sparkle.Size = UDim2.fromScale(spec[3] / 760, spec[3] / 380)
		sparkle.Visible = false
		sparkle.ZIndex = 9
		sparkle.Parent = holder
		table.insert(sparkles, sparkle)
	end

	return { holder = holder, burst = burst, board = board, bulbs = bulbs, letters = letters, dice = dice, sparkles = sparkles, shine = shine }
end

-- Plays the logo reveal. `alive()` turns false when Skip is pressed or the scene closes, and
-- the reveal jumps to its end state.
local function revealLogo(logo: Logo, still: boolean, alive: () -> boolean)
	local function wait(seconds: number)
		local untilAt = os.clock() + seconds
		while alive() and os.clock() < untilAt do
			task.wait()
		end
	end
	local chasing = true
	local burst = logo.burst
	if burst ~= nil and burst:IsA("ImageLabel") then
		tween(burst, 0.6, { ImageTransparency = 0 })
	end
	-- The starburst spins and the bulbs chase for as long as the logo shows.
	task.spawn(function()
		local step = 0
		while chasing and logo.holder.Parent ~= nil do
			step += 1
			for i, b in logo.bulbs do
				b.BackgroundColor3 = if still or (i + step) % 3 == 0 then BULB_ON else BULB_OFF
			end
			if burst ~= nil and not still then
				burst.Rotation += 1.2
			end
			for i, sparkle in logo.sparkles do
				local scale = sparkle:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
				scale.Scale = if still then 1 else 0.75 + 0.25 * math.sin(os.clock() * 4 + i * 1.7)
				scale.Parent = sparkle
			end
			task.wait(0.12)
		end
	end)

	-- The marquee slams down.
	wait(0.25)
	logo.board.Visible = true
	if not still and alive() then
		local final = logo.board.Position
		logo.board.Position = final - UDim2.fromScale(0, 1.2)
		tween(logo.board, 0.35, { Position = final }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		wait(0.3)
	end
	Sfx.play("introSlam")
	if not still then
		Fx.shake(0.25, 0.25)
	end
	for _, sparkle in logo.sparkles do
		sparkle.Visible = true
	end

	-- HOLLYWOOD, one letter at a time.
	for _, letter in logo.letters do
		local pop = letter:FindFirstChildOfClass("UIScale") :: UIScale
		if still or not alive() then
			pop.Scale = 1
		else
			tween(pop, 0.28, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			Sfx.play("introDice", 1.4)
			wait(0.07)
		end
	end
	wait(0.25)

	-- The dice tumble in from above and land, one after another.
	for i, die in logo.dice do
		die.Visible = true
		if not still and alive() then
			local final, rotation = die.Position, die.Rotation
			die.Position = final - UDim2.fromScale(0, 1.4)
			die.Rotation = rotation - 400
			tween(die, 0.5, { Position = final }, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)
			tween(die, 0.45, { Rotation = rotation }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			task.delay(0.3, function()
				Sfx.play("introDice", 0.9 + i * 0.1)
			end)
			wait(0.16)
		end
	end
	wait(0.4)
	Fx.flash(Color3.new(1, 1, 1), if still then 0.15 else 0.45)
	if not still then
		Fx.confetti(45, { GOLD, Color3.fromRGB(244, 231, 207), Color3.fromRGB(46, 134, 222), Color3.fromRGB(200, 32, 47) })
	end

	-- A shine sweeps across the board.
	if not still and alive() then
		logo.shine.Visible = true
		tween(logo.shine, 0.7, { Position = UDim2.fromScale(1.2, 0.5) }, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	end
	wait(1.2)
	chasing = false
end

-- Plays the whole intro and returns when it ends. Does nothing if it is already playing.
function IntroScene.play()
	if playing then
		return
	end
	playing = true
	local scene = StageScene.new()
	local ok, err = pcall(function()
		local still = StageScene.reducedMotion()
		-- The title pressed into the closed curtains (Figma 5:74).
		local emboss = Instance.new("TextLabel")
		emboss.Name = "Emboss"
		emboss.BackgroundTransparency = 1
		emboss.AnchorPoint = Vector2.new(0.5, 0.5)
		emboss.Position = UDim2.fromScale(0.5, 0.49)
		emboss.Size = UDim2.fromScale(0.3, 0.06)
		emboss.Font = UiKit.DISPLAY_FONT
		emboss.TextScaled = true
		emboss.Text = "HOLLYWOOD RNG"
		emboss.TextColor3 = Color3.fromRGB(214, 90, 60)
		emboss.TextTransparency = 0.25
		emboss.ZIndex = 12
		emboss.Parent = scene.art:FindFirstChild("Stage")
		local embossStroke = UiKit.outline(emboss, 3)
		embossStroke.Color = Color3.fromRGB(90, 10, 24)
		embossStroke.Transparency = 0.4

		local skipped = false
		scene:onSkip(function()
			skipped = true
		end)
		local function alive(): boolean
			return scene:isOpen() and not skipped
		end
		local function wait(seconds: number)
			local untilAt = os.clock() + seconds
			while alive() and os.clock() < untilAt do
				task.wait()
			end
		end

		-- 1-2: the curtains part on the logo.
		wait(0.7)
		Music.duck(6)
		Sfx.play("introFanfare")
		tween(emboss, 0.3, { TextTransparency = 1 })
		tween(embossStroke, 0.3, { Transparency = 1 })
		scene:curtains("peek")
		scene:spotlights()
		local logo = buildLogo(scene.content)
		revealLogo(logo, still or not alive(), alive)
		emboss:Destroy()

		-- 3: the logo rises into the title, the curtains open, Lucien walks in and waves.
		scene:onSkip(nil)
		if not scene:isOpen() then
			return nil
		end
		if not still then
			tween(logo.holder, 0.45, { Position = UDim2.fromScale(0.5, 0.12), Size = UDim2.fromScale(0.25, 0.1) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end
		task.delay(if still then 0 else 0.4, function()
			logo.holder:Destroy()
			scene:title("HOLLYWOOD RNG")
		end)
		scene:curtains("open")
		scene:enter(true)

		-- 4: he talks.
		scene:say(LINES, "Let's begin!")
		return nil
	end)
	scene:close()
	playing = false
	if not ok then
		warn(`[IntroScene] {err}`)
	end
end

function IntroScene.isPlaying(): boolean
	return playing
end

return IntroScene
