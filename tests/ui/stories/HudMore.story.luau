-- The phone HUD with the More flyout open (on PC it just shows the normal menu) and badges on hidden tiles.
local H = require(game:GetService("ReplicatedStorage").UiTest.Harness)
return function(Target)
	local gui = H.boot(Target)
	local side = H.startHud(gui)
	require(H.client().CastingUi).start(gui, side.actors)
	local SideMenu = require(H.client().SideMenu)
	SideMenu.setBadge(side.rewards, 2)
	SideMenu.setBadge(side.upgrade, 1)
	SideMenu.setBadge(side.goals, 2)
	gui:SetAttribute("MoreOpen", true)
end
