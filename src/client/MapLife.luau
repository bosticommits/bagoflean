--!strict
-- Small moving things that make the map feel alive: gulls gliding over the town and the park,
-- clouds drifting overhead, butterflies over Starlight Park's lawns and ducks paddling round the
-- pond. All Blender map kit models.
--
-- Each player moves their own copies, so it costs the server nothing: the birds, clouds and
-- butterflies are made here; the ducks are the town's own (TownSets), moved here.
-- About thirty models a frame, none of which collide.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Build = require(ReplicatedStorage.Shared.Models.Build)
local MapKit = require(ReplicatedStorage.Shared.Models.MapKit)
local MapModels = require(ReplicatedStorage.Shared.Models.MapModels)
local TownSets = require(ReplicatedStorage.Shared.Models.TownSets)

local MapLife = {}

local TAU = math.pi * 2
local EDGE = MapModels.Layout.fenceZ + 1 -- where the park and the Gulch start
local POND = TownSets.Pond + Vector3.new(0, 0, EDGE) -- the park is built from z = EDGE

type Mover = (t: number) -> ()

-- A fixed pseudo-random number in [0, 1), so everyone sees the same sky.
local function noise(i: number, salt: number): number
	local n = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453
	return n - math.floor(n)
end

local function place(folder: Instance, name: string, scale: number): Model
	return MapKit.place(Build.new(folder, CFrame.identity), name, CFrame.identity, { scale = scale, far = true })
end

-- Pointing along `ahead` (models face -Z), with no tilt.
local function facing(at: Vector3, ahead: Vector3): CFrame
	local flat = Vector3.new(ahead.X, 0, ahead.Z)
	if flat.Magnitude < 1e-4 then
		return CFrame.new(at)
	end
	return CFrame.lookAt(at, at + flat)
end

-- Gulls in a loose V, circling `centre` at `radius` once every `lap` seconds, leaning into the turn.
local function flock(folder: Instance, movers: { Mover }, centre: Vector3, radius: number, lap: number, count: number, seed: number)
	local direction = if seed % 2 == 0 then 1 else -1
	for i = 0, count - 1 do
		local bird = place(folder, "Bird", 0.9 + noise(i, seed) * 0.3)
		local side = if i % 2 == 0 then 1 else -1
		local rank = (i + 1) // 2
		local offset = Vector3.new(side * rank * 4, noise(i, seed + 1) * 2, rank * 4)
		table.insert(movers, function(t)
			local a = direction * t / lap * TAU + seed
			local at = centre + Vector3.new(math.sin(a) * radius, math.sin(a * 3) * 3, math.cos(a) * radius)
			local ahead = Vector3.new(math.cos(a), 0, -math.sin(a)) * direction
			local lead = facing(at, ahead) * CFrame.Angles(0, 0, direction * math.rad(18))
			local bob = math.sin(t * 1.3 + i) * 0.6
			bird:PivotTo(lead * CFrame.new(offset + Vector3.new(0, bob, 0)))
		end)
	end
end

-- Clouds drifting slowly east high overhead, coming back round in the west.
local function clouds(folder: Instance, movers: { Mover })
	local span, speed = 1300, 3
	for i = 0, 13 do
		local cloud = place(folder, "Cloud", 1.1 + noise(i, 3) * 1.2)
		local x0 = noise(i, 4) * span
		local z = (noise(i, 5) - 0.5) * 1100
		local y = 170 + noise(i, 6) * 70
		local turn = CFrame.Angles(0, (noise(i, 7) - 0.5) * 0.6, 0)
		table.insert(movers, function(t)
			local x = (x0 + t * speed) % span - span / 2
			cloud:PivotTo(CFrame.new(x, y, z) * turn)
		end)
	end
end

-- Butterflies flitting over the park's lawns, each round its own patch.
local BUTTERFLY_SPOTS = {
	Vector3.new(-25, 0, 30), Vector3.new(24, 0, 34), Vector3.new(-32, 0, 68), Vector3.new(32, 0, 70),
	Vector3.new(80, 0, 55), Vector3.new(-88, 0, 40), Vector3.new(30, 0, 100), Vector3.new(-40, 0, 104),
}

local function butterflies(folder: Instance, movers: { Mover })
	for i, spot in BUTTERFLY_SPOTS do
		local fly = place(folder, "Butterfly", 1.6)
		local home = spot + Vector3.new(0, 0, EDGE)
		local p = noise(i, 8) * TAU
		table.insert(movers, function(t)
			local function at(s: number): Vector3
				return home + Vector3.new(math.sin(s * 0.7 + p) * 4, 2.2 + math.sin(s * 1.9 + p) * 0.8, math.sin(s * 0.45 + p * 2) * 4)
			end
			local now = at(t)
			-- Wings flutter: a quick rock from side to side.
			fly:PivotTo(facing(now, at(t + 0.1) - now) * CFrame.Angles(0, 0, math.sin(t * 22 + p) * 0.5))
		end)
	end
end

-- The park's ducks paddle slow loops on the pond: the big one with its duckling behind, and
-- one on its own, clear of the island and the bridge.
local DUCK_LOOPS = {
	{ centre = Vector3.new(11, 0.5, -9), radius = 5, lap = 40, lag = 0 },
	{ centre = Vector3.new(11, 0.5, -9), radius = 5, lap = 40, lag = 0.55 },
	{ centre = Vector3.new(-14, 0.5, -12), radius = 4, lap = 32, lag = 2 },
}

-- Calls `found(model, n)` for each of the town's models called `name`, the nth found, now and as
-- more arrive (with streaming, far parts of the map reach a player later).
local function each(town: Instance, name: string, found: (Model, number) -> ())
	local count = 0
	local function check(item: Instance)
		if item:IsA("Model") and item.Name == name then
			count += 1
			found(item, count)
		end
	end
	for _, item in town:GetDescendants() do
		check(item)
	end
	town.DescendantAdded:Connect(check)
end

local function ducks(town: Instance, movers: { Mover })
	each(town, "Duck", function(model, index)
		local loop = DUCK_LOOPS[index]
		if loop == nil then
			return
		end
		table.insert(movers, function(t)
			local a = t / loop.lap * TAU - loop.lag
			local bob = math.sin(t * 2 + index) * 0.05
			local at = POND + loop.centre + Vector3.new(math.sin(a) * loop.radius, bob, math.cos(a) * loop.radius)
			model:PivotTo(facing(at, Vector3.new(math.cos(a), 0, -math.sin(a))))
		end)
	end)
end

function MapLife.start()
	task.spawn(function()
		local town = workspace:WaitForChild("Town", 60)
		if town == nil then
			return
		end
		-- Let the town finish arriving before looking for its ducks.
		town:WaitForChild("Blimp", 30)

		local folder = Instance.new("Folder")
		folder.Name = "MapLife"
		folder.Parent = workspace
		local movers: { Mover } = {}
		flock(folder, movers, Vector3.new(0, 78, 0), 150, 80, 5, 2)
		flock(folder, movers, Vector3.new(0, 55, EDGE + 70), 70, 50, 3, 5)
		flock(folder, movers, Vector3.new(0, 50, -EDGE - 80), 60, 44, 3, 7)
		clouds(folder, movers)
		butterflies(folder, movers)
		ducks(town, movers)

		RunService.Heartbeat:Connect(function()
			local t = os.clock()
			for _, move in movers do
				move(t)
			end
		end)
	end)
end

return MapLife
