--!strict
-- Small moving life round the map, so it feels lived in: low-poly clouds drifting across the sky,
-- gulls circling over the town, the park and the Gulch, butterflies over Starlight Park's flower
-- beds, and the pond's ducks paddling slow circles. All of them are Blender map kit models
-- (art/blender/map_kit_town.py). Each player moves their own copies (the ducks are the server's,
-- moved on this screen only), so it costs the server nothing.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Build = require(ReplicatedStorage.Shared.Models.Build)
local MapKit = require(ReplicatedStorage.Shared.Models.MapKit)
local MapModels = require(ReplicatedStorage.Shared.Models.MapModels)

local MapLife = {}

local TAU = math.pi * 2

-- Clouds drift along +X and wrap round at the edge of the sky.
local CLOUD_SPAN = 1400
local CLOUDS = 16

-- Gull flocks: a centre, a circle's radius, a height and how many gulls. Seconds per lap.
local FLOCKS = {
	{ center = Vector3.new(-20, 78, -10), radius = 90, count = 4, lap = 46 },
	{ center = Vector3.new(10, 62, 200), radius = 46, count = 3, lap = 34 },
	{ center = Vector3.new(0, 58, -200), radius = 54, count = 3, lap = 38 },
}

-- A fixed spread of numbers in [0, 1), the same for every player.
local function hash(i: number, salt: number): number
	local n = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453
	return n - math.floor(n)
end

local function place(folder: Folder, kit: string, scale: number): Model
	local model = MapKit.place(Build.new(folder, CFrame.identity), kit, CFrame.identity, { scale = scale, far = true })
	return model
end

type Mover = { model: Model, step: (t: number) -> CFrame }

local function clouds(folder: Folder, movers: { Mover })
	for i = 1, CLOUDS do
		local scale = 1.4 + hash(i, 1) * 1.8
		local speed = 3 + hash(i, 2) * 3
		local z = -650 + (i - 0.5) / CLOUDS * 1300 + (hash(i, 3) - 0.5) * 60
		local y = 150 + hash(i, 4) * 90
		local start = hash(i, 5) * CLOUD_SPAN
		local yaw = (hash(i, 6) - 0.5) * 0.6
		table.insert(movers, {
			model = place(folder, "Cloud", scale),
			step = function(t: number): CFrame
				local x = (start + t * speed) % CLOUD_SPAN - CLOUD_SPAN / 2
				return CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0)
			end,
		})
	end
end

local function gulls(folder: Folder, movers: { Mover })
	for f, flock in FLOCKS do
		for i = 1, flock.count do
			local offset = (i - 1) / flock.count * 0.55 -- strung out round the circle
			local r = flock.radius * (0.85 + hash(f * 10 + i, 7) * 0.3)
			local lift = (hash(f * 10 + i, 8) - 0.5) * 8
			table.insert(movers, {
				model = place(folder, "Bird", 1.6),
				step = function(t: number): CFrame
					local a = (t / flock.lap + offset) * TAU
					local at = flock.center + Vector3.new(math.sin(a) * r, lift + math.sin(a * 2 + i) * 3, math.cos(a) * r)
					-- Nose (-Z) along the way it flies, banked in toward the middle of the circle.
					local yaw = a + math.pi / 2 + math.pi
					return CFrame.new(at) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(0, 0, math.rad(22))
				end,
			})
		end
	end
end

local function butterflies(folder: Folder, movers: { Mover })
	local e = MapModels.Layout.fenceZ + 1
	local beds = {
		Vector3.new(-16, 2.5, e + 38),
		Vector3.new(16, 2.5, e + 38),
		Vector3.new(-13, 2.5, e + 62),
		Vector3.new(16, 2.5, e + 62),
		Vector3.new(40, 2.5, e + 60),
		Vector3.new(-48, 2.5, e + 94), -- by the pond's flowers
	}
	for i, bed in beds do
		for k = 1, if i % 2 == 0 then 2 else 1 do
			local seed = i * 10 + k
			local speed = 0.5 + hash(seed, 9) * 0.4
			local kit = if hash(seed, 10) < 0.5 then "ButterflyPink" else "ButterflyBlue"
			table.insert(movers, {
				model = place(folder, kit, 1.3),
				step = function(t: number): CFrame
					local a = t * speed + seed
					-- A lazy figure of eight over the bed, bobbing, wings rocking fast.
					local at = bed + Vector3.new(math.sin(a) * 4.5, 1.2 + math.abs(math.sin(t * 5 + seed)) * 1.2, math.sin(a * 2) * 2.5)
					local ahead = Vector3.new(math.cos(a) * 4.5, 0, math.cos(a * 2) * 5)
					local yaw = math.atan2(-ahead.X, -ahead.Z)
					return CFrame.new(at) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(0, 0, math.sin(t * 22 + seed) * 0.45)
				end,
			})
		end
	end
end

local function ducks(movers: { Mover })
	for i, duck in CollectionService:GetTagged("PondDuck") do
		if duck:IsA("Model") then
			local home = duck:GetPivot()
			local radius = 3 + (i % 3)
			local lap = 24 + i * 5
			table.insert(movers, {
				model = duck,
				step = function(t: number): CFrame
					local a = t / lap * TAU * (if i % 2 == 0 then 1 else -1)
					local offset = Vector3.new(math.sin(a) * radius, math.sin(t * 2 + i) * 0.08, (math.cos(a) - 1) * radius)
					-- Turned to face along its little circle.
					local yaw = a + (if i % 2 == 0 then -math.pi / 2 else math.pi / 2)
					return CFrame.new(home.Position + offset) * CFrame.Angles(0, yaw, 0)
				end,
			})
		end
	end
end

function MapLife.start()
	task.spawn(function()
		local town = workspace:WaitForChild("Town", 60)
		if town == nil then
			return
		end
		local folder = Instance.new("Folder")
		folder.Name = "MapLife"
		folder.Parent = workspace
		local movers: { Mover } = {}
		clouds(folder, movers)
		gulls(folder, movers)
		butterflies(folder, movers)
		-- The server builds the park before the town's folder appears, but give it a moment.
		task.wait(2)
		ducks(movers)

		local frame = 0
		RunService.Heartbeat:Connect(function()
			frame += 1
			local t = os.clock()
			for i, mover in movers do
				-- Clouds hardly move: every few frames is plenty.
				if i > CLOUDS or frame % 4 == 0 then
					mover.model:PivotTo(mover.step(t))
				end
			end
		end)
	end)
end

return MapLife
