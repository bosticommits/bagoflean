-- The loading screen for a returning player: "Welcome back" plus a live line, no tip.
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
	view.showWelcome("Welcome back, Maximilian_the_Great_2007!", "Luck Weekend x2")
	view.update(2.2, 0.8, 1)
end
