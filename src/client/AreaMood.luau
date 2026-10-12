--!strict
-- Shifts the colors a little as the player walks between areas: warm golden-hour tones in Dusty
-- Gulch, a fresh lush green in Starlight Park, and the town's own look in between (MapService
-- sets that). Its own ColorCorrection, on this player's screen only, so it adds to the map's look
-- and to any special event's tint without touching them.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local MapModels = require(ReplicatedStorage.Shared.Models.MapModels)

local AreaMood = {}

type Mood = { tint: Color3, saturation: number, contrast: number, brightness: number, rays: number }

local MOODS: { [string]: Mood } = {
	town = { tint = Color3.new(1, 1, 1), saturation = 0, contrast = 0, brightness = 0, rays = 0 },
	gulch = { tint = Color3.fromRGB(255, 226, 190), saturation = 0.08, contrast = 0.05, brightness = 0.02, rays = 0.08 },
	park = { tint = Color3.fromRGB(236, 255, 232), saturation = 0.14, contrast = 0.03, brightness = 0.01, rays = 0.03 },
}

local CHECK_EVERY = 0.5 -- seconds
local BLEND = TweenInfo.new(2.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

-- Which area a spot is in: past the front hedge is the Gulch, past the back hedge the park.
function AreaMood.areaAt(position: Vector3): string
	local edge = MapModels.Layout.fenceZ
	if position.Z < -edge then
		return "gulch"
	elseif position.Z > edge then
		return "park"
	end
	return "town"
end

function AreaMood.start()
	local tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "AreaMood"
	tint.Parent = Lighting
	local rays = Instance.new("SunRaysEffect")
	rays.Name = "AreaMoodRays"
	rays.Intensity = 0
	rays.Spread = 0.7
	rays.Parent = Lighting

	local current = "town"
	task.spawn(function()
		while true do
			task.wait(CHECK_EVERY)
			local character = Players.LocalPlayer.Character
			local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
			if root ~= nil and root:IsA("BasePart") then
				local area = AreaMood.areaAt(root.Position)
				if area ~= current then
					current = area
					local mood = MOODS[area]
					TweenService:Create(tint, BLEND, {
						TintColor = mood.tint,
						Saturation = mood.saturation,
						Contrast = mood.contrast,
						Brightness = mood.brightness,
					}):Play()
					TweenService:Create(rays, BLEND, { Intensity = mood.rays }):Play()
				end
			end
		end
	end)
end

return AreaMood
