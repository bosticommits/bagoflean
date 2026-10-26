--!strict
-- Bottom button bar, Casting Call (agencies, odds, reveal), and the Collection screen (roster and
-- Index with reward claims). Styled after the design kit (see UiKit).
-- The client only asks; the server charges Cash, checks Fame, and decides every result.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Actors = require(ReplicatedStorage.Shared.Actors)
local Config = require(ReplicatedStorage.Shared.Config)
local Movies = require(ReplicatedStorage.Shared.Movies)
local Reveal = require(ReplicatedStorage.Shared.Reveal)
local SpecialEvents = require(ReplicatedStorage.Shared.SpecialEvents)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
local ClientState = require(script.Parent.ClientState)
local Fx = require(script.Parent.Fx)
local Hud = require(script.Parent.Hud)
local Icon3D = require(script.Parent.Icon3D)
local Screens = require(script.Parent.Screens)
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

-- The limited actor in season right now: the one of this week's seasonal Film Festival, as the
-- server published it (SpecialEventService's "Festival" attribute), or nil.
-- Also its last day for people ("Nov 1"; the festival ends the Monday after).
local function limitedInSeason(): (Actors.Actor?, string?)
	local raw = ReplicatedStorage:GetAttribute("Festival")
	if type(raw) ~= "string" then
		return nil
	end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not ok or type(data) ~= "table" or type(data.season) ~= "string" then
		return nil
	end
	local lastDay = if type(data.ends) == "number" then os.date("!%b %d", data.ends - 1):gsub(" 0", " ") else nil
	return Actors.limitedFor(data.season), lastDay
end

-- Index slots found: every actor-and-variant in the everyday Index (limited actors are counted on
-- their own, in the Collection's Limited group).
local function indexFound(): number
	local found = 0
	for key, hasIt in ClientState.index do
		if hasIt == true and not Actors.isLimited(string.split(key, ":")[1] or "") then
			found += 1
		end
	end
	return found
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

	-- Guarantee meter over the Cast button: counts down to the next guaranteed pull, whichever
	-- comes sooner: a new player's "Discovered!" hot start step (Actors.HotStart) or the chosen
	-- agency's pity meter (Actors.PityEvery, mirrored by the server as Pity<agencyId>).
	local hotBar = Instance.new("Frame")
	hotBar.Name = "HotStart"
	hotBar.BackgroundColor3 = UiKit.DARK
	hotBar.Position = UDim2.fromOffset(0, -34)
	hotBar.Size = UDim2.fromOffset(240, 28)
	hotBar.Visible = false
	hotBar.Parent = bar
	corner(hotBar, 14)
	UiKit.border(hotBar, 3)
	local hotFill = Instance.new("Frame")
	hotFill.Name = "Fill"
	hotFill.BorderSizePixel = 0
	hotFill.Size = UDim2.fromScale(0, 1)
	hotFill.Parent = hotBar
	corner(hotFill, 14)
	local hotLabel = UiKit.makeTitle(hotBar, "", WHITE, UDim2.new(1, -16, 1, -6), UDim2.fromOffset(8, 3), 2)
	hotLabel.ZIndex = hotFill.ZIndex + 1
	textConstraint(hotLabel, 18)
	local function refreshHotStart()
		local done = player:GetAttribute("HotStart")
		local agency = currentAgency()
		local pityCount = player:GetAttribute("Pity" .. agency.id)
		-- (tier, casts left, fraction filled) of the sooner guarantee
		local tierId, left, fraction = nil, math.huge, 0
		local step = if type(done) == "number" then Actors.nextHotStart(done) else nil
		if step ~= nil and (done :: number) > 0 then
			local previous = 0
			for _, other in Actors.HotStart do
				if other.cast < step.cast then
					previous = other.cast
				end
			end
			tierId, left = step.tier, step.cast - (done :: number)
			fraction = ((done :: number) - previous) / (step.cast - previous)
		end
		if type(pityCount) == "number" and Actors.PityEvery - pityCount < left then
			tierId, left, fraction = agency.pity, Actors.PityEvery - pityCount, pityCount / Actors.PityEvery
		end
		hotBar.Visible = tierId ~= nil and player:GetAttribute("DataLoaded") == true
		if tierId == nil then
			return
		end
		local tier = Actors.getTier(tierId) :: Actors.Tier
		hotLabel.Text = if left == 1
			then `{string.upper(tier.name)} GUARANTEED NEXT CAST!`
			else `{string.upper(tier.name)} GUARANTEED IN {left} CASTS`
		hotFill.BackgroundColor3 = tier.color
		TweenService:Create(hotFill, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1) }):Play()
	end
	refreshHotStart()

	-- In season, a gold tag over the Cast button features the limited actor and its odds; it
	-- sits above the hot start bar when that shows, and opens the odds.
	local limitedTag = makeButton(bar, "", UiKit.DARK, UDim2.fromOffset(340, 28), UDim2.fromOffset(0, -34))
	limitedTag.Name = "LimitedTag"
	limitedTag.Visible = false
	local limitedOutline = limitedTag:FindFirstChild("Outline")
	if limitedOutline ~= nil and limitedOutline:IsA("UIStroke") then
		limitedOutline.Color = UiKit.GOLD
	end
	local limitedLabel = UiKit.makeTitle(limitedTag, "", UiKit.GOLD, UDim2.new(1, -16, 1, -6), UDim2.fromOffset(8, 3), 2)
	limitedLabel.RichText = true
	limitedLabel.ZIndex = limitedTag.ZIndex + 1
	textConstraint(limitedLabel, 18)
	local function refreshLimitedTag()
		local limited, lastDay = limitedInSeason()
		local tier = if limited ~= nil then Actors.getTier(limited.tier) else nil
		local luck = player:GetAttribute("Luck") or Config.BaseLuck
		local chances = Actors.tierChances(luck, currentAgency().minTier)
		limitedTag.Visible = limited ~= nil and tier ~= nil and chances[tier.id] > 0
		if limited == nil then
			return
		end
		local odds = fmtOdds(Actors.limitedChance(chances, limited))
		local untilText = if lastDay ~= nil then `, until {lastDay}` else ""
		limitedLabel.Text = `LIMITED: {limited.name}  <font color="#FFFFFF">{odds}</font>{untilText}`
		limitedTag.Position = UDim2.fromOffset(0, if hotBar.Visible then -68 else -34)
	end
	refreshLimitedTag()
	ReplicatedStorage:GetAttributeChangedSignal("Festival"):Connect(refreshLimitedTag)
	hotBar:GetPropertyChangedSignal("Visible"):Connect(refreshLimitedTag)

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
			refreshHotStart()
			refreshLimitedTag()
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
		-- A limited actor in season: as likely as any one actor of its tier.
		local limited = limitedInSeason()
		local limitedTier = if limited ~= nil then Actors.getTier(limited.tier) else nil
		if limited ~= nil and limitedTier ~= nil and chances[limitedTier.id] > 0 then
			order += 1
			local row = UiKit.addRow(oddsList, order, 40)
			local name = UiKit.makeTitle(row, `LIMITED: {limited.name}`, UiKit.GOLD, UDim2.fromScale(0.4, 1), UDim2.fromOffset(10, 0))
			name.TextXAlignment = Enum.TextXAlignment.Left
			textConstraint(name, 18)
			local outline = row:FindFirstChild("Outline") :: UIStroke
			outline.Color = UiKit.GOLD
			makeLabel(row, fmtOdds(Actors.limitedChance(chances, limited)), WHITE, UDim2.fromScale(0.3, 1), UDim2.fromScale(0.4, 0))
			local _, lastDay = limitedInSeason()
			makeLabel(row, if lastDay ~= nil then `{limitedTier.name}, until {lastDay}` else `{limitedTier.name}, this season only`, UiKit.GOLD, UDim2.fromScale(0.3, 1), UDim2.fromScale(0.7, 0))
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
		order += 1
		local pity = UiKit.addRow(oddsList, order, 40)
		makeLabel(pity, `Pity: a {agency.pity} or better at least once every {Actors.PityEvery} casts here`, UiKit.MUTED, UDim2.fromScale(1, 1))
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

	-- Under an undiscovered limited actor: "In season now!", or when its season comes back.
	local function seasonNote(actor: Actors.Actor): (string, Color3)
		local live = limitedInSeason()
		if live ~= nil and live.id == actor.id then
			return "In season now!", UiKit.GOLD
		end
		local season = SpecialEvents.getSeason(actor.season or "")
		return if season ~= nil then SpecialEvents.seasonDates(season) else "Limited", UiKit.FAINT
	end

	-- `chipText(variant, found)` labels each variant chip (owned count, or found / not found).
	-- `actors` defaults to the tier's everyday actors (the Limited group passes its own).
	local function tierCards(order: number, tier: Actors.Tier, chipText: (key: string, found: boolean) -> string, actors: { Actors.Actor }?, gridName: string?)
		local grid = Instance.new("Frame")
		grid.Name = "Cards_" .. (gridName or tier.id)
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
		for slot, actor in actors or Actors.actorsInTier(tier.id) do
			local actorTier = Actors.getTier(actor.tier) or tier
			local seen = Upgrades.actorDiscovered(ClientState.index, actor.id)
			local card = Instance.new("Frame")
			card.Name = actor.id
			card.LayoutOrder = slot
			card.Parent = grid
			corner(card, 12)
			UiKit.border(card, 2)
			rarityFrame(card, actorTier, seen)

			local art = Instance.new("Frame")
			art.Name = "Art"
			art.BackgroundTransparency = 1
			art.Position = UDim2.fromScale(0.05, 0.03)
			art.Size = UDim2.fromScale(0.9, 0.54)
			art.Parent = card
			Icon3D.glow(Icon3D.actor(art, actor.id, "Normal", not seen), actorTier.color, if seen then 1 else 0.5)

			local name = UiKit.makeTitle(card, if seen then actor.name else "???", if seen then WHITE else UiKit.FAINT, UDim2.fromScale(0.94, 0.13), UDim2.fromScale(0.03, 0.57), 2)
			name.ZIndex = 3
			textConstraint(name, 18)
			local note, noteColor = actorTier.name, UiKit.FAINT
			if seen then
				note, noteColor = actor.genre, UiKit.GENRE_COLORS[actor.genre] or UiKit.MUTED
			elseif actor.season ~= nil then
				note, noteColor = seasonNote(actor)
			end
			local genre = makeLabel(card, note, noteColor, UDim2.fromScale(0.94, 0.1), UDim2.fromScale(0.03, 0.71))
			genre.ZIndex = 3
			textConstraint(genre, 14)
			if actor.season ~= nil then
				-- A gold LIMITED ribbon across the top corner.
				local ribbon = UiKit.makeTitle(card, "LIMITED", UiKit.INK, UDim2.fromScale(0.5, 0.11), UDim2.fromScale(0.04, 0.03), 0)
				ribbon.BackgroundTransparency = 0
				ribbon.BackgroundColor3 = UiKit.GOLD
				ribbon.ZIndex = 4
				corner(ribbon, 6)
				UiKit.border(ribbon, 2, UiKit.INK)
				textConstraint(ribbon, 13)
			end
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

	-- The Limited group's header: seasonal actors, counted on their own and with no reward, so a
	-- player who missed a season can still finish every Index row.
	local LIMITED_COLOR = Color3.fromRGB(255, 140, 60)
	local LIMITED_TIER: Actors.Tier = { id = "Limited", name = "Limited", oneIn = 0, starPower = 0, color = LIMITED_COLOR }
	local function limitedFound(): number
		local found = 0
		for _, actor in Actors.Limited do
			if Upgrades.actorDiscovered(ClientState.index, actor.id) then
				found += 1
			end
		end
		return found
	end

	local function renderRoster()
		local order = 0
		-- Common first, so a new player sees what they own without scrolling past a wall of "???".
		local function chips(key: string, found: boolean): string
			return if found then "x" .. (ClientState.roster[key] or 0) else "-"
		end
		for _, tier in Actors.Tiers do
			order += 1
			tierHeader(order, tier, 32, tier.name)
			order += 1
			tierCards(order, tier, chips)
		end
		order += 1
		tierHeader(order, LIMITED_TIER, 32, "Limited  -  seasonal")
		order += 1
		tierCards(order, LIMITED_TIER, chips, Actors.Limited, "Limited")
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

		-- Limited seasonal actors: their own group, outside the tier rows and genre sets.
		order += 1
		local limitedHead = tierHeader(order, LIMITED_TIER, 44, `Limited  {limitedFound()}/{#Actors.Limited}`)
		local limitedNote = makeLabel(limitedHead, "Seasonal festivals only", WHITE, UDim2.new(0.5, -10, 1, 0), UDim2.new(0.5, 0, 0, 0))
		limitedNote.TextXAlignment = Enum.TextXAlignment.Right
		order += 1
		tierCards(order, LIMITED_TIER, function(_key, hasIt)
			return if hasIt then "+" else "-"
		end, Actors.Limited, "Limited")

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

	-- What the collection was last built for: a sync that changes nothing it shows keeps the cards
	-- (rebuilt 3D pictures are blank until Roblox redraws them).
	local collectionBuiltFor: string? = nil
	local function buildCollection()
		local studio = ClientState.studio
		local wanted = `{collectionTab}|{UiKit.isCompact()}|{UiKit.signature({
			roster = ClientState.roster,
			index = ClientState.index,
			rewards = if studio ~= nil then studio.rewards else nil,
		})}`
		if wanted == collectionBuiltFor then
			return
		end
		collectionBuiltFor = wanted
		-- Keep the scroll position across rebuilds (data refreshes while the panel is open).
		local scroll = collectionList.CanvasPosition
		task.defer(function()
			collectionList.CanvasPosition = scroll
		end)
		UiKit.clear(collectionList)
		for name, button in collectionTabs do
			UiKit.styleTab(button, name == collectionTab)
		end
		collectionHeader.Text = `Collection  -  Index {indexFound()}/{Actors.IndexSlots}`
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
	-- Rarity card, like the reference games' pull cards: tilted corner badges (NEW! or the copy
	-- count, and the variant), the actor, their name, a ribbon across the card in the rarity
	-- color, and stat chips for the odds of this exact pull, Star Power and genre.
	local function cornerBadge(position: UDim2, rotation: number): TextLabel
		local badge = UiKit.makeTitle(card, "", WHITE, UDim2.fromScale(0.3, 0.075), position, 2.5)
		badge.BackgroundTransparency = 0
		badge.BackgroundColor3 = UiKit.CLOSE_RED
		badge.Rotation = rotation
		badge.ZIndex = 14
		corner(badge, 10)
		UiKit.border(badge, 4)
		textConstraint(badge, 24)
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 4)
		pad.PaddingBottom = UDim.new(0, 4)
		pad.Parent = badge
		return badge
	end
	local tagLabel = cornerBadge(UDim2.fromScale(-0.03, -0.02), -8) -- NEW! / xN
	local variantLabel = cornerBadge(UDim2.fromScale(0.73, -0.02), 8) -- Shiny / Award-Winning
	local nameLabel = cardLabel(0.46, 0.09, 38)
	UiKit.outline(nameLabel, 3.5)

	local ribbon = Instance.new("Frame")
	ribbon.Name = "Ribbon"
	ribbon.AnchorPoint = Vector2.new(0.5, 0)
	ribbon.Position = UDim2.fromScale(0.5, 0.555)
	ribbon.Size = UDim2.fromScale(1.1, 0.09)
	ribbon.Rotation = -3
	ribbon.ZIndex = 13
	ribbon.Parent = card
	corner(ribbon, 8)
	local ribbonStroke = UiKit.border(ribbon, 4)
	local ribbonShade = Instance.new("UIGradient")
	ribbonShade.Rotation = 90
	ribbonShade.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.62, Color3.fromRGB(235, 235, 235)),
		ColorSequenceKeypoint.new(0.66, Color3.fromRGB(165, 165, 165)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 140, 140)),
	})
	ribbonShade.Parent = ribbon
	local ribbonRainbow = Instance.new("UIGradient")
	ribbonRainbow.Color = UiKit.RAINBOW
	ribbonRainbow.Enabled = false
	ribbonRainbow.Parent = ribbonStroke
	local tierLabel = UiKit.makeTitle(ribbon, "", WHITE, UDim2.fromScale(0.86, 0.86), UDim2.fromScale(0.07, 0.07), 3.5)
	tierLabel.ZIndex = 14
	textConstraint(tierLabel, 40)

	-- Stat chips: small title on top, big value under it.
	local chipRow = Instance.new("Frame")
	chipRow.Name = "Stats"
	chipRow.BackgroundTransparency = 1
	chipRow.Position = UDim2.fromScale(0.04, 0.675)
	chipRow.Size = UDim2.fromScale(0.92, 0.125)
	chipRow.ZIndex = 12
	chipRow.Parent = card
	local chipLayout = Instance.new("UIListLayout")
	chipLayout.FillDirection = Enum.FillDirection.Horizontal
	chipLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	chipLayout.Padding = UDim.new(0.025, 0)
	chipLayout.SortOrder = Enum.SortOrder.LayoutOrder
	chipLayout.Parent = chipRow
	local function statChip(order: number, title: string, color: Color3): TextLabel
		local chip = Instance.new("Frame")
		chip.LayoutOrder = order
		chip.BackgroundColor3 = UiKit.INK
		chip.BackgroundTransparency = 0.25
		chip.Size = UDim2.fromScale(0.315, 1)
		chip.ZIndex = 12
		chip.Parent = chipRow
		corner(chip, 10)
		UiKit.border(chip, 3)
		local heading = UiKit.makeTitle(chip, title, UiKit.MUTED, UDim2.fromScale(0.9, 0.34), UDim2.fromScale(0.05, 0.06), 2)
		heading.ZIndex = 13
		textConstraint(heading, 14)
		local value = UiKit.makeTitle(chip, "", color, UDim2.fromScale(0.92, 0.5), UDim2.fromScale(0.04, 0.42), 2.5)
		value.ZIndex = 13
		textConstraint(value, 24)
		return value
	end
	local chanceLabel = statChip(1, "CHANCE", WHITE)
	local powerLabel = statChip(2, "STAR POWER", UiKit.GOLD)
	local genreLabel = statChip(3, "GENRE", WHITE)

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
	-- Two spotlights sweep from the bottom corners during the build-up. Each beam is the top half of
	-- a holder centered on its pivot, so rotating the holder swings the beam from its base.
	local spotlights: { Frame } = {}
	for i, x in { 0.12, 0.88 } do
		local holder = Instance.new("Frame")
		holder.Name = "Spotlight"
		holder.BackgroundTransparency = 1
		holder.AnchorPoint = Vector2.new(0.5, 0.5)
		holder.Position = UDim2.fromScale(x, 1.02)
		holder.Size = UDim2.fromScale(0.2, 2.2)
		holder.ZIndex = 10
		holder.Visible = false
		holder.Parent = overlay
		local beam = Instance.new("Frame")
		beam.Size = UDim2.fromScale(1, 0.5)
		beam.BorderSizePixel = 0
		beam.BackgroundTransparency = 0.5
		beam.ZIndex = 10
		beam.Parent = holder
		local fade = Instance.new("UIGradient")
		fade.Rotation = 90
		fade.Transparency = NumberSequence.new(1, 0.2)
		fade.Parent = beam
		spotlights[i] = holder
	end

	-- A gold note across the top of the card: the guarantee that covered this cast, or the near
	-- miss's kind "So close!".
	local noteLabel = UiKit.makeTitle(card, "", WHITE, UDim2.fromScale(0.62, 0.065), UDim2.fromScale(0.19, 0.085), 2.5)
	noteLabel.BackgroundTransparency = 0
	noteLabel.BackgroundColor3 = UiKit.GOLD
	noteLabel.ZIndex = 14
	corner(noteLabel, 10)
	UiKit.border(noteLabel, 3)
	textConstraint(noteLabel, 22)

	-- The build-up can be skipped by a tap anywhere (or A / Space); the result never is.
	local skipButton = Instance.new("TextButton")
	skipButton.Name = "Skip"
	skipButton.Text = ""
	skipButton.AutoButtonColor = false
	skipButton.BackgroundTransparency = 1
	skipButton.Size = UDim2.fromScale(1, 1)
	skipButton.ZIndex = 16
	skipButton.Visible = false
	skipButton.Parent = overlay
	local skipHint = UiKit.makeTitle(skipButton, "Tap to skip", UiKit.MUTED, UDim2.fromScale(0.5, 0.05), UDim2.fromScale(0.25, 0.9), 2)
	skipHint.ZIndex = 16
	textConstraint(skipHint, 22)

	local building = false -- the build-up is playing
	local skipBuild = false
	local buildAmp = 0 -- card shake, degrees
	skipButton.Activated:Connect(function()
		skipBuild = true
	end)
	UserInputService.InputBegan:Connect(function(input)
		local key = input.KeyCode
		if building and (key == Enum.KeyCode.ButtonA or key == Enum.KeyCode.ButtonB or key == Enum.KeyCode.Space or key == Enum.KeyCode.Return) then
			skipBuild = true
		end
	end)

	overlay:GetPropertyChangedSignal("Visible"):Connect(function()
		if not overlay.Visible and stopSpin ~= nil then
			stopSpin()
			stopSpin = nil
		end
	end)
	RunService.RenderStepped:Connect(function()
		if not overlay.Visible then
			return
		end
		local now = os.clock()
		card.Rotation = if building then math.sin(now * 47) * buildAmp else 0
		for i, holder in spotlights do
			if holder.Visible then
				holder.Rotation = (if i == 1 then 1 else -1) * (18 + math.sin(now * 1.6 + i * 2) * 22)
			end
		end
		if not rays.Visible then
			return
		end
		local angle = now * 12
		for i, bar in rayBars do
			bar.Rotation = angle + i * 30
		end
	end)

	local againButton = makeButton(card, "Cast again", UiKit.GREEN, UDim2.fromScale(0.44, 0.13), UDim2.fromScale(0.04, 0.83))
	local doneButton = makeButton(card, "Continue", UiKit.BLUE, UDim2.fromScale(0.44, 0.13), UDim2.fromScale(0.52, 0.83))
	againButton.ZIndex = 12
	doneButton.ZIndex = 12

	local revealToken = 0
	local castAgency: Actors.Agency? = nil -- the agency of the cast being revealed
	local function setCardVisible(visible: boolean)
		for _, child in card:GetChildren() do
			if child:IsA("GuiObject") then
				child.Visible = visible
			end
		end
	end

	local SUSPENSE_TIMEOUT_SECONDS = 4 -- a "Casting..." screen with no answer closes itself

	local function showSuspense()
		revealToken += 1
		local mine = revealToken
		task.delay(SUSPENSE_TIMEOUT_SECONDS, function()
			if revealToken == mine then
				overlay.Visible = false
			end
		end)
		overlay.Visible = true
		setCardVisible(false)
		stroke.Color = UiKit.FAINT
		rainbow.Enabled = false
		card.BackgroundColor3 = PANEL
		nameLabel.Visible = true
		nameLabel.Text = "Casting..."
		noteLabel.Visible = false
		nameLabel.TextColor3 = WHITE
		art.Visible = true
		showArt(function(frame)
			return Icon3D.icon(frame, "clapper", 0.9)
		end, 90)
		setRays(nil, 0)
		Sfx.play("castRoll")
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
		card.BackgroundColor3 = PANEL
		stroke.Color = UiKit.FAINT
		rainbow.Enabled = false
		-- Build-up (Reveal.plan): the silhouette spins fast while spotlights sweep, a drumroll speeds
		-- up and the card shakes, glowing one rarity after another up to the real one (or looking
		-- Common, then bursting: the fake-out; or climbing to Superstar gold: the near miss). Then the
		-- card flips to the result.
		art.Visible = true
		showArt(function(frame)
			return Icon3D.actor(frame, actor.id, variant.id, true)
		end, 150)
		setRays(nil, 0)
		local rank = table.find(Actors.Tiers, tier) or 1
		local plan = Reveal.plan(rank, result.tease, math.random())
		local long = plan.seconds >= 0.8
		if rank >= 5 then
			Fx.holdOwnPull() -- the fireworks over our lot wait for the flip
		end
		task.spawn(function()
			building, skipBuild = true, false
			skipButton.Visible = long
			for _, holder in spotlights do
				holder.Visible = long
			end
			local deep = plan.nearMiss or rank >= 5
			local start, stepIndex, nextTick, glowRank = os.clock(), 0, 0, 1
			while revealToken == mine and not skipBuild do
				local t = os.clock() - start
				if t >= plan.seconds then
					break
				end
				local progress = t / plan.seconds
				while stepIndex < #plan.steps and plan.steps[stepIndex + 1].at <= t do
					stepIndex += 1
					glowRank = plan.steps[stepIndex].rank
					local glow = Actors.Tiers[glowRank]
					stroke.Color = glow.color
					rainbow.Enabled = glowRank == 7
					setRays(glow.color, 0.15 + glowRank * 0.07)
					for _, holder in spotlights do
						(holder:FindFirstChildOfClass("Frame") :: Frame).BackgroundColor3 = glow.color:Lerp(WHITE, 0.4)
					end
					if plan.fakeOut and stepIndex == 2 then
						Sfx.play("revealBurst")
						Fx.flash(glow.color, 0.3)
					elseif stepIndex > 1 then
						Sfx.play("revealStep", 0.8 + glowRank * 0.1)
					end
				end
				if long and t >= nextTick then
					Sfx.play("drumroll", 1 + progress * 0.3)
					if deep then
						Sfx.play("drumrollLow")
					end
					nextTick = t + 0.16 - progress * 0.1
				end
				buildAmp = progress * (0.5 + glowRank * 0.6)
				task.wait()
			end
			building, buildAmp = false, 0
			skipButton.Visible = false
			for _, holder in spotlights do
				holder.Visible = false
			end
			if revealToken ~= mine then
				return
			end
			-- The flip: the card squeezes to an edge and opens on the result.
			TweenService:Create(card, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = UDim2.fromScale(0, 0.72) }):Play()
			task.wait(0.12)
			if revealToken ~= mine then
				return
			end
			setCardVisible(true)
			showArt(function(frame)
				return Icon3D.actor(frame, actor.id, variant.id)
			end, 12)
			setRays(if variant.id == "Normal" then tier.color else variant.color, math.clamp(0.25 + rank * 0.1, 0, 0.9))
			stroke.Color = if tier.id == "Icon" then WHITE else tier.color
			rainbow.Enabled = tier.id == "Icon"
			-- The card takes on the rarity: a deep shade of its color, the ribbon in full color.
			card.BackgroundColor3 = tier.color:Lerp(UiKit.INK, 0.62)
			nameLabel.Text = actor.name
			nameLabel.TextColor3 = WHITE
			ribbon.BackgroundColor3 = tier.color
			ribbonStroke.Color = if tier.id == "Icon" then WHITE else UiKit.INK
			ribbonRainbow.Enabled = tier.id == "Icon"
			tierLabel.Text = string.upper(tier.name)
			-- Odds of this exact pull (tier, then one of its actors, then the variant) at the Luck
			-- and agency it was cast with, as the Odds screen works them out.
			local luck = player:GetAttribute("Luck") or Config.BaseLuck
			local agency = castAgency or currentAgency()
			local tierChance = Actors.tierChances(luck, agency.minTier)[tier.id] or 0
			local pool = #Actors.actorsInTier(tier.id) -- a limited actor is as likely as one of these
			local chance = tierChance / math.max(pool, 1) * (Actors.variantChances(luck)[variant.id] or 0)
			chanceLabel.Text = fmtOdds(chance)
			powerLabel.Text = Hud.comma(tier.starPower * variant.multiplier)
			genreLabel.Text = actor.genre
			genreLabel.TextColor3 = UiKit.GENRE_COLORS[actor.genre] or WHITE
			-- A limited seasonal actor's first copy says LIMITED! in gold.
			local limitedNew = result.isNew and actor.season ~= nil
			tagLabel.Text = if limitedNew then "LIMITED!" elseif result.isNew then "NEW!" else "x" .. result.count
			tagLabel.BackgroundColor3 = if limitedNew
				then UiKit.GOLD
				elseif result.isNew then UiKit.CLOSE_RED
				else UiKit.TAB_OFF
			variantLabel.Visible = variant.id ~= "Normal"
			variantLabel.Text = string.upper(if variant.id == "Award" then "Award" else variant.name)
			variantLabel.BackgroundColor3 = variant.color
			variantLabel.TextColor3 = WHITE
			-- The guarantee that covered this cast (server-decided), or the near miss's kind line.
			local note = if plan.nearMiss
				then "So close! Superstar soon!"
				elseif result.guarantee == "firstSuperstar" then "YOUR FIRST SUPERSTAR!"
				elseif result.guarantee == "pity" then "PITY GUARANTEE!"
				elseif result.guarantee == "hotStart" or result.discovered then "DISCOVERED!"
				else nil
			noteLabel.Visible = note ~= nil
			noteLabel.Text = note or ""
			Fx.castReveal(tier.id, variant.id)
			if plan.nearMiss then
				Sfx.play("voiceSoClose")
			end
			if rank >= 5 then
				Fx.releaseOwnPull()
			end
			card.Size = UDim2.fromScale(0.05, 0.72)
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
		castAgency = agency
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
		UiKit.chip(actorsButton, `{indexFound()}/{Actors.IndexSlots}`)
	end
	refreshChip()
	ClientState.changed:Connect(function()
		refreshChip()
		if collection.Visible then
			buildCollection()
		end
	end)
	player.AttributeChanged:Connect(function(name)
		if name == "Luck" then
			refreshLimitedTag()
		end
		if (name == "Luck" or name == "Fame") and oddsPanel.Visible then
			buildOdds()
		elseif name == "HotStart" or name == "DataLoaded" or string.sub(name, 1, 4) == "Pity" then
			refreshHotStart()
		end
	end)

	rosterButton.Activated:Connect(function()
		UiKit.togglePanel(collection, buildCollection)
	end)
	oddsButton.Activated:Connect(function()
		UiKit.togglePanel(oddsPanel, buildOdds)
	end)
	limitedTag.Activated:Connect(function()
		UiKit.togglePanel(oddsPanel, buildOdds)
	end)
	Screens.register("Actors", function()
		if not collection.Visible then
			UiKit.togglePanel(collection, buildCollection)
		end
	end)
	Screens.register("Odds", function()
		if not oddsPanel.Visible then
			UiKit.togglePanel(oddsPanel, buildOdds)
		end
	end)

end

return CastingUi
