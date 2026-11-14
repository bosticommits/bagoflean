-- The Studio panel (Stages tab) open over the HUD.
local H = require(game:GetService("ReplicatedStorage").UiTest.Harness)
return function(Target)
	local gui = H.boot(Target)
	local side = H.startHud(gui)
	require(H.client().StudioUi).start(gui, side.studio)
	require(H.client().Screens).open("Studio")
end
