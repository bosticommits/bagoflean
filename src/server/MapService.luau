--!strict
-- Builds the town around the studio lots (MapModels): the boulevard, the spawn plaza, the paths
-- that join every lot, and the store stands. Each stand gets a prompt that opens its screen on
-- the player's own client (src/client/Stands.luau). The stands only open menus, so they need no
-- remotes and grant nothing.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapModels = require(ReplicatedStorage.Shared.Models.MapModels)

local MapService = {}

-- Studio's starting baseplate and spawn pad would sit inside the town (the baseplate's top is
-- the same height as the town's grass, so the two would flicker). Only removed while the game
-- runs; the saved place keeps them.
local function clearTemplate()
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate ~= nil and baseplate:IsA("BasePart") then
		baseplate:Destroy()
	end
	for _, part in workspace:GetDescendants() do
		if part:IsA("SpawnLocation") then
			part:Destroy()
		end
	end
end

-- ART_STYLE.md section 5: a light warm haze (it also hides the far edge of the ground), a little
-- extra color, and a soft glow on neon signs. Each is added only when the place has none of its
-- own, so settings made in Studio win.
local function addLook()
	if Lighting:FindFirstChildOfClass("Atmosphere") == nil then
		local air = Instance.new("Atmosphere")
		air.Density = 0.3
		air.Offset = 0.1
		air.Color = Color3.fromRGB(240, 228, 210)
		air.Decay = Color3.fromRGB(120, 125, 140)
		air.Glare = 0
		air.Haze = 1
		air.Parent = Lighting
	end
	if Lighting:FindFirstChildOfClass("ColorCorrectionEffect") == nil then
		local color = Instance.new("ColorCorrectionEffect")
		color.Saturation = 0.15
		color.Contrast = 0.05
		color.Parent = Lighting
	end
	if Lighting:FindFirstChildOfClass("BloomEffect") == nil then
		local bloom = Instance.new("BloomEffect")
		bloom.Intensity = 0.5
		bloom.Size = 20
		bloom.Threshold = 1.6
		bloom.Parent = Lighting
	end
end

local function addSpawn(folder: Instance)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Size = Vector3.new(6, 0.2, 6)
	spawn.CFrame = MapModels.Layout.spawn
	spawn.Anchored = true
	spawn.Transparency = 1 -- the gold star on the plaza marks it
	spawn.CanCollide = false
	spawn.CanQuery = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = folder
end

local function addPrompt(info: MapModels.StandInfo, anchor: BasePart)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StandPrompt"
	prompt.ActionText = info.action
	prompt.ObjectText = info.title
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12 -- when two stands are in reach, only the nearer one shows
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Screen", info.screen)
	prompt.Parent = anchor
end

function MapService.start()
	clearTemplate()
	addLook()
	local folder = Instance.new("Folder")
	folder.Name = "Town"
	local built = MapModels.build(folder)
	for _, stand in built.stands do
		addPrompt(stand.info, stand.anchor)
	end
	addSpawn(folder)
	folder.Parent = workspace
end

return MapService
