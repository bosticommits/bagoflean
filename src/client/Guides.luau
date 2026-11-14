--!strict
-- Yellow guide pieces shared by the tutorial and the Next Up "Show me" button: the glossy arrow, the
-- pulsing ring on a UI control, the glow + bobbing arrow over a world target, and the screen-edge
-- arrow maths. Moved verbatim out of Tutorial.luau (the hand pointer and chevron trail stay there).
local TweenService = game:GetService("TweenService")

local UiKit = require(script.Parent.UiKit)

local Guides = {}

-- The guide color: brighter and yellower than the UI's gold, so directions read as directions.
Guides.GUIDE = Color3.fromRGB(255, 222, 26)
Guides.HINT_BLUE = Color3.fromRGB(110, 190, 255)

export type WorldTarget = {
	adornee: BasePart, -- the arrow floats over this
	glow: Instance, -- what glows (a pad, or a stand's whole model)
	label: string,
	height: number, -- studs above the adornee for the arrow
	kind: string, -- "primary" | "secondary" | "hint"
}

function Guides.pulse(object: Instance, seconds: number, goal: { [string]: any }): Tween
	local tween = TweenService:Create(object, TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), goal)
	tween:Play()
	return tween
end

-- A chunky, glossy yellow arrow with a dark outline, pointing down (turn it with Rotation: 90
-- points left, 180 up, 270 right). A shaft and a diamond, so the head's back edges sweep toward the
-- shaft; a top-to-bottom gold shade and a white shine down its left side make it read as glossy.
local GLOSS = ColorSequence.new(Color3.fromRGB(255, 242, 150), Color3.fromRGB(255, 178, 20))
function Guides.arrow(parent: Instance, size: number, zIndex: number): Frame
	local holder = Instance.new("Frame")
	holder.Name = "GuideArrow"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Size = UDim2.fromOffset(size, size)
	holder.ZIndex = zIndex
	local outline = math.max(7, math.floor(size * 0.12))
	local function piece(name: string, color: Color3, grow: number, z: number, diamond: boolean): Frame
		local frame = Instance.new("Frame")
		frame.Name = name
		frame.BorderSizePixel = 0
		frame.BackgroundColor3 = color
		frame.ZIndex = z
		if diamond then
			frame.AnchorPoint = Vector2.new(0.5, 0.5)
			frame.Position = UDim2.fromScale(0.5, 0.6)
			frame.Size = UDim2.new(0.48, grow, 0.48, grow)
			frame.Rotation = 45
		else
			frame.Position = UDim2.new(0.35, -grow / 2, 0.04, -grow / 2)
			frame.Size = UDim2.new(0.3, grow, 0.5, grow)
		end
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(0, if diamond then 5 else 4)
		round.Parent = frame
		frame.Parent = holder
		return frame
	end
	piece("ShaftOutline", UiKit.INK, outline, zIndex, false)
	piece("HeadOutline", UiKit.INK, outline + 1, zIndex, true)
	local shaft = piece("Shaft", Guides.GUIDE, 0, zIndex + 1, false)
	local head = piece("Head", Guides.GUIDE, 0, zIndex + 1, true)
	for _, frame in { shaft, head } do
		frame.BackgroundColor3 = Color3.new(1, 1, 1)
		local shade = Instance.new("UIGradient")
		shade.Color = GLOSS
		-- Screen-vertical: the diamond is turned 45 degrees, so its gradient turns back by as much.
		shade.Rotation = if frame == head then 45 else 90
		shade.Parent = frame
	end
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.BorderSizePixel = 0
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.BackgroundTransparency = 0.25
	shine.Position = UDim2.fromScale(0.16, 0.12)
	shine.Size = UDim2.fromScale(0.2, 0.62)
	shine.ZIndex = zIndex + 2
	local shineRound = Instance.new("UICorner")
	shineRound.CornerRadius = UDim.new(1, 0)
	shineRound.Parent = shine
	shine.Parent = shaft
	holder.Parent = parent
	return holder
end


-- A pulsing yellow ring on a control. A button keeps one border stroke ("Outline"), so the ring
-- borrows it and puts its color and thickness back afterwards.
function Guides.ring(target: GuiObject): () -> ()
	local existing = target:FindFirstChild("Outline")
	local stroke: UIStroke
	local restore: { Color: Color3, Thickness: number, Transparency: number }? = nil
	if existing ~= nil and existing:IsA("UIStroke") then
		stroke = existing
		restore = { Color = stroke.Color, Thickness = stroke.Thickness, Transparency = stroke.Transparency }
	else
		stroke = Instance.new("UIStroke")
		stroke.Name = "TutorialPulse"
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	end
	stroke.Color = Guides.GUIDE
	stroke.Thickness = 4
	stroke.Parent = target
	local tween = Guides.pulse(stroke, 0.45, { Thickness = 8, Transparency = 0.4 })
	-- Scroll a list so the control is in view (once its layout has settled).
	task.delay(0.1, function()
		local list = target:FindFirstAncestorWhichIsA("ScrollingFrame")
		if list == nil or target.Parent == nil then
			return
		end
		local offset = target.AbsolutePosition.Y - list.AbsolutePosition.Y
		if offset < 0 or offset + target.AbsoluteSize.Y > list.AbsoluteSize.Y then
			list.CanvasPosition = Vector2.new(list.CanvasPosition.X, math.max(0, list.CanvasPosition.Y + offset - 8))
		end
	end)
	return function()
		tween:Cancel()
		if restore ~= nil then
			-- If its screen restyled the outline meanwhile (a picked script turns gold), keep that.
			if stroke.Color == Guides.GUIDE then
				stroke.Color = restore.Color
				stroke.Thickness = restore.Thickness
			end
			stroke.Transparency = restore.Transparency
		else
			stroke:Destroy()
		end
	end
end

-- Glow on a world target and (unless it is a "hint") a bobbing arrow with its label over it.
-- Returns the cleanup and the arrow's board, so a caller can add pieces (the tutorial's trail).
function Guides.world(target: WorldTarget, playerGui: Instance?): { cleanup: () -> (), board: BillboardGui? }
	local made: { Instance } = {}
	local tweens: { Tween } = {}
	local boardOut: BillboardGui? = nil
	-- Glow on the target, local to this player.
	local glow = Instance.new("Highlight")
	glow.Name = "TutorialGlow"
	glow.Adornee = target.glow
	if target.kind == "hint" then
		glow.FillTransparency = 1
		glow.OutlineColor = Guides.HINT_BLUE
		glow.DepthMode = Enum.HighlightDepthMode.Occluded
	else
		glow.FillColor = Guides.GUIDE
		glow.OutlineColor = Guides.GUIDE
		local pad = target.glow:IsA("BasePart")
		glow.FillTransparency = if pad then 0.6 else 0.8
		glow.DepthMode = if pad then Enum.HighlightDepthMode.AlwaysOnTop else Enum.HighlightDepthMode.Occluded
		table.insert(tweens, Guides.pulse(glow, 0.5, { FillTransparency = if pad then 0.15 else 0.55 }))
	end
	glow.Parent = target.glow
	table.insert(made, glow)

	if target.kind ~= "hint" then
		-- A glossy arrow bobbing over the target, sized in studs so it shrinks with distance and
		-- walls hide it (the ground chevron trail still leads around them).
		local primary = target.kind == "primary"
		local studs = math.max(3, target.height * 0.35) * (if primary then 1 else 0.65)
		local board = Instance.new("BillboardGui")
		board.Name = "TutorialArrow"
		board.Adornee = target.adornee
		board.AlwaysOnTop = false
		board.LightInfluence = 0
		board.MaxDistance = 220
		board.Size = UDim2.fromScale(studs * 1.3, studs * 1.3 + (if target.label ~= "" then studs * 0.5 else 0))
		board.StudsOffsetWorldSpace = Vector3.new(0, target.height, 0)
		-- BillboardGuis do not render inside a ScreenGui; they live directly under PlayerGui.
		board.Parent = playerGui
		local labelShare = if target.label ~= "" then studs * 0.5 / board.Size.Y.Scale else 0
		if target.label ~= "" then
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Size = UDim2.fromScale(1, labelShare)
			label.TextColor3 = Guides.GUIDE
			label.Font = UiKit.DISPLAY_FONT
			label.TextScaled = true
			label.Text = target.label
			UiKit.outline(label, 3.5)
			label.Parent = board
		end
		boardOut = board
		local arrow = Guides.arrow(board, 10, 1)
		arrow.AnchorPoint = Vector2.new(0.5, 1)
		arrow.Position = UDim2.fromScale(0.5, 1)
		arrow.Size = UDim2.fromScale(studs / board.Size.X.Scale, studs / board.Size.Y.Scale)
		table.insert(tweens, Guides.pulse(board, 0.5, { StudsOffset = Vector3.new(0, studs * 0.3, 0) }))
		table.insert(made, board)
	end
	return {
		board = boardOut,
		cleanup = function()
			for _, tween in tweens do
				tween:Cancel()
			end
			for _, instance in made do
				instance:Destroy()
			end
		end,
	}
end

-- Puts the screen-edge arrow toward `point` when it is out of view (or hides it). `origin` and
-- `area` are the guide ScreenGui's AbsolutePosition and AbsoluteSize; `hidden` forces it off.
function Guides.placeEdge(edge: GuiObject, camera: Camera, point: Vector3, origin: Vector2, area: Vector2, hidden: boolean)
	local screen = camera:WorldToScreenPoint(point)
	local rel = Vector2.new(screen.X, screen.Y) - origin
	local margin = 40
	local visible = screen.Z > 0 and rel.X > margin and rel.Y > margin and rel.X < area.X - margin and rel.Y < area.Y - margin
	edge.Visible = not visible and not hidden
	if edge.Visible then
		local centre = area / 2
		local direction = rel - centre
		if screen.Z < 0 then
			direction = -direction
		end
		if direction.Magnitude < 1 then
			direction = Vector2.new(0, 1)
		end
		local inset = edge.AbsoluteSize.X / 2 + 16
		local scale = math.min((centre.X - inset) / math.max(math.abs(direction.X), 0.001), (centre.Y - inset) / math.max(math.abs(direction.Y), 0.001))
		local at = centre + direction * scale
		edge.Position = UDim2.fromOffset(at.X, at.Y)
		edge.Rotation = math.deg(math.atan2(direction.Y, direction.X)) - 90
	end
end

return Guides
