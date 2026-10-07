--!strict
-- Bottom button bar, Casting Call (agencies, odds, reveal), and the Collection screen (roster and
-- Index with reward claims). Styled after the design kit (see UiKit).
-- The client only asks; the server charges Cash, checks Fame, and decides every result.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Actors = require(ReplicatedStorage.Shared.Actors)
local Config = require(ReplicatedStorage.Shared.Config)
local Movies = require(ReplicatedStorage.Shared.Movies)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
local ClientState = require(script.Parent.ClientState)
local Fx = require(script.Parent.Fx)
local Hud = require(script.Parent.Hud)
local Icon3D = require(script.Parent.Icon3D)
local Sfx = require(script.Parent.Sfx)
local UiKit = require(script.Parent.UiKit)

local corner, textConstraint, makeLabel, makeButton = UiKit.corner, UiKit.textConstraint, UiKit.makeLabel, UiKit.makeButton
local WHITE, PANEL = UiKit.WHITE, UiKit.PANEL

local CastingUi = {}

local function fmtOdds(chance: number): string
	if chance <= 0 then
		return "never"
	end
	local oneIn = 1 / chance
	if oneIn < 1.5 then
		return string.format("%.0f%%", chance * 100)
	end
	return "1 in " .. Hud.comma(math.floor(oneIn + 0.5))
end

-- `actorsButton` (in the side menu) opens the Collection.
function CastingUi.start(gui: ScreenGui, actorsButton: TextButton)
	local player = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 15)
	if remotes == nil then
		warn("[CastingUi] Remotes folder never arrived")
		return
	end
	local castRemote = remotes:WaitForChild("Cast") :: RemoteEvent
	local castResult = remotes:WaitForChild("CastResult") :: RemoteEvent
	local claimReward = remotes:WaitForChild("ClaimReward") :: RemoteEvent

	local agencyId = "Open"
	local function currentAgency(): Actors.Agency
		return Actors.getAgency(agencyId) or Actors.Agencies[1]
	end
	local function fame(): number
		return player:GetAttribute("Fame") or 0
	end

	-- Bottom centre: the big CAST button with the Odds icon beside it ---------------------------
	local bar = Instance.new("Frame")
	bar.Name = "CastingBar"
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.BackgroundTransparency = 1
	bar.Size = UDim2.fromOffset(340, 88)
	bar.Parent = gui
	local barScale = Instance.new("UIScale")
	barScale.Parent = bar

	-- Portrait touch screens: sit above the thumbstick and jump button.
	local TOUCH_PORTRAIT_LIFT = 130
	UiKit.onViewportChanged(function()
		local viewport = UiKit.viewport()
		barScale.Scale = if UiKit.isCompact() then 0.82 else 1
		if UserInputService.TouchEnabled and viewport.X < viewport.Y then
			bar.Position = UDim2.new(0.5, 0, 1, -TOUCH_PORTRAIT_LIFT)
		else
			bar.Position = UDim2.new(0.5, 0, 1, -14)
		end
	end)

	local castButton = makeButton(bar, "", UiKit.GREEN, UDim2.fromOffset(240, 84), UDim2.fromOffset(0, 2))
	castButton.Name = "CastButton"
	castButton:SetAttribute("Silent", true) -- the reveal has its own sounds
	local oddsButton = UiKit.makeIconTile(bar, "dice", "Odds", UDim2.fromOffset(84, 84), UDim2.fromOffset(254, 2))
	local rosterButton = actorsButton
	-- The Cast button is the hero: thicker outline and text, a clapperboard, and a slow pulse.
	local castOutline = castButton:FindFirstChild("Outline") :: UIStroke
	castOutline.Thickness = 4
	local castLabel = UiKit.makeTitle(castButton, "CAST!", WHITE, UDim2.fromScale(0.6, 0.52), UDim2.fromScale(0.37, 0.08), 3)
	castLabel.Name = "Label"
	castLabel.ZIndex = castButton.ZIndex + 3
	UiKit.textConstraint(castLabel, 34)
	local costLabel = UiKit.makeTitle(castButton, "", UiKit.GOLD, UDim2.fromScale(0.6, 0.32), UDim2.fromScale(0.37, 0.6), 2)
	costLabel.Name = "Cost"
	costLabel.ZIndex = castButton.ZIndex + 3
	UiKit.textConstraint(costLabel, 22)
	local clapper = Instance.new("Frame")
	clapper.Name = "Art"
	clapper.BackgroundTransparency = 1
	clapper.AnchorPoint = Vector2.new(0.5, 0.5)
	clapper.Position = UDim2.fromScale(0.2, 0.45)
	clapper.Size = UDim2.fromScale(0.36, 1.25)
	clapper.Parent = castButton
	local clapperView = Icon3D.icon(clapper, "clapper")
	local stopWobble: (() -> ())? = nil
	UiKit.bounce(castButton, function(hovered)
		if stopWobble ~= nil then
			stopWobble()
			stopWobble = nil
		end
		if hovered then
			stopWobble = Icon3D.wobble(clapperView)
		end
	end)
	local pulse = Instance.new("UIScale")
	pulse.Name = "Pulse"
	pulse.Parent = clapper
	TweenService:Create(pulse, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.12 }):Play()

	local function refreshCastButton()
		local agency = currentAgency()
		costLabel.Text = "$" .. Hud.comma(agency.cost)
	end
	refreshCastButton()

	-- Odds panel (with agency selector) --------------------------------------------------------
	local oddsPanel, oddsList, oddsHeader = UiKit.makePanel(gui, "OddsPanel", "Casting odds", 108)
	UiKit.panelIcon(oddsPanel, oddsHeader, "dice")
	local agencyRow = Instance.new("Frame")
	agencyRow.Name = "Agencies"
	agencyRow.BackgroundTransparency = 1
	agencyRow.Position = UDim2.fromOffset(10, 58)
	agencyRow.Size = UDim2.new(1, -20, 0, 42)
	agencyRow.Parent = oddsPanel
	local agencyButtons: { [string]: TextButton } = {}

	local buildOdds: () -> ()
	local agencyTabs: { TextButton } = {}
	for slot, agency in Actors.Agencies do
		local button = makeButton(agencyRow, agency.name, UiKit.TAB_OFF, UDim2.new(0.32, 0, 1, 0), UDim2.new((slot - 1) * 0.34, 0, 0, 0))
		agencyButtons[agency.id] = button
		table.insert(agencyTabs, button)
		button.Activated:Connect(function()
			agencyId = agency.id
			refreshCastButton()
			buildOdds()
		end)
	end
	UiKit.evenText(agencyTabs, 24)

	buildOdds = function()
		UiKit.clear(oddsList)
		local agency = currentAgency()
		for id, button in agencyButtons do
			local unlocked = fame() >= (Actors.getAgency(id) :: Actors.Agency).fame
			UiKit.styleTab(button, id == agencyId)
			if id ~= agencyId and not unlocked then
				button.BackgroundColor3 = UiKit.DISABLED
				button.TextColor3 = UiKit.MUTED
			end
		end
		local luck = player:GetAttribute("Luck") or Config.BaseLuck
		local chances = Actors.tierChances(luck, agency.minTier)
		local order = 0

		order += 1
		local info = UiKit.addRow(oddsList, order, 44)
		local removed = if agency.minTier > 1 then `no {Actors.Tiers[1].name}{if agency.minTier > 2 then " or " .. Actors.Tiers[2].name else ""}` else "every tier"
		local unlocked = fame() >= agency.fame
		makeLabel(info, `${Hud.comma(agency.cost)} per cast  -  {removed}  -  {if unlocked then "unlocked" else "needs Fame " .. Hud.comma(agency.fame)}`, if unlocked then UiKit.GOLD else UiKit.WARN, UDim2.new(1, -20, 1, -8), UDim2.fromOffset(10, 4))

		for tierIndex = #Actors.Tiers, 1, -1 do
			local tier = Actors.Tiers[tierIndex]
			if chances[tier.id] > 0 then
				order += 1
				local row = UiKit.addRow(oddsList, order, 40)
				local name = UiKit.makeTitle(row, tier.name, tier.color, UDim2.fromScale(0.4, 1), UDim2.fromOffset(10, 0))
				local outline = row:FindFirstChild("Outline") :: UIStroke
				outline.Color = tier.color
				name.TextXAlignment = Enum.TextXAlignment.Left
				makeLabel(row, fmtOdds(chances[tier.id]), WHITE, UDim2.fromScale(0.3, 1), UDim2.fromScale(0.4, 0))
				makeLabel(row, "Power " .. Hud.comma(tier.starPower), UiKit.GOLD, UDim2.fromScale(0.3, 1), UDim2.fromScale(0.7, 0))
			end
		end
		local vChances = Actors.variantChances(luck)
		for _, variant in Actors.Variants do
			if variant.oneIn ~= nil then
				order += 1
				local row = UiKit.addRow(oddsList, order, 40)
				local name = UiKit.makeTitle(row, variant.name, variant.color, UDim2.fromScale(0.4, 1), UDim2.fromOffset(10, 0))
				name.TextXAlignment = Enum.TextXAlignment.Left
				makeLabel(row, fmtOdds(vChances[variant.id]), WHITE, UDim2.fromScale(0.3, 1), UDim2.fromScale(0.4, 0))
				makeLabel(row, "x" .. variant.multiplier .. " power", UiKit.GOLD, UDim2.fromScale(0.3, 1), UDim2.fromScale(0.7, 0))
			end
		end
		order += 1
		local note = UiKit.addRow(oddsList, order, 40)
		makeLabel(note, "Luck x" .. string.format("%.2f", luck) .. "  -  odds apply to every roll", UiKit.MUTED, UDim2.fromScale(1, 1))
	end

	-- Collection panel: Roster and Index tabs -------------------------------------------------
	local collection, collectionList, collectionHeader = UiKit.makePanel(gui, "RosterPanel", "Collection", 108, nil, nil, UiKit.PURPLE)
	UiKit.panelIcon(collection, collectionHeader, "star")
	local collectionTab = "Roster"
	local collectionTabs: { [string]: TextButton } = {}
	local tabRow = Instance.new("Frame")
	tabRow.Name = "Tabs"
	tabRow.BackgroundTransparency = 1
	tabRow.Position = UDim2.fromOffset(10, 58)
	tabRow.Size = UDim2.new(1, -20, 0, 42)
	tabRow.Parent = collection

	-- Actor cards, three to a row (one row per tier): the 3D figure in a frame of its rarity
	-- color, or a black silhouette and "???" until discovered, like the reference games' Index.
	local function variantChip(card: Frame, text: string, color: Color3, found: boolean, slot: number)
		local label = UiKit.makeTitle(card, text, if found then WHITE else UiKit.FAINT, UDim2.fromScale(0.28, 0.13), UDim2.fromScale(0.05 + (slot - 1) * 0.31, 0.83), 1.5)
		label.BackgroundTransparency = if found then 0 else 0.4
		label.BackgroundColor3 = if found then color:Lerp(UiKit.NAVY, 0.35) else UiKit.DARK
		label.ZIndex = 3
		corner(label, 6)
		UiKit.border(label, 2, if found then color else UiKit.INK)
		textConstraint(label, 16)
	end

	local function rarityFrame(card: Frame, tier: Actors.Tier, seen: boolean)
		local outline = card:FindFirstChild("Outline") :: UIStroke
		if not seen then
			card.BackgroundColor3 = UiKit.DARK
			return
		end
		card.BackgroundColor3 = tier.color:Lerp(UiKit.NAVY, 0.45)
		outline.Thickness = 3
		outline.Color = tier.color
		local glow = Instance.new("UIGradient")
		glow.Rotation = 90
		glow.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(120, 120, 140))
		glow.Parent = card
		if tier.id == "Icon" then
			outline.Color = WHITE
			local rainbow = Instance.new("UIGradient")
			rainbow.Color = UiKit.RAINBOW
			rainbow.Parent = outline
		end
	end

	-- `chipText(variant, found)` labels each variant chip (owned count, or found / not found).
	local function tierCards(order: number, tier: Actors.Tier, chipText: (key: string, found: boolean) -> string)
		local grid = Instance.new("Frame")
		grid.Name = "Cards_" .. tier.id
		grid.LayoutOrder = order
		grid.BackgroundTransparency = 1
		grid.Size = UDim2.new(1, -8, 0, 0)
		grid.AutomaticSize = Enum.AutomaticSize.Y
		grid.Parent = collectionList
		local layout = Instance.new("UIGridLayout")
		layout.CellSize = UDim2.new(1 / 3, -8, 0, if UiKit.isCompact() then 150 else 176)
		layout.CellPadding = UDim2.fromOffset(10, 8)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = grid
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 3)
		pad.PaddingTop = UDim.new(0, 3)
		pad.Parent = grid
		for slot, actor in Actors.actorsInTier(tier.id) do
			local seen = Upgrades.actorDiscovered(ClientState.index, actor.id)
			local card = Instance.new("Frame")
			card.Name = actor.id
			card.LayoutOrder = slot
			card.Parent = grid
			corner(card, 12)
			UiKit.border(card, 2)
			rarityFrame(card, tier, seen)

			local art = Instance.new("Frame")
			art.Name = "Art"
			art.BackgroundTransparency = 1
			art.Position = UDim2.fromScale(0.05, 0.03)
			art.Size = UDim2.fromScale(0.9, 0.54)
			art.Parent = card
			Icon3D.actor(art, actor.id, "Normal", not seen)

			local name = UiKit.makeTitle(card, if seen then actor.name else "???", if seen then WHITE else UiKit.FAINT, UDim2.fromScale(0.94, 0.13), UDim2.fromScale(0.03, 0.57), 2)
			name.ZIndex = 3
			textConstraint(name, 18)
			local genre = makeLabel(card, if seen then actor.genre else tier.name, if seen then UiKit.GENRE_COLORS[actor.genre] or UiKit.MUTED else UiKit.FAINT, UDim2.fromScale(0.94, 0.1), UDim2.fromScale(0.03, 0.71))
			genre.ZIndex = 3
			textConstraint(genre, 14)
			for chipSlot, variant in Actors.Variants do
				local key = Actors.key(actor.id, variant.id)
				local found = ClientState.index[key] == true
				variantChip(card, chipText(key, found), variant.color, found, chipSlot)
			end
		end
	end

	local function tierHeader(order: number, tier: Actors.Tier, height: number, text: string): Frame
		local head = UiKit.addRow(collectionList, order, height)
		head.BackgroundColor3 = tier.color
		local shade = Instance.new("UIGradient")
		shade.Rotation = 90
		shade.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190))
		shade.Parent = head
		UiKit.makeTitle(head, text, WHITE, UDim2.new(0.5, 0, 1, 0), UDim2.fromOffset(10, 0)).TextXAlignment = Enum.TextXAlignment.Left
		return head
	end

	local function renderRoster()
		local order = 0
		-- Common first, so a new player sees what they own without scrolling past a wall of "???".
		for _, tier in Actors.Tiers do
			order += 1
			tierHeader(order, tier, 32, tier.name)
			order += 1
			tierCards(order, tier, function(key, found)
				return if found then "x" .. (ClientState.roster[key] or 0) else "-"
			end)
		end
	end

	-- A reward line: claim button when earned, otherwise a status label.
	local function rewardControl(row: Frame, rewardId: string, earned: boolean, claimed: boolean, label: string)
		if claimed then
			local text = makeLabel(row, label .. " (claimed)", UiKit.GOLD, UDim2.new(0.5, -10, 1, 0), UDim2.new(0.5, 0, 0, 0))
			text.TextXAlignment = Enum.TextXAlignment.Right
		elseif earned then
			local button = makeButton(row, "Claim " .. label, UiKit.GREEN, UDim2.new(0.5, -10, 1, -8), UDim2.new(0.5, 0, 0, 4))
			button.Activated:Connect(function()
				claimReward:FireServer(rewardId)
			end)
		else
			local text = makeLabel(row, label .. " when complete", UiKit.MUTED, UDim2.new(0.5, -10, 1, 0), UDim2.new(0.5, 0, 0, 0))
			text.TextXAlignment = Enum.TextXAlignment.Right
		end
	end

	local function renderIndex()
		local studio = ClientState.studio
		local rewards: { [string]: boolean } = if studio ~= nil then studio.rewards else {}
		local order = 0
		for _, tier in Actors.Tiers do
			local found, total = Upgrades.tierProgress(ClientState.index, tier.id)
			local rewardId = "tier:" .. tier.id
			order += 1
			local head = tierHeader(order, tier, 44, `{tier.name}  {found}/{total}`)
			rewardControl(head, rewardId, found == total, rewards[rewardId] == true, `+{Config.TierRewardLuck} Luck`)
			order += 1
			tierCards(order, tier, function(_key, hasIt)
				return if hasIt then "+" else "-"
			end)
		end

		order += 1
		local setsHead = UiKit.addRow(collectionList, order, 32)
		setsHead.BackgroundColor3 = UiKit.AWARD_GOLD
		UiKit.makeTitle(setsHead, "Genre sets  -  discover every actor of a genre", WHITE, UDim2.new(1, -20, 1, 0), UDim2.fromOffset(10, 0)).TextXAlignment = Enum.TextXAlignment.Left
		for _, genre in Movies.Genres do
			local found, total = Upgrades.genreProgress(ClientState.index, genre)
			local rewardId = "genre:" .. genre
			order += 1
			local row = UiKit.addRow(collectionList, order, 44)
			UiKit.makeTitle(row, `{genre}  {found}/{total}`, UiKit.GENRE_COLORS[genre], UDim2.new(0.4, 0, 1, 0), UDim2.fromOffset(10, 0)).TextXAlignment = Enum.TextXAlignment.Left
			rewardControl(row, rewardId, found == total, rewards[rewardId] == true, `x{1 + Config.GenreBonus} payout`)
		end
	end

	local function buildCollection()
		-- Keep the scroll position across rebuilds (data refreshes while the panel is open).
		local scroll = collectionList.CanvasPosition
		task.defer(function()
			collectionList.CanvasPosition = scroll
		end)
		UiKit.clear(collectionList)
		for name, button in collectionTabs do
			UiKit.styleTab(button, name == collectionTab)
		end
		local discovered = 0
		for _ in ClientState.index do
			discovered += 1
		end
		collectionHeader.Text = `Collection  -  Index {discovered}/{Actors.IndexSlots}`
		if collectionTab == "Roster" then
			renderRoster()
		else
			renderIndex()
		end
	end

	for slot, name in { "Roster", "Index" } do
		local button = makeButton(tabRow, name, UiKit.TAB_OFF, UDim2.new(0.49, 0, 1, 0), UDim2.new((slot - 1) * 0.51, 0, 0, 0))
		collectionTabs[name] = button
		button.Activated:Connect(function()
			collectionTab = name
			buildCollection()
		end)
	end

	-- Reveal -----------------------------------------------------------------------------------
	local overlay = Instance.new("Frame")
	overlay.Name = "Reveal"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = UiKit.DARK
	overlay.BackgroundTransparency = 0.25
	overlay.Active = true -- swallows taps so the world is not clicked through
	overlay.Visible = false
	overlay.ZIndex = 10
	overlay.Parent = gui

	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromScale(0.85, 0.72)
	card.BackgroundColor3 = PANEL
	card.ZIndex = 11
	card.Parent = overlay
	corner(card, 20)
	local cardLimit = Instance.new("UISizeConstraint")
	cardLimit.MaxSize = Vector2.new(440, 600)
	cardLimit.Parent = card
	-- The card's frame glows in the rarity color; the Icon tier gets a rainbow.
	local stroke = UiKit.border(card, 6, WHITE)
	local rainbow = Instance.new("UIGradient")
	rainbow.Color = UiKit.RAINBOW
	rainbow.Enabled = false
	rainbow.Parent = stroke

	local function cardLabel(y: number, h: number, size: number): TextLabel
		local label = UiKit.makeTitle(card, "", WHITE, UDim2.new(0.9, 0, h, 0), UDim2.new(0.05, 0, y, 0), if size >= 30 then 3 else 2)
		label.ZIndex = 12
		textConstraint(label, size)
		return label
	end
	local tagLabel = cardLabel(0.03, 0.08, 22) -- NEW! / variant
	local nameLabel = cardLabel(0.5, 0.11, 38)
	local tierLabel = cardLabel(0.61, 0.07, 26)
	local detailLabel = cardLabel(0.68, 0.06, 20)
	local powerLabel = cardLabel(0.74, 0.06, 20)

	-- The actor (or a spinning clapperboard while casting) turns on a turntable in the card.
	local art = Instance.new("Frame")
	art.Name = "Art"
	art.BackgroundTransparency = 1
	art.AnchorPoint = Vector2.new(0.5, 0)
	art.Position = UDim2.fromScale(0.5, 0.1)
	art.Size = UDim2.fromScale(0.8, 0.4)
	art.ZIndex = 12
	art.Parent = card
	local stopSpin: (() -> ())? = nil
	local function showArt(build: (Frame) -> ViewportFrame, rpm: number): ViewportFrame
		if stopSpin ~= nil then
			stopSpin()
			stopSpin = nil
		end
		art:ClearAllChildren()
		local view = build(art)
		stopSpin = Icon3D.spin(view, rpm)
		return view
	end

	-- Light rays behind the card in the rarity color, slowly turning: six bars through the
	-- centre make twelve rays, each fading out toward its tip.
	local rays = Instance.new("Frame")
	rays.Name = "Rays"
	rays.BackgroundTransparency = 1
	rays.AnchorPoint = Vector2.new(0.5, 0.5)
	rays.Position = UDim2.fromScale(0.5, 0.45)
	rays.Size = UDim2.fromScale(1.4, 1.4)
	rays.ZIndex = 10
	rays.Parent = overlay
	local rayAspect = Instance.new("UIAspectRatioConstraint")
	rayAspect.Parent = rays
	local rayBars: { Frame } = {}
	for i = 1, 6 do
		local rayBar = Instance.new("Frame")
		rayBar.AnchorPoint = Vector2.new(0.5, 0.5)
		rayBar.Position = UDim2.fromScale(0.5, 0.5)
		rayBar.Size = UDim2.fromScale(0.09, 1)
		rayBar.BorderSizePixel = 0
		rayBar.ZIndex = 10
		rayBar.Parent = rays
		local fade = Instance.new("UIGradient")
		fade.Rotation = 90
		fade.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		})
		fade.Parent = rayBar
		rayBars[i] = rayBar
	end
	local function setRays(color: Color3?, strength: number)
		rays.Visible = color ~= nil
		for _, bar in rayBars do
			bar.BackgroundColor3 = color or WHITE
			bar.BackgroundTransparency = 1 - strength
		end
	end
	overlay:GetPropertyChangedSignal("Visible"):Connect(function()
		if not overlay.Visible and stopSpin ~= nil then
			stopSpin()
			stopSpin = nil
		end
	end)
	RunService.RenderStepped:Connect(function()
		if not (overlay.Visible and rays.Visible) then
			return
		end
		local angle = os.clock() * 12
		for i, bar in rayBars do
			bar.Rotation = angle + i * 30
		end
	end)

	local againButton = makeButton(card, "Cast again", UiKit.GREEN, UDim2.fromScale(0.44, 0.13), UDim2.fromScale(0.04, 0.83))
	local doneButton = makeButton(card, "Continue", UiKit.BLUE, UDim2.fromScale(0.44, 0.13), UDim2.fromScale(0.52, 0.83))
	againButton.ZIndex = 12
	doneButton.ZIndex = 12

	local revealToken = 0
	local function setCardVisible(visible: boolean)
		for _, child in card:GetChildren() do
			if child:IsA("GuiObject") then
				child.Visible = visible
			end
		end
	end

	local function showSuspense()
		revealToken += 1
		overlay.Visible = true
		setCardVisible(false)
		stroke.Color = UiKit.FAINT
		rainbow.Enabled = false
		nameLabel.Visible = true
		nameLabel.Text = "Casting..."
		nameLabel.TextColor3 = WHITE
		art.Visible = true
		showArt(function(frame)
			return Icon3D.icon(frame, "clapper", 0.9)
		end, 90)
		setRays(nil, 0)
		Sfx.play("whoosh")
	end

	local function showReveal(result: any)
		local actor = Actors.getActor(result.actorId)
		local variant = Actors.getVariant(result.variantId)
		local tier = if actor ~= nil then Actors.getTier(actor.tier) else nil
		if actor == nil or variant == nil or tier == nil then
			overlay.Visible = false
			return
		end
		revealToken += 1
		local mine = revealToken
		overlay.Visible = true
		setCardVisible(false)
		nameLabel.Visible = true
		nameLabel.Text = "..."
		nameLabel.TextColor3 = WHITE
		stroke.Color = UiKit.FAINT
		rainbow.Enabled = false
		-- Build-up: the new actor's silhouette spins fast, then stops spinning to show who it is.
		art.Visible = true
		showArt(function(frame)
			return Icon3D.actor(frame, actor.id, variant.id, true)
		end, 150)
		setRays(nil, 0)

		task.delay(0.7, function()
			if revealToken ~= mine then
				return
			end
			setCardVisible(true)
			showArt(function(frame)
				return Icon3D.actor(frame, actor.id, variant.id)
			end, 12)
			local rank = table.find(Actors.Tiers, tier) or 1
			setRays(if variant.id == "Normal" then tier.color else variant.color, math.clamp(0.25 + rank * 0.1, 0, 0.9))
			stroke.Color = if tier.id == "Icon" then WHITE else tier.color
			rainbow.Enabled = tier.id == "Icon"
			nameLabel.Text = actor.name
			nameLabel.TextColor3 = tier.color
			tierLabel.Text = tier.name
			tierLabel.TextColor3 = tier.color
			detailLabel.Text = actor.genre .. " specialist"
			powerLabel.Text = "Star Power " .. Hud.comma(tier.starPower * variant.multiplier)
			powerLabel.TextColor3 = UiKit.GOLD
			local tag = if result.isNew then "NEW!" else "x" .. result.count
			if variant.id ~= "Normal" then
				tag = variant.name .. "  " .. tag
				tagLabel.TextColor3 = variant.color
			else
				tagLabel.TextColor3 = if result.isNew then UiKit.GOLD else UiKit.MUTED
			end
			tagLabel.Text = tag
			Fx.castReveal(tier.id, variant.id)
			card.Size = UDim2.fromScale(0.7, 0.6)
			TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromScale(0.85, 0.72) }):Play()
		end)
	end

	-- Wiring -----------------------------------------------------------------------------------
	local function requestCast(): boolean
		local agency = currentAgency()
		if fame() < agency.fame then
			UiKit.toast(gui, `{agency.name} needs Fame {Hud.comma(agency.fame)}`)
			return false
		end
		if (player:GetAttribute("Cash") or 0) < agency.cost then
			UiKit.toast(gui, "Not enough Cash")
			return false
		end
		castRemote:FireServer(agency.id)
		return true
	end

	castButton.Activated:Connect(function()
		if overlay.Visible or not player:GetAttribute("DataLoaded") then
			return
		end
		if requestCast() then
			showSuspense()
		end
	end)
	againButton.Activated:Connect(function()
		if requestCast() then
			showSuspense()
		else
			overlay.Visible = false
		end
	end)
	doneButton.Activated:Connect(function()
		overlay.Visible = false
	end)

	castResult.OnClientEvent:Connect(function(result)
		if type(result) ~= "table" then
			return
		end
		if result.ok then
			showReveal(result)
		else
			overlay.Visible = false
			if result.reason == "cash" then
				UiKit.toast(gui, "Not enough Cash")
			elseif result.reason == "fame" then
				UiKit.toast(gui, "You need more Fame for that agency")
			elseif result.reason == "cooldown" then
				UiKit.toast(gui, "Slow down!")
			else
				UiKit.toast(gui, "Still loading your data")
			end
		end
	end)

	-- Green chip on the Actors icon: how much of the Index is found.
	local function refreshChip()
		local discovered = 0
		for _ in ClientState.index do
			discovered += 1
		end
		UiKit.chip(actorsButton, `{discovered}/{Actors.IndexSlots}`)
	end
	refreshChip()
	ClientState.changed:Connect(function()
		refreshChip()
		if collection.Visible then
			buildCollection()
		end
	end)
	player.AttributeChanged:Connect(function(name)
		if (name == "Luck" or name == "Fame") and oddsPanel.Visible then
			buildOdds()
		end
	end)

	rosterButton.Activated:Connect(function()
		UiKit.togglePanel(collection, buildCollection)
	end)
	oddsButton.Activated:Connect(function()
		UiKit.togglePanel(oddsPanel, buildOdds)
	end)
end

return CastingUi
