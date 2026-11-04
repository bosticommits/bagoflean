--!strict
-- Gamepad navigation for Hollywood RNG: turns on the gamepad selection cursor, and B/Circle first
-- deselects the selected UI object, then closes the open panel. The casting reveal's B-skip lives in
-- CastingUi and is left alone: this binding only sinks B when it did something.
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")

local UiKit = require(script.Parent.UiKit)

local GamepadNavigation = {}

local CLOSE_ACTION = "GamepadCloseScreen"

local function handleCloseAction(_actionName: string, inputState: Enum.UserInputState, _inputObject: InputObject)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	if GuiService.SelectedObject ~= nil then
		GuiService.SelectedObject = nil
		return Enum.ContextActionResult.Sink
	end
	if UiKit.anyPanelOpen() and not UiKit.overlayOpen() then
		UiKit.closePanels()
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end

function GamepadNavigation.start()
	pcall(function()
		GuiService.AutoSelectGuiEnabled = true
	end)
	ContextActionService:BindAction(CLOSE_ACTION, handleCloseAction, false, Enum.KeyCode.ButtonB)
end

return GamepadNavigation
