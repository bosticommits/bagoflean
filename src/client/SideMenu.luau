--!strict
-- Left-side menu in the reference games' style: big floating 3D icons with outlined labels in two
-- loose columns (Shop, Rewards, Codes / Actors, Studio, Upgrade), red badges for things to claim,
-- and the wallet (Cash and Fame) under them. Phones in landscape keep the bottom left clear for the
-- thumbstick, so there the wallet moves to the top centre.
local UserInputService = game:GetService("UserInputService")

local UiKit = require(script.Parent.UiKit)

local SideMenu = {}

local BUTTON = 84
local GAP = 6
local STAGGER = BUTTON // 2 -- the second column starts half a button lower, like the reference
local WALLET_HEIGHT = 96

export type Buttons = {
	shop: TextButton,
	rewards: TextButton,
	codes: TextButton,
	actors: TextButton,
	studio: TextButton,
	upgrade: TextButton,
	wallet: Frame, -- empty; the HUD fills it with the Cash and Fame rows
}

function SideMenu.start(gui: ScreenGui): Buttons
	local menu = Instance.new("Frame")
	menu.Name = "SideMenu"
	menu.AnchorPoint = Vector2.new(0, 0.5)
	menu.BackgroundTransparency = 1
	menu.Size = UDim2.fromOffset(2 * BUTTON + GAP, 3 * (BUTTON + GAP) + STAGGER)
	menu.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = menu

	local function button(column: number, row: number, icon: string, text: string): TextButton
		local x = (column - 1) * (BUTTON + GAP)
		local y = (row - 1) * (BUTTON + GAP) + (column - 1) * STAGGER
		return UiKit.makeIconTile(menu, icon, text, UDim2.fromOffset(BUTTON, BUTTON), UDim2.fromOffset(x, y))
	end

	local wallet = Instance.new("Frame")
	wallet.Name = "Wallet"
	wallet.BackgroundTransparency = 1
	wallet.Size = UDim2.fromOffset(260, WALLET_HEIGHT)
	wallet.Parent = gui
	local walletScale = Instance.new("UIScale")
	walletScale.Parent = wallet

	UiKit.onViewportChanged(function()
		local compact = UiKit.isCompact()
		scale.Scale = if compact then 0.72 else 1
		walletScale.Scale = if compact then 0.8 else 1
		if UserInputService.TouchEnabled then
			-- Thumbstick bottom left: menu sits high on the left, wallet at the top centre.
			menu.Position = UDim2.new(0, 10, 0.42, 0)
			wallet.AnchorPoint = Vector2.new(0.5, 0)
			wallet.Position = UDim2.new(0.5, 0, 0, 4)
		else
			menu.Position = UDim2.new(0, 14, 0.4, 0)
			wallet.AnchorPoint = Vector2.new(0, 1)
			wallet.Position = UDim2.new(0, 16, 1, -16)
		end
	end)

	return {
		shop = button(1, 1, "popcorn", "Shop"),
		rewards = button(1, 2, "gift", "Rewards"),
		codes = button(1, 3, "ticket", "Codes"),
		actors = button(2, 1, "star", "Actors"),
		studio = button(2, 2, "movieCamera", "Studio"),
		upgrade = button(2, 3, "arrow", "Upgrade"),
		wallet = wallet,
	}
end

-- Red corner badge showing `count` (hidden at 0).
function SideMenu.setBadge(button: TextButton, count: number)
	UiKit.badge(button, if count > 0 then tostring(count) else nil)
end

return SideMenu
