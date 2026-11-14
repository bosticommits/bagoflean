-- The Visit screen with the Invite friends button.
local H = require(game:GetService("ReplicatedStorage").UiTest.Harness)
return function(Target)
	local gui = H.boot(Target)
	local side = H.startHud(gui)
	local VisitUi = require(H.client().VisitUi)
	VisitUi.assumeCanInvite = true -- rur's SocialService says no; see the seam in VisitUi.luau
	VisitUi.start(gui, side.visit)
	require(H.client().Screens).open("Visit")
end
