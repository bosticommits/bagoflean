--!strict
-- Upgrade tree: spend Cash on stages, cinema size, offline earnings, Luck, and the clapperboard.
-- Each upgrade is a column of level nodes, like the reference games' upgrade trees: owned levels
-- glow gold with a tick, the next level shows its price, and later levels stay hidden as "?".
-- Tapping a node shows that upgrade in the card above the tree, with its Buy button. Shows what
-- each level gives (from the shared Upgrades definitions); the server prices, gates and applies
-- every purchase.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Rebirth = require(ReplicatedStorage.Shared.Rebirth)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
local ClientState = require(script.Parent.ClientState)
local Hud = require(script.Parent.Hud)
local Icon3D = require(script.Parent.Icon3D)
local Screens = require(script.Parent.Screens)
local SideMenu = require(script.Parent.SideMenu)
local UiKit = require(script.Parent.UiKit)

local makeLabel, makeButton = UiKit.makeLabel, UiKit.makeButton

local UpgradesUi = {}

-- 3D icon for each upgrade column (IconModels ids).
local ICONS: { [string]: string } = {
	Stages = "stage",
	Cinema = "popcorn",
	Offline = "moneybag",
	Luck = "clover",
	Clap = "clapper",
}

-- Short column names, so five fit side by side on a phone.
local SHORT_NAMES: { [string]: string } = {
	Stages = "Stages",
	Cinema = "Cinema",
	Offline = "Offline",
	Luck = "Luck",
	Clap = "Clapper",
}

-- Tree geometry, in pixels.
local HEADER_HEIGHT = 92 -- icon, name and level above the first node
local NODE = 42
local STEP = 54 -- node plus the link under it

-- "$600", "$25K", "$1.5M": node prices have to fit in a small square.
local function shortCash(amount: number): string
	local function trim(value: number, suffix: string): string
		local text = string.format("%.1f", value)
		text = string.gsub(text, "%.0$", "")
		return "$" .. text .. suffix
	end
	if amount >= 1e9 then
		return trim(amount / 1e9, "B")
	elseif amount >= 1e6 then
		return trim(amount / 1e6, "M")
	elseif amount >= 1e3 then
		return trim(amount / 1e3, "K")
	end
	return "$" .. tostring(amount)
end

-- "owned", "buy" (affordable next level), "short" (next level, not enough Cash), "fame" (next level,
-- needs more Fame) or "hidden" (later levels).
type NodeState = string

-- What a level node shows. `level` is the upgrade's current level; `n` is the node's level.
local function nodeState(upgrade: Upgrades.Upgrade, level: number, n: number, cash: number, fame: number): NodeState
	if n <= level then
		return "owned"
	elseif n > level + 1 then
		return "hidden"
	elseif fame < upgrade.fame[n] then
		return "fame"
	elseif cash >= upgrade.costs[n] then
		return "buy"
	end
	return "short"
end

-- Upgrades whose next level the player can buy right now (for the menu badge).
local function buyableCount(stats: any, cash: number, fame: number): number
	local count = 0
	for _, upgrade in Upgrades.List do
		local level = Upgrades.level(stats, upgrade.id)
		if level < upgrade.maxLevel and nodeState(upgrade, level, level + 1, cash, fame) == "buy" then
			count += 1
		end
	end
	return count
end

function UpgradesUi.start(gui: ScreenGui, upgradesButton: TextButton)
	local player = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 15)
	if remotes == nil then
		warn("[UpgradesUi] Remotes folder never arrived")
		return
	end
	local buyUpgrade = remotes:WaitForChild("BuyUpgrade") :: RemoteEvent

	local panel, list, header = UiKit.makePanel(gui, "UpgradesPanel", "Upgrade Tree", nil, nil, nil, UiKit.AWARD_GOLD)
	UiKit.panelIcon(panel, header, "arrow")

	local selected: string? = nil

	-- Built once and then refreshed in place: rebuilding would recreate the 3D icons, which
	-- Roblox draws blank for a moment.
	local summaryTop: TextLabel, summaryBottom: TextLabel
	local cardIcon: Frame, cardTitle: TextLabel, cardNow: TextLabel, cardNext: TextLabel, cardButton: TextButton
	local columnLevels: { [string]: TextLabel } = {}
	local nodes: { [string]: { TextButton } } = {}
	local links: { [string]: { Frame } } = {}
	local built = false
	local refresh: () -> ()

	local function create()
		built = true
		local summary = UiKit.addRow(list, 1, 64)
		summaryTop = makeLabel(summary, "", UiKit.GOLD, UDim2.new(1, -20, 0, 28), UDim2.fromOffset(10, 4))
		summaryBottom = makeLabel(summary, "", UiKit.MUTED, UDim2.new(1, -20, 0, 22), UDim2.fromOffset(10, 36))

		-- The selected upgrade: what it gives now, what the next level adds, and its Buy button.
		local card = UiKit.addRow(list, 2, 104)
		card.Name = "Selected"
		cardIcon = UiKit.rowIcon(card, "arrow", 72)
		cardTitle = UiKit.makeTitle(card, "", UiKit.WHITE, UDim2.new(0.62, -88, 0, 30), UDim2.fromOffset(88, 6))
		cardTitle.TextXAlignment = Enum.TextXAlignment.Left
		cardNow = makeLabel(card, "", UiKit.MUTED, UDim2.new(0.62, -88, 0, 22), UDim2.fromOffset(88, 40))
		cardNow.TextXAlignment = Enum.TextXAlignment.Left
		cardNext = makeLabel(card, "", UiKit.CASH_GREEN, UDim2.new(0.62, -88, 0, 22), UDim2.fromOffset(88, 68))
		cardNext.TextXAlignment = Enum.TextXAlignment.Left
		cardButton = makeButton(card, "", UiKit.GREEN, UDim2.new(0.34, 0, 0, 50), UDim2.new(0.64, 0, 0, 27))
		cardButton.Activated:Connect(function()
			local upgrade = if selected ~= nil then Upgrades.get(selected) else nil
			if upgrade == nil then
				return
			end
			local level = Upgrades.level(ClientState.stats(), upgrade.id)
			if level >= upgrade.maxLevel then
				return
			end
			local state = nodeState(upgrade, level, level + 1, player:GetAttribute("Cash") or 0, player:GetAttribute("Fame") or 0)
			if state == "fame" then
				UiKit.toast(gui, `Needs Fame {Hud.comma(upgrade.fame[level + 1])}`)
			elseif state == "short" then
				UiKit.toast(gui, "Not enough Cash")
			else
				buyUpgrade:FireServer(upgrade.id)
			end
		end)

		-- The tree: one column per upgrade, its levels top to bottom.
		local tallest = 0
		for _, upgrade in Upgrades.List do
			tallest = math.max(tallest, upgrade.maxLevel)
		end
		local tree = UiKit.addRow(list, 3, HEADER_HEIGHT + tallest * STEP + 4)
		tree.Name = "Tree"
		UiKit.plainRow(tree)
		local count = #Upgrades.List
		for i, upgrade in Upgrades.List do
			local column = Instance.new("Frame")
			column.Name = upgrade.id
			column.BackgroundTransparency = 1
			column.Position = UDim2.fromScale((i - 1) / count, 0)
			column.Size = UDim2.fromScale(1 / count, 1)
			column.Parent = tree

			local art = Instance.new("TextButton")
			art.Name = "Icon"
			art.Text = ""
			art.BackgroundTransparency = 1
			art.AnchorPoint = Vector2.new(0.5, 0)
			art.Position = UDim2.fromScale(0.5, 0)
			art.Size = UDim2.fromOffset(52, 52)
			art.Parent = column
			Icon3D.outlined(art, ICONS[upgrade.id] or "arrow")
			local name = UiKit.makeTitle(column, SHORT_NAMES[upgrade.id] or upgrade.name, UiKit.WHITE, UDim2.new(1, -4, 0, 20), UDim2.fromOffset(2, 50), 1.5)
			UiKit.textConstraint(name, 18)
			local levelLabel = makeLabel(column, "", UiKit.GOLD, UDim2.new(1, -4, 0, 16), UDim2.fromOffset(2, 70))
			UiKit.textConstraint(levelLabel, 14)
			columnLevels[upgrade.id] = levelLabel

			nodes[upgrade.id] = {}
			links[upgrade.id] = {}
			for n = 1, upgrade.maxLevel do
				local y = HEADER_HEIGHT + (n - 1) * STEP
				if n > 1 then
					-- Link from the node above, gold once both ends are owned.
					local link = Instance.new("Frame")
					link.Name = `Link{n}`
					link.BorderSizePixel = 0
					link.AnchorPoint = Vector2.new(0.5, 0)
					link.Position = UDim2.new(0.5, 0, 0, y - (STEP - NODE))
					link.Size = UDim2.fromOffset(6, STEP - NODE)
					link.Parent = column
					links[upgrade.id][n] = link
				end
				local node = Instance.new("TextButton")
				node.Name = `Level{n}`
				node.AutoButtonColor = true
				node.AnchorPoint = Vector2.new(0.5, 0)
				node.Position = UDim2.new(0.5, 0, 0, y)
				node.Size = UDim2.fromOffset(NODE, NODE)
				node.TextScaled = true
				node.Font = UiKit.DISPLAY_FONT
				node.TextColor3 = UiKit.WHITE
				node.ZIndex = 2
				node.Parent = column
				UiKit.corner(node, 10)
				UiKit.border(node, 3)
				UiKit.outline(node, 1.5)
				local pad = Instance.new("UIPadding")
				pad.PaddingLeft = UDim.new(0, 3)
				pad.PaddingRight = UDim.new(0, 3)
				pad.Parent = node
				nodes[upgrade.id][n] = node
				node.Activated:Connect(function()
					selected = upgrade.id
					refresh()
				end)
			end
			art.Activated:Connect(function()
				selected = upgrade.id
				refresh()
			end)
		end
	end

	-- Paints one node for its state. The node for the next level shows its price; a pulse marks
	-- one the player can afford.
	local function paintNode(node: TextButton, state: NodeState, upgrade: Upgrades.Upgrade, n: number, isSelected: boolean)
		local tick = node:FindFirstChild("Tick")
		if tick ~= nil then
			tick:Destroy()
		end
		local pulse = node:FindFirstChild("Pulse")
		if pulse ~= nil then
			pulse:Destroy()
			node.Size = UDim2.fromOffset(NODE, NODE)
			node.AnchorPoint = Vector2.new(0.5, 0)
			node.Position = UDim2.new(0.5, 0, 0, HEADER_HEIGHT + (n - 1) * STEP)
		end
		local outline = node:FindFirstChild("Outline")
		if outline ~= nil and outline:IsA("UIStroke") then
			outline.Color = if isSelected then UiKit.WHITE else UiKit.INK
		end
		node.TextColor3 = UiKit.WHITE
		if state == "owned" then
			node.BackgroundColor3 = UiKit.AWARD_GOLD
			node.Text = ""
			UiKit.tick(node, node.ZIndex + 1)
		elseif state == "buy" then
			node.BackgroundColor3 = UiKit.GREEN
			node.Text = shortCash(upgrade.costs[n])
			UiKit.pulse(node, 1.1)
		elseif state == "short" then
			node.BackgroundColor3 = UiKit.DISABLED
			node.TextColor3 = UiKit.MUTED
			node.Text = shortCash(upgrade.costs[n])
		elseif state == "fame" then
			node.BackgroundColor3 = UiKit.BURGUNDY
			node.TextColor3 = UiKit.GOLD
			node.Text = "Fame"
		else
			node.BackgroundColor3 = UiKit.DARK
			node.TextColor3 = UiKit.FAINT
			node.Text = "?"
		end
	end

	refresh = function()
		if not built then
			create()
		end
		local stats = ClientState.stats()
		local cash = player:GetAttribute("Cash") or 0
		local fame = player:GetAttribute("Fame") or 0

		local rate = if ClientState.studio ~= nil then ClientState.studio.rate else Config.CinemaIncomePerSecond
		local rebirths = stats.rebirths or 0
		local rebirthText = if rebirths > 0 then `  -  Rebirth {Rebirth.multiplierText(rebirths)} Cash` else ""
		summaryTop.Text = `Luck x{string.format("%.2f", Upgrades.luck(stats))}  -  Fame {Hud.comma(fame)}{rebirthText}`
		summaryBottom.Text = `Royalties ${string.format("%.2f", rate)}/s  -  offline cap {Upgrades.offlineCap(stats) / 3600}h`

		-- Default selection: the first upgrade the player can buy, else the first one not maxed.
		if selected == nil then
			for _, upgrade in Upgrades.List do
				local level = Upgrades.level(stats, upgrade.id)
				if level < upgrade.maxLevel and nodeState(upgrade, level, level + 1, cash, fame) == "buy" then
					selected = upgrade.id
					break
				end
			end
			selected = selected or Upgrades.List[1].id
		end

		for _, upgrade in Upgrades.List do
			local level = Upgrades.level(stats, upgrade.id)
			columnLevels[upgrade.id].Text = if level >= upgrade.maxLevel then "MAX" else `Lv {level}/{upgrade.maxLevel}`
			for n, node in nodes[upgrade.id] do
				local state = nodeState(upgrade, level, n, cash, fame)
				paintNode(node, state, upgrade, n, upgrade.id == selected and n == level + 1)
			end
			for n, link in links[upgrade.id] do
				link.BackgroundColor3 = if n <= level then UiKit.AWARD_GOLD else UiKit.DISABLED
			end
		end

		local upgrade = Upgrades.get(selected or "")
		if upgrade == nil then
			return
		end
		local level = Upgrades.level(stats, upgrade.id)
		local icon = cardIcon:FindFirstChildWhichIsA("ViewportFrame")
		if cardIcon:GetAttribute("IconId") ~= upgrade.id then
			if icon ~= nil then
				icon:Destroy()
			end
			Icon3D.outlined(cardIcon, ICONS[upgrade.id] or "arrow")
			cardIcon:SetAttribute("IconId", upgrade.id)
		end
		cardTitle.Text = `{upgrade.name}  Lv {level}/{upgrade.maxLevel}`
		cardNow.Text = "Now: " .. upgrade.effect(level)
		if level >= upgrade.maxLevel then
			cardNext.Text = "Fully upgraded"
			cardNext.TextColor3 = UiKit.GOLD
			cardButton.Text = "MAX"
			cardButton.BackgroundColor3 = UiKit.AWARD_GOLD
			cardButton.TextColor3 = UiKit.WHITE
			return
		end
		cardNext.Text = "Next: " .. upgrade.effect(level + 1)
		cardNext.TextColor3 = UiKit.CASH_GREEN
		local state = nodeState(upgrade, level, level + 1, cash, fame)
		-- Like the reference games' level-locked rows: gold "locked", green "buy", grey "can't afford".
		if state == "fame" then
			cardButton.Text = `Fame {Hud.comma(upgrade.fame[level + 1])}`
			cardButton.BackgroundColor3 = UiKit.AWARD_GOLD
			cardButton.TextColor3 = UiKit.WHITE
		else
			cardButton.Text = `${Hud.comma(upgrade.costs[level + 1])}`
			UiKit.setEnabled(cardButton, state == "buy", UiKit.GREEN)
		end
	end

	-- Red badge on the Upgrade button: how many upgrades can be bought right now.
	local function updateBadge()
		SideMenu.setBadge(upgradesButton, buyableCount(ClientState.stats(), player:GetAttribute("Cash") or 0, player:GetAttribute("Fame") or 0))
	end

	ClientState.changed:Connect(function()
		updateBadge()
		if panel.Visible then
			refresh()
		end
	end)
	player.AttributeChanged:Connect(function(name)
		if name == "Cash" or name == "Fame" then
			updateBadge()
			if panel.Visible then
				refresh()
			end
		end
	end)
	updateBadge()

	upgradesButton.Activated:Connect(function()
		UiKit.togglePanel(panel, refresh)
	end)
	Screens.register("Upgrades", function()
		if not panel.Visible then
			UiKit.togglePanel(panel, refresh)
		end
	end)
end

return UpgradesUi
