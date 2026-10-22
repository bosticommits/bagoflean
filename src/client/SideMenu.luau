--!strict
-- Left-side menu in the reference games' style: big floating 3D icons with outlined labels in two
-- loose columns (Shop, Rewards, Codes, Goals, Visit / Actors, Studio, Upgrade, Rebirth, Mascots), red badges for
-- things to claim, and the wallet (Cash and Fame) under them. Phones in landscape keep the bottom left clear for the
-- thumbstick, so there the wallet moves to the top centre.
--
-- Everything scales with the screen: up to 1.25x on tall screens, and down until the menu fits
-- above the wallet on short ones. The layout is published on the ScreenGui for the other screens:
-- "HudTop" (where the top HUD starts), "HudRight" (true when the event line belongs at the top
-- right, on touch screens) and "MenuRight" (the right edge of the menu and wallet, which panels keep
-- clear of when there is room).
local UserInputService = game:GetService("UserInputService")

local UiKit = require(script.Parent.UiKit)

local SideMenu = {}

local BUTTON = 84
local GAP = 12
local STAGGER = BUTTON // 2 -- the second column starts half a button lower, like the reference
local MENU_WIDTH = 2 * BUTTON + GAP
-- Both columns have five buttons; the second is staggered half a button down.
local MENU_HEIGHT = 5 * (BUTTON + GAP) + STAGGER
local OVERHANG = 22 -- labels and the Actors chip reach this far past the second column
local WALLET_WIDTH = 260
local WALLET_HEIGHT = 96

export type Buttons = {
	shop: TextButton,
	rewards: TextButton,
	codes: TextButton,
	actors: TextButton,
	studio: TextButton,
	upgrade: TextButton,
	goals: TextButton, -- achievements
	rebirth: TextButton,
	visit: TextButton, -- studio visits
	mascots: TextButton, -- studio mascots
	wallet: Frame, -- empty; the HUD fills it with the Cash and Fame rows
}

function SideMenu.start(gui: ScreenGui): Buttons
	local menu = Instance.new("Frame")
	menu.Name = "SideMenu"
	menu.BackgroundTransparency = 1
	menu.Size = UDim2.fromOffset(MENU_WIDTH, MENU_HEIGHT)
	menu.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = menu

	local function button(column: number, row: number, icon: string, text: string): TextButton
		local x = (column - 1) * (BUTTON + GAP)
		local y = (row - 1) * (BUTTON + GAP) + (column - 1) * STAGGER
		local tile = UiKit.makeIconTile(menu, icon, text, UDim2.fromOffset(BUTTON, BUTTON), UDim2.fromOffset(x, y))
		-- Badges sit inside the corner, so they never land on the label of the button above.
		tile:SetAttribute("BadgeInset", true)
		return tile
	end

	local wallet = Instance.new("Frame")
	wallet.Name = "Wallet"
	wallet.BackgroundTransparency = 1
	wallet.Size = UDim2.fromOffset(WALLET_WIDTH, WALLET_HEIGHT)
	wallet.Parent = gui
	local walletScale = Instance.new("UIScale")
	walletScale.Parent = wallet

	local function layout()
		local area = gui.AbsoluteSize
		if area.X < 1 or area.Y < 1 then
			area = UiKit.viewport()
		end
		local grow = math.clamp(area.Y / 880, 1, 1.25)
		local walletSize = math.clamp(area.Y / 880, if area.Y < 500 then 0.8 else 1, 1.25)
		walletScale.Scale = walletSize
		local top = 8
		local size, hudTop
		local touch = UserInputService.TouchEnabled
		if touch then
			-- Thumbstick bottom left: the menu hangs from the top left, the wallet sits top centre.
			local room = area.Y * 0.74 - top
			size = math.clamp(math.min(grow, room / MENU_HEIGHT), 0.5, 1.25)
			menu.Position = UDim2.fromOffset(10, top)
			wallet.AnchorPoint = Vector2.new(0.5, 0)
			wallet.Position = UDim2.new(0.5, 0, 0, 4)
			hudTop = 4 + math.ceil(WALLET_HEIGHT * walletSize) + 2
		else
			-- The menu fills the space above the wallet (bottom left), centred in it.
			local room = area.Y - top - WALLET_HEIGHT * walletSize - 32
			size = math.clamp(math.min(grow, room / MENU_HEIGHT), 0.5, 1.25)
			menu.Position = UDim2.fromOffset(14, top + math.max(0, math.floor((room - MENU_HEIGHT * size) / 2)))
			wallet.AnchorPoint = Vector2.new(0, 1)
			wallet.Position = UDim2.new(0, 16, 1, -16)
			hudTop = 8
		end
		scale.Scale = size
		gui:SetAttribute("HudTop", hudTop)
		-- On touch screens the event line moves to the top right, off the player's character.
		gui:SetAttribute("HudRight", touch)
		local menuRight = menu.Position.X.Offset + math.ceil((MENU_WIDTH + OVERHANG) * size)
		if not touch then
			-- The wallet under the menu is wider than it: panels keep clear of the Cash number too.
			menuRight = math.max(menuRight, 16 + math.ceil(WALLET_WIDTH * walletSize))
		end
		gui:SetAttribute("MenuRight", menuRight)
	end
	UiKit.onViewportChanged(layout)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)

	return {
		shop = button(1, 1, "popcorn", "Shop"),
		rewards = button(1, 2, "gift", "Rewards"),
		codes = button(1, 3, "ticket", "Codes"),
		actors = button(2, 1, "star", "Actors"),
		studio = button(2, 2, "movieCamera", "Studio"),
		upgrade = button(2, 3, "arrow", "Upgrade"),
		goals = button(1, 4, "trophy", "Goals"),
		rebirth = button(2, 4, "rebirth", "Rebirth"), -- under Upgrade: both are about growing the studio
		visit = button(1, 5, "visit", "Visit"),
		mascots = button(2, 5, "mascot:PopcornPup", "Mascots"),
		wallet = wallet,
	}
end

-- Red corner badge showing `count` (hidden at 0).
function SideMenu.setBadge(button: TextButton, count: number)
	UiKit.badge(button, if count > 0 then tostring(count) else nil)
end

return SideMenu
