--!strict
-- Brings the actors standing round town to life: the star on each lot's pedestal, the store
-- keepers and the Top Studios wall breathe with a little bob, look round, sway their arms and now
-- and then wave hello. The Phantom Auteur hovers instead.
--
-- ActorModels splits every figure into rig pieces (Body, Head, ArmL, ArmR, Base) and tags it
-- "ActorRig"; this turns the pieces round their pivots. Each player moves their own view of the
-- figures, so it costs the server nothing. Only figures near the camera move, 30 times a second.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ActorLife = {}

local RANGE = 120 -- studs from the camera
local STEP = 1 / 30 -- seconds between updates
local WAVE_TIME = 2.4
local PIECES = { "Body", "Head", "ArmL", "ArmR" }

type Rig = {
	model: Model,
	root: CFrame,
	parts: { BasePart },
	pieces: { string },
	rest: { CFrame },
	pivots: { [string]: Vector3 },
	scale: number,
	wave: string?,
	float: boolean,
	phase: number,
	nextWave: number,
	waveStart: number,
	still: boolean, -- left at rest (out of range)
}

local rigs: { [Model]: Rig } = {}
local random = Random.new()

local function register(model: Instance)
	if not model:IsA("Model") or rigs[model] ~= nil or not model:IsDescendantOf(Workspace) then
		return
	end
	local root = model.WorldPivot
	local rig: Rig = {
		model = model,
		root = root,
		parts = {},
		pieces = {},
		rest = {},
		pivots = {},
		scale = model:GetAttribute("RigScale") :: number? or 1,
		wave = model:GetAttribute("Wave") :: string?,
		float = model:GetAttribute("Float") == true,
		phase = random:NextNumber(0, 10),
		nextWave = os.clock() + random:NextNumber(2, 10),
		waveStart = -math.huge,
		still = true,
	}
	for _, name in PIECES do
		rig.pivots[name] = model:GetAttribute("Pivot" .. name) :: Vector3? or Vector3.zero
	end
	local function add(d: Instance)
		if d:IsA("BasePart") then
			local piece = d:GetAttribute("Piece") :: string?
			if piece ~= nil and piece ~= "Base" then
				table.insert(rig.parts, d)
				table.insert(rig.pieces, piece)
				-- Where it rests: as the server built it (parts that stream in later arrive there).
				table.insert(rig.rest, root:ToObjectSpace(d.CFrame))
			end
		end
	end
	for _, d in model:GetDescendants() do
		add(d)
	end
	model.DescendantAdded:Connect(add)
	rigs[model] = rig
end

-- Turn `rotation` round `pivot` (both in the figure's own space).
local function about(pivot: Vector3, rotation: CFrame): CFrame
	return CFrame.new(pivot) * rotation * CFrame.new(-pivot)
end

-- How far into a wave: 0 at rest, rising to 1, holding, then back down.
local function waveAmount(rig: Rig, now: number): number
	local p = (now - rig.waveStart) / WAVE_TIME
	if p < 0 or p > 1 then
		return 0
	end
	return math.min(1, p * 5, (1 - p) * 5)
end

local function pose(rig: Rig, now: number): { [string]: CFrame }
	local t = now + rig.phase
	local k = rig.scale
	local lift = if rig.float then (0.25 + math.sin(t * 1.4) * 0.25) * k else math.abs(math.sin(t * 2.2)) * 0.06 * k
	local body = CFrame.new(0, lift, 0) * about(rig.pivots.Body, CFrame.Angles(0, 0, math.sin(t * 1.1) * math.rad(2)))
	local head = body * about(rig.pivots.Head, CFrame.Angles(math.sin(t * 0.7) * math.rad(4), math.sin(t * 0.45) * math.rad(10), math.sin(t * 1.1) * math.rad(3)))
	local out = { Body = body, Head = head }
	local waving = waveAmount(rig, now)
	for _, arm in { "ArmL", "ArmR" } do
		local pivot = rig.pivots[arm]
		local out_ = if pivot.X >= 0 then 1 else -1 -- which way is outwards
		local swing = math.sin(t * 2.2 + pivot.X) * math.rad(4)
		local turn = CFrame.Angles(swing, 0, 0)
		if arm == rig.wave and waving > 0 then
			-- Up and out to the side, then a wave back and forth.
			local raise = math.rad(140) * waving + math.sin(now * 12) * math.rad(18) * waving
			turn = CFrame.Angles(0, 0, out_ * raise) * turn
		end
		out[arm] = body * about(pivot, turn)
	end
	return out
end

local function step()
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	local eye = camera.CFrame.Position
	local now = os.clock()
	local parts: { BasePart } = {}
	local frames: { CFrame } = {}
	for model, rig in rigs do
		if model.Parent == nil then
			rigs[model] = nil
			continue
		end
		local near = (rig.root.Position - eye).Magnitude < RANGE * math.max(rig.scale, 1)
		if not near then
			if not rig.still then
				-- Back to rest, so a figure far away isn't left mid-wave.
				for i, part in rig.parts do
					if part.Parent ~= nil then
						table.insert(parts, part)
						table.insert(frames, rig.root * rig.rest[i])
					end
				end
				rig.still = true
			end
			continue
		end
		rig.still = false
		if rig.wave ~= nil and now >= rig.nextWave then
			rig.waveStart = now
			rig.nextWave = now + WAVE_TIME + random:NextNumber(6, 14)
		end
		local offsets = pose(rig, now)
		for i, part in rig.parts do
			if part.Parent ~= nil then -- streamed out
				table.insert(parts, part)
				table.insert(frames, rig.root * (offsets[rig.pieces[i]] or CFrame.identity) * rig.rest[i])
			end
		end
	end
	if #parts > 0 then
		Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

function ActorLife.start()
	for _, model in CollectionService:GetTagged("ActorRig") do
		register(model)
	end
	CollectionService:GetInstanceAddedSignal("ActorRig"):Connect(function(model)
		-- The parts are already in it: ActorModels tags the model before parenting it.
		register(model)
	end)
	CollectionService:GetInstanceRemovedSignal("ActorRig"):Connect(function(model)
		if model:IsA("Model") then
			rigs[model] = nil
		end
	end)
	local wait = 0
	RunService.Heartbeat:Connect(function(dt)
		wait += dt
		if wait < STEP then
			return
		end
		wait = 0
		step()
	end)
end

return ActorLife
