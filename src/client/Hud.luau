--!strict
-- HUD: the wallet (3D coin + big outlined Cash with a green "+" to the shop, and Fame), and at the
-- top centre chunky event badges (Award Night, Lucky Casting) over the box office bar, which fills
-- up as the cinema earns and flashes FULL at the cap. Reads server-owned attributes; it never sends
-- amounts to the server.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Events = require(ReplicatedStorage.Shared.Events)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
local ClientState = require(script.Parent.ClientState)
local Icon3D = require(script.Parent.Icon3D)
local Sfx = require(script.Parent.Sfx)
local UiKit = require(script.Parent.UiKit)

local Hud = {}

local WALLET_CARD_MIN = 150
local HUD_WIDTH = 420 -- width of the event lines at full scale
local HUD_SIDE_MARGIN = 12 -- gap kept to each screen edge
local HUD_MIN_SCALE = 0.5 -- smallest the event lines shrink to on a narrow screen
local BADGE_WIDTH = 196
local BOX_WIDTH = 310

-- Light top, darker bottom band and a glossy strip: the chunky Roblox button look.
local function chunky(frame: GuiObject)
	local shade = Instance.new("UIGradient")
	shade.Rotation = 90
	shade.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.66, Color3.fromRGB(238, 238, 238)),
		ColorSequenceKeypoint.new(0.7, Color3.fromRGB(170, 170, 170)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(145, 145, 145)),
	})
	shade.Parent = frame
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.BorderSizePixel = 0
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.BackgroundTransparency = 0.65
	shine.Position = UDim2.new(0, 14, 0, 4)
	shine.Size = UDim2.new(1, -28, 0, 6)
	shine.ZIndex = frame.ZIndex + 1
	shine.Parent = frame
	UiKit.corner(shine, 3)
end

local function comma(n: number): string
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end
Hud.comma = comma

-- "m:ss", or "h:mm:ss" past an hour.
local function clock(seconds: number): string
	local total = math.max(0, math.ceil(seconds))
	local h, m, sec = total // 3600, (total % 3600) // 60, total % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, sec)
	end
	return string.format("%d:%02d", m, sec)
end
Hud.clock = clock

-- `wallet` is the empty frame the side menu reserves for Cash and Fame. Returns the green "+"
-- button next to Cash (the shop opens on it).
function Hud.start(gui: ScreenGui, wallet: Frame): TextButton
	local player = Players.LocalPlayer

	-- Top centre: no box, outlined text floats over the world, as in the reference games. It starts
	-- where the side menu says ("HudTop"). On touch screens the wallet takes the top centre, so the
	-- event lines move to the top right corner ("HudRight"), smaller on short screens, where they
	-- stay clear of the player's character.
	local frame = Instance.new("Frame")
	frame.Name = "Hud"
	frame.Size = UDim2.fromOffset(HUD_WIDTH, 108)
	frame.BackgroundTransparency = 1
	frame.Parent = gui
	local frameScale = Instance.new("UIScale")
	frameScale.Parent = frame
	local labels: { TextLabel } = {}
	local alignTop = function(_right: boolean) end -- set once the badges and bar exist
	local function placeFrame()
		local top = gui:GetAttribute("HudTop")
		local right = gui:GetAttribute("HudRight") == true
		if right then
			frame.AnchorPoint = Vector2.new(1, 0)
			frame.Position = UDim2.new(1, -12, 0, 8)
		else
			-- Under the tutorial's dialogue while it is up ("TutorialBottom", set by Tutorial).
			local below = gui:GetAttribute("TutorialBottom")
			local y = if typeof(top) == "number" then top else 8
			frame.AnchorPoint = Vector2.new(0.5, 0)
			frame.Position = UDim2.new(0.5, 0, 0, if typeof(below) == "number" then math.max(y, below) else y)
		end
		-- Narrow screens (portrait phones) shrink the 420 px event lines to fit between the edges.
		local widthFit = math.clamp((UiKit.viewport().X - HUD_SIDE_MARGIN * 2) / HUD_WIDTH, HUD_MIN_SCALE, 1)
		frameScale.Scale = math.min(if right and UiKit.isCompact() then 0.72 else 1, widthFit)
		for _, label in labels do
			label.TextXAlignment = if right then Enum.TextXAlignment.Right else Enum.TextXAlignment.Center
		end
		alignTop(right)
	end
	gui:GetAttributeChangedSignal("HudTop"):Connect(placeFrame)
	gui:GetAttributeChangedSignal("HudRight"):Connect(placeFrame)
	gui:GetAttributeChangedSignal("TutorialBottom"):Connect(placeFrame)

	local function makeLabel(y: number, height: number, color: Color3): TextLabel
		local label = UiKit.makeTitle(frame, "", color, UDim2.new(1, 0, 0, height), UDim2.fromOffset(0, y), if height >= 40 then 3.5 else 2.5)
		UiKit.textConstraint(label, height)
		table.insert(labels, label)
		return label
	end

	-- Event badges: one chunky pill per event, side by side, with a 3D icon poking out of the left
	-- end, a small title and a big timer.
	local badgeRow = Instance.new("Frame")
	badgeRow.Name = "Badges"
	badgeRow.BackgroundTransparency = 1
	badgeRow.Size = UDim2.new(1, 0, 0, 48)
	badgeRow.Parent = frame
	local badgeLayout = Instance.new("UIListLayout")
	badgeLayout.FillDirection = Enum.FillDirection.Horizontal
	badgeLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	badgeLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	badgeLayout.Padding = UDim.new(0, 22)
	badgeLayout.SortOrder = Enum.SortOrder.LayoutOrder
	badgeLayout.Parent = badgeRow

	local function makeBadge(order: number, color: Color3, iconId: string): (Frame, TextLabel, TextLabel)
		local badge = Instance.new("Frame")
		badge.Name = "Badge" .. iconId
		badge.LayoutOrder = order
		badge.BackgroundColor3 = color
		badge.Size = UDim2.fromOffset(BADGE_WIDTH, 44)
		badge.Parent = badgeRow
		UiKit.corner(badge, 14)
		UiKit.border(badge, 4)
		chunky(badge)
		local art = Instance.new("Frame")
		art.Name = "Icon"
		art.BackgroundTransparency = 1
		art.Position = UDim2.fromOffset(-18, -8)
		art.Size = UDim2.fromOffset(58, 58)
		art.ZIndex = 3
		art.Parent = badge
		Icon3D.outlined(art, iconId)
		local title = UiKit.makeTitle(badge, "", UiKit.WHITE, UDim2.new(1, -50, 0, 15), UDim2.fromOffset(42, 3), 2)
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.ZIndex = 3
		UiKit.textConstraint(title, 15)
		local timer = UiKit.makeTitle(badge, "", UiKit.WHITE, UDim2.new(1, -50, 0, 24), UDim2.fromOffset(42, 17), 2.5)
		timer.TextXAlignment = Enum.TextXAlignment.Left
		timer.ZIndex = 3
		UiKit.textConstraint(timer, 24)
		return badge, title, timer
	end
	local awardBadge, awardTitle, awardTimer = makeBadge(1, UiKit.PURPLE, "trophy")
	local awardStroke = awardBadge:FindFirstChild("Outline") :: UIStroke
	local luckyBadge, luckyTitle, luckyTimer = makeBadge(2, UiKit.FRESH_GREEN, "clover")
	luckyTitle.Text = "LUCKY CASTING"
	luckyBadge.Visible = false

	-- Box office bar: the cinema's pile, filling towards the offline cap (the most it holds, see
	-- EconomyService), with the amount in big green numbers. At the cap it turns red and flashes
	-- FULL, so players know they're losing earnings until they collect.
	local box = Instance.new("Frame")
	box.Name = "BoxOffice"
	box.BackgroundColor3 = UiKit.NAVY
	box.AnchorPoint = Vector2.new(0.5, 0)
	box.Position = UDim2.new(0.5, 0, 0, 56)
	box.Size = UDim2.fromOffset(BOX_WIDTH, 50)
	box.Parent = frame
	UiKit.corner(box, 14)
	local boxStroke = UiKit.border(box, 4)
	chunky(box)
	local ticketArt = Instance.new("Frame")
	ticketArt.Name = "Icon"
	ticketArt.BackgroundTransparency = 1
	ticketArt.Position = UDim2.fromOffset(-20, -8)
	ticketArt.Size = UDim2.fromOffset(62, 62)
	ticketArt.ZIndex = 3
	ticketArt.Parent = box
	Icon3D.outlined(ticketArt, "ticket")
	local boxTitle = UiKit.makeTitle(box, "BOX OFFICE", UiKit.GOLD, UDim2.fromOffset(120, 17), UDim2.fromOffset(44, 3), 2)
	boxTitle.TextXAlignment = Enum.TextXAlignment.Left
	boxTitle.ZIndex = 3
	UiKit.textConstraint(boxTitle, 17)
	local boxAmount = UiKit.makeTitle(box, "", UiKit.CASH_GREEN, UDim2.new(1, -170, 0, 22), UDim2.fromOffset(160, 0), 2.5)
	boxAmount.TextXAlignment = Enum.TextXAlignment.Right
	boxAmount.ZIndex = 3
	UiKit.textConstraint(boxAmount, 22)
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.BackgroundColor3 = UiKit.INK
	track.Position = UDim2.fromOffset(44, 24)
	track.Size = UDim2.new(1, -54, 0, 19)
	track.ZIndex = 3
	track.Parent = box
	UiKit.corner(track, 9)
	UiKit.border(track, 2)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = UiKit.GREEN
	fill.Size = UDim2.fromScale(0, 1)
	fill.ZIndex = 4
	fill.Parent = track
	UiKit.corner(fill, 9)
	local fillShade = Instance.new("UIGradient")
	fillShade.Rotation = 90
	fillShade.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(165, 165, 165))
	fillShade.Parent = fill
	local barText = UiKit.makeTitle(track, "", UiKit.WHITE, UDim2.fromScale(1, 1), nil, 2)
	barText.ZIndex = 5
	UiKit.textConstraint(barText, 15)
	local boxFull = false

	alignTop = function(right: boolean)
		badgeLayout.HorizontalAlignment = if right then Enum.HorizontalAlignment.Right else Enum.HorizontalAlignment.Center
		box.AnchorPoint = Vector2.new(if right then 1 else 0.5, 0)
		box.Position = if right then UDim2.new(1, -4, 0, 56) else UDim2.new(0.5, 0, 0, 56)
	end

	local function refreshBox()
		if player:GetAttribute("LotIndex") == nil then
			boxFull = false
			boxTitle.Text = "CLAIM A LOT"
			boxAmount.Text = ""
			fill.Size = UDim2.fromScale(0, 1)
			barText.Text = "Step on a green pad"
			barText.TextColor3 = UiKit.WHITE
			boxStroke.Color = UiKit.INK
			return
		end
		boxTitle.Text = "BOX OFFICE"
		local pending = player:GetAttribute("Pending") or 0
		local rate = player:GetAttribute("Rate") or Config.CinemaIncomePerSecond
		local cap = math.floor(Upgrades.offlineCap(ClientState.stats()) * rate)
		local share = if cap > 0 then math.clamp(pending / cap, 0, 1) else 0
		boxFull = cap > 0 and pending >= cap - 1
		boxAmount.Text = "$" .. comma(pending)
		fill.Size = UDim2.fromScale(if boxFull then 1 else share, 1)
		fill.BackgroundColor3 = if boxFull then UiKit.CLOSE_RED elseif share >= 0.8 then UiKit.AWARD_GOLD else UiKit.GREEN
		if boxFull then
			barText.Text = "FULL! Collect at gold pad"
		else
			barText.Text = `{math.floor(share * 100)}%`
			barText.TextColor3 = UiKit.WHITE
			boxStroke.Color = UiKit.INK
		end
	end
	ClientState.changed:Connect(refreshBox)

	-- A soft dark card behind the wallet, so the numbers read over bright signs in the world.
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.BackgroundColor3 = UiKit.NAVY
	card.BackgroundTransparency = 0.3
	card.Position = UDim2.fromOffset(-8, -6)
	card.Size = UDim2.fromOffset(WALLET_CARD_MIN, 100)
	card.ZIndex = 0
	card.Parent = wallet
	UiKit.corner(card, 18)
	local cardStroke = UiKit.border(card, 3)
	cardStroke.Transparency = 0.2

	-- Wallet rows: icon, big outlined number, and for Cash a green "+".
	local function walletRow(y: number, height: number, icon: string, color: Color3): (TextLabel, Frame)
		local art = Instance.new("Frame")
		art.Name = icon
		art.BackgroundTransparency = 1
		art.Size = UDim2.fromOffset(height + 6, height + 6)
		art.Position = UDim2.fromOffset(-3, y - 3)
		art.Parent = wallet
		local label = UiKit.makeTitle(wallet, "", color, UDim2.fromOffset(200, height), UDim2.fromOffset(height + 8, y), if height >= 40 then 3.5 else 3)
		label.TextXAlignment = Enum.TextXAlignment.Left
		UiKit.textConstraint(label, height)
		return label, art
	end
	local cashLabel, coinArt = walletRow(0, 46, "coin", UiKit.GOLD)
	Icon3D.spin(Icon3D.outlined(coinArt, "coin", 0.95), 20)
	cashLabel.Text = "..."
	local fameLabel, fameArt = walletRow(54, 34, "star", UiKit.WHITE)
	Icon3D.outlined(fameArt, "star", 0.95)
	local plus = UiKit.makePlusButton(wallet, 36, UDim2.fromOffset(0, 5))
	-- Just after the number. TextBounds is in screen pixels, so undo the wallet's scale first.
	local function placePlus()
		local scale = if wallet.Size.X.Offset > 0 then wallet.AbsoluteSize.X / wallet.Size.X.Offset else 1
		local width = cashLabel.TextBounds.X / math.max(scale, 0.01)
		local plusX = cashLabel.Position.X.Offset + math.ceil(width) + 10
		plus.Position = UDim2.fromOffset(plusX, 5)
		local fameWidth = fameLabel.TextBounds.X / math.max(scale, 0.01)
		local right = math.max(plusX + 36, fameLabel.Position.X.Offset + math.ceil(fameWidth))
		card.Size = UDim2.fromOffset(math.max(WALLET_CARD_MIN, right + 18), 100)
	end
	fameLabel:GetPropertyChangedSignal("TextBounds"):Connect(placePlus)
	cashLabel:GetPropertyChangedSignal("TextBounds"):Connect(placePlus)
	wallet:GetPropertyChangedSignal("AbsoluteSize"):Connect(placePlus)
	placePlus()

	local function refresh()
		if not player:GetAttribute("DataLoaded") then
			return
		end
		cashLabel.Text = "$" .. comma(player:GetAttribute("Cash") or 0)
		fameLabel.Text = "Fame " .. comma(player:GetAttribute("Fame") or 0)
		refreshBox()
	end

	-- Collect feedback: pending royalties only ever drop when they are collected, so a drop means
	-- Cash just received that amount. Float "+$X" under the HUD and play a sweep.
	local lastPending = player:GetAttribute("Pending") or 0
	local function onPending()
		local pending = player:GetAttribute("Pending") or 0
		local collected = lastPending - pending
		lastPending = pending
		if collected < 1 then
			return
		end
		Sfx.play("cashCollect")
		Sfx.play("coin")
		-- Rises from the Cash number.
		local float = UiKit.makeTitle(wallet, "+$" .. comma(collected), UiKit.CASH_GREEN, UDim2.fromOffset(220, 32), UDim2.fromOffset(54, -6), 3)
		float.TextXAlignment = Enum.TextXAlignment.Left
		float.ZIndex = 3
		UiKit.textConstraint(float, 32)
		TweenService:Create(float, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(54, -56), TextTransparency = 1 }):Play()
		task.delay(1.3, function()
			float:Destroy()
		end)
	end

	-- Event badges: the Award Night countdown (purple), gold and pulsing while it's live, and a
	-- green Lucky Casting badge while that boost runs. Award Night follows the shared schedule on
	-- the server's clock. The same loop flashes the box office bar while it's FULL.
	UiKit.onViewportChanged(placeFrame)

	task.spawn(function()
		local wasActive: boolean? = nil
		local flash = false
		while frame.Parent ~= nil do
			local now = workspace:GetServerTimeNow()
			local active, left = Events.awardNight(now)
			if active and wasActive == false then
				Sfx.play("awardNight")
			end
			wasActive = active
			if active then
				awardTitle.Text = "AWARD NIGHT LIVE!"
				awardTimer.Text = `x{Config.AwardNightLuckMultiplier} LUCK  {clock(left)}`
				awardBadge.BackgroundColor3 = UiKit.AWARD_GOLD
			else
				awardTitle.Text = "AWARD NIGHT IN"
				awardTimer.Text = clock(left)
				awardBadge.BackgroundColor3 = UiKit.PURPLE
			end
			local boostLeft = (player:GetAttribute("LuckBoostUntil") or 0) - now
			luckyBadge.Visible = boostLeft > 0
			if boostLeft > 0 then
				luckyTimer.Text = clock(boostLeft)
			end

			flash = not flash
			-- Live Award Night flashes its rim white, like a marquee.
			awardStroke.Color = if active and flash then UiKit.WHITE else UiKit.INK
			if boxFull then
				boxStroke.Color = if flash then UiKit.CLOSE_RED else UiKit.INK
				barText.TextColor3 = if flash then UiKit.GOLD else UiKit.WHITE
			end
			task.wait(0.5)
		end
	end)

	-- Welcome back: what the cinema earned while the player was away, once, right after joining.
	local function showAwayEarnings()
		local pending = player:GetAttribute("Pending") or 0
		if pending < 1 then
			return
		end
		local away = makeLabel(0, 34, UiKit.WHITE)
		away.Name = "AwayEarnings"
		away.Text = `Your cinema earned ${comma(pending)} while you were away! Collect it at the gold pad`
		away.BackgroundTransparency = 0
		away.BackgroundColor3 = UiKit.NAVY
		away.Position = if gui:GetAttribute("HudRight") == true then UDim2.new(0, -80, 1, 8) else UDim2.new(0, -40, 1, 8)
		away.TextXAlignment = Enum.TextXAlignment.Center
		away.Size = UDim2.new(1, 80, 0, 34)
		away.ZIndex = 4
		UiKit.corner(away, 12)
		UiKit.border(away, 3, UiKit.AWARD_GOLD)
		UiKit.textConstraint(away, 22)
		Sfx.play("welcome")
		task.delay(7, function()
			away:Destroy()
		end)
	end

	-- Cash only drops when the player spends it (upgrades, scripts, casting, stages).
	local lastCash = player:GetAttribute("Cash") or 0
	local function onCash()
		local cash = player:GetAttribute("Cash") or 0
		if cash < lastCash and player:GetAttribute("DataLoaded") then
			Sfx.play("spend")
		end
		lastCash = cash
	end

	player.AttributeChanged:Connect(function(name)
		if name == "Rate" or name == "LotIndex" then
			refreshBox()
		end
		if name == "Cash" then
			onCash()
		elseif name == "Pending" then
			onPending()
		elseif name == "DataLoaded" and player:GetAttribute("DataLoaded") then
			showAwayEarnings()
		end
		refresh()
	end)
	refresh()
	if player:GetAttribute("DataLoaded") then
		showAwayEarnings()
	end
	return plus
end

return Hud
