-- The Goals screen (full-screen on phones) open with the sound button and its badge.
local H = require(game:GetService("ReplicatedStorage").UiTest.Harness)
return function(Target)
	local gui = H.boot(Target)
	local side = H.startHud(gui)
	local remotes = game:GetService("ReplicatedStorage").Remotes
	require(H.client().AchievementsUi).start(gui, side.goals)
	require(H.client().SoundSettingsUi).start(gui, remotes)
	require(H.client().Declutter).start(gui)
	require(H.client().SideMenu).setBadge(side.goals, 2)
end
