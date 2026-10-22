--!strict
-- Drifts the town's blimp (TownSets.blimp, built by MapService) in a slow circle round the town.
-- Each player moves their own copy, so it costs the server nothing (about a dozen parts a frame).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MapModels = require(ReplicatedStorage.Shared.Models.MapModels)

local Blimp = {}

local LAP = 300 -- seconds for one circle

function Blimp.start()
	task.spawn(function()
		local town = workspace:WaitForChild("Town", 60)
		local model = if town ~= nil then town:WaitForChild("Blimp", 30) else nil
		if model == nil or not model:IsA("Model") then
			return
		end
		local radius, height = MapModels.Layout.blimpRadius, MapModels.Layout.blimpHeight
		RunService.Heartbeat:Connect(function()
			local a = (os.clock() / LAP) * math.pi * 2
			local at = Vector3.new(math.sin(a) * radius, height + math.sin(a * 3) * 4, -math.cos(a) * radius)
			-- Nose (-Z) along the direction of travel.
			local ahead = Vector3.new(math.cos(a), 0, math.sin(a))
			model:PivotTo(CFrame.lookAt(at, at + ahead))
		end)
	end)
end

return Blimp
