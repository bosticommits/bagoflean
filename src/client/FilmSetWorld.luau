--!strict
-- The film sets on this player's screen (rules in Shared/FilmSets):
--   * The crew and actors shooting on the Dusty Gulch set: Blender puppets (CrewRig) this game
--     builds and moves itself, playing FilmScenes from the server clock, so every player sees the
--     same take. Only moved while the camera is near, and none of it collides.
--   * The gate: its prompt buys the set (FilmSetService checks the Cash and charges). Once this
--     player owns it, their own screen lifts the boom, opens the invisible wall and hides the
--     prompt; other players still see the gate shut and bump into the wall.
-- The clapperboard shows the scene, the take and the title of a film this player is making.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ClientState = require(script.Parent.ClientState)
local UiKit = require(script.Parent.UiKit)
local FilmScenes = require(ReplicatedStorage.Shared.FilmScenes)
local FilmSets = require(ReplicatedStorage.Shared.FilmSets)
local CrewRig = require(ReplicatedStorage.Shared.Models.CrewRig)
local MapModels = require(ReplicatedStorage.Shared.Models.MapModels)

local FilmSetWorld = {}

local NEAR = 240 -- the crew moves while the camera is this close to the action
local ARM_OPEN = math.rad(80) -- how far the boom lifts for owners
local FALLBACK_TITLE = "HOLLYWOOD RNG"

local player = Players.LocalPlayer

local function owns(id: string): boolean
	local list = player:GetAttribute("FilmSets")
	if type(list) ~= "string" then
		return false
	end
	for owned in string.gmatch(list, "[^,]+") do
		if owned == id then
			return true
		end
	end
	return false
end

-- The title of a film this player is making, for the clapperboard.
local function filmTitle(): string
	local studio = ClientState.studio
	if studio ~= nil and type(studio.films) == "table" then
		for _, film in studio.films do
			if type(film) == "table" and type(film.title) == "string" then
				return string.upper(film.title)
			end
		end
	end
	return FALLBACK_TITLE
end

-- The crew ---------------------------------------------------------------------------------------

local function startCrew()
	local folder = Instance.new("Folder")
	folder.Name = "FilmCrew"
	folder.Parent = workspace
	local rigs: { [string]: CrewRig.Rig } = {}
	for _, who in FilmScenes.Cast do
		rigs[who] = CrewRig.build(folder, who)
	end

	local flash = Instance.new("Part")
	flash.Name = "MuzzleFlash"
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.new(1.4, 1.4, 1.4)
	flash.Material = Enum.Material.Neon
	flash.Color = Color3.fromRGB(255, 214, 120)
	flash.Anchored, flash.CanCollide, flash.CanTouch, flash.CanQuery, flash.CastShadow = true, false, false, false, false
	local light = Instance.new("PointLight")
	light.Range = 12
	light.Brightness = 3
	light.Color = flash.Color
	light.Parent = flash

	local base = MapModels.GulchFrame
	local centre = base * FilmScenes.Centre
	local lastBoard = ""
	local moved: { BasePart } = {}
	local targets: { CFrame } = {}
	RunService.Heartbeat:Connect(function()
		local camera = workspace.CurrentCamera
		if camera == nil or (camera.CFrame.Position - centre).Magnitude > NEAR then
			return
		end
		local frame = FilmScenes.frame(workspace:GetServerTimeNow())
		table.clear(moved)
		table.clear(targets)
		for who, rig in rigs do
			local pose = frame.poses[who]
			if pose ~= nil then
				CrewRig.apply(rig, base, pose, frame.stick, frame.say[who], moved, targets)
			end
		end
		workspace:BulkMoveTo(moved, targets, Enum.BulkMoveMode.FireCFrameChanged)

		local shooter = if frame.shot ~= nil then frame.poses[frame.shot] else nil
		if shooter ~= nil then
			flash.CFrame = CrewRig.cframes(base, shooter, 0).Muzzle or CFrame.new(centre)
			flash.Parent = folder
		elseif flash.Parent ~= nil then
			flash.Parent = nil
		end

		local board = rigs.Clapper.board
		local text = `{filmTitle()}\nSCENE {frame.scene}   TAKE {frame.take}`
		if board ~= nil and text ~= lastBoard then
			lastBoard = text
			board.Text = text
		end
	end)
end

-- The gates --------------------------------------------------------------------------------------

type Gate = { id: string, hinge: CFrame, arms: { Model }, walls: { BasePart }, prompts: { ProximityPrompt }, angle: number }

local function startGates(gui: ScreenGui)
	local gates: { [string]: Gate } = {}
	for _, info in MapModels.FilmSets do
		gates[info.id] = { id = info.id, hinge = info.gate * MapModels.GateArmHinge, arms = {}, walls = {}, prompts = {}, angle = 0 }
	end

	-- The gate parts come from the server's town, and can stream out and back in: track them as
	-- they arrive.
	local function track(d: Instance)
		local id = d:GetAttribute("FilmSet")
		local gate = if type(id) == "string" then gates[id] else nil
		if gate == nil then
			return
		end
		if d:IsA("Model") and d.Name == "FilmSetGateArm" then
			table.insert(gate.arms, d)
		elseif d:IsA("BasePart") and d.Name == "FilmSetWall" then
			table.insert(gate.walls, d)
		elseif d:IsA("ProximityPrompt") then
			table.insert(gate.prompts, d)
		end
	end
	local town = workspace:WaitForChild("Town", 30)
	if town == nil then
		return
	end
	for _, d in town:GetDescendants() do
		track(d)
	end
	town.DescendantAdded:Connect(track)

	RunService.Heartbeat:Connect(function(dt: number)
		for id, gate in gates do
			local open = owns(id)
			local target = if open then ARM_OPEN else 0
			if gate.angle ~= target then
				gate.angle = if open then math.min(target, gate.angle + dt * 1.6) else target
			end
			for i = #gate.arms, 1, -1 do
				local arm = gate.arms[i]
				if arm.Parent == nil then
					table.remove(gate.arms, i)
				else
					local want = gate.hinge * CFrame.Angles(0, 0, gate.angle)
					if not arm:GetPivot():FuzzyEq(want, 1e-3) then
						arm:PivotTo(want)
					end
				end
			end
			for i = #gate.walls, 1, -1 do
				local wall = gate.walls[i]
				if wall.Parent == nil then
					table.remove(gate.walls, i)
				elseif wall.CanCollide == open then
					wall.CanCollide = not open
				end
			end
			for i = #gate.prompts, 1, -1 do
				local prompt = gate.prompts[i]
				if prompt.Parent == nil then
					table.remove(gate.prompts, i)
				elseif prompt.Enabled == open then
					prompt.Enabled = not open
				end
			end
		end
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		local id = prompt:GetAttribute("FilmSet")
		local set = if type(id) == "string" then FilmSets.get(id) else nil
		if set == nil or owns(set.id) then
			return
		end
		local cash = player:GetAttribute("Cash")
		if type(cash) == "number" and cash < set.price then
			UiKit.toast(gui, `You need {FilmSets.priceText(set)} to open the {set.name} film set`)
			return
		end
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local buy = if remotes ~= nil then remotes:FindFirstChild("BuyFilmSet") else nil
		if buy ~= nil and buy:IsA("RemoteEvent") then
			buy:FireServer(set.id)
		end
	end)

	-- Say what a new set gives the moment it's bought, and when the bonus starts inside.
	local had: { [string]: boolean } = {}
	for _, set in FilmSets.List do
		had[set.id] = owns(set.id)
	end
	player:GetAttributeChangedSignal("FilmSets"):Connect(function()
		for _, set in FilmSets.List do
			local now = owns(set.id)
			if now and not had[set.id] then
				UiKit.toast(gui, `{set.name} film set is yours! {(string.gsub(FilmSets.describe(set), "\n", ", "))}`)
			end
			had[set.id] = now
		end
	end)
	player:GetAttributeChangedSignal("OnFilmSet"):Connect(function()
		local id = player:GetAttribute("OnFilmSet")
		local set = if type(id) == "string" then FilmSets.get(id) else nil
		if set ~= nil then
			local bonus = if set.boxOffice >= 1 then "double" else `+{math.floor(set.boxOffice * 100 + 0.5)}%`
			UiKit.toast(gui, `On the {set.name} set: your box office pays {bonus} here!`)
		end
	end)
end

function FilmSetWorld.start(gui: ScreenGui)
	startCrew()
	task.spawn(startGates, gui)
end

return FilmSetWorld
