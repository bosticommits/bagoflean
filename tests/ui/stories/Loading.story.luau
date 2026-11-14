-- The film-leader loading screen (ReplicatedFirst/LoadingView) at 1.5 s: number 2, hand a half turn, strip 45% full.
-- In the game the content sits in its own ScreenGui with CoreUISafeInsets; here the story's ScreenGui has them.
return function(Target)
	local gui = Target.Parent :: ScreenGui
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None
	local View = require(game:GetService("ReplicatedFirst").LoadingView)
	local backdrop = Instance.new("Frame")
	backdrop.Name = "Cover"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BorderSizePixel = 0
	backdrop.Parent = gui
	local safe = Instance.new("Frame")
	safe.Name = "LoadingPanel"
	safe.Size = UDim2.fromScale(1, 1)
	safe.BackgroundTransparency = 1
	safe.Parent = gui
	local view = View.build(backdrop, safe, false)
	view.update(1.5, 0.45, 1)
end
