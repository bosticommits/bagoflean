--!strict
-- Floating text in the world, in the menus' style: chunky letters with a dark outline and no box
-- behind them. Sizes are in studs, so a label shrinks with distance like the scenery around it
-- instead of staying a fixed bar across the screen, and walls in front of it hide it.
local WorldLabel = {}

local INK = Color3.fromRGB(11, 15, 31) -- the menus' outline color (UiKit.INK)

export type Options = {
	color: Color3?,
	offset: Vector3?, -- from the part's centre, in world space
	maxDistance: number?,
	outline: number?, -- outline thickness in pixels
}

-- A `width` x `height` stud label floating over `target`. Returns the text, to change later.
function WorldLabel.new(target: Instance, text: string, width: number, height: number, options: Options?): TextLabel
	local o: Options = options or {}
	local gui = Instance.new("BillboardGui")
	gui.Name = "WorldLabel"
	gui.Size = UDim2.fromScale(width, height) -- studs
	gui.StudsOffsetWorldSpace = o.offset or Vector3.new(0, 4, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = o.maxDistance or 80
	gui.Parent = target
	local label = Instance.new("TextLabel")
	label.Name = "TextLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = o.color or Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = o.outline or 2.5
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label
	return label
end

return WorldLabel
