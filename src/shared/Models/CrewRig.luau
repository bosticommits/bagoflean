--!strict
-- The film crew's puppets: each person on the film set is six Blender pieces from the map kit
-- (Crew<Who>Head, Torso, Arm, Leg, from art/blender/crew_kit.py; the arm and leg are used for both
-- sides) and a prop for the right hand. CrewRig puts the pieces together and turns them at their
-- joints for a FilmScenes pose. Each piece keeps its joint at its own origin: the legs hang from
-- the hips, the arms from the shoulders, the torso stands on the hips and the head on the neck.
--
-- Body (studs, the feet at y = 0, facing -Z): hips 2 up, shoulders 1.75 above the hips and 1.2 out,
-- the neck 2.1 above the hips. A prop's grip is 1.6 down the arm from the shoulder, and it points
-- the way the arm does (or straight ahead, for a `level` prop).
local Build = require(script.Parent.Build)
local FilmScenes = require(script.Parent.Parent.FilmScenes)
local MapKit = require(script.Parent.MapKit)

local CrewRig = {}

local HIPS = 2
local HIP_OUT = 0.45
local SHOULDER = Vector3.new(1.2, 1.75, 0)
local NECK = 2.1
local GRIP = 1.6
-- The clapperboard's hinged top, in the grip's space: its hinge at the board's top-left corner.
local STICK_HINGE = CFrame.new(-1.2, -0.3, -2.05) * CFrame.Angles(-math.pi / 2, 0, 0)
local MUZZLE = CFrame.new(0, -1.5, -0.05) -- the revolver's muzzle, in the grip's space

local PROPS: { [string]: { string } } = {
	Director = { "PropMegaphone" },
	Clapper = { "PropClapper" },
	Sheriff = { "PropRevolver" },
	Outlaw = { "PropRevolver" },
}

export type Rig = {
	who: string,
	model: Model,
	home: Instance, -- where the model goes while the person is on set
	-- Every part with its place in its piece's space, by piece (Head, Torso, ArmL, ArmR, LegL, LegR,
	-- a prop's kit name, Stick).
	parts: { [string]: { { part: BasePart, offset: CFrame } } },
	props: { [string]: Model },
	board: TextLabel?, -- the clapperboard's chalk writing
	bubble: TextLabel, -- the speech bubble over the head
	bubbleGui: BillboardGui,
}

-- Where each piece goes for `pose`, with `base` the film set's space (MapModels.GulchFrame).
-- Pure CFrame math; FilmSetWorld moves the parts there and tests check it.
function CrewRig.cframes(base: CFrame, pose: FilmScenes.Pose, stick: number): { [string]: CFrame }
	local root = base * CFrame.new(pose.at) * CFrame.Angles(0, math.rad(pose.yaw), 0)
	if pose.tilt ~= 0 then
		root = root * CFrame.new(0, pose.pivot, 0) * CFrame.Angles(pose.tilt, 0, 0) * CFrame.new(0, -pose.pivot, 0)
	end
	local torso = root * CFrame.new(0, HIPS, 0)
	local out: { [string]: CFrame } = {
		Torso = torso,
		Head = torso * CFrame.new(0, NECK, 0) * CFrame.Angles(0, pose.head, 0),
		LegL = root * CFrame.new(-HIP_OUT, HIPS, 0) * CFrame.Angles(pose.legs[1], 0, 0),
		LegR = root * CFrame.new(HIP_OUT, HIPS, 0) * CFrame.Angles(pose.legs[2], 0, 0),
	}
	-- The character's right is +X (it faces -Z); an arm swings out to its own side.
	for i, side in { -1, 1 } do
		local arm = pose.arms[i]
		local shoulder = CFrame.new(SHOULDER.X * side, SHOULDER.Y, SHOULDER.Z)
		out[if side < 0 then "ArmL" else "ArmR"] = torso * shoulder * CFrame.Angles(arm[1], 0, 0) * CFrame.Angles(0, 0, side * arm[2])
	end
	if pose.hold ~= nil then
		local grip = out.ArmR * CFrame.new(0, -GRIP, 0)
		if pose.level then
			grip = CFrame.new(grip.Position) * root.Rotation * CFrame.Angles(math.pi / 2, 0, 0)
		end
		out[pose.hold] = grip
		if pose.hold == "PropClapper" then
			out.Stick = grip * STICK_HINGE * CFrame.Angles(0, 0, stick)
		elseif pose.hold == "PropRevolver" then
			out.Muzzle = grip * MUZZLE
		end
	end
	return out
end

local function collect(model: Model, pivot: CFrame): { { part: BasePart, offset: CFrame } }
	local list = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			table.insert(list, { part = d, offset = pivot:ToObjectSpace(d.CFrame) })
		end
	end
	return list
end

-- Builds `who` (one of FilmScenes.Cast) into `parent`, standing at the origin.
function CrewRig.build(parent: Instance, who: string): Rig
	local model = Instance.new("Model")
	model.Name = "Crew" .. who
	local b = Build.new(model, CFrame.identity)
	local parts: { [string]: { { part: BasePart, offset: CFrame } } } = {}
	local function piece(key: string, kit: string, labels: { [string]: MapKit.Label }?): Model
		local m = MapKit.place(b, kit, CFrame.identity, { solid = false, labels = labels })
		m.Name = key
		parts[key] = collect(m, CFrame.identity)
		return m
	end
	local head = piece("Head", `Crew{who}Head`)
	piece("Torso", `Crew{who}Torso`)
	piece("ArmL", `Crew{who}Arm`)
	piece("ArmR", `Crew{who}Arm`)
	piece("LegL", `Crew{who}Leg`)
	piece("LegR", `Crew{who}Leg`)

	-- The speech bubble rides above the head.
	local anchor = Instance.new("Part")
	anchor.Name = "BubbleAnchor"
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Transparency = 1
	anchor.CFrame = CFrame.new(0, 3, 0)
	anchor.Parent = head
	table.insert(parts.Head, { part = anchor :: BasePart, offset = anchor.CFrame })
	anchor.Anchored, anchor.CanCollide, anchor.CanTouch, anchor.CanQuery = true, false, false, false
	local gui = Instance.new("BillboardGui")
	gui.Name = "Bubble"
	gui.Size = UDim2.fromScale(7, 1.6)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 0.6, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 140
	gui.Enabled = false
	gui.Adornee = anchor
	gui.Parent = anchor
	local bubble = Instance.new("TextLabel")
	bubble.Size = UDim2.fromScale(1, 1)
	bubble.BackgroundColor3 = Color3.new(1, 1, 1)
	bubble.TextColor3 = Color3.fromRGB(11, 15, 31)
	bubble.Font = Enum.Font.FredokaOne
	bubble.TextScaled = true
	bubble.Text = ""
	bubble.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.4, 0)
	corner.Parent = bubble
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(11, 15, 31)
	stroke.Thickness = 3
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = bubble

	local props: { [string]: Model } = {}
	local board: TextLabel? = nil
	local kits: { string } = PROPS[who] or {}
	for _, kit in kits do
		local labels: { [string]: MapKit.Label }? = if kit == "PropClapper"
			then { Board = { text = "", color = Color3.new(1, 1, 1), stroke = 0 } :: MapKit.Label }
			else nil
		props[kit] = piece(kit, kit, labels)
		if kit == "PropClapper" then
			board = props[kit]:FindFirstChildWhichIsA("TextLabel", true)
			local stick = piece("Stick", "PropClapperStick")
			stick.Parent = props[kit]
		end
	end
	for _, prop in props do
		prop.Parent = nil -- out of sight until a pose holds it
	end

	model.Parent = parent
	return { who = who, model = model, home = parent, parts = parts, props = props, board = board, bubble = bubble, bubbleGui = gui }
end

-- Puts the rig in `pose` (see CrewRig.cframes), shows the prop it holds and its speech bubble.
-- `moved` and `targets` are scratch lists, so a frame of moves goes to workspace:BulkMoveTo at once.
function CrewRig.apply(rig: Rig, base: CFrame, pose: FilmScenes.Pose, stick: number, say: string?, moved: { BasePart }, targets: { CFrame })
	for kit, prop in rig.props do
		local shown = pose.hold == kit and not pose.hidden
		local want: Instance? = if shown then rig.model else nil
		if prop.Parent ~= want then
			prop.Parent = want
		end
	end
	local onSet: Instance? = if pose.hidden then nil else rig.home
	if rig.model.Parent ~= onSet then
		rig.model.Parent = onSet
	end
	if pose.hidden then
		return
	end
	local where = CrewRig.cframes(base, pose, stick)
	for key, cf in where do
		local list = rig.parts[key]
		if list ~= nil then
			for _, entry in list do
				table.insert(moved, entry.part)
				table.insert(targets, cf * entry.offset)
			end
		end
	end
	local showSay = say ~= nil
	if rig.bubbleGui.Enabled ~= showSay then
		rig.bubbleGui.Enabled = showSay
	end
	if say ~= nil and rig.bubble.Text ~= say then
		rig.bubble.Text = say
	end
end

return CrewRig
