--!strict
-- The premiere on the red carpet: the camera flies to the Grand Premiere Theatre and the result is
-- staged there (a crowd behind the velvet ropes, the film's cast on the carpet, a marquee that flips
-- over to the result, and weather and fireworks that grow with the result). Only this player sees
-- it: everything is built on this client and removed again. PremiereReveal draws the card on top.
-- How long each beat lasts is PremiereNight.Shows. The camera is PremiereCamera, which always gives
-- the view back; the crowd is the Town Life rig (TownLife.figure).
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ActorModels = require(ReplicatedStorage.Shared.Models.ActorModels)
local Build = require(ReplicatedStorage.Shared.Models.Build)
local MapKit = require(ReplicatedStorage.Shared.Models.MapKit)
local MapModels = require(ReplicatedStorage.Shared.Models.MapModels)
local PremiereNight = require(ReplicatedStorage.Shared.PremiereNight)
local Fx = require(script.Parent.Fx)
local Music = require(script.Parent.Music)
local PremiereCamera = require(script.Parent.PremiereCamera)
local Sfx = require(script.Parent.Sfx)
local TownLife = require(script.Parent.TownLife)

local PremiereShow = {}

export type Hooks = {
	card: () -> (), -- the box office card comes up now
	aborted: () -> (), -- the show ended early (death, respawn, moved away): go straight to the card
}

local FAN_LOOKS = { "FanA", "FanB", "FanC", "FanD" }
local SIGNS = { "FanSign", "FanSignHeart", "FanSignBlank" } -- every third fan holds one
local FANS, PAPARAZZI = 16, 2
local STEP = 1 / 30
local FLASH_EVERY = 0.3
local GOLD = Color3.fromRGB(245, 184, 46)
local GOLDS = { GOLD, Color3.fromRGB(255, 226, 140), Color3.fromRGB(255, 255, 255) }
local PURPLE = Color3.fromRGB(176, 96, 255)
local MOVED_AWAY = 30 -- studs the character may be moved (a Visit teleport) before the show ends
local DRIP = "rbxasset://textures/particles/sparkles_main.dds"

type Person = TownLife.Figure

type Stage = {
	tb: CFrame,
	f: Vector3, -- the theatre's front, down the carpet
	r: Vector3, -- across the carpet
	origin: Vector3, -- the carpet at the foot of the steps
	marquee: Vector3,
	wide: number, -- >1 on a tall screen: shots stand farther back so the marquee fits
}

type Run = {
	result: any,
	res: any,
	hooks: Hooks,
	first: boolean,
	stage: Stage,
	show: PremiereNight.Show,
	props: Folder,
	fans: { Person },
	photogs: { Person },
	cast: { Model },
	castBase: { CFrame },
	mode: string, -- "build" | "hush" | "react"
	mood: string,
	frozenAt: number,
	startedAt: number,
	revealed: boolean,
	leaving: boolean,
	cleaned: boolean,
	fast: boolean,
	far: boolean,
	dist: number,
	board: Model?,
	boardCF: CFrame,
	front: TextLabel?,
	back: TextLabel?,
	tint: ColorCorrectionEffect?,
	palms: { { part: BasePart, cf: CFrame } },
	beat: RBXScriptConnection?,
	homeAt: Vector3?,
	lastMove: number,
}

local random = Random.new()
local lite = false -- sticky for the session: set when the glide ran under 30 FPS
local active: Run? = nil
local starting = false
local token = 0
local rig: { fans: { Person }, photogs: { Person } }? = nil
local palmCache: { { part: BasePart, cf: CFrame } }? = nil
local iris: Frame? = nil

local function noCollide(model: Instance)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
		end
	end
end

local function at(s: Stage, forward: number, lateral: number, up: number): Vector3
	return s.origin + s.f * forward + s.r * lateral + Vector3.yAxis * up
end

-- A camera shot `forward` studs out on the carpet and `up` high, looking at the marquee.
local function shot(s: Stage, forward: number, up: number, drop: number?): CFrame
	local pos = at(s, forward * s.wide, 0, up * (1 + (s.wide - 1) * 0.6))
	return CFrame.lookAt(pos, s.marquee - Vector3.yAxis * (drop or 0))
end

local function animate(r: Run, seconds: number, style: Enum.EasingStyle, dir: Enum.EasingDirection, fn: (number) -> ())
	local start = os.clock()
	task.spawn(function()
		while not r.cleaned do
			local t = math.clamp((os.clock() - start) / seconds, 0, 1)
			fn(TweenService:GetValue(t, style, dir))
			if t >= 1 then
				return
			end
			RunService.Heartbeat:Wait()
		end
	end)
end

local function sleep(r: Run, mine: number, seconds: number): boolean
	local untilT = os.clock() + seconds
	while os.clock() < untilT do
		task.wait()
		if token ~= mine or r.cleaned then
			return false
		end
	end
	return token == mine and not r.cleaned
end

-- The white iris that hides a long cut.
local function irisTo(transparency: number, seconds: number)
	if iris == nil or iris.Parent == nil then
		local gui = Instance.new("ScreenGui")
		gui.Name = "PremiereIris"
		gui.IgnoreGuiInset = true
		gui.DisplayOrder = 25
		gui.ResetOnSpawn = false
		gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		local frame = Instance.new("Frame")
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = Color3.new(1, 1, 1)
		frame.BackgroundTransparency = 1
		frame.BorderSizePixel = 0
		frame.Parent = gui
		iris = frame
	end
	local frame = iris :: Frame
	TweenService:Create(frame, TweenInfo.new(seconds, Enum.EasingStyle.Quad), { BackgroundTransparency = transparency }):Play()
end

-- The crowd -----------------------------------------------------------------------------------------

local function ensureRig(): { fans: { Person }, photogs: { Person } }
	if rig ~= nil then
		return rig
	end
	local name = string.upper(string.sub(Players.LocalPlayer.DisplayName, 1, 14)) .. " STUDIOS"
	local fans, photogs = {}, {}
	for index = 1, FANS do
		local hold = if index % 3 == 1 then SIGNS[(index // 3) % #SIGNS + 1] else nil
		local fan = TownLife.figure(FAN_LOOKS[(index - 1) % #FAN_LOOKS + 1], hold, if hold == "FanSignBlank" then name else nil)
		-- The sign is held upside down by the raised arm (the kit is modelled for that), so the words turn round.
		local words = fan.model:FindFirstChild("Text", true)
		if words ~= nil and words:IsA("TextLabel") then
			words.Rotation = 180
		end
		table.insert(fans, fan)
	end
	for _ = 1, PAPARAZZI do
		table.insert(photogs, TownLife.figure("Photog", "PaparazziCamera"))
	end
	local built = { fans = fans, photogs = photogs }
	rig = built
	return built
end

local function fanPose(person: Person, t: number, r: Run): TownLife.FigurePose
	local d = person.data
	local s = t + person.phase
	local p = TownLife.pose(d.base)
	local sign = person.hold ~= nil
	local keepSign = sign
	if r.mode == "build" then
		p.root = d.base * CFrame.new(0, math.abs(math.sin(s * 5)) * 0.25, 0)
		p.arms = { { 0.2, 2.2 + math.sin(s * 7) * 0.35 }, { 0.2, 2.2 + math.sin(s * 7 + 2) * 0.35 } }
		p.head = math.sin(s * 0.8) * 0.35
	elseif r.mode == "hush" then
		p.nod = -0.12 -- holding their breath, eyes on the marquee
	elseif r.mood == "aww" then
		p.nod = 0.4
		p.head = math.sin(s * 1.6) * 0.5
		keepSign = false
	elseif r.mood == "chant" then
		local clap = math.abs(math.sin(t * 8)) * 0.3 -- all together
		p.root = d.base * CFrame.new(0, math.abs(math.sin(t * 4)) * 0.3, 0)
		p.arms = { { 1.2, -0.35 + clap }, { 1.2, -0.35 + clap } }
	else
		local excite = if r.mood == "wild" then 1 else 0.6
		p.root = d.base * CFrame.new(0, math.abs(math.sin(s * 6)) * 0.6 * excite, 0)
		p.arms = { { 0.2, 2.5 + math.sin(s * 8) * 0.35 }, { 0.2, 2.5 + math.sin(s * 8 + 2) * 0.35 } }
		p.legs = { math.sin(s * 6) * 0.2 * excite, -math.sin(s * 6) * 0.2 * excite }
		p.head = math.sin(s * 0.8) * 0.35
	end
	if keepSign then
		p.arms[2] = { 0, 2.95 + math.sin(s * 3) * 0.12 }
	end
	return p
end

local function photogPose(person: Person, t: number): TownLife.FigurePose
	local s = t + person.phase
	local p = TownLife.pose(person.data.base * CFrame.new(math.sin(s * 0.4) * 0.5, 0, 0))
	if (s % 6) < 2.2 then
		p.root = p.root * CFrame.new(0, -0.35, 0)
		p.legs = { 0.35, -0.2 }
	end
	p.arms = { { 1.4, -0.35 }, { 1.4, -0.35 } }
	p.nod = math.sin(s * 0.9) * 0.05
	return p
end

local parts: { BasePart } = {}
local cframes: { CFrame } = {}

local function beat(r: Run)
	local t = os.clock() - r.startedAt
	if r.mode == "hush" then
		t = r.frozenAt
	end
	table.clear(parts)
	table.clear(cframes)
	for _, fan in r.fans do
		TownLife.collect(fan, fanPose(fan, t, r), parts, cframes)
	end
	local now = os.clock()
	for _, photog in r.photogs do
		TownLife.collect(photog, photogPose(photog, t), parts, cframes)
		local flash = photog.flash
		if flash ~= nil then
			local since = now - photog.flashAt
			flash.Brightness = if since < 0.2 then 9 * (1 - since / 0.2) else 0
		end
	end
	if #parts > 0 then
		Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
	-- The cast jumps for joy after the reveal.
	if r.mode == "react" and r.mood ~= "aww" then
		for index, model in r.cast do
			model:PivotTo(r.castBase[index] * CFrame.new(0, math.abs(math.sin(now * 6 + index)) * 0.5, 0))
		end
	end
	-- Moved away (a Visit teleport): the show is over.
	local character = Players.LocalPlayer.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if r.homeAt ~= nil and root ~= nil and root:IsA("BasePart") and (root.Position - r.homeAt).Magnitude > MOVED_AWAY then
		PremiereShow.abort(true)
	end
end

-- Props ----------------------------------------------------------------------------------------------

local function place(r: Run, name: string, at3: Vector3, scale: number?): Model
	local model = MapKit.place(Build.new(r.props, CFrame.identity), name, CFrame.new(at3) * r.stage.tb.Rotation, { solid = false, scale = scale })
	noCollide(model)
	return model
end

local function letter(label: TextLabel?, text: string, color: Color3)
	if label ~= nil then
		label.Text = text
		label.TextColor3 = color
	end
end

-- The flip board over the marquee: the film's title on the front, the result on the back.
local function buildBoard(r: Run)
	local s = r.stage
	local cf = s.tb * MapKit.spot("PremiereTheatre", "Marquee") * CFrame.new(0, 0, -0.45)
	local ink = Color3.fromRGB(11, 15, 31)
	local model = MapKit.place(Build.new(r.props, CFrame.identity), "MarqueeFlipBoard", cf, {
		solid = false,
		labels = {
			Front = { text = "", color = Color3.new(1, 1, 1), stroke = 3 },
			Back = { text = "", color = r.res.color, stroke = 3 },
		},
	})
	noCollide(model)
	local pivot = model:GetPivot()
	for _, gui in model:GetDescendants() do
		if gui:IsA("TextLabel") and gui.Parent ~= nil and gui.Parent:IsA("SurfaceGui") then
			local board = gui.Parent.Parent :: BasePart
			if pivot:PointToObjectSpace(board.Position).Z < 0 then
				r.front = gui
			else
				r.back = gui
				gui.Rotation = 180 -- it is read after the board has turned over
			end
		end
	end
	r.board, r.boardCF = model, cf
	letter(r.front, string.upper(if type(r.result.title) == "string" then r.result.title else ""), Color3.new(1, 1, 1))
	letter(r.back, PremiereNight.stampText(r.res.id), r.res.color)
	for _, label in { r.front, r.back } do
		local stroke = (label :: TextLabel):FindFirstChildOfClass("UIStroke")
		if stroke ~= nil then
			stroke.Color = ink
		end
	end
end

local function flipBoard(r: Run)
	local board = r.board
	if board == nil then
		return
	end
	Sfx.play("showFlip")
	animate(r, 0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out, function(e)
		board:PivotTo(r.boardCF * CFrame.Angles(math.pi * e, 0, 0))
	end)
end

-- The theatre's palms wilt for a Flop (they stand up again afterwards). Meshed palms only.
local function palms(): { { part: BasePart, cf: CFrame } }
	if palmCache ~= nil then
		return palmCache
	end
	local out = {}
	local tb = MapModels.theatreBase()
	local town = Workspace:FindFirstChild("Town")
	if town ~= nil then
		for _, d in town:GetDescendants() do
			if d.Name == "PalmTree" and d:IsA("MeshPart") and (d.Position - tb.Position).Magnitude < 40 then
				table.insert(out, { part = d, cf = d.CFrame })
			end
		end
	end
	palmCache = out
	return out
end

local function droopPalms(r: Run)
	r.palms = palms()
	for _, palm in r.palms do
		local base = palm.cf.Position - palm.cf.UpVector * (palm.part.Size.Y / 2)
		local goal = CFrame.new(base) * CFrame.Angles(0, 0, math.rad(22)) * CFrame.new(-base) * palm.cf
		animate(r, 2.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, function(e)
			if palm.part.Parent ~= nil then
				palm.part.CFrame = palm.cf:Lerp(goal, e)
			end
		end)
	end
end

local function raining(r: Run)
	local s = r.stage
	local cloud = place(r, "RainCloud", at(s, 9, 0, 17), 2.2)
	local home = cloud:GetPivot()
	animate(r, 0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, function(e)
		cloud:PivotTo(home * CFrame.new(0, 10 * (1 - e), 0))
	end)
	if lite then
		return
	end
	local emitterPart = Instance.new("Part")
	emitterPart.Name = "Rain"
	emitterPart.Anchored = true
	emitterPart.Transparency = 1
	emitterPart.Size = Vector3.new(16, 0.2, 12)
	emitterPart.CFrame = CFrame.new(at(s, 9, 0, 15))
	emitterPart.Parent = r.props
	noCollide(emitterPart)
	local rain = Instance.new("ParticleEmitter")
	rain.Texture = DRIP
	rain.Color = ColorSequence.new(Color3.fromRGB(170, 200, 255))
	rain.Rate = 110
	rain.Lifetime = NumberRange.new(0.5, 0.7)
	rain.Speed = NumberRange.new(30, 38)
	rain.EmissionDirection = Enum.NormalId.Bottom
	rain.SpreadAngle = Vector2.new(3, 3)
	rain.Size = NumberSequence.new(0.35)
	rain.Transparency = NumberSequence.new(0.35)
	rain.LightEmission = 0.2
	rain.Parent = emitterPart
end

local function burst(r: Run, color: Color3)
	local s = r.stage
	Fx.fireworkAt(at(s, random:NextNumber(4, 16), random:NextNumber(-14, 14), random:NextNumber(24, 38)), color)
end

local function bursts(r: Run, count: number, colors: { Color3 }, spread: number)
	local mine = token
	task.spawn(function()
		for i = 1, if lite then math.min(count, 2) else count do
			if token ~= mine or r.cleaned then
				return
			end
			burst(r, colors[(i - 1) % #colors + 1])
			task.wait(spread * random:NextNumber(0.7, 1.3))
		end
	end)
end

local function tintTo(r: Run, color: Color3, saturation: number, brightness: number, seconds: number)
	local tint = r.tint
	if tint ~= nil then
		TweenService:Create(tint, TweenInfo.new(seconds, Enum.EasingStyle.Sine), { TintColor = color, Saturation = saturation, Brightness = brightness }):Play()
	end
end

-- The result lands: the marquee flips and the weather arrives. Runs once.
local function reveal(r: Run)
	if r.revealed then
		return
	end
	r.revealed = true
	r.mode = "react"
	local s, id, show = r.stage, r.res.id, r.show
	r.mood = show.mood
	PremiereCamera.move(shot(s, 19, 11), 45, 0.45, 0, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	Fx.shake(if id == "Masterpiece" or id == "Blockbuster" then 1.4 else 0.8, 0.4)
	flipBoard(r)
	Fx.premiere(id, r.res.color)
	if id == "Flop" then
		Sfx.play("showAww", nil, 3)
		Sfx.play("showRain", nil, 6)
		tintTo(r, Color3.fromRGB(190, 200, 215), -0.5, -0.1, 0.8)
		raining(r)
		droopPalms(r)
	elseif id == "Hit" then
		Sfx.play("showCheer", nil, 4)
	elseif id == "Blockbuster" then
		Sfx.play("showCheerWild", nil, 5)
		Sfx.play("showFireworks", nil, 5)
		bursts(r, 6, { Color3.fromRGB(255, 120, 60), GOLD, Color3.fromRGB(80, 170, 255) }, 0.3)
	elseif id == "Cult" then
		Sfx.play("showCheerWild", 0.9, 5)
		tintTo(r, Color3.fromRGB(210, 150, 255), 0.2, -0.03, 0.8)
		bursts(r, 4, { PURPLE, Color3.fromRGB(255, 120, 220) }, 0.35)
		Fx.confetti(70, { PURPLE, Color3.fromRGB(255, 120, 220), Color3.new(1, 1, 1) })
		local glow = Instance.new("Part")
		glow.Anchored, glow.Transparency, glow.Size = true, 1, Vector3.one
		glow.CFrame = CFrame.new(at(s, 6, 0, 9))
		glow.Parent = r.props
		noCollide(glow)
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness, light.Shadows = PURPLE, 60, 0, false
		light.Parent = glow
		animate(r, 0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, function(e)
			light.Brightness = 5 * e
		end)
	else
		Sfx.play("showCheerWild", nil, 6)
		Sfx.play("showFireworks", nil, 6)
		tintTo(r, Color3.fromRGB(255, 232, 170), 0.25, 0.03, 0.8)
		Fx.skyFlash(GOLD, 0.3)
		local trophy = place(r, "GrandTrophy", at(s, 7, 0, -9), 2)
		local home = trophy:GetPivot()
		animate(r, 1.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, function(e)
			trophy:PivotTo(home * CFrame.new(0, 9 * e, 0))
		end)
		bursts(r, 10, GOLDS, 0.2)
		if r.first then
			Fx.confetti(120, GOLDS, true) -- golden tickets
		end
	end
end

-- The timeline ----------------------------------------------------------------------------------------

local function flashLoop(r: Run, mine: number, seconds: number)
	task.spawn(function()
		local untilT = os.clock() + seconds
		local count = 0
		while os.clock() < untilT and token == mine and not r.cleaned do
			for _, photog in r.photogs do
				photog.flashAt = os.clock() - random:NextNumber(0, 0.05)
			end
			count += 1
			if count % 2 == 1 then
				Sfx.play("premiereFlash", random:NextNumber(0.9, 1.2))
			end
			task.wait(FLASH_EVERY)
		end
	end)
end

local function applyLite(r: Run)
	for index, fan in r.fans do
		if (index - 1) // 2 % 2 == 1 then
			fan.model.Parent = nil
		end
	end
end

local function timeline(r: Run, mine: number, jump: boolean)
	local s, show = r.stage, r.show
	if not jump then
		-- Glide (or cut) to the establishing shot.
		local est = shot(s, 34, 20)
		local glide = PremiereNight.glideSeconds(r.dist)
		if glide == nil then
			irisTo(0, 0.25)
			if not sleep(r, mine, 0.3) then
				return
			end
			PremiereCamera.cut(est, 60)
			irisTo(1, 0.25)
			glide = 0.3
		else
			PremiereCamera.move(est, 60, glide, 22)
			Sfx.play("showGlide")
			-- Under 30 FPS on the way: thin the crowd and the weather for the rest of the session.
			local frames, start = 0, os.clock()
			local over = start + glide
			while os.clock() < over do
				task.wait()
				if token ~= mine or r.cleaned then
					return
				end
				frames += 1
			end
			if not lite and frames / math.max(os.clock() - start, 0.1) < 30 then
				lite = true
				applyLite(r)
			end
		end
		if token ~= mine or r.cleaned then
			return
		end
		-- The build-up: the camera dollies up the carpet while the flashes pop and the drumroll rolls.
		r.mode = "build"
		r.startedAt = os.clock()
		Music.duck(show.build + show.hush + 4)
		Sfx.play("showDrumroll", nil, show.build)
		Sfx.play("lucienPremiere")
		PremiereCamera.move(shot(s, 11, 5.5, 2.5), 55, show.build, 0, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		flashLoop(r, mine, show.build)
		if r.result.awardNight then
			task.delay(show.build * 0.5, function()
				if token == mine and not r.cleaned and r.front ~= nil then
					letter(r.front, "AWARD NIGHT x2", GOLD)
					task.delay(0.7, function()
						if not r.cleaned and not r.revealed then
							letter(r.front, string.upper(if type(r.result.title) == "string" then r.result.title else ""), Color3.new(1, 1, 1))
						end
					end)
				end
			end)
		end
		if not sleep(r, mine, show.build) then
			return
		end
		if show.hush > 0 then
			r.mode, r.frozenAt = "hush", os.clock() - r.startedAt
			Sfx.play("showHeartbeat", nil, show.hush)
			PremiereCamera.move(shot(s, 10, 5, 2.5), 52, show.hush, 0, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			if not sleep(r, mine, show.hush) then
				return
			end
		end
	end
	reveal(r)
	if not sleep(r, mine, 0.6 + (if r.fast then 0.3 else show.celebrate)) then
		return
	end
	r.hooks.card()
	-- Behind the card the camera drifts slowly round the marquee.
	PremiereCamera.move(shot(s, 22, 13), 45, 8, 0, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
end

-- Public ------------------------------------------------------------------------------------------------

function PremiereShow.active(): boolean
	return active ~= nil or starting
end

local function cleanup(r: Run)
	if r.cleaned then
		return
	end
	r.cleaned = true
	token += 1
	if r.beat ~= nil then
		r.beat:Disconnect()
	end
	for _, fan in r.fans do
		fan.model.Parent = nil
	end
	for _, photog in r.photogs do
		photog.model.Parent = nil
	end
	r.props:Destroy()
	for _, model in r.cast do
		model:Destroy()
	end
	for _, palm in r.palms do
		if palm.part.Parent ~= nil then
			palm.part.CFrame = palm.cf
		end
	end
	local tint = r.tint
	if tint ~= nil then
		local fade = TweenService:Create(tint, TweenInfo.new(0.4), { TintColor = Color3.new(1, 1, 1), Saturation = 0, Brightness = 0, Contrast = 0 })
		fade:Play()
		task.delay(0.5, function()
			tint:Destroy()
		end)
	end
	if active == r then
		active = nil
	end
	PremiereCamera.restore()
end

-- Starts the show. Yields while the theatre streams in. False means there is nothing to show
-- (the theatre has not loaded, no camera): the caller shows the card alone. `first` is a first
-- Masterpiece (golden-ticket confetti).
local function start(result: any, res: any, first: boolean, hooks: Hooks): boolean
	if active ~= nil or starting then
		return false
	end
	starting = true
	local tb = MapModels.theatreBase()
	-- Ask the server to stream the theatre in (no waiting when it is already there), then give it up
	-- to two seconds to arrive.
	task.spawn(pcall, function()
		Players.LocalPlayer:RequestStreamAroundAsync(tb.Position, 2)
	end)
	local town = Workspace:FindFirstChild("Town")
	local waited = 0
	while waited < 2 and (town == nil or town:FindFirstChild("PremiereTheatre", true) == nil) do
		task.wait(0.1)
		waited += 0.1
		town = Workspace:FindFirstChild("Town")
	end
	if town == nil or town:FindFirstChild("PremiereTheatre", true) == nil or not PremiereCamera.begin() then
		starting = false
		return false
	end
	local f = tb.LookVector
	local floorY = 0.26
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character ~= nil then
			table.insert(exclude, player.Character)
		end
	end
	params.FilterDescendantsInstances = exclude
	local hit = Workspace:Raycast(tb.Position + f * 10 + Vector3.yAxis * 40, Vector3.new(0, -80, 0), params)
	if hit ~= nil then
		floorY = hit.Position.Y
	end
	local viewport = (Workspace.CurrentCamera :: Camera).ViewportSize
	local stage: Stage = {
		tb = tb,
		f = f,
		r = f:Cross(Vector3.yAxis),
		origin = Vector3.new(tb.Position.X, floorY, tb.Position.Z) + f * 3,
		marquee = (tb * MapKit.spot("PremiereTheatre", "Marquee")).Position,
		wide = math.clamp(1.6 / math.max(viewport.X / math.max(viewport.Y, 1), 0.3), 1, 3),
	}
	local crowd = ensureRig()
	local folder = Instance.new("Folder")
	folder.Name = "PremiereShow"
	folder.Parent = Workspace
	local character = Players.LocalPlayer.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	local camera = PremiereCamera.pose()
	local run: Run = {
		result = result,
		res = res,
		hooks = hooks,
		first = first,
		stage = stage,
		show = PremiereNight.show(res.id),
		props = folder,
		fans = crowd.fans,
		photogs = crowd.photogs,
		cast = {},
		castBase = {},
		mode = "build",
		mood = "cheer",
		frozenAt = 0,
		startedAt = os.clock(),
		revealed = false,
		leaving = false,
		cleaned = false,
		fast = false,
		far = false,
		dist = (camera.Position - at(stage, 34, 0, 20)).Magnitude,
		board = nil,
		boardCF = CFrame.identity,
		front = nil,
		back = nil,
		tint = nil,
		palms = {},
		beat = nil,
		homeAt = if root ~= nil and root:IsA("BasePart") then root.Position else nil,
		lastMove = 0,
	}
	run.far = PremiereNight.glideSeconds(run.dist) == nil
	active = run
	starting = false
	token += 1
	local mine = token

	-- The crowd behind the ropes: two rows a side, facing the carpet; two photographers up front.
	for index, fan in run.fans do
		local side = if index % 2 == 1 then -1 else 1
		local row = (index - 1) // 2 % 2
		local col = (index - 1) // 4
		local pos = at(stage, 8 + col * 2.6, side * (6.2 + row * 1.9), 0)
		fan.data.base = CFrame.lookAt(pos, pos - stage.r * side)
		fan.model.Parent = if lite and row == 1 then nil else folder
	end
	for index, photog in run.photogs do
		local pos = at(stage, 17, (if index == 1 then -1 else 1) * 5.4, 0)
		photog.data.base = CFrame.lookAt(pos, at(stage, 9, 0, 0))
		photog.flashAt = -math.huge
		photog.model.Parent = folder
	end
	-- The film's cast on the carpet, facing the camera.
	local cast = if type(result.cast) == "table" then result.cast else {}
	local count = math.min(#cast, 3)
	for slot = 1, count do
		local key = cast[slot]
		if type(key) == "string" then
			local parts3 = string.split(key, ":")
			local pos = at(stage, 10, (slot - (count + 1) / 2) * 3.6, 0)
			local base = CFrame.lookAt(pos, pos + stage.f)
			local model = ActorModels.build(folder, base, parts3[1] or "", parts3[2])
			noCollide(model)
			table.insert(run.cast, model)
			table.insert(run.castBase, base)
		end
	end
	buildBoard(run)
	if res.id == "Blockbuster" then
		for _, side in { -1, 1 } do
			place(run, "FireworkMortar", at(stage, 5, side * 3.9, 0), 1.3)
		end
	end
	-- Dusk, for this player only.
	local tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "PremiereTint"
	tint.Parent = Lighting
	run.tint = tint
	tintTo(run, Color3.fromRGB(215, 205, 250), 0.05, -0.05, 0.8)

	run.beat = RunService.Heartbeat:Connect(function()
		if os.clock() - run.lastMove >= STEP then
			run.lastMove = os.clock()
			beat(run)
		end
	end)
	-- The camera was handed back from outside (death, respawn): finish the show.
	local watch
	watch = PremiereCamera.restored:Connect(function()
		watch:Disconnect()
		if not run.cleaned then
			cleanup(run)
			hooks.aborted()
		end
	end)
	task.spawn(timeline, run, mine, false)
	return true
end

function PremiereShow.play(result: any, res: any, first: boolean, hooks: Hooks): boolean
	local ok, started = pcall(start, result, res, first, hooks)
	if ok then
		return started
	end
	warn(`[PremiereShow] {started}`)
	starting = false
	if active ~= nil then
		cleanup(active)
	else
		PremiereCamera.restore()
	end
	return false
end

-- First tap: jump to the result. False when it is already revealed or leaving.
function PremiereShow.skip(): boolean
	local r = active
	if r == nil or r.revealed or r.leaving then
		return false
	end
	token += 1
	r.fast = true
	task.spawn(timeline, r, token, true)
	return true
end

-- Glides home, then clears the stage and gives the camera back. `done` runs after.
function PremiereShow.finish(done: (() -> ())?)
	local r = active
	if r == nil then
		PremiereCamera.restore()
		if done ~= nil then
			done()
		end
		return
	end
	r.leaving = true
	token += 1
	local mine = token
	task.spawn(function()
		local home = PremiereCamera.home()
		if home ~= nil and not r.cleaned then
			if (PremiereCamera.pose().Position - home.Position).Magnitude > PremiereNight.FAR then
				irisTo(0, 0.25)
				sleep(r, mine, 0.3)
				PremiereCamera.cut(home, PremiereCamera.homeFov())
				irisTo(1, 0.25)
			else
				PremiereCamera.move(home, PremiereCamera.homeFov(), PremiereNight.RETURN_SECONDS)
				sleep(r, mine, PremiereNight.RETURN_SECONDS)
			end
		end
		cleanup(r)
		if done ~= nil then
			done()
		end
	end)
end

-- Ends everything right now (the character was moved, the game is closing the screen).
function PremiereShow.abort(callHook: boolean?)
	local r = active
	if r == nil then
		PremiereCamera.restore()
		return
	end
	cleanup(r)
	if callHook then
		r.hooks.aborted()
	end
end

return PremiereShow
