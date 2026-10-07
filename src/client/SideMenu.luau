--!strict
-- Left-side column of picture tiles: Shop, Rewards and Codes, with a red count badge for things
-- to claim.
-- Sits mid-left, clear of the touch thumbstick (bottom left) and the Roblox top bar.
local UiKit = require(script.Parent.UiKit)

local SideMenu = {}

local BUTTON = 80
local GAP = 12

export type Buttons = { shop: TextButton, rewards: TextButton, codes: TextButton }

function SideMenu.start(gui: ScreenGui): Buttons
	local column = Instance.new("Frame")
	column.Name = "SideMenu"
	column.AnchorPoint = Vector2.new(0, 0.5)
	column.Position = UDim2.new(0, 12, 0.42, 0)
	column.Size = UDim2.fromOffset(BUTTON, 3 * BUTTON + 2 * GAP)
	column.BackgroundTransparency = 1
	column.Parent = gui

	local function button(order: number, icon: string, text: string, color: Color3): TextButton
		return UiKit.makeIconTile(column, icon, text, color, UDim2.fromOffset(BUTTON, BUTTON), UDim2.fromOffset(0, (order - 1) * (BUTTON + GAP)))
	end

	return {
		shop = button(1, "popcorn", "Shop", UiKit.AWARD_GOLD),
		rewards = button(2, "gift", "Rewards", UiKit.PURPLE),
		codes = button(3, "ticket", "Codes", UiKit.BLUE),
	}
end

-- Red corner badge showing `count` (hidden at 0).
function SideMenu.setBadge(button: TextButton, count: number)
	UiKit.badge(button, if count > 0 then tostring(count) else nil)
end

return SideMenu
