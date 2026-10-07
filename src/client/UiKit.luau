--!strict
-- Small helpers shared by the placeholder screens. Real visuals come in M5.
local UiKit = {}

UiKit.DARK = Color3.fromRGB(25, 25, 35)
UiKit.PANEL = Color3.fromRGB(38, 38, 52)
UiKit.WHITE = Color3.new(1, 1, 1)
UiKit.MUTED = Color3.fromRGB(170, 170, 185)
UiKit.GOLD = Color3.fromRGB(255, 220, 90)
UiKit.GREEN = Color3.fromRGB(70, 160, 90)
UiKit.RED = Color3.fromRGB(230, 70, 70)
UiKit.BLUE = Color3.fromRGB(70, 90, 160)

function UiKit.corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

function UiKit.textConstraint(label: TextLabel | TextButton, maxSize: number)
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = maxSize
	c.Parent = label
end

function UiKit.makeLabel(parent: Instance, text: string, color: Color3, size: UDim2, position: UDim2?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = size
	label.Position = position or UDim2.new()
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = parent
	UiKit.textConstraint(label, 28)
	return label
end

function UiKit.makeButton(parent: Instance, text: string, color: Color3, size: UDim2, position: UDim2?): TextButton
	local button = Instance.new("TextButton")
	button.AutoButtonColor = true
	button.BackgroundColor3 = color
	button.Size = size
	button.Position = position or UDim2.new()
	button.Text = text
	button.TextColor3 = UiKit.WHITE
	button.TextScaled = true
	button.Font = Enum.Font.GothamBold
	button.Parent = parent
	UiKit.corner(button, 10)
	UiKit.textConstraint(button, 26)
	return button
end

-- Bottom-of-screen message that fades after two seconds.
local toastLabel: TextLabel? = nil
local toastToken = 0
function UiKit.toast(gui: ScreenGui, text: string)
	local label = toastLabel
	if label == nil then
		label = UiKit.makeLabel(gui, "", UiKit.WHITE, UDim2.fromOffset(320, 40), UDim2.new(0.5, -160, 1, -140))
		label.Name = "Toast"
		label.BackgroundTransparency = 0.2
		label.BackgroundColor3 = UiKit.DARK
		label.ZIndex = 20
		UiKit.corner(label, 10)
		toastLabel = label
	end
	assert(label ~= nil)
	toastToken += 1
	local mine = toastToken
	label.Text = text
	label.Visible = true
	task.delay(2, function()
		if toastToken == mine then
			label.Visible = false
		end
	end)
end

-- Panels --------------------------------------------------------------------------------------
local exclusivePanels: { Frame } = {}

function UiKit.closePanels()
	for _, panel in exclusivePanels do
		panel.Visible = false
	end
end

-- Opens `panel` (building it first) and closes the other panels; opens nothing if it was open.
function UiKit.togglePanel(panel: Frame, build: () -> ())
	local willOpen = not panel.Visible
	UiKit.closePanels()
	if willOpen then
		build()
		panel.Visible = true
	end
end

-- A centered window with a title, close button and scrolling list.
-- `topOffset` leaves room under the header for a tab row; `modal` panels sit above the others and
-- are not closed by togglePanel.
function UiKit.makePanel(gui: ScreenGui, name: string, title: string, topOffset: number?, modal: boolean?): (Frame, ScrollingFrame, TextLabel)
	local top = topOffset or 60
	local panel = Instance.new("Frame")
	panel.Name = name
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.92, 0.72)
	panel.BackgroundColor3 = UiKit.PANEL
	panel.Visible = false
	panel.ZIndex = if modal then 5 else 1
	panel.Parent = gui
	UiKit.corner(panel, 14)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(560, 640)
	limit.Parent = panel
	if not modal then
		table.insert(exclusivePanels, panel)
	end

	local header = UiKit.makeLabel(panel, title, UiKit.WHITE, UDim2.new(1, -70, 0, 44), UDim2.fromOffset(14, 8))
	header.TextXAlignment = Enum.TextXAlignment.Left
	local close = UiKit.makeButton(panel, "X", Color3.fromRGB(200, 60, 60), UDim2.fromOffset(44, 44), UDim2.new(1, -54, 0, 8))
	close.Name = "Close"
	close.Activated:Connect(function()
		panel.Visible = false
	end)

	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromOffset(10, top)
	list.Size = UDim2.new(1, -20, 1, -(top + 10))
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	return panel, list, header
end

function UiKit.clear(list: ScrollingFrame)
	for _, child in list:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
end

function UiKit.addRow(list: ScrollingFrame, order: number, height: number): Frame
	local row = Instance.new("Frame")
	row.LayoutOrder = order
	row.Size = UDim2.new(1, -8, 0, height)
	row.BackgroundColor3 = UiKit.DARK
	row.BackgroundTransparency = 0.3
	row.Parent = list
	UiKit.corner(row, 8)
	return row
end

return UiKit
