--!strict
-- Bottom button bar, Casting Call (agencies, odds, reveal), and the Collection screen (roster and
-- Index with reward claims). Placeholder visuals until M5.
-- The client only asks; the server charges Cash, checks Fame, and decides every result.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Actors = require(ReplicatedStorage.Shared.Actors)
local Config = require(ReplicatedStorage.Shared.Config)
local Movies = require(ReplicatedStorage.Shared.Movies)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
local ClientState = require(script.Parent.ClientState)
local Hud = require(script.Parent.Hud)
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

-- Returns the Studio and Upgrades buttons so those screens can attach to them.
function CastingUi.start(gui: ScreenGui): (TextButton?, TextButton?)
	local player = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 15)
	if remotes == nil then
		warn("[CastingUi] Remotes folder never arrived")
		return nil, nil
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

	-- Bottom bar -------------------------------------------------------------------------------
	local bar = Instance.new("Frame")
	bar.Name = "CastingBar"
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.BackgroundTransparency = 1
	bar.Parent = gui
	local barLimit = Instance.new("UISizeConstraint")
	barLimit.MaxSize = Vector2.new(560, 80)
	barLimit.Parent = bar

	-- Roblox draws the thumbstick (bottom left) and jump button (bottom right) over our UI on touch
	-- devices. Landscape: leave both side zones clear. Portrait: sit above the control cluster.
	local TOUCH_SIDE_ZONE = 150
	local TOUCH_PORTRAIT_LIFT = 130
	UiKit.onViewportChanged(function()
		local viewport = UiKit.viewport()
		if UserInputService.TouchEnabled and viewport.X >= viewport.Y then
			bar.Position = UDim2.new(0.5, 0, 1, -16)
			bar.Size = UDim2.new(1, -2 * TOUCH_SIDE_ZONE, 0, 64)
		elseif UserInputService.TouchEnabled then
			bar.Position = UDim2.new(0.5, 0, 1, -TOUCH_PORTRAIT_LIFT)
			bar.Size = UDim2.new(0.96, 0, 0, 64)
		else
			bar.Position = UDim2.new(0.5, 0, 1, -16)
			bar.Size = UDim2.new(0.92, 0, 0, 72)
		end
	end)

	local rosterButton = makeButton(bar, "Roster", UiKit.BLUE, UDim2.fromScale(0.17, 1))
	local studioButton = makeButton(bar, "Studio", Color3.fromRGB(70, 130, 110), UDim2.fromScale(0.17, 1), UDim2.fromScale(0.18, 0))
	studioButton.Name = "StudioButton"
	local castButton = makeButton(bar, "", UiKit.RED, UDim2.fromScale(0.28, 1), UDim2.fromScale(0.36, 0))
	castButton.Name = "CastButton"
	local oddsButton = makeButton(bar, "Odds", UiKit.BLUE, UDim2.fromScale(0.17, 1), UDim2.fromScale(0.65, 0))
	local upgradesButton = makeButton(bar, "Upgrade", Color3.fromRGB(150, 110, 50), UDim2.fromScale(0.17, 1), UDim2.fromScale(0.83, 0))
	upgradesButton.Name = "UpgradesButton"

	local function refreshCastButton()
		local agency = currentAgency()
		castButton.Text = "CAST  $" .. Hud.comma(agency.cost)
	end
	refreshCastButton()

	-- Odds panel (with agency selector) --------------------------------------------------------
	local oddsPanel, oddsList = UiKit.makePanel(gui, "OddsPanel", "Casting odds", 108)
	local agencyRow = Instance.new("Frame")
	agencyRow.Name = "Agencies"
	agencyRow.BackgroundTransparency = 1
	agencyRow.Position = UDim2.fromOffset(10, 58)
	agencyRow.Size = UDim2.new(1, -20, 0, 42)
	agencyRow.Parent = oddsPanel
	local agencyButtons: { [string]: TextButton } = {}

	local buildOdds: () -> ()
	for slot, agency in Actors.Agencies do
		local button = makeButton(agencyRow, agency.name, UiKit.BLUE, UDim2.new(0.32, 0, 1, 0), UDim2.new((slot - 1) * 0.34, 0, 0, 0))
		agencyButtons[agency.id] = button
		button.Activated:Connect(function()
			agencyId = agency.id
			refreshCastButton()
			buildOdds()
		end)
	end

	buildOdds = function()
		UiKit.clear(oddsList)
		local agency = currentAgency()
		for id, button in agencyButtons do
			local unlocked = fame() >= (Actors.getAgency(id) :: Actors.Agency).fame
			button.BackgroundColor3 = if id == agencyId then Color3.fromRGB(70, 130, 110) elseif unlocked then UiKit.BLUE else Color3.fromRGB(70, 70, 80)
		end
		local luck = player:GetAttribute("Luck") or Config.BaseLuck
		local chances = Actors.tierChances(luck, agency.minTier)
		local order = 0

		order += 1
		local info = UiKit.addRow(oddsList, order, 44)
		local removed = if agency.minTier > 1 then `no {Actors.Tiers[1].name}{if agency.minTier > 2 then " or " .. Actors.Tiers[2].name else ""}` else "every tier"
		local unlocked = fame() >= agency.fame
		makeLabel(info, `${Hud.comma(agency.cost)} per cast  -  {removed}  -  {if unlocked then "unlocked" else "needs Fame " .. Hud.comma(agency.fame)}`, if unlocked then UiKit.GOLD else Color3.fromRGB(220, 110, 110), UDim2.new(1, -20, 1, -8), UDim2.fromOffset(10, 4))

		for tierIndex = #Actors.Tiers, 1, -1 do
			local tier = Actors.Tiers[tierIndex]
			if chances[tier.id] > 0 then
				order += 1
				local row = UiKit.addRow(oddsList, order, 40)
				local name = makeLabel(row, tier.name, tier.color, UDim2.fromScale(0.4, 1), UDim2.fromOffset(10, 0))
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
				local name = makeLabel(row, variant.name, variant.color, UDim2.fromScale(0.4, 1), UDim2.fromOffset(10, 0))
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
	local collection, collectionList, collectionHeader = UiKit.makePanel(gui, "RosterPanel", "Collection", 108)
	local collectionTab = "Roster"
	local collectionTabs: { [string]: TextButton } = {}
	local tabRow = Instance.new("Frame")
	tabRow.Name = "Tabs"
	tabRow.BackgroundTransparency = 1
	tabRow.Position = UDim2.fromOffset(10, 58)
	tabRow.Size = UDim2.new(1, -20, 0, 42)
	tabRow.Parent = collection

	local function chip(row: Frame, text: string, color: Color3, found: boolean, slot: number)
		local label = makeLabel(row, text, if found then color else Color3.fromRGB(100, 100, 110), UDim2.fromScale(0.14, 0.7), UDim2.fromScale(0.5 + (slot - 1) * 0.16, 0.15))
		label.BackgroundTransparency = 0.7
		label.BackgroundColor3 = if found then color else Color3.fromRGB(60, 60, 70)
		corner(label, 6)
	end

	local function actorRowLabels(row: Frame, actor: Actors.Actor, seen: boolean)
		local name = makeLabel(row, if seen then actor.name else "???", if seen then WHITE else Color3.fromRGB(130, 130, 140), UDim2.fromScale(0.5, 0.6), UDim2.fromOffset(10, 2))
		name.TextXAlignment = Enum.TextXAlignment.Left
		local genre = makeLabel(row, if seen then actor.genre else "", UiKit.MUTED, UDim2.fromScale(0.5, 0.35), UDim2.new(0, 10, 0.62, 0))
		genre.TextXAlignment = Enum.TextXAlignment.Left
	end

	local function renderRoster()
		local order = 0
		-- Common first, so a new player sees what they own without scrolling past a wall of "???".
		for _, tier in Actors.Tiers do
			order += 1
			local head = UiKit.addRow(collectionList, order, 28)
			head.BackgroundColor3 = tier.color
			head.BackgroundTransparency = 0.55
			makeLabel(head, tier.name, WHITE, UDim2.fromScale(1, 1), UDim2.fromOffset(10, 0)).TextXAlignment = Enum.TextXAlignment.Left
			for _, actor in Actors.actorsInTier(tier.id) do
				order += 1
				local row = UiKit.addRow(collectionList, order, 48)
				actorRowLabels(row, actor, Upgrades.actorDiscovered(ClientState.index, actor.id))
				for slot, variant in Actors.Variants do
					local key = Actors.key(actor.id, variant.id)
					local found = ClientState.index[key] == true
					chip(row, if found then "x" .. (ClientState.roster[key] or 0) else "-", variant.color, found, slot)
				end
			end
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
			local head = UiKit.addRow(collectionList, order, 40)
			head.BackgroundColor3 = tier.color
			head.BackgroundTransparency = 0.55
			makeLabel(head, `{tier.name}  {found}/{total}`, WHITE, UDim2.new(0.4, 0, 1, 0), UDim2.fromOffset(10, 0)).TextXAlignment = Enum.TextXAlignment.Left
			rewardControl(head, rewardId, found == total, rewards[rewardId] == true, `+{Config.TierRewardLuck} Luck`)
			for _, actor in Actors.actorsInTier(tier.id) do
				order += 1
				local row = UiKit.addRow(collectionList, order, 44)
				actorRowLabels(row, actor, Upgrades.actorDiscovered(ClientState.index, actor.id))
				for slot, variant in Actors.Variants do
					local key = Actors.key(actor.id, variant.id)
					local hasIt = ClientState.index[key] == true
					chip(row, if hasIt then "+" else "-", variant.color, hasIt, slot)
				end
			end
		end

		order += 1
		local setsHead = UiKit.addRow(collectionList, order, 32)
		setsHead.BackgroundColor3 = UiKit.GOLD
		setsHead.BackgroundTransparency = 0.6
		makeLabel(setsHead, "Genre sets  -  discover every actor of a genre", WHITE, UDim2.new(1, -20, 1, 0), UDim2.fromOffset(10, 0)).TextXAlignment = Enum.TextXAlignment.Left
		for _, genre in Movies.Genres do
			local found, total = Upgrades.genreProgress(ClientState.index, genre)
			local rewardId = "genre:" .. genre
			order += 1
			local row = UiKit.addRow(collectionList, order, 44)
			makeLabel(row, `{genre}  {found}/{total}`, UiKit.GENRE_COLORS[genre], UDim2.new(0.4, 0, 1, 0), UDim2.fromOffset(10, 0)).TextXAlignment = Enum.TextXAlignment.Left
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
			button.BackgroundColor3 = if name == collectionTab then Color3.fromRGB(70, 130, 110) else UiKit.BLUE
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
		local button = makeButton(tabRow, name, UiKit.BLUE, UDim2.new(0.49, 0, 1, 0), UDim2.new((slot - 1) * 0.51, 0, 0, 0))
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
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.35
	overlay.Active = true -- swallows taps so the world is not clicked through
	overlay.Visible = false
	overlay.ZIndex = 10
	overlay.Parent = gui

	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromScale(0.85, 0.6)
	card.BackgroundColor3 = PANEL
	card.ZIndex = 11
	card.Parent = overlay
	corner(card, 16)
	local cardLimit = Instance.new("UISizeConstraint")
	cardLimit.MaxSize = Vector2.new(440, 480)
	cardLimit.Parent = card
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = WHITE
	stroke.Parent = card

	local function cardLabel(y: number, h: number, size: number): TextLabel
		local label = makeLabel(card, "", WHITE, UDim2.new(0.9, 0, h, 0), UDim2.new(0.05, 0, y, 0))
		label.ZIndex = 12
		textConstraint(label, size)
		return label
	end
	local tagLabel = cardLabel(0.04, 0.1, 22) -- NEW! / variant
	local nameLabel = cardLabel(0.16, 0.2, 40)
	local tierLabel = cardLabel(0.38, 0.1, 26)
	local detailLabel = cardLabel(0.5, 0.1, 22)
	local powerLabel = cardLabel(0.6, 0.1, 22)

	local againButton = makeButton(card, "Cast again", UiKit.RED, UDim2.fromScale(0.44, 0.15), UDim2.fromScale(0.04, 0.8))
	local doneButton = makeButton(card, "Continue", UiKit.GREEN, UDim2.fromScale(0.44, 0.15), UDim2.fromScale(0.52, 0.8))
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
		stroke.Color = Color3.fromRGB(120, 120, 140)
		nameLabel.Visible = true
		nameLabel.Text = "Casting..."
		nameLabel.TextColor3 = WHITE
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
		stroke.Color = Color3.fromRGB(120, 120, 140)

		task.delay(0.7, function()
			if revealToken ~= mine then
				return
			end
			setCardVisible(true)
			stroke.Color = tier.color
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
			card.Size = UDim2.fromScale(0.7, 0.5)
			TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromScale(0.85, 0.6) }):Play()
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

	ClientState.changed:Connect(function()
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

	return studioButton, upgradesButton
end

return CastingUi
