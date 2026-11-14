-- The always-visible HUD: side menu, wallet, event lines, CAST bar.
local H = require(game:GetService("ReplicatedStorage").UiTest.Harness)
return function(Target)
	local gui = H.boot(Target)
	local side = H.startHud(gui)
	require(H.client().CastingUi).start(gui, side.actors)
end
