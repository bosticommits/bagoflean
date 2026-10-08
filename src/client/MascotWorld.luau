--!strict
-- Draws every player's studio mascot (Shared/Mascots) trotting along beside them. Purely visual and
-- local: each client builds the mascots itself from the "Mascot" attribute the server sets on each
-- player, and moves them every frame, so they never lag behind over the network or bump into
-- anything. Walking mascots hop, hovering ones (Camera Bot) bob in the air, and an idle mascot
-- turns to face where its owner faces. Mascots far from the camera stop moving to save work.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Mascots = require(ReplicatedStorage.Shared.Mascots)
local MascotModels = require(ReplicatedStorage.Shared.Models.MascotModels)

local MascotWorld = {}

local SIDE = 2.6 -- studs to the owner's right
local BEHIND = 2.2 -- and behind them
local FOLLOW = 7 -- how quickly it catches up (higher is snappier)
local TURN = 9
local SNAP = 40 -- further than this (a teleport, a respawn) and it jumps straight there
local FAR = 220 -- beyond this from the camera it is left where it is
local HOVER = 1.4 -- how high a hovering mascot floats
local GROUND_EVERY = 0.15 -- seconds between ground checks
local INK = Color3.fromRGB(11, 15, 31)

type Follower = {
	model: Model,
	id: string,
	hover: boolean,
	position: Vector3,
	yaw: number,
	ground: number?,
	groundAt: number,
	phase: number,
}

local followers: { [Player]: Follower } = {}
local folder: Folder

local function remove(player: Player)
	local f = followers[player]
	if f ~= nil then
		f.model:Destroy()
		followers[player] = nil
	end
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

-- Where the owner's feet are: the bottom of the root part minus the legs.
local function feetOf(player: Player, root: BasePart): number
	local humanoid = if player.Character ~= nil then player.Character:FindFirstChildOfClass("Humanoid") else nil
	local hip = if humanoid ~= nil then humanoid.HipHeight else 2
	return root.Position.Y - root.Size.Y / 2 - hip
end

local function spawnFor(player: Player)
	remove(player)
	local id = player:GetAttribute("Mascot")
	if type(id) ~= "string" or id == "" then
		return
	end
	local mascot = Mascots.get(id)
	if mascot == nil then
		return
	end
	local model = MascotModels.build(folder, id)
	if model == nil then
		return
	end
	model.Name = player.Name .. "Mascot"
	if not model:GetAttribute("Meshed") then
		-- The part version gets the Blender mesh's dark outline from a Highlight.
		local outline = Instance.new("Highlight")
		outline.FillTransparency = 1
		outline.OutlineColor = INK
		outline.OutlineTransparency = 0
		outline.DepthMode = Enum.HighlightDepthMode.Occluded
		outline.Parent = model
	end
	local root = rootOf(player)
	local start = if root ~= nil then root.CFrame:PointToWorldSpace(Vector3.new(SIDE, 0, BEHIND)) else Vector3.new(0, -500, 0)
	if root ~= nil then
		start = Vector3.new(start.X, feetOf(player, root), start.Z)
	end
	local yaw = 0
	if root ~= nil then
		local look = root.CFrame.LookVector
		yaw = math.atan2(-look.X, -look.Z)
	end
	followers[player] = {
		model = model,
		id = id,
		hover = mascot.hover == true,
		position = start,
		yaw = yaw,
		ground = nil,
		groundAt = 0,
		phase = math.random() * 10,
	}
	model:PivotTo(CFrame.new(start) * CFrame.Angles(0, yaw, 0))
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

-- The ground under a point (the owner's feet height if nothing is found close below).
local function groundUnder(point: Vector3, feet: number): number
	local origin = Vector3.new(point.X, feet + 4, point.Z)
	local hit = workspace:Raycast(origin, Vector3.new(0, -12, 0), rayParams)
	if hit ~= nil and math.abs(hit.Position.Y - feet) < 6 then
		return hit.Position.Y
	end
	return feet
end

local function step(dt: number)
	local camera = workspace.CurrentCamera
	local eye = if camera ~= nil then camera.CFrame.Position else Vector3.zero
	local now = os.clock()
	local exclude: { Instance } = { folder }
	for player in followers do
		if player.Character ~= nil then
			table.insert(exclude, player.Character)
		end
	end
	rayParams.FilterDescendantsInstances = exclude
	for player, f in followers do
		local root = rootOf(player)
		if root == nil or root.Parent == nil then
			continue
		end
		if (root.Position - eye).Magnitude > FAR then
			continue
		end
		local feet = feetOf(player, root)
		local target = root.CFrame:PointToWorldSpace(Vector3.new(SIDE, 0, BEHIND))
		target = Vector3.new(target.X, feet, target.Z)
		local flat = Vector3.new(target.X - f.position.X, 0, target.Z - f.position.Z)
		if flat.Magnitude > SNAP or math.abs(target.Y - f.position.Y) > SNAP then
			f.position = target
		else
			local k = 1 - math.exp(-FOLLOW * dt)
			f.position = f.position:Lerp(target, k)
		end
		if now - f.groundAt > GROUND_EVERY or f.ground == nil then
			f.groundAt = now
			f.ground = groundUnder(f.position, feet)
		end
		local ground = f.ground or feet

		-- Face the way it is going while it moves, else the way its owner faces.
		local speed = flat.Magnitude / math.max(dt, 1 / 240)
		local moving = flat.Magnitude > 0.35
		local wantYaw: number
		if moving then
			wantYaw = math.atan2(-flat.X, -flat.Z)
		else
			local look = root.CFrame.LookVector
			wantYaw = math.atan2(-look.X, -look.Z)
		end
		local diff = (wantYaw - f.yaw + math.pi) % (2 * math.pi) - math.pi
		f.yaw += diff * (1 - math.exp(-TURN * dt))

		f.phase += dt
		local lift, tilt = 0, 0
		if f.hover then
			lift = HOVER + math.sin(f.phase * 2.2) * 0.25
			tilt = math.clamp(speed * 0.02, 0, 0.25)
		elseif moving then
			-- A hop per step; quicker hops when it runs to catch up.
			local rate = math.clamp(8 + speed * 0.4, 8, 14)
			lift = math.abs(math.sin(f.phase * rate)) * 0.55
			tilt = math.sin(f.phase * rate * 2) * 0.06
		else
			lift = math.abs(math.sin(f.phase * 1.6)) * 0.08
		end
		local at = Vector3.new(f.position.X, ground + lift, f.position.Z)
		f.model:PivotTo(CFrame.new(at) * CFrame.Angles(0, f.yaw, 0) * CFrame.Angles(-tilt, 0, if f.hover then 0 else tilt))
	end
end

local function watch(player: Player)
	player:GetAttributeChangedSignal("Mascot"):Connect(function()
		spawnFor(player)
	end)
	player.CharacterAdded:Connect(function()
		-- Wait for the root part so the mascot appears beside the new character.
		local character = player.Character
		if character ~= nil then
			character:WaitForChild("HumanoidRootPart", 10)
		end
		spawnFor(player)
	end)
	spawnFor(player)
end

function MascotWorld.start()
	folder = Instance.new("Folder")
	folder.Name = "Mascots"
	folder.Parent = workspace
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(remove)
	for _, player in Players:GetPlayers() do
		task.spawn(watch, player)
	end
	RunService.RenderStepped:Connect(step)
end

return MascotWorld
