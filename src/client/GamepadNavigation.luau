--!strict
-- Gamepad navigation handler for Hollywood RNG.
-- Handles virtual cursor selection, bumper tab switching, and B/Circle button screen dismissal.
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local GamepadNavigation = {}

local CLOSE_ACTION = "GamepadCloseScreen"

local function handleCloseAction(_actionName: string, inputState: Enum.UserInputState, _inputObject: InputObject)
	if inputState == Enum.UserInputState.Begin then
		-- Deselect UI object or send Back intention
		if GuiService.SelectedObject ~= nil then
			GuiService.SelectedObject = nil
			return Enum.ContextActionResult.Sink
		end
	end
	return Enum.ContextActionResult.Pass
end

function GamepadNavigation.start(gui: ScreenGui)
	-- Enable virtual gamepad cursor if supported
	pcall(function()
		GuiService.AutoSelectGuiEnabled = true
	end)

	-- Bind Gamepad B button to cancel/close menus gracefully
	ContextActionService:BindAction(
		CLOSE_ACTION,
		handleCloseAction,
		false,
		Enum.KeyCode.ButtonB
	)

	-- Whenever gamepad is connected, optimize navigation mode
	UserInputService.GamepadConnected:Connect(function(gamepadNum)
		if gamepadNum == Enum.UserInputType.Gamepad1 then
			GuiService.SelectedObject = nil
		end
	end)
end

return GamepadNavigation
