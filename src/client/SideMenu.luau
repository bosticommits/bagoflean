--!strict
-- Left-side menu in the reference games' style: big floating 3D icons with outlined labels in two
-- loose columns (Shop, Rewards, Codes, Goals, Visit / Actors, Studio, Upgrade, Rebirth, Mascots), red badges for
-- things to claim, and the wallet (Cash and Fame) under them. Phones in landscape keep the bottom left clear for the
-- thumbstick, so there the wallet moves to the top centre and the menu becomes a small "5 tiles + More" rail (Shop,
-- Actors, Studio, Rewards, Codes, More); More opens a flyout with the other five (Upgrade, Goals, Rebirth, Visit,
-- Mascots) and shows their red badges combined. The ScreenGui attribute "MoreOpen" says (and sets) whether it is open.
--
-- Everything scales with the screen: up to 1.25x on tall screens, and down until the menu fits
-- above the wallet on short ones. The layout is published on the ScreenGui for the other screens:
-- "HudTop" (where the top HUD starts), "HudRight" (true when the event line belongs at the top
-- right, on touch screens) and "MenuRight" (the right edge of the menu and wallet, which panels keep
-- clear of when there is room).
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
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
-- Phones in landscape: roblox's thumbstick owns the bottom left (x < 30%, y > 62% of the screen). Six tiles in ONE
-- column cannot be 44 px tall above that line on a 375 px screen (6 x 44 = 264 px > 190 px), so the rail is two
-- columns by three rows, from the top left: Shop Actors / Studio Rewards / Codes More. The smallest tile is 46 px
-- (a 44 px tap target plus a pixel of slack).
local RAIL_COLUMNS = 2
local RAIL_ROWS = 3
local PHONE_GAP = 26 -- wider than the PC gap: the labels are 30% wider than the tiles
local PHONE_ROW_GAP = 12
local RAIL_WIDTH = RAIL_COLUMNS * BUTTON + (RAIL_COLUMNS - 1) * PHONE_GAP
local PHONE_HEIGHT = RAIL_ROWS * BUTTON + (RAIL_ROWS - 1) * PHONE_ROW_GAP
local PHONE_MIN_SCALE = 46 / BUTTON
local PHONE_MAX_SCALE = 0.7 -- bigger would squeeze the panels, which keep clear of the menu
local FLY_COLUMNS = 3
local FLY_ROWS = 2
local FLY_PAD = 16 -- inside the flyout card
local FLY_TILES_WIDTH = FLY_COLUMNS * BUTTON + (FLY_COLUMNS - 1) * PHONE_GAP
local FLY_HEIGHT = FLY_ROWS * BUTTON + (FLY_ROWS - 1) * PHONE_ROW_GAP + 2 * FLY_PAD
local FLY_MIN_SCALE = 0.78 -- the flyout may shrink to this to stay under the wallet (46 px tiles at the smallest)
local FLY_GAP = 18 -- between the rail's labels and the flyout card
local CLOSE_HIT = 46 -- px on screen
local WALLET_SHIFT = 10 -- phones: the wallet sits this far left of centre, so the Box Office card keeps a 12 px gap
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
	more: TextButton, -- phones only: opens the flyout with the tiles marked "more" below
	wallet: Frame, -- empty; the HUD fills it with the Cash and Fame rows
}

function SideMenu.start(gui: ScreenGui): Buttons
	local menu = Instance.new("Frame")
	menu.Name = "SideMenu"
	menu.BackgroundTransparency = 1
	menu.Size = UDim2.fromOffset(MENU_WIDTH, MENU_HEIGHT)
	local scale = Instance.new("UIScale")
	scale.Parent = menu

	-- Every tile with its homes: (column, row) in the PC/tablet two-column menu, and on phones either its slot (1..5) in
	-- the rail or, for the tiles marked `more`, its slot (1..5) in the More flyout.
	local tiles: { { tile: TextButton, column: number, row: number, slot: number, more: boolean } } = {}
	local function button(column: number, row: number, slot: number, more: boolean, icon: string, text: string): TextButton
		local x = (column - 1) * (BUTTON + GAP)
		local y = (row - 1) * (BUTTON + GAP) + (column - 1) * STAGGER
		local tile = UiKit.makeIconTile(menu, icon, text, UDim2.fromOffset(BUTTON, BUTTON), UDim2.fromOffset(x, y))
		-- Badges sit inside the corner, so they never land on the label of the button above.
		tile:SetAttribute("BadgeInset", true)
		table.insert(tiles, { tile = tile, column = column, row = row, slot = slot, more = more })
		return tile
	end

	-- The More flyout (phones): a card to the right of the rail holding the tiles marked `more`.
	menu.Parent = gui
	local flyout = Instance.new("Frame")
	flyout.Name = "MoreFlyout"
	flyout.AnchorPoint = Vector2.new(0, 1)
	flyout.BackgroundColor3 = UiKit.NAVY
	flyout.BackgroundTransparency = 0.04
	flyout.Size = UDim2.fromOffset(FLY_TILES_WIDTH + 2 * FLY_PAD, FLY_HEIGHT)
	flyout.Active = true -- the card swallows taps, so they do not count as taps on the world
	flyout.Visible = false
	flyout.ZIndex = 3
	flyout.Parent = menu
	UiKit.corner(flyout, 22)
	UiKit.border(flyout, UiKit.HEAVY)
	local flyScale = Instance.new("UIScale")
	flyScale.Parent = flyout
	local closeButton = UiKit.makeHitButton(flyout, "X", UiKit.CLOSE_RED, 36, CLOSE_HIT)
	closeButton.Name = "Close"
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -8, 0, 8)
	closeButton.ZIndex = 8

	-- The More tile: a round "..." stand-in (no new art) with the same label as the 3D tiles.
	local more = Instance.new("TextButton")
	more.Name = "MoreButton"
	more.AutoButtonColor = false
	more.BackgroundTransparency = 1
	more.Size = UDim2.fromOffset(BUTTON, BUTTON)
	more.Text = ""
	more.Visible = false
	more.Parent = menu
	UiKit.corner(more, 18)
	more:SetAttribute("BadgeInset", true)
	local disc = Instance.new("Frame")
	disc.Name = "Art"
	disc.AnchorPoint = Vector2.new(0.5, 0)
	disc.Position = UDim2.fromScale(0.5, 0.04)
	disc.Size = UDim2.fromScale(0.7, 0.7)
	disc.BackgroundColor3 = UiKit.BLUE
	disc.Parent = more
	UiKit.corner(disc, 40)
	UiKit.border(disc, 4)
	UiKit.bevel(disc)
	local dots = UiKit.makeTitle(disc, "...", UiKit.WHITE, UDim2.fromScale(1, 1), nil, 3)
	dots.Name = "Dots"
	UiKit.textConstraint(dots, 40)
	local moreLabel = UiKit.makeTitle(more, "More", UiKit.WHITE, UDim2.fromScale(1.3, 0.34), UDim2.fromScale(-0.15, 0.64), 3)
	moreLabel.Name = "Label"
	moreLabel.ZIndex = more.ZIndex + 5
	UiKit.textConstraint(moreLabel, 24)
	UiKit.bounce(more, nil)

	local phoneRail = false
	local flyBase = 1 -- the flyout's resting scale (layout shrinks it to fit under the wallet)
	local function isOpen(): boolean
		return gui:GetAttribute("MoreOpen") == true
	end
	local function showFlyout()
		local open = isOpen() and phoneRail
		if open and not flyout.Visible then
			flyout.Visible = true
			flyScale.Scale = 0.86 * flyBase -- opens 0.86 -> 1 in 0.3 s with a little overshoot, from the More tile's corner
			TweenService:Create(flyScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = flyBase }):Play()
		elseif open then
			flyScale.Scale = flyBase
		else
			flyout.Visible = false
		end
	end
	local function setOpen(open: boolean)
		if (gui:GetAttribute("MoreOpen") == true) ~= open then
			gui:SetAttribute("MoreOpen", open)
		end
	end
	gui:GetAttributeChangedSignal("MoreOpen"):Connect(showFlyout)
	more.Activated:Connect(function()
		setOpen(not isOpen())
	end)
	closeButton.Activated:Connect(function()
		setOpen(false)
	end)
	-- B on a gamepad, or a tap on the world (a tap on a button or on the flyout card itself is "game processed" and is
	-- handled by that button, so the More tile and the X never fight this).
	UserInputService.InputBegan:Connect(function(input, processed)
		if not isOpen() then
			return
		end
		local tap = input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1
		if input.KeyCode == Enum.KeyCode.ButtonB or (tap and not processed) then
			setOpen(false)
		end
	end)

	-- Badges are 24 px boxes under the menu's UIScale (and the flyout's): on phones each is scaled back up about its
	-- tile's top-right corner so its number stays 12 px text (the box needs about 17 px). PC and tablet: untouched.
	local railSize = 1 -- the menu's UIScale on phones
	local function boostBadge(tile: TextButton, onScreenSize: number)
		local badge = tile:FindFirstChild("Badge")
		if badge == nil or not badge:IsA("TextLabel") then
			return
		end
		local grow = badge:FindFirstChild("Boost") :: UIScale?
		if not phoneRail then
			if grow ~= nil then
				grow.Scale = 1
			end
			return
		end
		if grow == nil then
			local created = Instance.new("UIScale")
			created.Name = "Boost"
			created.Parent = badge
			badge.AnchorPoint = Vector2.new(1, 0)
			badge.Position = UDim2.new(1, -2, 0, 2)
			grow = created
		end
		assert(grow ~= nil, "SideMenu: badge boost was not created")
		grow.Scale = math.clamp(0.72 / onScreenSize, 1, 1.5)
	end
	local function boostBadges()
		for _, entry in tiles do
			boostBadge(entry.tile, if entry.more then railSize * flyBase else railSize)
		end
		boostBadge(more, railSize)
	end
	-- Red counts on the hidden tiles show on More, combined ("!" counts as 1).
	local function refreshMore()
		local total = 0
		for _, entry in tiles do
			local badge = entry.tile:FindFirstChild("Badge")
			if entry.more and badge ~= nil and badge:IsA("TextLabel") and badge.Visible then
				total += tonumber(badge.Text) or 1
			end
		end
		UiKit.badge(more, if total > 0 then (if total > 99 then "99+" else tostring(total)) else nil)
		boostBadges()
	end
	local function watchBadges(tile: TextButton)
		local function watch(child: Instance)
			if child.Name == "Badge" and child:IsA("TextLabel") then
				boostBadges()
				child:GetPropertyChangedSignal("Visible"):Connect(refreshMore)
				child:GetPropertyChangedSignal("Text"):Connect(refreshMore)
				refreshMore()
			end
		end
		tile.ChildAdded:Connect(watch)
		for _, child in tile:GetChildren() do
			watch(child)
		end
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
		phoneRail = phoneGrid
		local menuWidth, menuHeight = MENU_WIDTH, MENU_HEIGHT
		for _, entry in tiles do
			local column, row = entry.column, entry.row
			local home: Instance = menu
			local gap = GAP
			local originX, originY = 0, 0
			if phoneGrid then
				gap = PHONE_GAP
				if entry.more then
					home = flyout
					column = (entry.slot - 1) % FLY_COLUMNS + 1
					row = (entry.slot - 1) // FLY_COLUMNS + 1
					originX, originY = FLY_PAD, FLY_PAD
				else
					column = (entry.slot - 1) % RAIL_COLUMNS + 1
					row = (entry.slot - 1) // RAIL_COLUMNS + 1
				end
			end
			local x = originX + (column - 1) * (BUTTON + gap)
			local y = originY + (row - 1) * (BUTTON + (if phoneGrid then PHONE_ROW_GAP else gap)) + (if phoneGrid then 0 else (column - 1) * STAGGER)
			entry.tile.Parent = home
			entry.tile.Position = UDim2.fromOffset(x, y)
		end
		more.Visible = phoneGrid
		more.Position = UDim2.fromOffset(BUTTON + PHONE_GAP, 2 * (BUTTON + PHONE_ROW_GAP))
		if not phoneGrid then
			setOpen(false)
		end
		showFlyout()
		if phoneGrid then
			menuWidth, menuHeight = RAIL_WIDTH, PHONE_HEIGHT
			-- The thumbstick starts at 62% of the screen height; the safe area starts under the top bar.
			local room = THUMBSTICK_TOP * area.Y - (TOP_BAR * (1 - THUMBSTICK_TOP)) - top
			-- Beside the wallet at the top centre (its card pokes a little past the frame).
			local walletLeft = area.X / 2 - WALLET_SHIFT - (WALLET_WIDTH / 2 + 18) * walletSize
			size = math.clamp(math.min((walletLeft - 8 - 10) / RAIL_WIDTH, room / PHONE_HEIGHT), PHONE_MIN_SCALE, PHONE_MAX_SCALE)
			-- The flyout card hangs off the rail's right edge, its bottom level with the rail's, and shrinks (a little) so
			-- its top stays under the wallet card. The X gets its own strip on the right, 46 px on screen.
			local walletBottom = 4 + WALLET_HEIGHT * walletSize + 6
			local roomUnder = (top + PHONE_HEIGHT * size) - walletBottom
			local fly = math.clamp(roomUnder / (FLY_HEIGHT * size), FLY_MIN_SCALE, 1)
			local closeBase = math.ceil(CLOSE_HIT / (size * fly))
			flyBase = fly
			railSize = size
			boostBadges()
			flyout.Size = UDim2.fromOffset(FLY_TILES_WIDTH + 2 * FLY_PAD + closeBase, FLY_HEIGHT)
			flyout.Position = UDim2.fromOffset(RAIL_WIDTH + 0.15 * BUTTON + FLY_GAP, PHONE_HEIGHT)
			closeButton.Size = UDim2.fromOffset(closeBase, closeBase)
			local face = closeButton:FindFirstChild("Face")
			if face ~= nil and face:IsA("GuiObject") then
				face.Size = UDim2.fromOffset(math.ceil(36 / (size * fly)), math.ceil(36 / (size * fly)))
			end
			showFlyout()
			menu.Position = UDim2.fromOffset(10, top)
			wallet.AnchorPoint = Vector2.new(0.5, 0)
			wallet.Position = UDim2.new(0.5, -WALLET_SHIFT, 0, 4)
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

	-- button(pcColumn, pcRow, phoneSlot, inMoreFlyout, icon, label)
	local buttons: Buttons = {
		shop = button(1, 1, 1, false, "popcorn", "Shop"),
		rewards = button(1, 2, 4, false, "gift", "Rewards"),
		codes = button(1, 3, 5, false, "ticket", "Codes"),
		actors = button(2, 1, 2, false, "star", "Actors"),
		studio = button(2, 2, 3, false, "movieCamera", "Studio"),
		upgrade = button(2, 3, 1, true, "arrow", "Upgrade"),
		goals = button(1, 4, 2, true, "trophy", "Goals"),
		rebirth = button(2, 4, 3, true, "rebirth", "Rebirth"), -- under Upgrade: both are about growing the studio
		visit = button(1, 5, 4, true, "visit", "Visit"),
		mascots = button(2, 5, 5, true, "mascot:PopcornPup", "Mascots"),
		more = more,
		wallet = wallet,
	}
	for _, entry in tiles do
		if entry.more then
			watchBadges(entry.tile)
			entry.tile.Activated:Connect(function()
				setOpen(false) -- the tile opens its screen: the flyout has done its job
			end)
		end
	end
	layout() -- the first pass ran before the tiles existed
	return buttons
end

-- Red corner badge showing `count` (hidden at 0).
function SideMenu.setBadge(button: TextButton, count: number)
	UiKit.badge(button, if count > 0 then tostring(count) else nil)
end

return SideMenu
