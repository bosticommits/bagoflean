--!strict
-- The film crew's puppets: each person on the film set is six Blender pieces from the map kit
-- (Crew<Who>Head, Torso, Arm, Leg, from art/blender/crew_kit.py; the arm and leg are used for both
-- sides) and the props they can hold in the right hand. CrewRig puts the pieces together and turns
-- them at their joints for a FilmScenes pose. Each piece keeps its joint at its own origin: the
-- legs hang from the hips, the arms from the shoulders, the torso stands on the hips and the head
-- on the neck (body sizes in FilmScenes.Body). A prop points the way the arm does, straight ahead
-- (`level`) or at a spot (`aim`, the boom pole).
local Build = require(script.Parent.Build)
local FilmScenes = require(script.Parent.Parent.FilmScenes)
local MapKit = require(script.Parent.MapKit)

local CrewRig = {}

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

-- Where each piece goes for `pose`, with `base` the film set's space (MapModels.FilmSets[...].frame).
-- Pure CFrame math (FilmScenes.pieces); FilmSetWorld moves the parts there and tests check it.
function CrewRig.cframes(base: CFrame, pose: FilmScenes.Pose, stick: number): { [string]: CFrame }
	return FilmScenes.pieces(base, pose, stick)
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

-- Builds `who` (one of a set's FilmScenes cast) into `parent`, standing at the origin, with the
-- props they can hold (FilmScenes.Sets[...].props[who]).
function CrewRig.build(parent: Instance, who: string, kits: { string }?): Rig
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
	for _, kit in kits or ({} :: { string }) do
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
