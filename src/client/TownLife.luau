--!strict
-- Townsfolk that make the boulevard feel lived in, on each player's own screen (like MapLife and
-- ActorLife, so they cost the server nothing):
--   * a hot-dog vendor at his cart, a mime and a busker playing for tips, people waiting at the
--     two bus stops;
--   * paparazzi snapping photos by the top-star pedestal of a lot whose star is Star or rarer;
--   * when a player premieres a film (the server's LotPremiere broadcast, which every client hears),
--     fans run up the red carpet of that studio and cheer for a few seconds (more fans for bigger
--     results), the paparazzi join them, and the marquee and carpet lights come up (brighter
--     after dark, DayNightWorld).
--
-- Every person is the townsfolk rig from art/blender/townlife_kit.py: six pieces (Head, Torso,
-- two arms, two legs) turned at their joints with plain CFrame math, no Humanoids or pathfinding.
-- They are built once and reused (the fans are a pool of eight). One Heartbeat moves them all with
-- one BulkMoveTo, 30 times a second; only the CAP nearest within RANGE move, those past NEAR only
-- every FAR_EVERY steps, and people past CULL are taken out of the world until the camera comes back.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Actors = require(ReplicatedStorage.Shared.Actors)
local Build = require(ReplicatedStorage.Shared.Models.Build)
local Config = require(ReplicatedStorage.Shared.Config)
local MapKit = require(ReplicatedStorage.Shared.Models.MapKit)
local MapModels = require(ReplicatedStorage.Shared.Models.MapModels)
local DayNightWorld = require(script.Parent.DayNightWorld)

local TownLife = {}

local STEP = 1 / 30 -- seconds between moves
local RANGE = 150 -- studs from the camera: closer people move
local NEAR = 60 -- closer than this, every step; farther, every FAR_EVERY steps
local FAR_EVERY = 3
local CULL = 260 -- farther than this, out of the world
local CAP = 24 -- most people moved in one step
local PREMIERE_RANGE = 200 -- premieres farther from the camera than this get no crowd
local STAR_RANGE = 140 -- the paparazzi visit the nearest star lot within this

-- Body (studs, feet at y = 0, facing -Z): the same joints as CrewRig and the Blender kit.
local HIPS = 2
local HIP_OUT = 0.45
local SHOULDER_X, SHOULDER_Y = 1.2, 1.75
local NECK = 2.1
local GRIP = 1.6

local CROWD = { Flop = 2, Hit = 4, Blockbuster = 6, Cult = 7, Masterpiece = 8 }
local CHEER_SECONDS = { Flop = 4, Hit = 6, Blockbuster = 8, Cult = 9, Masterpiece = 11 }
local EXCITEMENT = { Flop = 0.2, Hit = 0.7, Blockbuster = 0.9, Cult = 1, Masterpiece = 1 }
local FAN_LOOKS = { "FanA", "FanB", "FanC", "FanD" }
-- Lot space (MapModels.lotBase; the ground is at y = 1, the carpet runs up x = 0 from the gate at
-- z = -27 to the cinema door at z = 4.5): behind the velvet ropes, clear of the pedestal and pads.
local FAN_SPOTS = {
	Vector3.new(-5.2, 1, -6), Vector3.new(5.2, 1, -11), Vector3.new(-5.2, 1, -9), Vector3.new(-5.2, 1, -3),
	Vector3.new(5.2, 1, -14), Vector3.new(-5.2, 1, -12), Vector3.new(-5.2, 1, 0), Vector3.new(-5.2, 1, -15),
}
local GATE_Z = -26
local STAR_SPOTS = { Vector3.new(4.6, 1, -7.4), Vector3.new(12.4, 1, -6.8) } -- round the pedestal
local PEDESTAL = Vector3.new(8.5, 1, -3)
local PREMIERE_SPOTS = { Vector3.new(-5.2, 1, 2.2), Vector3.new(5.2, 1, 1.8) } -- by the cinema door
local TIER_RANK: { [string]: number } = {}
for index, tier in Actors.Tiers do
	TIER_RANK[tier.id] = index
end
local STAR_TIER = TIER_RANK.Star

type Piece = { { part: BasePart, offset: CFrame } }
type Pose = {
	root: CFrame, -- the feet
	head: number, -- head turn (radians)
	nod: number,
	arms: { { number } }, -- { pitch forward, swing out } for left and right
	legs: { number }, -- pitch forward, left and right
}
type Person = {
	model: Model,
	pieces: { [string]: Piece },
	hold: string?, -- prop piece name
	at: Vector3, -- where it is, for distance checks
	slot: number,
	phase: number,
	shown: boolean,
	posed: boolean, -- has been put in a pose since it was last shown
	active: boolean,
	pose: (person: Person, t: number) -> Pose,
	flash: PointLight?,
	flashAt: number,
	nextFlash: number,
	-- Free for each kind of person's own state.
	data: { [string]: any },
}

local random = Random.new()
local folder: Folder
local people: { Person } = {}
local slots = 0

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

-- One piece of a person: a kit model placed at the origin, kept as its parts and their offsets.
local function piece(model: Model, kitName: string, light: boolean?): (Piece, PointLight?)
	local b = Build.new(model, CFrame.identity)
	local kit = MapKit.place(b, kitName, CFrame.identity, {
		solid = false,
		light = if light then { range = 18, brightness = 0, color = Color3.new(1, 1, 1) } else nil,
	})
	noCollide(kit)
	local out: Piece = {}
	for _, part in kit:GetDescendants() do
		if part:IsA("BasePart") then
			table.insert(out, { part = part, offset = part.CFrame })
		end
	end
	return out, kit:FindFirstChildWhichIsA("PointLight", true)
end

local function newPerson(who: string, hold: string?, pose: (person: Person, t: number) -> Pose): Person
	local model = Instance.new("Model")
	model.Name = "Town" .. who
	local pieces: { [string]: Piece } = {}
	pieces.Head = piece(model, `Town{who}Head`)
	pieces.Torso = piece(model, `Town{who}Torso`)
	pieces.ArmL = piece(model, `Town{who}Arm`)
	pieces.ArmR = piece(model, `Town{who}Arm`)
	pieces.LegL = piece(model, `Town{who}Leg`)
	pieces.LegR = piece(model, `Town{who}Leg`)
	local flash = nil
	if hold ~= nil then
		pieces[hold], flash = piece(model, hold, hold == "PaparazziCamera")
	end
	slots += 1
	local person: Person = {
		model = model,
		pieces = pieces,
		hold = hold,
		at = Vector3.zero,
		slot = slots,
		phase = random:NextNumber(0, 10),
		shown = false,
		posed = false,
		active = false,
		pose = pose,
		flash = flash,
		flashAt = -math.huge,
		nextFlash = 0,
		data = {},
	}
	table.insert(people, person)
	return person
end

-- Where each piece goes for a pose (pure CFrame math, CrewRig's joints).
local function frames(person: Person, pose: Pose): { [string]: CFrame }
	local torso = pose.root * CFrame.new(0, HIPS, 0)
	local out = {
		Torso = torso,
		Head = torso * CFrame.new(0, NECK, 0) * CFrame.Angles(pose.nod, pose.head, 0),
		LegL = pose.root * CFrame.new(-HIP_OUT, HIPS, 0) * CFrame.Angles(pose.legs[1], 0, 0),
		LegR = pose.root * CFrame.new(HIP_OUT, HIPS, 0) * CFrame.Angles(pose.legs[2], 0, 0),
	}
	for i, side in { -1, 1 } do
		local arm = pose.arms[i]
		out[if side < 0 then "ArmL" else "ArmR"] = torso
			* CFrame.new(SHOULDER_X * side, SHOULDER_Y, 0)
			* CFrame.Angles(arm[1], 0, 0)
			* CFrame.Angles(0, 0, side * arm[2])
	end
	local hold = person.hold
	if hold == "FanSign" then
		out.FanSign = out.ArmR * CFrame.new(0, -GRIP, 0)
	elseif hold == "PaparazziCamera" then
		out.PaparazziCamera = torso * CFrame.new(0, 2.05, -1.45)
	elseif hold == "Guitar" then
		out.Guitar = torso * CFrame.new(0.1, 0.85, -0.8) * CFrame.Angles(0, 0, math.rad(22))
	end
	return out
end

local function pose(root: CFrame): Pose
	return { root = root, head = 0, nod = 0, arms = { { 0, 0.12 }, { 0, 0.12 } }, legs = { 0, 0 } }
end

-- Static props (the cart, the tip hats), standing on the ground.
local function prop(name: string, at: CFrame): Model
	local model = MapKit.place(Build.new(folder, CFrame.identity), name, at, { solid = false })
	noCollide(model)
	return model
end

-- The ground under (x, z), skipping the townsfolk and the players.
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function ground(x: number, z: number): number
	local exclude: { Instance } = { folder }
	for _, other in Players:GetPlayers() do
		if other.Character ~= nil then
			table.insert(exclude, other.Character)
		end
	end
	rayParams.FilterDescendantsInstances = exclude
	local hit = Workspace:Raycast(Vector3.new(x, 60, z), Vector3.new(0, -120, 0), rayParams)
	return if hit ~= nil then hit.Position.Y else 0.2
end

local function standAt(x: number, z: number, yaw: number): CFrame
	return CFrame.new(x, ground(x, z), z) * CFrame.Angles(0, yaw, 0)
end

local function setShown(person: Person, shown: boolean)
	if person.shown ~= shown then
		person.shown = shown
		person.posed = false
		person.model.Parent = if shown then folder else nil
	end
end

local function flashSoon(person: Person, t: number, busy: boolean)
	person.nextFlash = t + (if busy then random:NextNumber(0.25, 0.9) else random:NextNumber(0.8, 2.8))
end

-- Ambient townsfolk --------------------------------------------------------------------------------

local function vendor(base: CFrame)
	local person = newPerson("Vendor", nil, function(self, t)
		local p = pose(self.data.base)
		local s = t + self.phase
		p.head = math.sin(s * 0.5) * 0.5
		local wave = (s % 7) < 1.6 -- "Hot dogs!": a big wave every few seconds
		p.arms[1] = { 0.9 + math.sin(s * 3) * 0.1, -0.2 }
		p.arms[2] = if wave then { 0, 2.6 + math.sin(s * 9) * 0.35 } else { 0.9 + math.sin(s * 3 + 1) * 0.1, -0.2 }
		return p
	end)
	person.data.base = base
	person.at = base.Position
	person.active = true
end

local function mime(base: CFrame)
	local person = newPerson("Mime", nil, function(self, t)
		local s = t + self.phase
		-- Feeling round an invisible box, now and then leaning on it.
		local lean = math.max(0, math.sin(s * 0.4)) * 0.12
		local p = pose(self.data.base * CFrame.new(0, 0, 0) * CFrame.Angles(-lean, 0, 0))
		p.head = math.sin(s * 0.7) * 0.4
		p.nod = math.sin(s * 1.3) * 0.1
		p.arms[1] = { 1.5 + math.sin(s * 2.1) * 0.25, -0.25 + math.max(0, math.sin(s * 1.1)) * 0.6 }
		p.arms[2] = { 1.5 + math.sin(s * 2.1 + 1.6) * 0.25, -0.25 + math.max(0, math.sin(s * 1.1 + 2)) * 0.6 }
		return p
	end)
	person.data.base = base
	person.at = base.Position
	person.active = true
	prop("TipHat", base * CFrame.new(0, 0, -2.6))
end

local function busker(base: CFrame)
	local person = newPerson("FanB", "Guitar", function(self, t)
		local s = t + self.phase
		local p = pose(self.data.base * CFrame.new(0, math.abs(math.sin(s * 4)) * 0.08, 0))
		p.nod = math.sin(s * 8) * 0.08
		p.head = math.sin(s * 0.6) * 0.3
		p.arms[1] = { 1.2, -0.75 } -- on the neck
		p.arms[2] = { 0.7 + math.sin(s * 14) * 0.18, -0.55 } -- strumming
		p.legs[2] = math.max(0, math.sin(s * 8)) * 0.15 -- tapping a foot
		return p
	end)
	person.data.base = base
	person.at = base.Position
	person.active = true
	prop("TipHat", base * CFrame.new(1.8, 0, -2.4))
end

-- The map kit's BusStop (TownSets.busStop): its bench top is 1.675 up, at x -3.9..0.7, z 0.8.
local function busStop(stop: CFrame, looks: { string })
	local spots = {
		{ at = CFrame.new(-3.0, 0, 0.7), seated = true },
		{ at = CFrame.new(-1.0, 0, 0.7), seated = true },
		{ at = CFrame.new(2.6, 0, -0.6) * CFrame.Angles(0, math.rad(-30), 0), seated = false },
	}
	for i, spot in spots do
		local person = newPerson(looks[i], nil, function(self, t)
			local s = t + self.phase
			local seated = self.data.seated
			local root = self.data.base * (if seated then CFrame.new(0, 1.7 - HIPS, 0) else CFrame.identity)
			local p = pose(root)
			-- Looking down the road for the bus, then back.
			p.head = math.clamp(math.sin(s * 0.35) * 1.6, -1, 1)
			if seated then
				p.legs = { 1.45, 1.45 }
				p.arms = { { 0.7, -0.05 }, { 0.7, -0.05 } }
			elseif (s % 9) < 2 then
				p.arms[1] = { 1.3, -0.7 } -- checking the time
				p.head, p.nod = 0.35, 0.3
			end
			return p
		end)
		person.data.base = stop * spot.at
		person.data.seated = spot.seated
		person.at = person.data.base.Position
		person.active = true
	end
end

-- Paparazzi ------------------------------------------------------------------------------------------

local paparazzi: { Person } = {}
local starLot: number? = nil
local premiere: { lot: number, starts: number, ends: number }? = nil
local placedFor = "" -- what the paparazzi are standing for: "p<lot>", "s<lot>" or ""

local function photographer(index: number)
	local person = newPerson("Photog", "PaparazziCamera", function(self, t)
		local s = t + self.phase
		local d = self.data
		local p = pose(d.base * CFrame.new(math.sin(s * 0.4) * 0.5, 0, 0))
		local crouch = (s % 6) < 2.2
		if crouch then
			p.root = p.root * CFrame.new(0, -0.35, 0)
			p.legs = { 0.35, -0.2 }
		end
		p.arms = { { 1.4, -0.35 }, { 1.4, -0.35 } }
		p.nod = math.sin(s * 0.9) * 0.05
		if t >= self.nextFlash then
			self.flashAt = t
			flashSoon(self, t, premiere ~= nil)
		end
		return p
	end)
	person.data.index = index
	table.insert(paparazzi, person)
end

local function facingPoint(at: Vector3, target: Vector3): CFrame
	local flat = Vector3.new(target.X, at.Y, target.Z)
	return CFrame.lookAt(at, flat)
end

local function placePaparazzi()
	local spots, target = nil, nil
	local lot = if premiere ~= nil then premiere.lot else starLot
	placedFor = if premiere ~= nil then `p{premiere.lot}` elseif starLot ~= nil then `s{starLot}` else ""
	if lot ~= nil then
		local base = MapModels.lotBase(lot)
		if premiere ~= nil then
			spots = PREMIERE_SPOTS
			target = base * Vector3.new(0, 1, -8)
		else
			spots = STAR_SPOTS
			target = base * PEDESTAL
		end
		for i, person in paparazzi do
			local at = base * spots[i]
			person.data.base = facingPoint(Vector3.new(at.X, at.Y, at.Z), target)
			person.at = at
			person.active = true
		end
	else
		for _, person in paparazzi do
			person.active = false
		end
	end
end

-- The nearest lot whose top star is Star or rarer, within STAR_RANGE of the camera.
local function findStarLot(camera: Vector3): number?
	local lots = Workspace:FindFirstChild("Lots")
	if lots == nil then
		return nil
	end
	local best, bestDistance = nil, STAR_RANGE
	for index = 1, Config.LotCount do
		local model = lots:FindFirstChild("Lot" .. index)
		local tier = if model ~= nil then model:GetAttribute("TopStarTier") else nil
		local rank = if type(tier) == "string" then TIER_RANK[tier] else nil
		if rank ~= nil and rank >= STAR_TIER then
			local distance = ((MapModels.lotBase(index) * PEDESTAL) - camera).Magnitude
			if distance < bestDistance then
				best, bestDistance = index, distance
			end
		end
	end
	return best
end

-- Premiere crowd -------------------------------------------------------------------------------------

local fans: { Person } = {}
local premiereLights: { PointLight } = {}

local function fan(index: number)
	local look = FAN_LOOKS[(index - 1) % #FAN_LOOKS + 1]
	local person = newPerson(look, if index % 3 == 1 then "FanSign" else nil, function(self, t)
		local d = self.data
		local s = t + self.phase
		local run = 1.3
		local stage, u
		if t < d.start + run then
			stage, u = "in", math.clamp((t - d.start) / run, 0, 1)
		elseif t < d.leave then
			stage, u = "cheer", 0
		else
			stage, u = "out", math.clamp((t - d.leave) / run, 0, 1)
			if u >= 1 then
				self.active = false
			end
		end
		if stage ~= "cheer" then
			local from, to = d.gate, d.spot
			if stage == "out" then
				from, to = d.spot, d.gate
			end
			local at = from:Lerp(to, u)
			local p = pose(CFrame.lookAt(at, at + (to - from)) * CFrame.new(0, math.abs(math.sin(s * 12)) * 0.25, 0))
			local swing = math.sin(s * 12) * 0.8
			p.legs = { swing, -swing }
			p.arms = { { -swing, 0.15 }, { swing, 0.15 } }
			self.at = at
			return p
		end
		local excite = d.excite
		local hop = math.abs(math.sin(s * 6)) * 0.6 * excite
		local p = pose(d.face * CFrame.new(0, hop, 0))
		if excite < 0.4 then
			-- A polite clap for a Flop.
			local clap = math.abs(math.sin(s * 9)) * 0.3
			p.arms = { { 1.2, -0.35 + clap }, { 1.2, -0.35 + clap } }
		else
			p.arms = { { 0.2, 2.5 + math.sin(s * 8) * 0.35 }, { 0.2, 2.5 + math.sin(s * 8 + 2) * 0.35 } }
			if self.hold == "FanSign" then
				p.arms[2] = { 0, 2.95 + math.sin(s * 3) * 0.12 }
			end
			p.legs = { math.sin(s * 6) * 0.2 * excite, -math.sin(s * 6) * 0.2 * excite }
		end
		p.head = math.sin(s * 0.8) * 0.35
		self.at = d.face.Position
		return p
	end)
	table.insert(fans, person)
end

local function lightAt(at: Vector3, color: Color3, range: number): PointLight
	local holder = Instance.new("Part")
	holder.Name = "PremiereLight"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.Position = at
	holder.Parent = folder
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = 0
	light.Shadows = false
	light.Parent = holder
	return light
end

local function startPremiere(lot: number, resultId: string)
	local camera = Workspace.CurrentCamera
	local base = MapModels.lotBase(lot)
	if camera == nil or (base.Position - camera.CFrame.Position).Magnitude > PREMIERE_RANGE then
		return
	end
	if #fans == 0 then
		for i = 1, #FAN_SPOTS do
			fan(i)
		end
		premiereLights = {
			lightAt(Vector3.zero, Color3.fromRGB(255, 214, 140), 26), -- the marquee
			lightAt(Vector3.zero, Color3.fromRGB(255, 120, 110), 18), -- the carpet
			lightAt(Vector3.zero, Color3.fromRGB(255, 120, 110), 18),
		}
	end
	local t = os.clock()
	local cheer = CHEER_SECONDS[resultId] or CHEER_SECONDS.Hit
	local count = CROWD[resultId] or CROWD.Hit
	premiere = { lot = lot, starts = t, ends = t + 1.3 + cheer }
	for i, person in fans do
		if i > count then
			person.active = false
			continue
		end
		local spot = base * FAN_SPOTS[i]
		local d = person.data
		d.spot = spot
		d.gate = base * Vector3.new(FAN_SPOTS[i].X, 1, GATE_Z - random:NextNumber(0, 3))
		d.face = facingPoint(spot, base * Vector3.new(0, 1, FAN_SPOTS[i].Z + 2))
		d.start = t + random:NextNumber(0, 0.6)
		d.leave = d.start + 1.3 + cheer + random:NextNumber(-0.5, 0.5)
		d.excite = EXCITEMENT[resultId] or 0.7
		person.at = d.gate
		person.active = true
	end
	local spots = { Vector3.new(0, 9.5, 0.4), Vector3.new(0, 3, -11), Vector3.new(0, 3, -3) }
	for i, light in premiereLights do
		(light.Parent :: BasePart).Position = base * spots[i]
	end
	placePaparazzi()
	for _, person in paparazzi do
		flashSoon(person, t, true)
	end
end

-- The loop ---------------------------------------------------------------------------------------------

local function start()
	folder = Instance.new("Folder")
	folder.Name = "TownLife"
	folder.Parent = Workspace

	-- Street spots (world space, on the wide sidewalks between the road and the lots).
	vendor(standAt(64, 26.4, 0)) -- behind the cart, facing the boulevard
	prop("HotDogCart", standAt(64, 24, 0))
	mime(standAt(-64, -24, math.pi))
	busker(standAt(150, 34, 0))
	busStop(CFrame.new(96, ground(96, -22), -22) * CFrame.Angles(0, math.pi, 0), { "FanA", "FanC", "FanD" })
	busStop(CFrame.new(-128, ground(-128, 22), 22), { "FanD", "FanB", "Photog" })
	photographer(1)
	photographer(2)

	local remotes = ReplicatedStorage:WaitForChild("Remotes", 30)
	local lotPremiere = if remotes ~= nil then remotes:WaitForChild("LotPremiere", 30) else nil
	if lotPremiere ~= nil and lotPremiere:IsA("RemoteEvent") then
		lotPremiere.OnClientEvent:Connect(function(index, _title, resultId)
			if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > Config.LotCount or type(resultId) ~= "string" then
				return
			end
			startPremiere(index, resultId)
		end)
	end

	local parts: { BasePart } = {}
	local cframes: { CFrame } = {}
	local near: { Person } = {}
	local distances: { [Person]: number } = {}
	local wait = 0
	local frame = 0
	local nextScan = 0
	RunService.Heartbeat:Connect(function(dt)
		wait -= dt
		if wait > 0 then
			return
		end
		wait = STEP
		frame += 1
		local camera = Workspace.CurrentCamera
		if camera == nil then
			return
		end
		local eye = camera.CFrame.Position
		local t = os.clock()

		-- Once a second: is there a star lot nearby for the paparazzi, and is the premiere over?
		if t >= nextScan then
			nextScan = t + 1
			if premiere ~= nil and t > premiere.ends + 1.5 then
				premiere = nil
			end
			starLot = findStarLot(eye)
			local want = if premiere ~= nil then `p{premiere.lot}` elseif starLot ~= nil then `s{starLot}` else ""
			if want ~= placedFor then
				placePaparazzi()
			end
		end

		-- Premiere lights: up for the show, a gentle chase, brighter after dark.
		if #premiereLights > 0 then
			local level = 0
			if premiere ~= nil then
				level = math.clamp(math.min(t - premiere.starts, premiere.ends + 1.5 - t), 0, 1)
			end
			local glow = level * (1.2 + 2.3 * DayNightWorld.darkness())
			for i, light in premiereLights do
				light.Brightness = glow * (0.8 + 0.2 * math.sin(t * 5 + i * 2))
			end
		end

		table.clear(parts)
		table.clear(cframes)
		table.clear(near)
		for _, person in people do
			local distance = if person.active then (person.at - eye).Magnitude else math.huge
			setShown(person, distance < CULL)
			-- Just shown: pose it once wherever it is, so nobody waits at the origin.
			if distance < RANGE or (person.shown and not person.posed) then
				distances[person] = distance
				table.insert(near, person)
			end
		end
		if #near > CAP then
			table.sort(near, function(a, b)
				return distances[a] < distances[b]
			end)
		end
		for i = 1, math.min(#near, CAP) do
			local person = near[i]
			if person.posed and distances[person] > NEAR and (frame + person.slot) % FAR_EVERY ~= 0 then
				continue
			end
			person.posed = true
			local frameOf = frames(person, person.pose(person, t))
			for name, list in person.pieces do
				local at = frameOf[name]
				if at ~= nil then
					for _, item in list do
						table.insert(parts, item.part)
						table.insert(cframes, at * item.offset)
					end
				end
			end
			local flash = person.flash
			if flash ~= nil then
				local since = t - person.flashAt
				flash.Brightness = if since < 0.2 then 9 * (1 - since / 0.2) else 0
			end
		end
		if #parts > 0 then
			Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end)
end

function TownLife.start()
	task.spawn(function()
		-- Wait for the town, so the raycasts find the sidewalks.
		if Workspace:WaitForChild("Town", 60) == nil then
			return
		end
		local ok, err = pcall(start)
		if not ok then
			warn(`[TownLife] {err}`)
		end
	end)
end

return TownLife
