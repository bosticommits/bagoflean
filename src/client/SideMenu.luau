--!strict
-- Left-side button column: Shop, Rewards and Codes, with a red count badge for things to claim.
-- Sits mid-left, clear of the touch thumbstick (bottom left) and the Roblox top bar.
local UiKit = require(script.Parent.UiKit)

local SideMenu = {}

local BUTTON = 76
local GAP = 10

export type Buttons = { shop: TextButton, rewards: TextButton, codes: TextButton }

function SideMenu.start(gui: ScreenGui): Buttons
	local column = Instance.new("Frame")
	column.Name = "SideMenu"
	column.AnchorPoint = Vector2.new(0, 0.5)
	column.Position = UDim2.new(0, 12, 0.42, 0)
	column.Size = UDim2.fromOffset(BUTTON, 3 * BUTTON + 2 * GAP)
	column.BackgroundTransparency = 1
	column.Parent = gui

	local function button(order: number, text: string, color: Color3): TextButton
		local b = UiKit.makeButton(column, text, color, UDim2.fromOffset(BUTTON, BUTTON), UDim2.fromOffset(0, (order - 1) * (BUTTON + GAP)))
		b.Name = text .. "Button"
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.Color = Color3.fromRGB(20, 20, 25)
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = b
		return b
	end

	return {
		shop = button(1, "Shop", Color3.fromRGB(215, 160, 40)),
		rewards = button(2, "Rewards", Color3.fromRGB(150, 80, 200)),
		codes = button(3, "Codes", Color3.fromRGB(50, 150, 150)),
	}
end

-- Red corner badge showing `count` (hidden at 0).
function SideMenu.setBadge(button: TextButton, count: number)
	local badge = button:FindFirstChild("Badge") :: TextLabel?
	if badge == nil then
		local label = UiKit.makeLabel(button, "", UiKit.WHITE, UDim2.fromOffset(26, 26), UDim2.new(1, -18, 0, -8))
		label.Name = "Badge"
		label.BackgroundTransparency = 0
		label.BackgroundColor3 = UiKit.RED
		label.ZIndex = 3
		UiKit.corner(label, 13)
		badge = label
	end
	assert(badge ~= nil)
	badge.Text = tostring(count)
	badge.Visible = count > 0
end

return SideMenu
