--!strict
-- Mascots screen (rules in Shared/Mascots, checks in src/server/MascotService). At the top, the
-- mascot following you turns on a spotlight in its rarity color, with a button to hide or show it.
-- Under it, a picture card for each of the six: earned ones say EQUIP (or EQUIPPED), the others
-- show a black silhouette, how to earn them and how far along you are.
-- Earning a mascot says so at the bottom of the screen and puts a red badge on the Mascots button
-- until the screen is opened. The client only names the mascot it wants; the server checks it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Actors = require(ReplicatedStorage.Shared.Actors)
local Mascots = require(ReplicatedStorage.Shared.Mascots)
local Hud = require(script.Parent.Hud)
local Icon3D = require(script.Parent.Icon3D)
local SideMenu = require(script.Parent.SideMenu)
local Sfx = require(script.Parent.Sfx)
local UiKit = require(script.Parent.UiKit)

local makeLabel, makeTitle, makeButton = UiKit.makeLabel, UiKit.makeTitle, UiKit.makeButton

local MascotUi = {}

local function tierColor(mascot: Mascots.Mascot): Color3
	local tier = Actors.getTier(mascot.tier)
	return if tier ~= nil then tier.color else UiKit.BLUE
end

local function split(text: any): { string }
	if type(text) ~= "string" or text == "" then
		return {}
	end
	return string.split(text, ",")
end

local function unlockedSet(player: Player): { [string]: boolean }
	local set = {}
	for _, id in split(player:GetAttribute("MascotsUnlocked")) do
		set[id] = true
	end
	return set
end

function MascotUi.start(gui: ScreenGui, button: TextButton, remotes: Instance)
	local player = Players.LocalPlayer
	local equip = remotes:WaitForChild("EquipMascot") :: RemoteEvent
	local panel, list, header = UiKit.makePanel(gui, "MascotsPanel", "Mascots", nil, nil, nil, UiKit.PURPLE)
	UiKit.panelIcon(panel, header, "mascot:PopcornPup")

	local shown = "" -- signature of what the screen shows; rebuilt only when it changes
	local stopSpin: (() -> ())? = nil
	local fresh: { [string]: boolean } = {} -- earned this session and not seen on the screen yet

	local function build()
		local unlocked = unlockedSet(player)
		local equipped = player:GetAttribute("Mascot")
		local current = if type(equipped) == "string" then equipped else ""
		local progress = split(player:GetAttribute("MascotProgress"))
		local signature = UiKit.signature({ unlocked = unlocked, current = current, progress = progress, compact = UiKit.isCompact() } :: any)
		if signature == shown then
			return
		end
		shown = signature
		if stopSpin ~= nil then
			stopSpin()
			stopSpin = nil
		end
		UiKit.clear(list)
		local compact = UiKit.isCompact()

		-- The spotlight: your mascot turning slowly, its name and the hide / show button.
		local hero = Instance.new("Frame")
		hero.Name = "Spotlight"
		hero.LayoutOrder = 1
		hero.Size = UDim2.new(1, -8, 0, if compact then 118 else 150)
		hero.BackgroundColor3 = UiKit.DARK
		hero.Parent = list
		UiKit.corner(hero, 14)
		UiKit.border(hero, 3)
		local mascot = Mascots.get(current)
		local color = if mascot ~= nil then tierColor(mascot) else UiKit.MUTED
		local beam = Instance.new("UIGradient")
		beam.Rotation = 90
		beam.Color = ColorSequence.new(color:Lerp(UiKit.DARK, 0.35), UiKit.DARK)
		beam.Parent = hero
		local art = Instance.new("Frame")
		art.Name = "Art"
		art.BackgroundTransparency = 1
		art.AnchorPoint = Vector2.new(0, 0.5)
		art.Position = UDim2.new(0, 8, 0.5, 0)
		art.Size = UDim2.new(0.36, 0, 0.96, 0)
		art.Parent = hero
		local aspect = Instance.new("UIAspectRatioConstraint")
		aspect.Parent = art
		local name: TextLabel
		local line: TextLabel
		if mascot ~= nil then
			local view = Icon3D.mascot(art, mascot.id)
			Icon3D.glow(view, color, 1.6)
			stopSpin = Icon3D.spin(view, 6)
			name = makeTitle(hero, mascot.name, UiKit.WHITE, UDim2.new(0.58, 0, 0.3, 0), UDim2.fromScale(0.4, 0.08), 3)
			line = makeLabel(hero, `{mascot.blurb} Follows you everywhere.`, UiKit.MUTED, UDim2.new(0.56, 0, 0.2, 0), UDim2.fromScale(0.4, 0.38))
		else
			name = makeTitle(hero, "No mascot", UiKit.WHITE, UDim2.new(0.58, 0, 0.3, 0), UDim2.fromScale(0.4, 0.08), 3)
			line = makeLabel(hero, "Your mascot is hidden. Pick one below.", UiKit.MUTED, UDim2.new(0.56, 0, 0.2, 0), UDim2.fromScale(0.4, 0.38))
		end
		name.TextXAlignment = Enum.TextXAlignment.Left
		UiKit.textConstraint(name, 34)
		line.TextXAlignment = Enum.TextXAlignment.Left
		UiKit.textConstraint(line, 16)
		if current ~= "" then
			local hide = makeButton(hero, "HIDE", UiKit.DISABLED, UDim2.fromScale(0.3, 0.26), UDim2.fromScale(0.4, 0.66))
			hide.Name = "Hide"
			UiKit.textConstraint(hide, 22)
			hide.Activated:Connect(function()
				equip:FireServer("")
			end)
		end

		-- The cards, two to a row.
		local grid = Instance.new("Frame")
		grid.Name = "Cards"
		grid.LayoutOrder = 2
		grid.BackgroundTransparency = 1
		grid.Size = UDim2.new(1, -8, 0, 0)
		grid.AutomaticSize = Enum.AutomaticSize.Y
		grid.Parent = list
		local layout = Instance.new("UIGridLayout")
		layout.CellSize = UDim2.new(0.5, -8, 0, if compact then 176 else 200)
		layout.CellPadding = UDim2.fromOffset(10, 10)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = grid
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 3)
		pad.PaddingTop = UDim.new(0, 3)
		pad.PaddingBottom = UDim.new(0, 3)
		pad.Parent = grid

		for slot, m in Mascots.List do
			local earned = unlocked[m.id] == true
			local tint = tierColor(m)
			local card = Instance.new("Frame")
			card.Name = m.id
			card.LayoutOrder = slot
			card.BackgroundColor3 = if earned then tint:Lerp(UiKit.NAVY, 0.25) else UiKit.ROW
			card.Parent = grid
			UiKit.corner(card, 14)
			local edge = UiKit.border(card, 3, if m.id == current then UiKit.GOLD else UiKit.INK)
			if m.id == current then
				edge.Thickness = 4
			end
			local shade = Instance.new("UIGradient")
			shade.Rotation = 90
			shade.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 160))
			shade.Parent = card
			local pic = Instance.new("Frame")
			pic.Name = "Art"
			pic.BackgroundTransparency = 1
			pic.AnchorPoint = Vector2.new(0.5, 0)
			pic.Position = UDim2.fromScale(0.5, 0.03)
			pic.Size = UDim2.fromScale(0.62, 0.46)
			pic.Parent = card
			local view = Icon3D.mascot(pic, m.id, not earned)
			Icon3D.glow(view, if earned then Color3.new(1, 1, 1) else tint, if earned then 1 else 0.7)
			local title = makeTitle(card, if earned then m.name else "???", UiKit.WHITE, UDim2.fromScale(0.94, 0.14), UDim2.fromScale(0.03, 0.48), 2.5)
			title.Name = "Title"
			title.ZIndex = 3
			UiKit.textConstraint(title, 22)
			local text = makeLabel(card, if earned then m.blurb else m.unlock, if earned then UiKit.WHITE else UiKit.GOLD, UDim2.fromScale(0.9, 0.13), UDim2.fromScale(0.05, 0.62))
			text.Name = "Description"
			text.ZIndex = 3
			UiKit.outline(text, 1.5)
			UiKit.textConstraint(text, 14)
			local actionSize, actionPos = UDim2.fromScale(0.86, 0.19), UDim2.fromScale(0.07, 0.78)
			if m.id == current then
				local label = makeTitle(card, "EQUIPPED", UiKit.GOLD, actionSize, actionPos, 2.5)
				label.ZIndex = 3
			elseif earned then
				local go = makeButton(card, "EQUIP", UiKit.GREEN, actionSize, actionPos)
				go.Name = "Equip"
				go.ZIndex = 3
				UiKit.textConstraint(go, 22)
				go.Activated:Connect(function()
					equip:FireServer(m.id)
					Sfx.play("reward")
				end)
			else
				-- How far along: a bar with "7 / 10" on it.
				local have = tonumber(progress[slot]) or 0
				local bar = Instance.new("Frame")
				bar.Name = "Progress"
				bar.BackgroundColor3 = UiKit.DARK
				bar.Size = actionSize
				bar.Position = actionPos
				bar.ZIndex = 3
				bar.Parent = card
				UiKit.corner(bar, 8)
				UiKit.border(bar, 2)
				local fill = Instance.new("Frame")
				fill.BackgroundColor3 = tint
				fill.BorderSizePixel = 0
				fill.Size = UDim2.fromScale(math.clamp(have / math.max(m.target, 1), 0, 1), 1)
				fill.ZIndex = 4
				fill.Parent = bar
				UiKit.corner(fill, 8)
				local count = makeTitle(bar, `{Hud.comma(math.min(have, m.target))} / {Hud.comma(m.target)}`, UiKit.WHITE, UDim2.fromScale(1, 1), UDim2.new(), 2)
				count.ZIndex = 5
				UiKit.textConstraint(count, 18)
			end
		end
	end

	local function refreshBadge()
		local count = 0
		for _ in fresh do
			count += 1
		end
		SideMenu.setBadge(button, count)
	end

	button.Activated:Connect(function()
		UiKit.togglePanel(panel, build)
		if panel.Visible then
			table.clear(fresh)
			refreshBadge()
		end
	end)
	local function update()
		if panel.Visible then
			build()
		end
	end

	-- Newly earned mascots: a message and a badge (not for the ones a player already had on joining).
	local known: { [string]: boolean }? = nil
	local function onUnlocked()
		local now = unlockedSet(player)
		if known ~= nil then
			for _, m in Mascots.List do
				if now[m.id] and not known[m.id] then
					fresh[m.id] = true
					UiKit.toast(gui, `New mascot: {m.name}!`)
					Sfx.play("goal")
				end
			end
		end
		known = now
		if panel.Visible then
			table.clear(fresh)
		end
		refreshBadge()
		update()
	end
	if player:GetAttribute("MascotsUnlocked") ~= nil then
		onUnlocked()
	end
	player:GetAttributeChangedSignal("MascotsUnlocked"):Connect(onUnlocked)
	player:GetAttributeChangedSignal("Mascot"):Connect(update)
	player:GetAttributeChangedSignal("MascotProgress"):Connect(update)
end

return MascotUi
