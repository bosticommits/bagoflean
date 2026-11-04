--!strict
-- The camera for the premiere show: takes the camera from the player (character and controls stay
-- put), glides it along a curve that first rises out of roofs, and always gives it back. `restore`
-- is safe to call any number of times and runs on death and respawn, so the player is never stuck
-- behind a Scriptable camera. The last shot is re-applied every frame, so Fx.shake (one render
-- priority later) never drifts it.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local PremiereCamera = {}

local BIND = "PremiereCamera"

type Saved = { cframe: CFrame, fov: number, cameraType: Enum.CameraType, subject: Instance? }
type Move = { from: CFrame, to: CFrame, lift: Vector3, fov0: number, fov1: number, start: number, seconds: number, style: Enum.EasingStyle, dir: Enum.EasingDirection }

local saved: Saved? = nil
local move: Move? = nil
local pose: CFrame = CFrame.identity -- where the camera is without shake
local fov = 70
local connections: { RBXScriptConnection } = {}
local restoredEvent = Instance.new("BindableEvent")
-- Fires after every restore that actually gave the camera back (death and respawn included).
PremiereCamera.restored = restoredEvent.Event

local function controls(on: boolean)
	pcall(function()
		local module = require(Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 2) :: ModuleScript) :: any
		local c = module:GetControls()
		if on then
			c:Enable()
		else
			c:Disable()
		end
	end)
end

function PremiereCamera.active(): boolean
	return saved ~= nil
end

function PremiereCamera.pose(): CFrame
	return pose
end

local function step()
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	local m = move
	if m ~= nil then
		local t = math.clamp((os.clock() - m.start) / m.seconds, 0, 1)
		local e = TweenService:GetValue(t, m.style, m.dir)
		-- A cubic curve whose first control point is straight up: the camera climbs, then travels.
		local p0, p3 = m.from.Position, m.to.Position
		local p1, p2 = p0 + m.lift, p3 + m.lift * 0.4
		local u = 1 - e
		local at = p0 * (u * u * u) + p1 * (3 * u * u * e) + p2 * (3 * u * e * e) + p3 * (e * e * e)
		pose = CFrame.new(at) * (m.from.Rotation:Lerp(m.to.Rotation, e))
		fov = m.fov0 + (m.fov1 - m.fov0) * e
		if t >= 1 then
			pose, fov, move = m.to, m.fov1, nil
		end
	end
	camera.CFrame = pose
	camera.FieldOfView = fov
end

-- Takes the camera. False when there is no camera.
function PremiereCamera.begin(): boolean
	if saved ~= nil then
		return true
	end
	local camera = workspace.CurrentCamera
	if camera == nil then
		return false
	end
	saved = { cframe = camera.CFrame, fov = camera.FieldOfView, cameraType = camera.CameraType, subject = camera.CameraSubject }
	pose, fov, move = camera.CFrame, camera.FieldOfView, nil
	camera.CameraType = Enum.CameraType.Scriptable
	controls(false)
	RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value, step)
	-- Dying or respawning ends the show right away.
	local player = Players.LocalPlayer
	table.insert(connections, player.CharacterAdded:Connect(PremiereCamera.restore))
	local humanoid = if player.Character ~= nil then player.Character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid ~= nil then
		table.insert(connections, humanoid.Died:Connect(PremiereCamera.restore))
	end
	return true
end

-- Cuts to a shot.
function PremiereCamera.cut(to: CFrame, toFov: number)
	move = nil
	pose, fov = to, toFov
end

-- Glides to a shot in `seconds`. `lift` is how far up the path first climbs (over roofs).
function PremiereCamera.move(to: CFrame, toFov: number, seconds: number, lift: number?, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	if saved == nil then
		return
	end
	move = {
		from = pose,
		to = to,
		lift = Vector3.new(0, lift or 0, 0),
		fov0 = fov,
		fov1 = toFov,
		start = os.clock(),
		seconds = math.max(seconds, 0.05),
		style = style or Enum.EasingStyle.Sine,
		dir = dir or Enum.EasingDirection.InOut,
	}
end

-- Gives the camera and the controls back, at once.
function PremiereCamera.restore()
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	local s = saved
	if s == nil then
		return
	end
	saved, move = nil, nil
	RunService:UnbindFromRenderStep(BIND)
	local camera = workspace.CurrentCamera
	if camera ~= nil then
		camera.CameraType = s.cameraType
		local subject = s.subject
		if subject == nil or not subject:IsDescendantOf(workspace) then
			local character = Players.LocalPlayer.Character
			subject = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
		end
		camera.CameraSubject = subject :: any
		camera.CFrame = s.cframe
		camera.FieldOfView = s.fov
	end
	controls(true)
	restoredEvent:Fire()
end

-- Where the camera will return to (the character's view).
function PremiereCamera.home(): CFrame?
	return if saved ~= nil then saved.cframe else nil
end

function PremiereCamera.homeFov(): number
	return if saved ~= nil then saved.fov else 70
end

return PremiereCamera
