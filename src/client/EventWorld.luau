--!strict
-- What the special events (Shared/SpecialEvents) look like in the world, on this client:
--   Lucky Star     a giant gold star crashes into the plaza, then hovers over the fountain
--   Cash Rain      money falls from the sky and gold coins land round town, each under a beam
--   Mystery Crate  a crate parachutes onto the boulevard under a purple beam, and opens for you
--   Spotlight      a pillar of light and sweeping searchlights on one player's studio
--   Golden Hour    the sun drops to a warm sunset and gold dust floats in the air
-- Everything here is presentation. Pickups are only asked for (the `claim` function given to
-- start); the server checks and pays (SpecialEventService). Props live in
-- workspace.SpecialEventFx and Lighting effects named "SpecialEvent...", and fade away when the
-- event ends. A player who joins mid-event sees it as it is, without the entrance.
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local EventModels = require(ReplicatedStorage.Shared.Models.EventModels)
local LotModels = require(ReplicatedStorage.Shared.Models.LotModels)
local MapModels = require(ReplicatedStorage.Shared.Models.MapModels)
local SpecialEvents = require(ReplicatedStorage.Shared.SpecialEvents)
local Fx = require(script.Parent.Fx)
local Sfx = require(script.Parent.Sfx)
local UiKit = require(script.Parent.UiKit)

export type Live = {
	event: SpecialEvents.Event,
	starts: number,
	ends: number,
	key: string, -- "<id>:<starts>"
	lot: number?, -- Spotlight: the studio in the light
	owner: string?, -- and its owner's display name
	ownerId: number?,
}

type Follower = { part: BasePart, above: number }

type Run = {
	live: Live,
	folder: Folder,
	endedAt: number?, -- os.clock() when the event ended; the run fades out for FADE seconds
	step: (now: number, dt: number) -> (), -- every frame; `now` is the server's clock
	onEnd: () -> (), -- the event just ended: start the exit
	onResult: (kind: string, index: number, ok: boolean, reason: string) -> (),
	status: () -> string?, -- a live line for the banner (coins grabbed, crate landing...)
	cleanup: { () -> () },
	followers: { Follower },
}

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SQUARE = "rbxasset://textures/particles/SquareParticle.png"
local GOLD = Color3.fromRGB(255, 210, 63)
local PALE_GOLD = Color3.fromRGB(255, 240, 170)
local PURPLE = Color3.fromRGB(170, 90, 255)
local BILL_GREEN = Color3.fromRGB(110, 205, 110)
local FADE = 1.6 -- seconds the props take to leave after an event ends

-- Lucky Star: it hovers over the fountain, high enough to see from anywhere in town.
local STAR_HOVER = 40
local STAR_HEIGHT = 24
local STAR_IMPACT = 16 -- its centre at the bottom of the bounce
local STAR_DROP = 320
local STAR_FALL = 1.3
local STAR_RISE = 1.2

local COIN_SIZE = 3.2
local COIN_DROP = 1.1
local CRATE_DROP = 150
local GOLDEN_CLOCK = 17.5 -- Lighting.ClockTime at the height of Golden Hour

local EventWorld = {}

local player = Players.LocalPlayer
local random = Random.new()
local runs: { Run } = {}
local current: Run? = nil
local sendClaim: (kind: string, index: number) -> () = function() end
local normalClock: number? = nil -- the place's own time of day, restored after Golden Hour

-- Helpers -------------------------------------------------------------------------------------

local function rootPosition(): Vector3?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root.Position else nil
end

-- The top of whatever the ground is at (x, z): grass, road, plaza paving.
local function groundAt(x: number, z: number, folder: Instance): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { folder }
	for _, other in Players:GetPlayers() do
		if other.Character ~= nil then
			table.insert(ignore, other.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	local hit = workspace:Raycast(Vector3.new(x, 6, z), Vector3.new(0, -14, 0), params)
	return if hit ~= nil then hit.Position.Y else 0
end

-- An invisible anchor for lights, particles and labels.
local function anchor(parent: Instance, at: Vector3, size: Vector3?): Part
	local part = Instance.new("Part")
	part.Name = "EventAnchor"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = size or Vector3.new(1, 1, 1)
	part.Position = at
	part.Parent = parent
	return part
end

local function colorSequence(colors: { Color3 }): ColorSequence
	if #colors < 2 then
		return ColorSequence.new(colors[1])
	end
	local keypoints = {}
	for index, color in colors do
		table.insert(keypoints, ColorSequenceKeypoint.new((index - 1) / (#colors - 1), color))
	end
	return ColorSequence.new(keypoints)
end

local function emitter(parent: Instance, texture: string, colors: { Color3 }, size: number, rate: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = texture
	e.Color = colorSequence(colors)
	e.Size = NumberSequence.new(size)
	e.Rate = rate
	e.LightEmission = 0.4
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-180, 180)
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.8, 0), NumberSequenceKeypoint.new(1, 1) })
	e.Parent = parent
	return e
end

-- A one-off burst of sparkles (and paper confetti when `confetti`) at `at`.
local function burst(parent: Instance, at: Vector3, colors: { Color3 }, count: number, confetti: boolean?)
	local holder = anchor(parent, at)
	local sparkles = emitter(holder, SPARKLE, colors, 1.6, 0)
	sparkles.LightEmission = 1
	sparkles.Speed = NumberRange.new(8, 22)
	sparkles.Lifetime = NumberRange.new(0.6, 1.2)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Drag = 2
	sparkles:Emit(count)
	if confetti then
		local paper = emitter(holder, SQUARE, { GOLD, Color3.fromRGB(200, 32, 47), Color3.fromRGB(46, 134, 222), Color3.fromRGB(91, 191, 90), PURPLE }, 0.5, 0)
		paper.Speed = NumberRange.new(20, 34)
		paper.Lifetime = NumberRange.new(2, 3)
		paper.SpreadAngle = Vector2.new(50, 50)
		paper.EmissionDirection = Enum.NormalId.Top
		paper.Acceleration = Vector3.new(0, -24, 0)
		paper.Drag = 1.2
		paper:Emit(count * 2)
	end
	Debris:AddItem(holder, 4)
end

-- Fades every part (and decal or label) under `root` out over `seconds`.
local function fadeOut(root: Instance, seconds: number)
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	for _, item in root:GetDescendants() do
		if item:IsA("BasePart") then
			TweenService:Create(item, info, { Transparency = 1 }):Play()
		elseif item:IsA("TextLabel") then
			TweenService:Create(item, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		elseif item:IsA("UIStroke") then
			TweenService:Create(item, info, { Transparency = 1 }):Play()
		elseif item:IsA("ParticleEmitter") then
			item.Enabled = false
		elseif item:IsA("Light") then
			TweenService:Create(item, info, { Brightness = 0 }):Play()
		end
	end
end

-- A floating marker over something worth walking to, readable from across town: a title, and
-- how far away it is (updated by the caller through the returned label).
local function marker(parent: Instance, at: Vector3, title: string, color: Color3, subtitle: string?): (BillboardGui, TextLabel)
	local holder = anchor(parent, at)
	local board = Instance.new("BillboardGui")
	board.Name = "EventMarker"
	board.AlwaysOnTop = true
	board.LightInfluence = 0
	board.MaxDistance = 2000
	board.Size = UDim2.fromOffset(220, if subtitle ~= nil then 76 else 54)
	board.Adornee = holder
	board.Parent = holder
	local y = 0
	local titleLabel = UiKit.makeTitle(board, title, color, UDim2.new(1, 0, 0, 30), UDim2.fromOffset(0, y), 3)
	UiKit.textConstraint(titleLabel, 28)
	y += 30
	if subtitle ~= nil then
		local sub = UiKit.makeTitle(board, subtitle, UiKit.WHITE, UDim2.new(1, 0, 0, 22), UDim2.fromOffset(0, y), 2.5)
		UiKit.textConstraint(sub, 20)
		y += 22
	end
	local distance = UiKit.makeTitle(board, "", UiKit.WHITE, UDim2.new(1, 0, 0, 22), UDim2.fromOffset(0, y), 2.5)
	UiKit.textConstraint(distance, 18)
	return board, distance
end

local function showDistance(label: TextLabel, to: Vector3)
	local at = rootPosition()
	label.Text = if at ~= nil then `{math.floor((Vector3.new(at.X, to.Y, at.Z) - to).Magnitude)} studs` else ""
end

-- Ease with a little overshoot, for landings and pop-ups.
local function backOut(u: number): number
	local c1 = 1.70158
	local c3 = c1 + 1
	return 1 + c3 * (u - 1) ^ 3 + c1 * (u - 1) ^ 2
end

-- A short camera shake (strength in degrees), applied after the camera scripts each frame.
local shakeUntil, shakeLength, shakeStrength = 0, 1, 0
local function shake(seconds: number, strength: number)
	shakeUntil, shakeLength, shakeStrength = os.clock() + seconds, seconds, strength
	RunService:UnbindFromRenderStep("SpecialEventShake")
	RunService:BindToRenderStep("SpecialEventShake", Enum.RenderPriority.Camera.Value + 1, function()
		local left = shakeUntil - os.clock()
		local camera = workspace.CurrentCamera
		if left <= 0 or camera == nil then
			RunService:UnbindFromRenderStep("SpecialEventShake")
			return
		end
		local amount = math.rad(shakeStrength) * left / shakeLength
		camera.CFrame *= CFrame.Angles(random:NextNumber(-amount, amount), random:NextNumber(-amount, amount), 0)
	end)
end

-- Something that rides along above the camera (falling money, floating dust), so the effect is
-- everywhere the player looks without filling the whole town with particles.
local function follower(run: Run, size: Vector3, above: number): BasePart
	local camera = workspace.CurrentCamera
	local part: BasePart = anchor(run.folder, if camera ~= nil then camera.CFrame.Position else Vector3.zero, size)
	table.insert(run.followers, { part = part, above = above })
	return part
end

local function newRun(live: Live): Run
	local folder = Instance.new("Folder")
	folder.Name = "SpecialEventFx"
	folder.Parent = workspace
	return {
		live = live,
		folder = folder,
		endedAt = nil,
		step = function() end,
		onEnd = function() end,
		onResult = function() end,
		status = function(): string?
			return nil
		end,
		cleanup = {},
		followers = {},
	}
end

-- Lucky Star ----------------------------------------------------------------------------------
local function luckyStar(run: Run, late: boolean)
	local folder = run.folder
	local ground = groundAt(0, 14, folder)
	local star = EventModels.star(folder, CFrame.new(0, STAR_HOVER, 0), STAR_HEIGHT)
	local core = anchor(folder, Vector3.new(0, STAR_HOVER, 0))
	local light = Instance.new("PointLight")
	light.Color = PALE_GOLD
	light.Range = 60
	light.Brightness = 2.5
	light.Shadows = false
	light.Parent = core
	local glitter = emitter(core, SPARKLE, { PALE_GOLD, GOLD }, 2.4, 14)
	glitter.LightEmission = 1
	glitter.Speed = NumberRange.new(3, 8)
	glitter.Lifetime = NumberRange.new(1.5, 2.5)
	glitter.SpreadAngle = Vector2.new(180, 180)
	glitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.4), NumberSequenceKeypoint.new(1, 0) })

	local began = os.clock() - (if late then STAR_FALL + STAR_RISE else 0)
	local landed = late
	local leaveFrom: number? = nil
	local height = STAR_HOVER
	if not late then
		Sfx.play("whoosh", 0.7)
	end

	local function impact()
		landed = true
		local at = Vector3.new(0, ground + 0.2, 0)
		for index, color in { GOLD, Color3.new(1, 1, 1) } do
			local ring = EventModels.ring(folder, at + Vector3.new(0, index * 0.05, 0), 10, color)
			TweenService:Create(ring, TweenInfo.new(0.9 + index * 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = Vector3.new(0.12, 150, 150),
				Transparency = 1,
			}):Play()
			Debris:AddItem(ring, 1.6)
		end
		burst(folder, Vector3.new(0, ground + 4, 0), { PALE_GOLD, GOLD }, 60, true)
		Fx.flash(PALE_GOLD, 0.55)
		shake(0.9, 1.4)
		Sfx.play("stinger", 0.75)
		Sfx.play("sweep", 0.8)
	end

	run.step = function(_now: number, _dt: number)
		local t = os.clock() - began
		local angle
		if t < STAR_FALL then
			local u = t / STAR_FALL
			height = STAR_DROP + (STAR_IMPACT - STAR_DROP) * u * u
			angle = t * 7
		else
			if not landed then
				impact()
			end
			local u = math.min(1, (t - STAR_FALL) / STAR_RISE)
			local hover = STAR_HOVER + math.sin(t * 1.6) * 1.2
			height = STAR_IMPACT + (hover - STAR_IMPACT) * backOut(u)
			angle = STAR_FALL * 7 + (t - STAR_FALL) * 0.9
		end
		local leaving = leaveFrom
		if leaving ~= nil then
			local u = os.clock() - leaving
			height += u * u * 260
			angle += u * u * 8
		end
		star:PivotTo(CFrame.new(0, height, 0) * CFrame.Angles(0, angle, 0))
		core.Position = Vector3.new(0, height, 0)
	end
	run.onEnd = function()
		leaveFrom = os.clock()
		glitter.Enabled = false
		Sfx.play("whoosh", 1.2)
	end
end

-- Cash Rain -----------------------------------------------------------------------------------
type Coin = {
	model: Model,
	spot: Vector3, -- SpecialEvents' spot (the grass), what the server measures from
	at: Vector3, -- the coin's centre, just above the ground there
	lands: number, -- os.clock() when it reaches the ground
	state: string, -- "open", "asked" (claim sent), "taken"
	retryAt: number,
}

local function cashRain(run: Run, late: boolean)
	local folder = run.folder
	local coins: { Coin } = {}
	local grabbed = 0
	local clock = os.clock()
	for index, spot in SpecialEvents.coinSpots(run.live.starts) do
		local ground = groundAt(spot.X, spot.Z, folder)
		local at = Vector3.new(spot.X, ground + COIN_SIZE / 2 + 0.8, spot.Z)
		local lands = if late then clock else clock + 0.4 + (index - 1) * 0.1 + COIN_DROP
		local model = EventModels.coin(folder, CFrame.new(at + Vector3.new(0, if late then 0 else 140, 0)), COIN_SIZE)
		-- A thin gold beam over each coin shows from across town where the coins are.
		local beam = EventModels.beam(model, Vector3.new(spot.X, ground, spot.Z), 46, 0.6, GOLD)
		beam.Transparency = 0.7
		table.insert(coins, { model = model, spot = spot, at = at, lands = lands, state = "open", retryAt = 0 })
	end

	-- Bills and coins fluttering down round the camera.
	local sky = follower(run, Vector3.new(110, 1, 110), 40)
	local bills = emitter(sky, SQUARE, { BILL_GREEN, Color3.fromRGB(150, 230, 140) }, 1.1, 40)
	bills.EmissionDirection = Enum.NormalId.Bottom
	bills.Speed = NumberRange.new(10, 16)
	bills.Lifetime = NumberRange.new(4, 6)
	bills.SpreadAngle = Vector2.new(25, 25)
	bills.Drag = 0.4
	bills.Squash = NumberSequence.new(-0.5) -- longer than wide, like a bill
	bills.RotSpeed = NumberRange.new(-220, 220)
	bills.LightEmission = 0.1
	local glints = emitter(sky, SPARKLE, { GOLD, PALE_GOLD }, 0.9, 18)
	glints.EmissionDirection = Enum.NormalId.Bottom
	glints.Speed = NumberRange.new(14, 22)
	glints.Lifetime = NumberRange.new(3, 4)
	glints.LightEmission = 1

	local function hide(coin: Coin)
		for _, part in coin.model:GetDescendants() do
			if part:IsA("BasePart") then
				part.LocalTransparencyModifier = 1
			end
		end
	end
	local function show(coin: Coin)
		for _, part in coin.model:GetDescendants() do
			if part:IsA("BasePart") then
				part.LocalTransparencyModifier = 0
			end
		end
	end

	run.step = function(_now: number, _dt: number)
		local t = os.clock()
		local at = rootPosition()
		for index, coin in coins do
			if coin.state == "taken" then
				continue
			end
			local fall = math.clamp(1 - (coin.lands - t) / COIN_DROP, 0, 1)
			local y = coin.at.Y + (1 - fall * fall) * 140 + (if fall >= 1 then math.sin(t * 2.4 + index) * 0.4 else 0)
			coin.model:PivotTo(CFrame.new(coin.at.X, y, coin.at.Z) * CFrame.Angles(0, t * 2.2 + index, 0))
			if fall >= 1 and coin.state == "open" and t >= coin.retryAt and at ~= nil and SpecialEvents.near(at, coin.spot, SpecialEvents.CoinRadius) then
				-- Grab it now; the server confirms (or puts it back).
				coin.state = "asked"
				hide(coin)
				burst(folder, coin.at, { GOLD, PALE_GOLD }, 18)
				Sfx.play("pop", 1 + random:NextNumber(0, 0.25))
				sendClaim("coin", index)
			end
		end
	end
	run.onResult = function(kind: string, index: number, ok: boolean, reason: string)
		local coin = coins[index]
		if kind ~= "coin" or coin == nil then
			return
		end
		if ok then
			coin.state = "taken"
			grabbed += 1
		elseif reason == "claimed" then
			coin.state = "taken" -- picked up before a rejoin
		else
			coin.state = "open"
			coin.retryAt = os.clock() + 1
			show(coin)
		end
	end
	run.status = function(): string?
		return `Grab the gold coins round town!  {grabbed}/{#coins}`
	end
	run.onEnd = function()
		bills.Enabled = false
		glints.Enabled = false
		for _, coin in coins do
			if coin.state ~= "taken" then
				burst(folder, coin.at, { GOLD }, 8)
			end
			coin.model:Destroy()
		end
	end
end

-- Mystery Crate -------------------------------------------------------------------------------
local function mysteryCrate(run: Run, late: boolean)
	local folder = run.folder
	local spot = SpecialEvents.crateSpot(run.live.starts)
	local ground = groundAt(spot.X, spot.Z, folder)
	local base = Vector3.new(spot.X, ground, spot.Z)
	local landAt = run.live.starts + SpecialEvents.CrateLandSeconds
	local crate, lid = EventModels.crate(folder, CFrame.new(base))
	local chute: Model? = EventModels.parachute(folder, CFrame.new(base))
	EventModels.beam(folder, base, 170, 4, PURPLE)
	-- The ring shows how close you need to get.
	EventModels.ring(folder, base + Vector3.new(0, 0.1, 0), SpecialEvents.CrateRadius * 2, PURPLE)
	local _, distance = marker(folder, base + Vector3.new(0, 9, 0), "MYSTERY CRATE", Color3.fromRGB(226, 180, 255))

	local landed = false
	local asked = false
	local opened = false
	local already = false
	local retryAt = 0
	local lidRest = lid:GetPivot()
	local openFrom: number? = nil

	local function land(quiet: boolean)
		landed = true
		crate:PivotTo(CFrame.new(base))
		lidRest = lid:GetPivot()
		local canopy = chute
		chute = nil
		if canopy ~= nil then
			-- The parachute sags onto the crate and fades.
			local info = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			for _, part in canopy:GetDescendants() do
				if part:IsA("BasePart") then
					TweenService:Create(part, info, { Transparency = 1, CFrame = part.CFrame - Vector3.new(0, 6, 0) }):Play()
				end
			end
			Debris:AddItem(canopy, 1)
		end
		if not quiet then
			burst(folder, base + Vector3.new(0, 1, 0), { Color3.fromRGB(226, 180, 255), Color3.new(1, 1, 1) }, 30)
			Sfx.play("pop", 0.8)
		end
	end
	local function open(quiet: boolean)
		opened = true
		openFrom = os.clock()
		if not quiet then
			burst(folder, base + Vector3.new(0, 5, 0), { GOLD, Color3.fromRGB(226, 180, 255) }, 40, true)
			Fx.confetti(60)
			Sfx.play("stinger")
		end
	end
	if late and workspace:GetServerTimeNow() >= landAt then
		land(true)
	end

	run.step = function(now: number, _dt: number)
		if not landed then
			local left = landAt - now
			if left <= 0 then
				land(false)
			else
				local u = math.clamp(1 - left / SpecialEvents.CrateLandSeconds, 0, 1)
				local sway = math.sin(now * 2.2) * 0.12 * (1 - u)
				local at = CFrame.new(base + Vector3.new(0, CRATE_DROP * (1 - u), 0)) * CFrame.Angles(sway, now * 0.4, sway * 0.6)
				crate:PivotTo(at)
				local canopy = chute
				if canopy ~= nil then
					canopy:PivotTo(at)
				end
			end
		end
		local from = openFrom
		if from ~= nil then
			local u = math.min(1, (os.clock() - from) / 0.5)
			lid:PivotTo(lidRest * CFrame.Angles(math.rad(115) * backOut(u), 0, 0))
		end
		showDistance(distance, base)
		local at = rootPosition()
		if landed and not opened and not asked and os.clock() >= retryAt and at ~= nil and SpecialEvents.near(at, spot, SpecialEvents.CrateRadius) then
			asked = true
			sendClaim("crate", 1)
		end
	end
	run.onResult = function(kind: string, _index: number, ok: boolean, reason: string)
		if kind ~= "crate" then
			return
		end
		asked = false
		if ok then
			open(false)
		elseif reason == "claimed" then
			already = true
			open(true)
		else
			retryAt = os.clock() + (if reason == "early" then 0.5 else 1)
		end
	end
	run.status = function(): string?
		if opened then
			return if already then "You already opened this crate" else "You opened the crate! Enjoy your free cast"
		elseif not landed then
			return `Crate landing in {math.max(1, math.ceil(landAt - workspace:GetServerTimeNow()))}... follow the purple beam!`
		end
		return "The crate landed on the boulevard! Reach it for a free x3 Luck cast"
	end
	run.onEnd = function()
		fadeOut(folder, FADE * 0.8)
	end
end

-- Spotlight -----------------------------------------------------------------------------------
local function spotlight(run: Run, late: boolean)
	local folder = run.folder
	local lot = run.live.lot
	if lot == nil then
		return
	end
	local center = MapModels.lotBase(lot).Position
	local glow = EventModels.beam(folder, center, 260, 36, Color3.fromRGB(255, 244, 214))
	local core = EventModels.beam(folder, center, 260, 12, Color3.new(1, 1, 1))
	EventModels.ring(folder, center + Vector3.new(0, 0.3, 0), LotModels.Layout.size + 6, GOLD)
	glow.Transparency = 1
	core.Transparency = 1
	local info = TweenInfo.new(if late then 0 else 0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(glow, info, { Transparency = 0.85 }):Play()
	TweenService:Create(core, info, { Transparency = 0.7 }):Play()

	-- Two searchlights at the lot's corners sweep the sky.
	local half = LotModels.Layout.size / 2
	local lights: { { beam: BasePart, origin: Vector3, phase: number } } = {}
	for index, corner in { Vector3.new(-half, 0, -half), Vector3.new(half, 0, half) } do
		local beam = EventModels.beam(folder, center + corner, 180, 3, PALE_GOLD)
		beam.Transparency = 0.65
		table.insert(lights, { beam = beam, origin = center + corner, phase = index * math.pi })
	end

	local owner = run.live.owner or "A player"
	local mine = run.live.ownerId == player.UserId
	local _, distance = marker(folder, center + Vector3.new(0, 34, 0), "SPOTLIGHT", GOLD, if mine then "Your studio" else `{owner}'s studio`)
	local party = anchor(folder, center + Vector3.new(0, 30, 0))
	local nextParty = 0
	local rewarded = mine

	if not late then
		Sfx.play("sweep")
	end
	run.step = function(_now: number, _dt: number)
		local t = os.clock()
		for _, light in lights do
			local yaw = t * 0.7 + light.phase
			local tilt = math.rad(22 + math.sin(t * 0.9 + light.phase) * 10)
			light.beam.CFrame = CFrame.new(light.origin)
				* CFrame.Angles(0, yaw, 0)
				* CFrame.Angles(tilt, 0, 0)
				* CFrame.new(0, light.beam.Size.X / 2, 0)
				* CFrame.Angles(0, 0, math.rad(90))
		end
		if t >= nextParty and run.endedAt == nil then
			nextParty = t + 2.5
			burst(folder, party.Position, { GOLD, Color3.new(1, 1, 1) }, 16, true)
		end
		showDistance(distance, center)
	end
	run.onResult = function(kind: string, _index: number, ok: boolean, _reason: string)
		if kind == "spotlight" and ok then
			rewarded = true
		end
	end
	run.status = function(): string?
		if mine then
			return "You're in the spotlight! Everyone who visits gets x2 Luck"
		elseif rewarded then
			return "Lucky Casting is on! Go cast some stars"
		end
		return `Visit {owner}'s studio for x2 Luck!`
	end
	run.onEnd = function()
		fadeOut(folder, FADE * 0.8)
	end
end

-- Golden Hour ---------------------------------------------------------------------------------
local function goldenHour(run: Run, late: boolean)
	local clockWas = normalClock or Lighting.ClockTime
	normalClock = clockWas
	local seconds = if late then 0 else 4
	local tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "SpecialEventTint"
	tint.Parent = Lighting
	local rays = Instance.new("SunRaysEffect")
	rays.Name = "SpecialEventRays"
	rays.Intensity = 0
	rays.Spread = 0.8
	rays.Parent = Lighting
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	TweenService:Create(Lighting, info, { ClockTime = GOLDEN_CLOCK }):Play()
	TweenService:Create(tint, info, { TintColor = Color3.fromRGB(255, 226, 186), Saturation = 0.12, Brightness = 0.03 }):Play()
	TweenService:Create(rays, info, { Intensity = 0.14 }):Play()

	local air = follower(run, Vector3.new(90, 30, 90), 4)
	local dust = emitter(air, SPARKLE, { PALE_GOLD, GOLD }, 0.5, 30)
	dust.LightEmission = 1
	dust.Speed = NumberRange.new(0.3, 1.2)
	dust.SpreadAngle = Vector2.new(180, 180)
	dust.Lifetime = NumberRange.new(4, 6)
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.2), NumberSequenceKeypoint.new(1, 1) })

	if not late then
		Sfx.play("sweep", 0.7)
	end
	run.onEnd = function()
		dust.Enabled = false
		local back = TweenInfo.new(FADE, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		TweenService:Create(Lighting, back, { ClockTime = clockWas }):Play()
		TweenService:Create(tint, back, { TintColor = Color3.new(1, 1, 1), Saturation = 0, Brightness = 0 }):Play()
		TweenService:Create(rays, back, { Intensity = 0 }):Play()
	end
	table.insert(run.cleanup, function()
		tint:Destroy()
		rays:Destroy()
		Lighting.ClockTime = clockWas
	end)
end

local BUILDERS: { [string]: (run: Run, late: boolean) -> () } = {
	LuckyStar = luckyStar,
	CashRain = cashRain,
	MysteryCrate = mysteryCrate,
	Spotlight = spotlight,
	GoldenHour = goldenHour,
}

-- API -----------------------------------------------------------------------------------------

local function destroy(run: Run)
	for _, clean in run.cleanup do
		pcall(clean)
	end
	run.folder:Destroy()
	local index = table.find(runs, run)
	if index ~= nil then
		table.remove(runs, index)
	end
end

-- Ends the live event: its props play their exit and are gone a moment later.
function EventWorld.finish()
	local run = current
	if run == nil then
		return
	end
	current = nil
	run.endedAt = os.clock()
	local ok, err = pcall(function()
		run.onEnd()
	end)
	if not ok then
		warn(`[EventWorld] {err}`)
	end
	task.delay(FADE, destroy, run)
end

-- Starts showing `live`. `late` skips the entrance (joining, or arriving, mid-event).
function EventWorld.begin(live: Live, late: boolean)
	EventWorld.finish()
	local run = newRun(live)
	current = run
	table.insert(runs, run)
	local build = BUILDERS[live.event.id]
	if build ~= nil then
		local ok, err = pcall(function()
			build(run, late)
		end)
		if not ok then
			warn(`[EventWorld] {live.event.id}: {err}`)
		end
	end
end

-- The server's answer to a claim (see SpecialEventService): (kind, index, ok, reason or reward).
function EventWorld.result(kind: string, index: number, ok: boolean, reason: string)
	local run = current
	if run ~= nil then
		run.onResult(kind, index, ok, reason)
	end
end

-- A live line for the banner, or nil to show the event's own tagline.
function EventWorld.status(): string?
	local run = current
	return if run ~= nil then run.status() else nil
end

-- `claim(kind, index)` asks the server for a pickup.
function EventWorld.start(claim: (kind: string, index: number) -> ())
	sendClaim = claim
	RunService.Heartbeat:Connect(function(dt: number)
		local camera = workspace.CurrentCamera
		local now = workspace:GetServerTimeNow()
		for _, run in table.clone(runs) do
			if camera ~= nil then
				for _, follow in run.followers do
					follow.part.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, follow.above, 0))
				end
			end
			local ok, err = pcall(function()
				run.step(now, dt)
			end)
			if not ok then
				warn(`[EventWorld] {err}`)
				run.step = function() end
			end
		end
	end)
end

return EventWorld
