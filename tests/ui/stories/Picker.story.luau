-- The Start-movie picker. Needs actions (Picker.actions.json): open the Studio panel's first empty
-- stage, pick a script, fill the cast so the footer shows three slots.
local H = require(game:GetService("ReplicatedStorage").UiTest.Harness)
return function(Target)
	local gui = H.boot(Target)
	local side = H.startHud(gui)
	require(H.client().StudioUi).start(gui, side.studio)
	require(H.client().Screens).open("Studio")
end
