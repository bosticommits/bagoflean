--!strict
-- Builds the town around the studio lots (MapModels): the boulevard, the spawn plaza, the paths
-- that join every lot, and the store stands. Each stand gets a prompt that opens its screen on
-- the player's own client (src/client/Stands.luau). The stands only open menus, so they need no
-- remotes and grant nothing.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FilmSets = require(ReplicatedStorage.Shared.FilmSets)
local MapModels = require(ReplicatedStorage.Shared.Models.MapModels)
local MapScenery = require(ReplicatedStorage.Shared.Models.MapScenery)

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

-- The map's look: late-afternoon golden light, a warm haze that hides the far edge of the world,
-- richer colors, a soft glow on neon and lit lamps, and sun rays. Lighting.Technology = Future
-- (real shadows, and lamps that light the ground) is set in default.project.json, because game
-- scripts can't change it; Rojo sets it on connect. Each effect reuses the place's own one if it
-- has one (so the template's effects don't stack with ours) and sets it to the map's look.
-- src/client/AreaMood.luau warms it up in Dusty Gulch and greens it up in Starlight Park.
local function effect<T>(className: string): T
	local found = Lighting:FindFirstChildOfClass(className :: any)
	if found == nil or found.Name:sub(1, 12) == "SpecialEvent" then
		found = Instance.new(className :: any)
		found.Parent = Lighting
	end
	return (found :: any) :: T
end

local function addLook()
	Lighting.ClockTime = 16
	Lighting.GeographicLatitude = 28
	Lighting.Brightness = 3
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.OutdoorAmbient = Color3.fromRGB(146, 132, 124)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 222, 176)
	Lighting.ShadowSoftness = 0.25
	Lighting.GlobalShadows = true

	local air = effect("Atmosphere") :: Atmosphere
	air.Density = 0.32
	air.Offset = 0.12
	air.Color = Color3.fromRGB(255, 218, 178)
	air.Decay = Color3.fromRGB(160, 126, 112)
	air.Glare = 0.35
	air.Haze = 1.4

	local color = effect("ColorCorrectionEffect") :: ColorCorrectionEffect
	color.Saturation = 0.18
	color.Contrast = 0.08
	color.Brightness = 0.01
	color.TintColor = Color3.fromRGB(255, 249, 240)

	local bloom = effect("BloomEffect") :: BloomEffect
	bloom.Intensity = 0.6
	bloom.Size = 24
	bloom.Threshold = 1.4

	local rays = effect("SunRaysEffect") :: SunRaysEffect
	rays.Intensity = 0.07
	rays.Spread = 0.55
end

-- The mountains on the horizon are terrain (MapScenery lists them). Built once, at start, a
-- mountain a frame, without holding up the rest of the server.
local function addMountains()
	task.spawn(function()
		local ok, err = pcall(function()
			MapScenery.buildTerrain(workspace.Terrain, function()
				task.wait()
			end)
		end)
		if not ok then
			warn(`[MapService] mountains not built: {err}`)
		end
	end)
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

-- The buy prompt at a film set's gate. FilmSetWorld sends the purchase and hides the prompt for
-- owners on their own screen; FilmSetService checks and charges.
local function addFilmSetPrompt(id: string, anchor: BasePart)
	local set = FilmSets.get(id)
	if set == nil then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "FilmSetPrompt"
	prompt.ActionText = `Buy for {FilmSets.priceText(set)}`
	prompt.ObjectText = `{set.name} Film Set`
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("FilmSet", id)
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
	for _, gate in built.filmSets do
		addFilmSetPrompt(gate.id, gate.anchor)
	end
	addSpawn(folder)
	folder.Parent = workspace
	addMountains()
end

return MapService
