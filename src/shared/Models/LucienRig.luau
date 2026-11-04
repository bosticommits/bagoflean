--!strict
-- Director Lucien Vale as an R15 rig: the fifteen body pieces and his cane from
-- art/blender/lucien.py (Blender meshes once `lucien_kit` is in ReplicatedStorage.LotMeshes, the
-- same shapes as parts until then, through MapKit). Each piece keeps its joint at its own origin,
-- so posing him is plain CFrame maths: every joint turns its piece (and everything hanging from
-- it) in the parent's space. No Humanoid or Animator, so the same code poses him in a
-- ViewportFrame, in the world and in the Lune tests.
--
-- Clips are keyframes of joint turns (degrees, the piece's own X/Y/Z: +X swings a hanging limb
-- forward or tips the head and torso back, +Y turns toward the figure's left, +Z swings a limb
-- toward the figure's right). Missing joints are 0 (standing straight). The cane stands upright
-- on the floor from the right hand while `CaneUpright` is 1, and follows the hand at its `Cane`
-- turn while it is 0 (the twirl).
local MapKit = require(script.Parent.MapKit)
local Build = require(script.Parent.Build)

local LucienRig = {}

export type Pose = { [string]: Vector3 }
export type Key = { time: number, pose: Pose, linear: boolean? }
export type Clip = { duration: number, loop: boolean, keys: { Key } }
export type Rig = {
	model: Model,
	parts: { [string]: { { part: BasePart, offset: CFrame } } },
	meshed: boolean,
}

-- Joints, parents first: the piece, its parent, and where its joint sits in the parent's space
-- at rest (studs). The root (LowerTorso) is at the hips, 2 studs above his feet. Same numbers as
-- JOINTS in art/blender/lucien.py.
LucienRig.Joints = {
	{ piece = "LowerTorso", parent = "", at = Vector3.new(0, 2, 0) },
	{ piece = "UpperTorso", parent = "LowerTorso", at = Vector3.new(0, 0.55, 0) },
	{ piece = "Head", parent = "UpperTorso", at = Vector3.new(0, 1.45, 0) },
	{ piece = "RightUpperArm", parent = "UpperTorso", at = Vector3.new(1.27, 1.3, 0) },
	{ piece = "RightLowerArm", parent = "RightUpperArm", at = Vector3.new(0, -0.85, 0) },
	{ piece = "RightHand", parent = "RightLowerArm", at = Vector3.new(0, -0.75, 0) },
	{ piece = "LeftUpperArm", parent = "UpperTorso", at = Vector3.new(-1.27, 1.3, 0) },
	{ piece = "LeftLowerArm", parent = "LeftUpperArm", at = Vector3.new(0, -0.85, 0) },
	{ piece = "LeftHand", parent = "LeftLowerArm", at = Vector3.new(0, -0.75, 0) },
	{ piece = "RightUpperLeg", parent = "LowerTorso", at = Vector3.new(0.47, 0, 0) },
	{ piece = "RightLowerLeg", parent = "RightUpperLeg", at = Vector3.new(0, -0.95, 0) },
	{ piece = "RightFoot", parent = "RightLowerLeg", at = Vector3.new(0, -0.75, 0) },
	{ piece = "LeftUpperLeg", parent = "LowerTorso", at = Vector3.new(-0.47, 0, 0) },
	{ piece = "LeftLowerLeg", parent = "LeftUpperLeg", at = Vector3.new(0, -0.95, 0) },
	{ piece = "LeftFoot", parent = "LeftLowerLeg", at = Vector3.new(0, -0.75, 0) },
	{ piece = "Cane", parent = "RightHand", at = Vector3.new(0, -0.25, -0.05) },
}

-- Pose keys that are not joints: the root's move (studs) and the cane's upright weight (X).
local EXTRA = { RootOffset = true, CaneUpright = true }

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

-- Holding the cane: the right arm a little forward and out, the cane upright beside him.
local HOLD: Pose = {
	RightUpperArm = v(8, 0, 6),
	RightLowerArm = v(14, 0, 0),
	CaneUpright = v(1, 0, 0),
	LeftUpperArm = v(2, 0, -4),
}

local function with(base: Pose, changes: Pose): Pose
	local out: Pose = table.clone(base)
	for key, value in changes do
		out[key] = value
	end
	return out
end

-- The talk gestures: the free (left) hand opens out and comes back while his head nods along.
local function talkKey(t: number, upper: Vector3, lower: Vector3, head: Vector3, chest: Vector3): Key
	return { time = t, pose = with(HOLD, { LeftUpperArm = upper, LeftLowerArm = lower, Head = head, UpperTorso = chest }) }
end

-- One full stride: right leg forward, passing, left leg forward, passing. The left arm swings
-- opposite the legs; the right one keeps the cane, swinging it a little.
local function stride(side: number, t: number): Key
	return {
		time = t,
		pose = {
			RightUpperLeg = v(24 * side, 0, 0),
			RightLowerLeg = v(if side > 0 then -6 else -28, 0, 0),
			LeftUpperLeg = v(-24 * side, 0, 0),
			LeftLowerLeg = v(if side > 0 then -28 else -6, 0, 0),
			RightFoot = v(if side > 0 then 10 else 0, 0, 0),
			LeftFoot = v(if side > 0 then 0 else 10, 0, 0),
			LeftUpperArm = v(22 * side, 0, -4),
			LeftLowerArm = v(12, 0, 0),
			RightUpperArm = v(-10 * side, 0, 6),
			RightLowerArm = v(14, 0, 0),
			Cane = v(-14 * side, 0, 0),
			UpperTorso = v(-3, 6 * side, 0),
			RootOffset = v(0, 0, 0),
		},
	}
end
local function passing(t: number): Key
	return {
		time = t,
		pose = {
			RightUpperLeg = v(0, 0, 0),
			RightLowerLeg = v(-14, 0, 0),
			LeftUpperLeg = v(0, 0, 0),
			LeftLowerLeg = v(-14, 0, 0),
			LeftUpperArm = v(0, 0, -4),
			LeftLowerArm = v(12, 0, 0),
			RightUpperArm = v(0, 0, 6),
			RightLowerArm = v(14, 0, 0),
			UpperTorso = v(-3, 0, 0),
			RootOffset = v(0, 0.07, 0),
		},
	}
end

LucienRig.Clips = {
	-- Breathing: the chest rises, the head settles, the free hand sways a touch.
	idle = {
		duration = 3.2,
		loop = true,
		keys = {
			{ time = 0, pose = with(HOLD, { UpperTorso = v(0, 0, 0), Head = v(-2, 0, 0) }) },
			{ time = 1.6, pose = with(HOLD, { UpperTorso = v(2, 0, 0), Head = v(1, 3, 1), LeftUpperArm = v(3, 0, -6), RootOffset = v(0, 0.03, 0) }) },
			{ time = 3.2, pose = with(HOLD, { UpperTorso = v(0, 0, 0), Head = v(-2, 0, 0) }) },
		},
	} :: Clip,
	walk = {
		duration = 0.9,
		loop = true,
		keys = { stride(1, 0), passing(0.225), stride(-1, 0.45), passing(0.675), stride(1, 0.9) },
	} :: Clip,
	-- A big wave with the free hand, head tipped toward it, then back to holding the cane.
	wave = {
		duration = 2.4,
		loop = false,
		keys = {
			{ time = 0, pose = HOLD },
			{ time = 0.55, pose = with(HOLD, { LeftUpperArm = v(10, 0, -150), LeftLowerArm = v(0, 0, -18), Head = v(2, -8, -4) }) },
			{ time = 0.8, pose = with(HOLD, { LeftUpperArm = v(10, 0, -152), LeftLowerArm = v(0, 0, 20), Head = v(2, -8, -4) }) },
			{ time = 1.05, pose = with(HOLD, { LeftUpperArm = v(10, 0, -150), LeftLowerArm = v(0, 0, -22), Head = v(2, -8, -4) }) },
			{ time = 1.3, pose = with(HOLD, { LeftUpperArm = v(10, 0, -152), LeftLowerArm = v(0, 0, 20), Head = v(2, -8, -4) }) },
			{ time = 1.55, pose = with(HOLD, { LeftUpperArm = v(10, 0, -150), LeftLowerArm = v(0, 0, -16), Head = v(2, -6, -3) }) },
			{ time = 2.15, pose = HOLD },
			{ time = 2.4, pose = HOLD },
		},
	} :: Clip,
	-- The cane twirl: the right arm comes forward, the cane swings across and spins twice like a
	-- baton (facing the camera), then plants back on the floor. Linear keys keep the spin even.
	twirl = {
		duration = 2.0,
		loop = false,
		keys = {
			{ time = 0, pose = HOLD },
			{ time = 0.3, pose = with(HOLD, { RightUpperArm = v(72, 0, 10), RightLowerArm = v(8, 0, 0), CaneUpright = v(0, 0, 0), Cane = v(0, 0, 90), Head = v(-4, 6, 0) }) },
			{ time = 0.55, linear = true, pose = with(HOLD, { RightUpperArm = v(74, 0, 10), RightLowerArm = v(8, 0, 0), CaneUpright = v(0, 0, 0), Cane = v(0, 180, 90), Head = v(-4, 6, 0) }) },
			{ time = 0.8, linear = true, pose = with(HOLD, { RightUpperArm = v(72, 0, 10), RightLowerArm = v(8, 0, 0), CaneUpright = v(0, 0, 0), Cane = v(0, 360, 90), Head = v(-4, 6, 0) }) },
			{ time = 1.05, linear = true, pose = with(HOLD, { RightUpperArm = v(74, 0, 10), RightLowerArm = v(8, 0, 0), CaneUpright = v(0, 0, 0), Cane = v(0, 540, 90), Head = v(-4, 6, 0) }) },
			{ time = 1.3, pose = with(HOLD, { RightUpperArm = v(72, 0, 10), RightLowerArm = v(8, 0, 0), CaneUpright = v(0, 0, 0), Cane = v(0, 720, 90), Head = v(-4, 4, 0) }) },
			{ time = 1.7, pose = with(HOLD, { Cane = v(0, 720, 0) }) },
			{ time = 2.0, pose = with(HOLD, { Cane = v(0, 720, 0) }) },
		},
	} :: Clip,
	talk = {
		duration = 3.2,
		loop = true,
		keys = {
			talkKey(0, v(14, 0, -10), v(58, 0, 0), v(-3, 0, 0), v(0, 0, 0)),
			talkKey(0.8, v(26, 0, -30), v(40, -20, 0), v(-6, -6, 0), v(1, -4, 0)),
			talkKey(1.6, v(10, 0, -8), v(66, 0, 0), v(2, 4, 0), v(0, 3, 0)),
			talkKey(2.4, v(22, 0, -26), v(46, -14, 0), v(-4, 0, 2), v(1, -2, 0)),
			talkKey(3.2, v(14, 0, -10), v(58, 0, 0), v(-3, 0, 0), v(0, 0, 0)),
		},
	} :: Clip,
}

local function smooth(t: number): number
	return t * t * (3 - 2 * t)
end

-- The pose `clip` is in `t` seconds after it started (looping clips wrap; others hold their end).
function LucienRig.sample(clip: Clip, t: number): Pose
	local keys = clip.keys
	local time = if clip.loop then t % clip.duration else math.clamp(t, 0, clip.duration)
	local index = #keys
	for i = 2, #keys do
		if time <= keys[i].time then
			index = i
			break
		end
	end
	local a, b = keys[math.max(index - 1, 1)], keys[index]
	local span = b.time - a.time
	local alpha = if span > 0 then math.clamp((time - a.time) / span, 0, 1) else 1
	if not b.linear then
		alpha = smooth(alpha)
	end
	return LucienRig.blend(a.pose, b.pose, alpha)
end

-- `a` turned `w` of the way to `b`, joint by joint (missing joints count as 0; a missing
-- CaneUpright counts as 1, standing on the cane).
function LucienRig.blend(a: Pose, b: Pose, w: number): Pose
	local out: Pose = {}
	local function default(key: string): Vector3
		return if key == "CaneUpright" then v(1, 0, 0) else Vector3.zero
	end
	local seen: { [string]: boolean } = {}
	for key, value in a do
		seen[key] = true
		out[key] = value:Lerp(b[key] or default(key), w)
	end
	for key, value in b do
		if not seen[key] then
			out[key] = default(key):Lerp(value, w)
		end
	end
	return out
end

local function turn(angles: Vector3?): CFrame
	if angles == nil then
		return CFrame.identity
	end
	return CFrame.Angles(math.rad(angles.X), math.rad(angles.Y), math.rad(angles.Z))
end

-- Every piece's CFrame (at its joint) for `pose`, with his feet at `base`.
function LucienRig.solve(pose: Pose, base: CFrame): { [string]: CFrame }
	local frames: { [string]: CFrame } = {}
	local root = base * CFrame.new(pose.RootOffset or Vector3.zero)
	for _, joint in LucienRig.Joints do
		local parent = if joint.parent == "" then root else frames[joint.parent]
		frames[joint.piece] = parent * CFrame.new(joint.at) * turn(pose[joint.piece])
	end
	-- The cane: from the hand at its turn, or standing upright (base's rotation) from the grip.
	local upright = math.clamp((pose.CaneUpright or v(1, 0, 0)).X, 0, 1)
	if upright > 0 then
		local cane = frames.Cane
		local standing = base.Rotation + cane.Position
		frames.Cane = cane:Lerp(standing, upright)
	end
	return frames
end

-- Is `key` something a pose may hold (a joint or one of the extras)?
function LucienRig.isKey(key: string): boolean
	if EXTRA[key] then
		return true
	end
	for _, joint in LucienRig.Joints do
		if joint.piece == key then
			return true
		end
	end
	return false
end

-- Builds Lucien's pieces into a new Model under `parent` (at rest until `apply` poses him).
-- `only` limits it to some pieces (a portrait).
function LucienRig.build(parent: Instance, only: { [string]: boolean }?): Rig
	local model = Instance.new("Model")
	model.Name = "DirectorLucienVale"
	local b = Build.new(model, CFrame.identity)
	local parts: { [string]: { { part: BasePart, offset: CFrame } } } = {}
	local meshed = false
	for _, joint in LucienRig.Joints do
		if only ~= nil and not only[joint.piece] then
			continue
		end
		local piece = MapKit.place(b, "Lucien" .. joint.piece, CFrame.identity, { solid = false })
		piece.Name = joint.piece
		meshed = meshed or piece:GetAttribute("Meshed") == true
		local list = {}
		for _, d in piece:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanTouch = false
				d.CanQuery = false
				d.CastShadow = false
				table.insert(list, { part = d, offset = d.CFrame })
			end
		end
		parts[joint.piece] = list
	end
	if meshed then
		model:SetAttribute("Meshed", true)
	end
	model.Parent = parent
	return { model = model, parts = parts, meshed = meshed }
end

-- Puts the rig in `pose` with his feet at `base`.
function LucienRig.apply(rig: Rig, base: CFrame, pose: Pose)
	local frames = LucienRig.solve(pose, base)
	for piece, list in rig.parts do
		local frame = frames[piece]
		for _, entry in list do
			entry.part.CFrame = frame * entry.offset
		end
	end
	rig.model.WorldPivot = base
end

return LucienRig
