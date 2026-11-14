-- The always-visible HUD: side menu, wallet, event lines, CAST bar.
local H = require(game:GetService("ReplicatedStorage").UiTest.Harness)
return function(Target)
	local gui = H.boot(Target)
	-- Luck Weekend badge on (LiveConfig copies these to ReplicatedStorage), 36 h left.
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	ReplicatedStorage:SetAttribute("LiveConfig_CastingLuckMultiplier", 1.5)
	ReplicatedStorage:SetAttribute("LiveConfig_LuckWeekendUntil", os.time() + 36 * 3600)
	local side = H.startHud(gui)
	require(H.client().CastingUi).start(gui, side.actors)
end
