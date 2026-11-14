-- The Mascots screen open over the HUD, with the sound button and a goal toast showing.
local H = require(game:GetService("ReplicatedStorage").UiTest.Harness)
return function(Target)
	local gui = H.boot(Target)
	local side = H.startHud(gui)
	local remotes = game:GetService("ReplicatedStorage").Remotes
	local player = game:GetService("Players").LocalPlayer
	player:SetAttribute("MascotsUnlocked", "PopcornPup")
	player:SetAttribute("Mascot", "PopcornPup")
	require(H.client().MascotUi).start(gui, side.mascots, remotes)
	require(H.client().SoundSettingsUi).start(gui, remotes)
	require(H.client().Declutter).start(gui)
	-- A goal toast arrives while the panel is open: it must wait, not cover the cards.
	task.delay(0.8, function()
		require(H.client().UiKit).toast(gui, "Goal reached: Collect the box office 10 times!", true)
	end)
end
