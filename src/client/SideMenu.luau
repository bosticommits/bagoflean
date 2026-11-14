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
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UiKit = require(script.Parent.UiKit)
local PhoneLayout = require(ReplicatedStorage.Shared.PhoneLayout)

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
-- Phones in landscape: roblox's thumbstick owns the bottom left (x < 30%, y > 62% of the screen), so all ten tiles
-- go in four columns by three rows from the top left, smallest 46 px (a 44 px tap target plus a pixel of slack).
local PHONE_COLUMNS = 4
local PHONE_ROWS = 3
local PHONE_GAP = 14 -- wider than the PC gap: the labels are wider than the tiles
local PHONE_WIDTH = PHONE_COLUMNS * BUTTON + (PHONE_COLUMNS - 1) * PHONE_GAP
local PHONE_HEIGHT = PHONE_ROWS * BUTTON + (PHONE_ROWS - 1) * PHONE_GAP
local PHONE_MIN_SCALE = 46 / BUTTON
local PHONE_MAX_SCALE = 0.6 -- bigger would squeeze the panels, which keep clear of the menu
local THUMBSTICK_TOP = 0.62 -- the thumbstick zone's top edge, as a fraction of the screen height
local TOP_BAR = 36 -- the Roblox top bar above the safe area, px
local CHIP_TEXT = 17 -- px a chip's box needs for 12 px text

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

	-- Every tile with its two homes: (column, row) in the PC/tablet two-column menu and its slot (1..10) in the
	-- phone grid, filled row by row.
	local tiles: { { tile: TextButton, column: number, row: number, slot: number } } = {}
	local function button(column: number, row: number, slot: number, icon: string, text: string): TextButton
		local x = (column - 1) * (BUTTON + GAP)
		local y = (row - 1) * (BUTTON + GAP) + (column - 1) * STAGGER
		local tile = UiKit.makeIconTile(menu, icon, text, UDim2.fromOffset(BUTTON, BUTTON), UDim2.fromOffset(x, y))
		-- Badges sit inside the corner, so they never land on the label of the button above.
		tile:SetAttribute("BadgeInset", true)
		table.insert(tiles, { tile = tile, column = column, row = row, slot = slot })
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
		local profile = PhoneLayout.profile(area.X, area.Y, UserInputService.TouchEnabled)
		local grow = profile.menuGrow
		local walletSize = profile.walletScale
		walletScale.Scale = walletSize
		local top = 8
		local size, hudTop
		local touch = UserInputService.TouchEnabled
		local phoneGrid = touch and profile.compact
		local menuWidth, menuHeight = MENU_WIDTH, MENU_HEIGHT
		for _, entry in tiles do
			local column, row = entry.column, entry.row
			if phoneGrid then
				column = (entry.slot - 1) % PHONE_COLUMNS + 1
				row = (entry.slot - 1) // PHONE_COLUMNS + 1
			end
			local gap = if phoneGrid then PHONE_GAP else GAP
			local x = (column - 1) * (BUTTON + gap)
			local y = (row - 1) * (BUTTON + gap) + (if phoneGrid then 0 else (column - 1) * STAGGER)
			entry.tile.Position = UDim2.fromOffset(x, y)
		end
		if phoneGrid then
			menuWidth, menuHeight = PHONE_WIDTH, PHONE_HEIGHT
			-- The thumbstick starts at 62% of the screen height; the safe area starts under the top bar.
			local room = THUMBSTICK_TOP * area.Y - (TOP_BAR * (1 - THUMBSTICK_TOP)) - top
			-- Beside the wallet at the top centre (its card pokes a little past the frame).
			local walletLeft = area.X / 2 - (WALLET_WIDTH / 2 + 18) * walletSize
			size = math.clamp(math.min((walletLeft - 8 - 10) / PHONE_WIDTH, room / PHONE_HEIGHT), PHONE_MIN_SCALE, PHONE_MAX_SCALE)
			menu.Position = UDim2.fromOffset(10, top)
			wallet.AnchorPoint = Vector2.new(0.5, 0)
			wallet.Position = UDim2.new(0.5, 0, 0, 4)
			hudTop = 4 + math.ceil(WALLET_HEIGHT * walletSize) + 2
		elseif touch then
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
		menu.Size = UDim2.fromOffset(menuWidth, menuHeight)
		-- Chips ("2/63") stay 12 px tall text however small the tiles are scaled.
		for _, entry in tiles do
			entry.tile:SetAttribute("ChipInset", phoneGrid)
			entry.tile:SetAttribute("ChipBoost", if phoneGrid then math.max(1, CHIP_TEXT / (22 * size) * 1.1) else nil)
			UiKit.boostChip(entry.tile)
		end
		gui:SetAttribute("HudTop", hudTop)
		-- On touch screens the event line moves to the top right, off the player's character.
		gui:SetAttribute("HudRight", touch)
		local menuRight = menu.Position.X.Offset + math.ceil((menuWidth + (if phoneGrid then 0.15 * BUTTON else OVERHANG)) * size)
		if not touch then
			-- The wallet under the menu is wider than it: panels keep clear of the Cash number too.
			menuRight = math.max(menuRight, 16 + math.ceil(WALLET_WIDTH * walletSize))
		end
		gui:SetAttribute("MenuRight", menuRight)
	end
	UiKit.onViewportChanged(layout)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)

	local buttons: Buttons = {
		shop = button(1, 1, 4, "popcorn", "Shop"),
		rewards = button(1, 2, 5, "gift", "Rewards"),
		codes = button(1, 3, 6, "ticket", "Codes"),
		actors = button(2, 1, 1, "star", "Actors"),
		studio = button(2, 2, 2, "movieCamera", "Studio"),
		upgrade = button(2, 3, 3, "arrow", "Upgrade"),
		goals = button(1, 4, 7, "trophy", "Goals"),
		rebirth = button(2, 4, 8, "rebirth", "Rebirth"), -- under Upgrade: both are about growing the studio
		visit = button(1, 5, 9, "visit", "Visit"),
		mascots = button(2, 5, 10, "mascot:PopcornPup", "Mascots"),
		wallet = wallet,
	}
	layout() -- the first pass ran before the tiles existed
	return buttons
end

-- Red corner badge showing `count` (hidden at 0).
function SideMenu.setBadge(button: TextButton, count: number)
	UiKit.badge(button, if count > 0 then tostring(count) else nil)
end

return SideMenu
