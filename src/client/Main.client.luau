--!strict
local Players = game:GetService("Players")

local CastingUi = require(script.Parent.CastingUi)
local Hud = require(script.Parent.Hud)
local StudioUi = require(script.Parent.StudioUi)

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "MovieMogulUI"
gui.ResetOnSpawn = false
-- Sibling ordering: a panel's children always draw above the panel itself, whatever their ZIndex.
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Parent = playerGui

Hud.start(gui)
local studioButton = CastingUi.start(gui)
if studioButton ~= nil then
	StudioUi.start(gui, studioButton)
end
