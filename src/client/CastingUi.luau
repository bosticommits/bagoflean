--!strict
-- Casting Call button, odds panel, reveal, and roster screen. Placeholder visuals until M5.
-- The client only asks to cast; the server charges Cash and decides the result.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Actors = require(ReplicatedStorage.Shared.Actors)
local Config = require(ReplicatedStorage.Shared.Config)
local Hud = require(script.Parent.Hud)

local CastingUi = {}

local DARK = Color3.fromRGB(25, 25, 35)
local PANEL = Color3.fromRGB(38, 38, 52)
local WHITE = Color3.new(1, 1, 1)

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function textConstraint(label: TextLabel | TextButton, maxSize: number)
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = maxSize
	c.Parent = label
end

local function makeLabel(parent: Instance, text: string, color: Color3, size: UDim2, position: UDim2?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = size
	label.Position = position or UDim2.new()
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = parent
	textConstraint(label, 28)
	return label
end

local function makeButton(parent: Instance, text: string, color: Color3, size: UDim2, position: UDim2?): TextButton
	local button = Instance.new("TextButton")
	button.AutoButtonColor = true
	button.BackgroundColor3 = color
	button.Size = size
	button.Position = position or UDim2.new()
	button.Text = text
	button.TextColor3 = WHITE
	button.TextScaled = true
	button.Font = Enum.Font.GothamBold
	button.Parent = parent
	corner(button, 10)
	textConstraint(button, 26)
	return button
end

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

function CastingUi.start(gui: ScreenGui)
	local player = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 15)
	if remotes == nil then
		warn("[CastingUi] Remotes folder never arrived")
		return
	end
	local castRemote = remotes:WaitForChild("Cast") :: RemoteEvent
	local castResult = remotes:WaitForChild("CastResult") :: RemoteEvent
	local rosterRequest = remotes:WaitForChild("RosterRequest") :: RemoteEvent
	local rosterSync = remotes:WaitForChild("RosterSync") :: RemoteEvent

	local roster: { [string]: number } = {}
	local index: { [string]: boolean } = {}

	-- Bottom bar -------------------------------------------------------------------------------
	local bar = Instance.new("Frame")
	bar.Name = "CastingBar"
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -16)
	bar.Size = UDim2.new(0.92, 0, 0, 72)
	bar.BackgroundTransparency = 1
	bar.Parent = gui
	local barLimit = Instance.new("UISizeConstraint")
	barLimit.MaxSize = Vector2.new(560, 80)
	barLimit.Parent = bar

	local rosterButton = makeButton(bar, "Roster", Color3.fromRGB(70, 90, 160), UDim2.fromScale(0.22, 1))
	local castButton = makeButton(bar, "", Color3.fromRGB(230, 70, 70), UDim2.fromScale(0.52, 1), UDim2.fromScale(0.24, 0))
	castButton.Name = "CastButton"
	castButton.Text = "CASTING CALL  $" .. Hud.comma(Config.CastCost)
	local oddsButton = makeButton(bar, "Odds", Color3.fromRGB(70, 90, 160), UDim2.fromScale(0.22, 1), UDim2.fromScale(0.78, 0))

	-- Toast ------------------------------------------------------------------------------------
	local toast = makeLabel(gui, "", WHITE, UDim2.fromOffset(300, 40), UDim2.new(0.5, -150, 1, -140))
	toast.Name = "Toast"
	toast.BackgroundTransparency = 0.2
	toast.BackgroundColor3 = DARK
	toast.Visible = false
	corner(toast, 10)
	local toastToken = 0
	local function showToast(text: string)
		toastToken += 1
		local mine = toastToken
		toast.Text = text
		toast.Visible = true
		task.delay(2, function()
			if toastToken == mine then
				toast.Visible = false
			end
		end)
	end

	-- Generic modal panel ----------------------------------------------------------------------
	local function makePanel(name: string, title: string): (Frame, ScrollingFrame, TextLabel)
		local panel = Instance.new("Frame")
		panel.Name = name
		panel.AnchorPoint = Vector2.new(0.5, 0.5)
		panel.Position = UDim2.fromScale(0.5, 0.5)
		panel.Size = UDim2.fromScale(0.92, 0.72)
		panel.BackgroundColor3 = PANEL
		panel.Visible = false
		panel.Parent = gui
		corner(panel, 14)
		local limit = Instance.new("UISizeConstraint")
		limit.MaxSize = Vector2.new(560, 640)
		limit.Parent = panel

		local header = makeLabel(panel, title, WHITE, UDim2.new(1, -70, 0, 44), UDim2.fromOffset(14, 8))
		header.TextXAlignment = Enum.TextXAlignment.Left
		local close = makeButton(panel, "X", Color3.fromRGB(200, 60, 60), UDim2.fromOffset(44, 44), UDim2.new(1, -54, 0, 8))
		close.Activated:Connect(function()
			panel.Visible = false
		end)

		local list = Instance.new("ScrollingFrame")
		list.Name = "List"
		list.BackgroundTransparency = 1
		list.Position = UDim2.fromOffset(10, 60)
		list.Size = UDim2.new(1, -20, 1, -70)
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

	local function clear(list: ScrollingFrame)
		for _, child in list:GetChildren() do
			if not child:IsA("UIListLayout") then
				child:Destroy()
			end
		end
	end

	local function addRow(list: ScrollingFrame, order: number, height: number): Frame
		local row = Instance.new("Frame")
		row.LayoutOrder = order
		row.Size = UDim2.new(1, -8, 0, height)
		row.BackgroundColor3 = DARK
		row.BackgroundTransparency = 0.3
		row.Parent = list
		corner(row, 8)
		return row
	end

	-- Odds panel -------------------------------------------------------------------------------
	local oddsPanel, oddsList = makePanel("OddsPanel", "Casting odds")
	local function buildOdds()
		clear(oddsList)
		local luck = player:GetAttribute("Luck") or Config.BaseLuck
		local chances = Actors.tierChances(luck)
		local order = 0
		for index = #Actors.Tiers, 1, -1 do
			local tier = Actors.Tiers[index]
			order += 1
			local row = addRow(oddsList, order, 40)
			local name = makeLabel(row, tier.name, tier.color, UDim2.fromScale(0.4, 1), UDim2.fromOffset(10, 0))
			name.TextXAlignment = Enum.TextXAlignment.Left
			makeLabel(row, fmtOdds(chances[tier.id]), WHITE, UDim2.fromScale(0.3, 1), UDim2.fromScale(0.4, 0))
			makeLabel(row, "Power " .. Hud.comma(tier.starPower), Color3.fromRGB(255, 220, 90), UDim2.fromScale(0.3, 1), UDim2.fromScale(0.7, 0))
		end
		local vChances = Actors.variantChances(luck)
		for _, variant in Actors.Variants do
			if variant.oneIn ~= nil then
				order += 1
				local row = addRow(oddsList, order, 40)
				local name = makeLabel(row, variant.name, variant.color, UDim2.fromScale(0.4, 1), UDim2.fromOffset(10, 0))
				name.TextXAlignment = Enum.TextXAlignment.Left
				makeLabel(row, fmtOdds(vChances[variant.id]), WHITE, UDim2.fromScale(0.3, 1), UDim2.fromScale(0.4, 0))
				makeLabel(row, "x" .. variant.multiplier .. " power", Color3.fromRGB(255, 220, 90), UDim2.fromScale(0.3, 1), UDim2.fromScale(0.7, 0))
			end
		end
		order += 1
		local note = addRow(oddsList, order, 40)
		makeLabel(note, "Luck x" .. luck .. "  -  odds apply to every roll", Color3.fromRGB(190, 190, 200), UDim2.fromScale(1, 1))
	end

	-- Roster panel -----------------------------------------------------------------------------
	local rosterPanel, rosterList, rosterHeader = makePanel("RosterPanel", "Roster")
	local function buildRoster()
		clear(rosterList)
		local discovered = 0
		for _ in index do
			discovered += 1
		end
		rosterHeader.Text = `Roster  -  Index {discovered}/{Actors.IndexSlots}`

		local order = 0
		-- Common first, so a new player sees what they own without scrolling past a wall of "???".
		for _, tier in Actors.Tiers do
			order += 1
			local head = addRow(rosterList, order, 28)
			head.BackgroundColor3 = tier.color
			head.BackgroundTransparency = 0.55
			local headLabel = makeLabel(head, tier.name, WHITE, UDim2.fromScale(1, 1), UDim2.fromOffset(10, 0))
			headLabel.TextXAlignment = Enum.TextXAlignment.Left
			for _, actor in Actors.actorsInTier(tier.id) do
				order += 1
				local row = addRow(rosterList, order, 48)
				local seen = false
				for _, variant in Actors.Variants do
					if index[Actors.key(actor.id, variant.id)] then
						seen = true
					end
				end
				local name = makeLabel(row, if seen then actor.name else "???", if seen then WHITE else Color3.fromRGB(130, 130, 140), UDim2.fromScale(0.5, 0.6), UDim2.fromOffset(10, 2))
				name.TextXAlignment = Enum.TextXAlignment.Left
				local genre = makeLabel(row, if seen then actor.genre else "", Color3.fromRGB(170, 170, 185), UDim2.fromScale(0.5, 0.35), UDim2.new(0, 10, 0.62, 0))
				genre.TextXAlignment = Enum.TextXAlignment.Left
				for slot, variant in Actors.Variants do
					local key = Actors.key(actor.id, variant.id)
					local owned = roster[key] or 0
					local text = if index[key] then "x" .. owned else "-"
					local chip = makeLabel(row, text, if index[key] then variant.color else Color3.fromRGB(100, 100, 110), UDim2.fromScale(0.14, 0.7), UDim2.fromScale(0.5 + (slot - 1) * 0.16, 0.15))
					chip.BackgroundTransparency = 0.7
					chip.BackgroundColor3 = if index[key] then variant.color else Color3.fromRGB(60, 60, 70)
					corner(chip, 6)
				end
			end
		end
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

	local againButton = makeButton(card, "Cast again", Color3.fromRGB(230, 70, 70), UDim2.fromScale(0.44, 0.15), UDim2.fromScale(0.04, 0.8))
	local doneButton = makeButton(card, "Continue", Color3.fromRGB(70, 160, 90), UDim2.fromScale(0.44, 0.15), UDim2.fromScale(0.52, 0.8))
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
		if actor == nil or variant == nil then
			overlay.Visible = false
			return
		end
		local tier = Actors.getTier(actor.tier)
		if tier == nil then
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
			powerLabel.TextColor3 = Color3.fromRGB(255, 220, 90)
			local tag = if result.isNew then "NEW!" else "x" .. result.count
			if variant.id ~= "Normal" then
				tag = variant.name .. "  " .. tag
				tagLabel.TextColor3 = variant.color
			else
				tagLabel.TextColor3 = if result.isNew then Color3.fromRGB(255, 220, 90) else Color3.fromRGB(190, 190, 200)
			end
			tagLabel.Text = tag
			card.Size = UDim2.fromScale(0.7, 0.5)
			TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromScale(0.85, 0.6) }):Play()
		end)
	end

	-- Wiring -----------------------------------------------------------------------------------
	local function requestCast()
		if (player:GetAttribute("Cash") or 0) < Config.CastCost then
			showToast("Not enough Cash")
			return false
		end
		castRemote:FireServer()
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
				showToast("Not enough Cash")
			elseif result.reason == "cooldown" then
				showToast("Slow down!")
			else
				showToast("Still loading your data")
			end
		end
	end)

	rosterSync.OnClientEvent:Connect(function(newRoster, newIndex)
		if type(newRoster) == "table" and type(newIndex) == "table" then
			roster = newRoster
			index = newIndex
			if rosterPanel.Visible then
				buildRoster()
			end
		end
	end)

	local function open(panel: Frame, build: () -> ())
		local willOpen = not panel.Visible
		oddsPanel.Visible = false
		rosterPanel.Visible = false
		if willOpen then
			build()
			panel.Visible = true
		end
	end
	rosterButton.Activated:Connect(function()
		open(rosterPanel, buildRoster)
	end)
	oddsButton.Activated:Connect(function()
		open(oddsPanel, buildOdds)
	end)

	-- Ask for the roster once the server has loaded this player's data.
	task.spawn(function()
		while not player:GetAttribute("DataLoaded") do
			player.AttributeChanged:Wait()
		end
		rosterRequest:FireServer()
	end)
end

return CastingUi
