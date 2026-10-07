--!strict
local Players = game:GetService("Players")

local CastingUi = require(script.Parent.CastingUi)
local Hud = require(script.Parent.Hud)

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "MovieMogulUI"
gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Parent = playerGui

Hud.start(gui)
CastingUi.start(gui)
