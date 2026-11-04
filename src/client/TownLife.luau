--!strict
-- Townsfolk that make the boulevard feel lived in, on each player's own screen (like MapLife and
-- ActorLife, so they cost the server nothing):
--   * a hot-dog vendor at his cart, a mime and a busker playing for tips, people waiting at the
--     two bus stops;
--   * paparazzi snapping photos by the top-star pedestal of a lot whose star is Star or rarer.
-- Premieres get no crowd on the lot: the owner's premiere is a private show (PremiereReveal).
--
-- Every person is the townsfolk rig from art/blender/townlife_kit.py: six pieces (Head, Torso,
-- two arms, two legs) turned at their joints with plain CFrame math, no Humanoids or pathfinding.
-- They are built once and reused. One Heartbeat moves them all with
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

local TownLife = {}

local STEP = 1 / 30 -- seconds between moves
local RANGE = 150 -- studs from the camera: closer people move
local NEAR = 60 -- closer than this, every step; farther, every FAR_EVERY steps
local FAR_EVERY = 3
local CULL = 260 -- farther than this, out of the world
local CAP = 24 -- most people moved in one step
local STAR_RANGE = 140 -- the paparazzi visit the nearest star lot within this

-- Body (studs, feet at y = 0, facing -Z): the same joints as CrewRig and the Blender kit.
local HIPS = 2
local HIP_OUT = 0.45
local SHOULDER_X, SHOULDER_Y = 1.2, 1.75
local NECK = 2.1
local GRIP = 1.6

-- Lot space (MapModels.lotBase; the ground is at y = 1).
local STAR_SPOTS = { Vector3.new(4.6, 1, -7.4), Vector3.new(12.4, 1, -6.8) } -- round the pedestal
local PEDESTAL = Vector3.new(8.5, 1, -3)
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
local function piece(model: Model, kitName: string, light: boolean?, labels: { [string]: MapKit.Label }?): (Piece, PointLight?)
	local b = Build.new(model, CFrame.identity)
	local kit = MapKit.place(b, kitName, CFrame.identity, {
		solid = false,
		light = if light then { range = 18, brightness = 0, color = Color3.new(1, 1, 1) } else nil,
		labels = labels,
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

-- `signText` letters a FanSignBlank; `solo` people are moved by the caller (the premiere show), not by the town's loop.
local function newPerson(who: string, hold: string?, pose: (person: Person, t: number) -> Pose, signText: string?, solo: boolean?): Person
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
		local labels = if signText ~= nil then { Sign = { text = signText, color = Color3.fromRGB(26, 34, 74), stroke = 0 } } else nil
		pieces[hold], flash = piece(model, hold, hold == "PaparazziCamera", labels)
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
	if not solo then
		table.insert(people, person)
	end
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
	if hold ~= nil and string.sub(hold, 1, 7) == "FanSign" then
		out[hold] = out.ArmR * CFrame.new(0, -GRIP, 0)
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

local function flashSoon(person: Person, t: number)
	person.nextFlash = t + random:NextNumber(0.8, 2.8)
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
		{ at = CFrame.new(7.6, 0, -1.2) * CFrame.Angles(0, math.rad(-30), 0), seated = false },
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
local placedFor: number? = nil -- the star lot the paparazzi are standing at

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
			flashSoon(self, t)
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
	local lot = starLot
	placedFor = lot
	if lot ~= nil then
		local base = MapModels.lotBase(lot)
		local target = base * PEDESTAL
		for i, person in paparazzi do
			local at = base * STAR_SPOTS[i]
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

-- The loop ---------------------------------------------------------------------------------------------

local function start()
	folder = Instance.new("Folder")
	folder.Name = "TownLife"
	folder.Parent = Workspace

	-- Street spots (world space, on the wide sidewalks between the road and the lots).
	vendor(standAt(84, 24.4, 0)) -- behind the cart, facing the boulevard
	prop("HotDogCart", standAt(84, 22, 0))
	mime(standAt(-84, -22, math.pi))
	busker(standAt(150, 34, 0))
	busStop(CFrame.new(96, ground(96, -22), -22) * CFrame.Angles(0, math.pi, 0), { "FanA", "FanC", "FanD" })
	busStop(CFrame.new(-128, ground(-128, 22), 22), { "FanD", "FanB", "Photog" })
	photographer(1)
	photographer(2)

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

		-- Once a second: is there a star lot nearby for the paparazzi?
		if t >= nextScan then
			nextScan = t + 1
			starLot = findStarLot(eye)
			if starLot ~= placedFor then
				placePaparazzi()
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
				if at then
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

-- The rig for the premiere show (PremiereShow): a person the caller poses and moves itself.
export type Figure = Person
export type FigurePose = Pose
TownLife.pose = pose

function TownLife.figure(who: string, hold: string?, signText: string?): Person
	local person = newPerson(who, hold, function()
		return pose(CFrame.identity)
	end, signText, true)
	return person
end

-- Adds the parts of `person` in `p` to the lists a BulkMoveTo takes.
function TownLife.collect(person: Person, p: Pose, parts: { BasePart }, cframes: { CFrame })
	local frameOf = frames(person, p)
	for name, list in person.pieces do
		local at = frameOf[name]
		if at then
			for _, item in list do
				table.insert(parts, item.part)
				table.insert(cframes, at * item.offset)
			end
		end
	end
end

function TownLife.start()
	task.spawn(function()
		-- Wait for the town, so the raycasts find the sidewalks.
		if Workspace:WaitForChild("Town", 60) == nil then
			return
		end
		local ok, err = pcall(function()
			start()
		end)
		if not ok then
			warn(`[TownLife] {err}`)
		end
	end)
end

return TownLife
