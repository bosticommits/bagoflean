--!strict
-- Draws every player's studio mascot (Shared/Mascots) trotting along beside them. Purely visual and
-- local: each client builds the mascots itself from the "Mascot" attribute the server sets on each
-- player, and moves them every frame, so they never lag behind over the network or bump into
-- anything. Walking mascots hop, hovering ones (Camera Bot) bob in the air, and an idle mascot
-- turns to face where its owner faces. Mascots far from the camera stop moving to save work.
--
-- Height has its own little physics so a mascot never sticks to its owner in mid-air: it stands on
-- the ground under itself, jumps a moment after its owner jumps, leaps up onto a ledge its owner
-- climbed, and falls with gravity when it walks off one. Hovering mascots use the same rules with
-- softer gravity, so they drift up and settle back.
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
local GRAVITY = 150 -- studs/s² pulling a jumping mascot down (a little floatier than a player)
local HOVER_GRAVITY = 60 -- hovering mascots drift down slower
local HOP = 4.2 -- how high a mascot jumps when its owner jumps
local HOVER_HOP = 2.6
local JUMP_DELAY = 0.08 -- seconds after its owner leaves the ground, so it reads as following
local OWNER_JUMP = 18 -- owner's upward speed (studs/s) that counts as a jump (a jump starts near 50)
local STANDING = 2 -- owner's vertical speed below this means they are standing on something
local STEP_UP = 1.6 -- ground this much higher than the mascot's feet needs a jump, lower is a step
local STEP_DOWN = 0.8 -- ground this much lower and it falls instead of walking down
local STEP_SPEED = 18 -- how fast it walks up or down small steps (higher is snappier)
local LAND_TIME = 0.16 -- seconds of the little nod when it lands
local INK = Color3.fromRGB(11, 15, 31)

type Follower = {
	model: Model,
	id: string,
	hover: boolean,
	position: Vector3, -- where it is across the ground; the height is `y`
	y: number, -- the height of its feet
	vy: number, -- how fast it is going up (negative is falling)
	grounded: boolean,
	jumpAt: number?, -- when it will copy its owner's jump
	floor: number, -- the last height its owner stood at
	ownerVy: number, -- its owner's vertical speed last frame, to spot the start of a jump
	landedAt: number,
	yaw: number,
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
		y = start.Y,
		vy = 0,
		grounded = false, -- drops onto whatever is under it on the first frame
		jumpAt = nil,
		floor = start.Y,
		ownerVy = 0,
		landedAt = -math.huge,
		yaw = yaw,
		phase = math.random() * 10,
	}
	model:PivotTo(CFrame.new(start) * CFrame.Angles(0, yaw, 0))
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true
rayParams.RespectCanCollide = true -- leaves, beams and other walk-through decor are not ground

-- The top of the ground under (x, z), looking down from `from`. Starting just above the mascot or
-- its owner, whichever is higher, keeps roofs and arches overhead from counting as ground.
local function groundAt(x: number, z: number, from: number): number?
	local hit = workspace:Raycast(Vector3.new(x, from, z), Vector3.new(0, -60, 0), rayParams)
	return if hit ~= nil then hit.Position.Y else nil
end

local function jump(f: Follower, height: number)
	local gravity = if f.hover then HOVER_GRAVITY else GRAVITY
	f.vy = math.sqrt(2 * gravity * height)
	f.grounded = false
	f.jumpAt = nil
end

-- Moves one mascot's height for this frame: standing, stepping, jumping or falling.
local function moveHeight(f: Follower, root: BasePart, feet: number, now: number, dt: number)
	local ownerVy = root.AssemblyLinearVelocity.Y
	if math.abs(ownerVy) < STANDING then
		f.floor = feet
	end
	-- The owner just jumped: copy it a moment later (not again until this one lands).
	if ownerVy > OWNER_JUMP and f.ownerVy <= OWNER_JUMP and f.grounded and f.jumpAt == nil then
		f.jumpAt = now + JUMP_DELAY
	end
	f.ownerVy = ownerVy

	local ground = groundAt(f.position.X, f.position.Z, math.max(f.y, f.floor) + 3.5) or f.floor
	if f.grounded then
		if f.jumpAt ~= nil and now >= f.jumpAt then
			jump(f, if f.hover then HOVER_HOP else HOP)
		elseif ground > f.y + STEP_UP then
			-- A ledge its owner climbed: leap just over it.
			jump(f, ground - f.y + 1.2)
		elseif ground < f.y - STEP_DOWN then
			f.grounded = false
			f.vy = 0
		else
			f.y += (ground - f.y) * (1 - math.exp(-STEP_SPEED * dt))
		end
	end
	if not f.grounded then
		f.vy -= (if f.hover then HOVER_GRAVITY else GRAVITY) * dt
		f.y += f.vy * dt
		if f.vy <= 0 and f.y <= ground then
			f.y = ground
			f.vy = 0
			f.grounded = true
			f.landedAt = now
		end
	end
	if f.jumpAt ~= nil and now - f.jumpAt > 0.4 then
		f.jumpAt = nil -- it was still in the air; skip this jump rather than hop late
	end
end

local function step(dt: number)
	dt = math.min(dt, 1 / 15) -- a long hitch would otherwise fling a falling mascot through the floor
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
		if flat.Magnitude > SNAP or math.abs(feet - f.y) > SNAP then
			-- A teleport or respawn: appear beside the owner and drop onto the ground there.
			f.position = target
			f.y = feet
			f.floor = feet
			f.vy = 0
			f.grounded = false
			f.jumpAt = nil
		else
			local k = 1 - math.exp(-FOLLOW * dt)
			f.position = f.position:Lerp(target, k)
		end
		moveHeight(f, root, feet, now, dt)

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
		local lift, tilt, pitch = 0, 0, 0
		if f.hover then
			lift = HOVER + math.sin(f.phase * 2.2) * 0.25
			pitch = math.clamp(speed * 0.02, 0, 0.25)
		elseif not f.grounded then
			-- Nose up on the way up, down on the way down.
			pitch = math.clamp(-f.vy * 0.012, -0.3, 0.3)
		elseif moving then
			-- A hop per step; quicker hops when it runs to catch up.
			local rate = math.clamp(8 + speed * 0.4, 8, 14)
			lift = math.abs(math.sin(f.phase * rate)) * 0.55
			tilt = math.sin(f.phase * rate * 2) * 0.06
		else
			lift = math.abs(math.sin(f.phase * 1.6)) * 0.08
		end
		local sinceLand = now - f.landedAt
		if not f.hover and sinceLand < LAND_TIME then
			pitch += math.sin(sinceLand / LAND_TIME * math.pi) * 0.18 -- a little nod as it lands
		end
		local at = Vector3.new(f.position.X, f.y + lift, f.position.Z)
		f.model:PivotTo(CFrame.new(at) * CFrame.Angles(0, f.yaw, 0) * CFrame.Angles(-pitch, 0, tilt))
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
