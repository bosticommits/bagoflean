--!strict
-- Rewards screen: the 21-day login streak (opens by itself as "Welcome back!" when today's reward is
-- waiting), today's three Studio Requests, and the code box. Everything is claimed from the server
-- (RewardService), which checks it and answers through RewardResult.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Rewards = require(ReplicatedStorage.Shared.Rewards)
local ClientState = require(script.Parent.ClientState)
local Hud = require(script.Parent.Hud)
local Icon3D = require(script.Parent.Icon3D)
local Screens = require(script.Parent.Screens)
local SideMenu = require(script.Parent.SideMenu)
local Sfx = require(script.Parent.Sfx)
local UiKit = require(script.Parent.UiKit)

local makeLabel, makeButton = UiKit.makeLabel, UiKit.makeButton

local RewardsUi = {}

local LIGHT_PURPLE = Color3.fromRGB(205, 160, 255) -- Skip Filming text on navy
local SILHOUETTE = Color3.fromRGB(46, 54, 92) -- rewards still to be discovered

-- 3D icon (IconModels id) for what a reward mostly gives.
local function rewardIcon(reward: Rewards.Reward): string
	if reward.script ~= nil then
		return "script"
	elseif reward.cash == nil and reward.cashMinutes == nil then
		return if reward.luckMinutes ~= nil then "clover" else "skip"
	end
	return if (reward.cashMinutes or 0) >= 60 then "vault" else "moneybag"
end

-- Each part of a reward as icon + short text + color, for day tiles and milestone banners.
local function rewardParts(reward: Rewards.Reward, rate: number): { { icon: string, text: string, color: Color3 } }
	local parts = {}
	local cash = Rewards.cashAmount(reward, rate)
	if cash > 0 then
		table.insert(parts, { icon = "moneybag", text = "$" .. Hud.comma(cash), color = UiKit.GOLD })
	end
	local script = reward.script
	if script ~= nil then
		table.insert(parts, { icon = "script", text = `{script.count} {script.genre} script{if script.count == 1 then "" else "s"}`, color = UiKit.WHITE })
	end
	if reward.luckMinutes ~= nil then
		table.insert(parts, { icon = "clover", text = `x2 Luck {reward.luckMinutes} min`, color = UiKit.CASH_GREEN })
	end
	if reward.skips ~= nil then
		table.insert(parts, { icon = "skip", text = `{reward.skips} Skip{if reward.skips == 1 then "" else "s"}`, color = LIGHT_PURPLE })
	end
	return parts
end

-- Icon for each kind of Studio Request.
local REQUEST_ICONS: { [string]: string } = {
	cast = "dice",
	premiere = "popcorn",
	clap = "clapper",
	script = "script",
	collect = "moneybag",
	hit = "trophy",
}

-- Number of things waiting to be claimed (daily reward + finished requests), for the badge.
local function claimableCount(state: any): number
	if state == nil then
		return 0
	end
	local count = 0
	if Rewards.dailyStatus(state.daily, state.today) then
		count += 1
	end
	for _, entry in state.requests do
		local request = Rewards.getRequest(entry.id)
		if request ~= nil and not entry.claimed and entry.progress >= request.target then
			count += 1
		end
	end
	return count
end

function RewardsUi.start(gui: ScreenGui, rewardsButton: TextButton, codesButton: TextButton)
	local player = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 15)
	if remotes == nil then
		warn("[RewardsUi] Remotes folder never arrived")
		return
	end
	local claimDaily = remotes:WaitForChild("ClaimDaily") :: RemoteEvent
	local claimRequest = remotes:WaitForChild("ClaimRequest") :: RemoteEvent
	local redeemCode = remotes:WaitForChild("RedeemCode") :: RemoteEvent
	local rewardResult = remotes:WaitForChild("RewardResult") :: RemoteEvent
	local claimStayGift = remotes:WaitForChild("ClaimStayGift") :: RemoteEvent
	local rewardsRequest = remotes:WaitForChild("RewardsRequest") :: RemoteEvent
	local sessionStart = os.clock()

	local panel, list, header = UiKit.makePanel(gui, "RewardsPanel", "Rewards", 108, nil, nil, UiKit.PURPLE)
	UiKit.panelIcon(panel, header, "gift")
	local tabRow = Instance.new("Frame")
	tabRow.Name = "Tabs"
	tabRow.BackgroundTransparency = 1
	tabRow.Position = UDim2.fromOffset(10, 58)
	tabRow.Size = UDim2.new(1, -20, 0, 42)
	tabRow.Parent = panel
	local tabNames = { "Daily", "Requests", "Codes" }
	local tabButtons: { [string]: TextButton } = {}
	local tab = "Daily"
	local welcome = false -- header says "Welcome back!" when the panel opened by itself
	local scrollToToday = false -- set when the Daily tab opens, so today's tile is in view
	-- "Next reward in ..." / "New requests in ..." label kept ticking while the panel is open.
	local countdown: { label: TextLabel, prefix: string }? = nil

	local function rate(): number
		return player:GetAttribute("Rate") or 0
	end

	-- Seconds until the next UTC day, when the daily reward and requests reset.
	local function untilTomorrow(state: any): number
		local now = state.serverNow + (os.clock() - (state.receivedAt or os.clock()))
		return (state.today + 1) * 86400 - now
	end

	-- Width the list gives its rows (before the first layout pass too, from the panel's size rules).
	local function listWidth(): number
		local width = list.AbsoluteSize.X
		if width < 100 then
			local view = UiKit.viewport()
			width = math.min(560, view.X * (if UiKit.isCompact() then 0.96 else 0.92)) - 20
		end
		return width - 11
	end

	-- The streak track, like the reference games' reward screens: a picture tile per day and a big
	-- banner for each rare milestone (days 7, 14, 21). Done days get a tick, today's reward glows
	-- and claims on tap, and days after tomorrow stay dark "???" silhouettes.
	local function renderDaily(state: any)
		local canClaim, nextStreak = Rewards.dailyStatus(state.daily, state.today)
		local streak = if canClaim then nextStreak else state.daily.streak
		local cycleDay = (streak - 1) % #Rewards.Daily + 1
		local function claim()
			claimDaily:FireServer()
		end

		-- Top: the streak and the big CLAIM button (or when the next reward unlocks).
		local titleText, subText
		if canClaim and nextStreak == 1 and state.daily.day > 0 then
			titleText, subText = "Streak lost!", "Starting again from Day 1"
		elseif canClaim and nextStreak == 1 then
			titleText, subText = "Daily rewards", "Come back every day for bigger rewards"
		elseif canClaim then
			titleText, subText = `{state.daily.streak} day streak`, "Claim today's reward to keep it going"
		else
			titleText, subText = `{state.daily.streak} day streak`, `Come back tomorrow for Day {cycleDay % #Rewards.Daily + 1}`
		end
		-- Short screens get a slimmer hero row, so the first week's tiles fit under it.
		local compact = UiKit.isCompact()
		local heroHeight = if compact then 60 else 78
		local hero = UiKit.addRow(list, 1, heroHeight)
		hero.BackgroundColor3 = UiKit.PURPLE:Lerp(UiKit.NAVY, 0.45)
		local heroTitle = UiKit.makeTitle(hero, titleText, UiKit.GOLD, UDim2.new(0.58, -12, 0, if compact then 28 else 34), UDim2.fromOffset(12, if compact then 4 else 7), 2.5)
		heroTitle.TextXAlignment = Enum.TextXAlignment.Left
		UiKit.textConstraint(heroTitle, 32)
		local heroSub = makeLabel(hero, subText, UiKit.WHITE, UDim2.new(0.58, -12, 0, 20), UDim2.fromOffset(12, if compact then 35 else 46))
		heroSub.TextXAlignment = Enum.TextXAlignment.Left
		UiKit.textConstraint(heroSub, 18)
		if canClaim then
			local buttonHeight = heroHeight - 20
			local claimButton = makeButton(hero, `CLAIM DAY {cycleDay}!`, UiKit.GREEN, UDim2.new(0.4, -6, 0, buttonHeight), UDim2.new(0.6, 0, 0.5, -buttonHeight // 2))
			claimButton.Name = "ClaimDaily"
			UiKit.textConstraint(claimButton, 28)
			UiKit.pulse(claimButton)
			claimButton.Activated:Connect(claim)
		else
			local nextLabel = UiKit.makeTitle(hero, "", UiKit.WHITE, UDim2.new(0.4, -12, 0, 44), UDim2.new(0.6, 0, 0.5, -22), 2.5)
			UiKit.textConstraint(nextLabel, 24)
			countdown = { label = nextLabel, prefix = "Next reward in\n" }
		end

		local columns = if listWidth() >= 430 then 6 else 3
		local cellWidth = (listWidth() - (columns - 1) * 6) / columns
		local cellHeight = math.floor(if compact then math.clamp(cellWidth * 1.15, 92, 130) else math.clamp(cellWidth * 1.3, 100, 150))
		local bannerHeight = if compact then 96 else 108
		local order = 1
		local todayWeek: Frame? = nil -- the week holding today's reward, scrolled into view on open

		local function dayTile(parent: Instance, day: number, reward: Rewards.Reward)
			local isToday = day == cycleDay
			local done = day < cycleDay or (isToday and not canClaim)
			local claimable = isToday and canClaim
			local hidden = day > cycleDay + 1
			local tile = Instance.new("TextButton")
			tile.Name = `Day{day}`
			tile.LayoutOrder = day
			tile.Text = ""
			tile.AutoButtonColor = false
			tile.BackgroundColor3 = if claimable then UiKit.GREEN:Lerp(UiKit.NAVY, 0.35) else UiKit.ROW
			tile.Parent = parent
			UiKit.corner(tile, 12)
			UiKit.border(tile, if claimable then 4 else 2, if claimable then UiKit.GOLD else UiKit.INK)
			local shade = Instance.new("UIGradient")
			shade.Rotation = 90
			shade.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 165))
			shade.Parent = tile

			local dayText = if isToday then "TODAY" elseif day == cycleDay + 1 then "Tomorrow" else `Day {day}`
			local dayLabel = UiKit.makeTitle(tile, dayText, if isToday then UiKit.GOLD elseif hidden then UiKit.FAINT else UiKit.WHITE, UDim2.fromScale(0.94, 0.17), UDim2.fromScale(0.03, 0.04), 2)
			dayLabel.ZIndex = 3
			UiKit.textConstraint(dayLabel, 18)
			local art = Instance.new("Frame")
			art.Name = "Art"
			art.BackgroundTransparency = 1
			art.AnchorPoint = Vector2.new(0.5, 0)
			art.Position = UDim2.fromScale(0.5, 0.22)
			art.Size = UDim2.fromScale(0.86, 0.5)
			art.Parent = tile
			local view = Icon3D.outlined(art, rewardIcon(reward), 0.95)
			Icon3D.glow(view, if claimable then UiKit.GOLD else nil, if hidden then 0.4 else 1)
			local parts = rewardParts(reward, rate())
			local first = parts[1]
			local amount = UiKit.makeTitle(tile, if hidden then "???" elseif first ~= nil then first.text else "", if hidden then UiKit.FAINT elseif first ~= nil then first.color else UiKit.WHITE, UDim2.fromScale(0.94, 0.2), UDim2.fromScale(0.03, 0.75), 2)
			amount.ZIndex = 3
			UiKit.textConstraint(amount, 18)

			if hidden then
				view.ImageColor3 = SILHOUETTE
			elseif claimable then
				Icon3D.spin(view, 18)
				UiKit.pulse(tile, 1.05)
				tile.Activated:Connect(claim)
			end
			if done then
				local dim = Instance.new("Frame")
				dim.Name = "Dim"
				dim.BackgroundColor3 = UiKit.INK
				dim.BackgroundTransparency = 0.45
				dim.Size = UDim2.fromScale(1, 1)
				dim.ZIndex = 5
				dim.Parent = tile
				UiKit.corner(dim, 12)
				UiKit.tick(tile, 6)
			end
		end

		local function milestoneBanner(day: number, reward: Rewards.Reward)
			local isToday = day == cycleDay
			local done = day < cycleDay or (isToday and not canClaim)
			local claimable = isToday and canClaim
			order += 1
			local banner = Instance.new("TextButton")
			banner.Name = `Day{day}`
			banner.LayoutOrder = order
			banner.Text = ""
			banner.AutoButtonColor = false
			banner.Size = UDim2.new(1, -8, 0, bannerHeight)
			banner.BackgroundColor3 = UiKit.BURGUNDY
			banner.Parent = list
			UiKit.corner(banner, 14)
			UiKit.border(banner, if claimable then 5 else 3, UiKit.AWARD_GOLD)
			local shade = Instance.new("UIGradient")
			shade.Rotation = 90
			shade.Color = ColorSequence.new(Color3.fromRGB(255, 225, 225), Color3.fromRGB(150, 120, 130))
			shade.Parent = banner

			local art = Instance.new("Frame")
			art.Name = "Art"
			art.BackgroundTransparency = 1
			art.AnchorPoint = Vector2.new(0, 0.5)
			art.Position = UDim2.new(0, 6, 0.5, 0)
			art.Size = UDim2.fromOffset(bannerHeight - 8, bannerHeight - 8)
			art.Parent = banner
			local view = Icon3D.outlined(art, "chest")
			Icon3D.glow(view, UiKit.GOLD)
			if claimable then
				Icon3D.spin(view, 18)
				UiKit.pulse(banner, 1.03)
				banner.Activated:Connect(claim)
			end

			local left = bannerHeight + 4
			local title = UiKit.makeTitle(banner, if isToday then `TODAY  -  Day {day}` else `Day {day}  -  Rare reward`, UiKit.GOLD, UDim2.new(1, -(left + 10), 0, 30), UDim2.fromOffset(left, 6), 2.5)
			title.TextXAlignment = Enum.TextXAlignment.Left
			title.ZIndex = 3
			UiKit.textConstraint(title, 28)

			-- What it gives, as little pictures in a row.
			local strip = Instance.new("Frame")
			strip.Name = "Parts"
			strip.BackgroundTransparency = 1
			strip.Position = UDim2.fromOffset(left, 38)
			strip.Size = UDim2.new(1, -(left + 10), 0, 34)
			strip.Parent = banner
			local parts = rewardParts(reward, rate())
			for slot, part in parts do
				local piece = Instance.new("Frame")
				piece.BackgroundTransparency = 1
				piece.Position = UDim2.fromScale((slot - 1) / #parts, 0)
				piece.Size = UDim2.new(1 / #parts, -4, 1, 0)
				piece.Parent = strip
				local pieceArt = Instance.new("Frame")
				pieceArt.BackgroundTransparency = 1
				pieceArt.Size = UDim2.fromOffset(34, 34)
				pieceArt.Parent = piece
				Icon3D.outlined(pieceArt, part.icon, 0.95)
				local text = UiKit.makeTitle(piece, part.text, part.color, UDim2.new(1, -38, 1, -6), UDim2.fromOffset(38, 3), 2)
				text.TextXAlignment = Enum.TextXAlignment.Left
				text.ZIndex = 3
				UiKit.textConstraint(text, 20)
			end

			local hint = if done then "Claimed!" elseif claimable then "Tap to claim!" else `Play {day} days in a row to unlock this rare reward`
			local hintLabel = makeLabel(banner, hint, if done then UiKit.CASH_GREEN else UiKit.CREAM, UDim2.new(1, -(left + 10), 0, 20), UDim2.new(0, left, 1, -26))
			hintLabel.TextXAlignment = Enum.TextXAlignment.Left
			hintLabel.ZIndex = 3
			UiKit.outline(hintLabel, 1.5)
			UiKit.textConstraint(hintLabel, 16)

			if done then
				local dim = Instance.new("Frame")
				dim.Name = "Dim"
				dim.BackgroundColor3 = UiKit.INK
				dim.BackgroundTransparency = 0.5
				dim.Size = UDim2.fromScale(1, 1)
				dim.ZIndex = 5
				dim.Parent = banner
				UiKit.corner(dim, 14)
				local tickHolder = Instance.new("Frame")
				tickHolder.BackgroundTransparency = 1
				tickHolder.AnchorPoint = Vector2.new(1, 0.5)
				tickHolder.Position = UDim2.new(1, -10, 0.5, 0)
				tickHolder.Size = UDim2.fromOffset(bannerHeight - 20, bannerHeight - 20)
				tickHolder.ZIndex = 6
				tickHolder.Parent = banner
				UiKit.tick(tickHolder, 6)
			end
		end

		-- Three weeks: six day tiles, then the milestone.
		local week = 0
		local day = 1
		while day <= #Rewards.Daily do
			week += 1
			order += 1
			local grid = Instance.new("Frame")
			grid.Name = `Week{week}`
			grid.LayoutOrder = order
			grid.BackgroundTransparency = 1
			grid.Parent = list
			local layout = Instance.new("UIGridLayout")
			layout.CellSize = UDim2.new(1 / columns, -6 + 6 / columns, 0, cellHeight)
			layout.CellPadding = UDim2.fromOffset(6, 8)
			layout.SortOrder = Enum.SortOrder.LayoutOrder
			layout.Parent = grid
			local pad = Instance.new("UIPadding")
			pad.PaddingLeft = UDim.new(0, 3)
			pad.PaddingTop = UDim.new(0, 3)
			pad.Parent = grid
			local count = 0
			local weekStart = day
			while day <= #Rewards.Daily and not Rewards.Milestones[day] do
				dayTile(grid, day, Rewards.Daily[day])
				count += 1
				day += 1
			end
			local rows = math.ceil(count / columns)
			grid.Size = UDim2.new(1, -8, 0, rows * cellHeight + (rows - 1) * 8 + 6)
			-- `day` is now the week's milestone, which counts as part of the week.
			if cycleDay >= weekStart and cycleDay <= day then
				todayWeek = if week > 1 then grid else nil
			end
			if day <= #Rewards.Daily then
				milestoneBanner(day, Rewards.Daily[day])
				day += 1
			end
		end

		order += 1
		local footer = UiKit.addRow(list, order, 34)
		UiKit.plainRow(footer)
		makeLabel(footer, "Miss a day and the streak starts again", UiKit.MUTED, UDim2.new(1, -20, 1, 0), UDim2.fromOffset(10, 0))

		-- On open, scroll to today's week (the first week is in view already, under the hero row).
		if scrollToToday then
			scrollToToday = false
			local anchor = todayWeek
			list.CanvasPosition = Vector2.zero
			if anchor ~= nil then
				task.spawn(function()
					task.wait() -- after the layout has placed the rows and sized the canvas
					if anchor.Parent ~= nil and panel.Visible then
						list.CanvasPosition = Vector2.new(0, anchor.AbsolutePosition.Y - list.AbsolutePosition.Y + list.CanvasPosition.Y - 6)
					end
				end)
			end
		end
	end

	local function renderRequests(state: any)
		local order = 1
		local top = UiKit.addRow(list, order, 44)
		local newIn = makeLabel(top, "", UiKit.GOLD, UDim2.new(1, -20, 1, -8), UDim2.fromOffset(10, 4))
		countdown = { label = newIn, prefix = "New Studio Requests in " }
		for index, entry in state.requests do
			local request = Rewards.getRequest(entry.id)
			if request == nil then
				continue
			end
			order += 1
			local finished = entry.progress >= request.target
			local row = UiKit.addRow(list, order, 92)
			if finished and not entry.claimed then
				local outline = row:FindFirstChild("Outline") :: UIStroke
				outline.Color = UiKit.GREEN
				outline.Thickness = 3
			end
			UiKit.rowIcon(row, REQUEST_ICONS[request.kind] or "clapper", 70)
			local textLeft = 86
			local title = UiKit.makeTitle(row, request.text, UiKit.WHITE, UDim2.new(0.66, -textLeft, 0, 28), UDim2.fromOffset(textLeft, 6))
			title.TextXAlignment = Enum.TextXAlignment.Left
			local reward = makeLabel(row, "Reward: " .. Rewards.describe(request.reward, rate()), UiKit.GOLD, UDim2.new(0.66, -textLeft, 0, 20), UDim2.fromOffset(textLeft, 36))
			reward.TextXAlignment = Enum.TextXAlignment.Left

			local bar = Instance.new("Frame")
			bar.BackgroundColor3 = UiKit.DARK
			bar.Position = UDim2.fromOffset(textLeft, 64)
			bar.Size = UDim2.new(0.66, -(textLeft + 4), 0, 16)
			bar.Parent = row
			UiKit.corner(bar, 8)
			UiKit.border(bar, 2)
			local fill = Instance.new("Frame")
			fill.BackgroundColor3 = UiKit.GREEN
			fill.Size = UDim2.fromScale(math.clamp(entry.progress / request.target, 0, 1), 1)
			fill.Parent = bar
			UiKit.corner(fill, 8)
			local count = UiKit.makeTitle(bar, `{math.min(entry.progress, request.target)}/{request.target}`, UiKit.WHITE, UDim2.fromScale(1, 1), nil, 1.5)
			count.ZIndex = 2

			if entry.claimed then
				local doneArea = Instance.new("Frame")
				doneArea.BackgroundTransparency = 1
				doneArea.Position = UDim2.fromScale(0.68, 0.08)
				doneArea.Size = UDim2.fromScale(0.3, 0.84)
				doneArea.Parent = row
				UiKit.tick(doneArea, 3)
			elseif finished then
				local claim = makeButton(row, "CLAIM", UiKit.GREEN, UDim2.new(0.3, 0, 0, 48), UDim2.new(0.68, 0, 0.5, -24))
				UiKit.pulse(claim)
				claim.Activated:Connect(function()
					claimRequest:FireServer(index)
				end)
			else
				makeLabel(row, "In progress", UiKit.MUTED, UDim2.new(0.3, 0, 0, 40), UDim2.new(0.68, 0, 0.5, -20))
			end
		end
	end

	local codeMessage: TextLabel? = nil
	local function renderCodes()
		local compact = UiKit.isCompact()
		-- The code box as a card: a big ticket, a title, the box with Redeem, and the answer.
		local iconSize = if compact then 64 else 96
		local titleY = iconSize + 8
		local boxY = titleY + (if compact then 34 else 40)
		local boxHeight = if compact then 42 else 48
		local messageY = boxY + boxHeight + 8
		local card = UiKit.addRow(list, 1, messageY + 30)
		card.BackgroundColor3 = UiKit.PURPLE:Lerp(UiKit.NAVY, 0.55)
		local art = Instance.new("Frame")
		art.Name = "Icon"
		art.BackgroundTransparency = 1
		art.AnchorPoint = Vector2.new(0.5, 0)
		art.Position = UDim2.new(0.5, 0, 0, 6)
		art.Size = UDim2.fromOffset(iconSize, iconSize)
		art.ZIndex = card.ZIndex + 1
		art.Parent = card
		Icon3D.outlined(art, "ticket")
		local title = UiKit.makeTitle(card, "Redeem a code", UiKit.GOLD, UDim2.new(1, -20, 0, if compact then 28 else 32), UDim2.fromOffset(10, titleY), 2.5)
		UiKit.textConstraint(title, 30)
		local box = Instance.new("TextBox")
		box.PlaceholderText = "Enter code"
		box.Text = ""
		box.ClearTextOnFocus = false
		box.BackgroundColor3 = UiKit.CREAM
		box.TextColor3 = UiKit.NAVY
		box.PlaceholderColor3 = UiKit.FAINT
		box.TextScaled = true
		box.Font = UiKit.DISPLAY_FONT
		box.Position = UDim2.fromOffset(16, boxY)
		box.Size = UDim2.new(0.62, -22, 0, boxHeight)
		box.Parent = card
		UiKit.corner(box, 10)
		UiKit.border(box, 3)
		UiKit.textConstraint(box :: any, 24)
		local boxPad = Instance.new("UIPadding")
		boxPad.PaddingLeft = UDim.new(0, 10)
		boxPad.PaddingRight = UDim.new(0, 10)
		boxPad.Parent = box
		local redeem = makeButton(card, "Redeem", UiKit.GREEN, UDim2.new(0.38, -16, 0, boxHeight), UDim2.new(0.62, 0, 0, boxY))
		local message = makeLabel(card, "", UiKit.GOLD, UDim2.new(1, -32, 0, 22), UDim2.fromOffset(16, messageY))
		UiKit.outline(message, 1.5)
		codeMessage = message
		local function submit()
			if box.Text ~= "" then
				redeemCode:FireServer(box.Text)
			end
		end
		redeem.Activated:Connect(submit)
		box.FocusLost:Connect(function(enterPressed)
			if enterPressed then
				submit()
			end
		end)

		-- What codes can give, as pictures.
		local pictureSize = if compact then 52 else 64
		local gives = UiKit.addRow(list, 2, pictureSize + 64)
		local heading = makeLabel(gives, "Codes can give", UiKit.MUTED, UDim2.new(1, -20, 0, 20), UDim2.fromOffset(10, 6))
		UiKit.textConstraint(heading, 18)
		local kinds = {
			{ icon = "moneybag", text = "Cash", color = UiKit.GOLD },
			{ icon = "clover", text = "Luck boosts", color = UiKit.CASH_GREEN },
			{ icon = "script", text = "Free scripts", color = UiKit.WHITE },
		}
		for index, kind in kinds do
			local slot = Instance.new("Frame")
			slot.BackgroundTransparency = 1
			slot.Position = UDim2.new((index - 1) / #kinds, 0, 0, 28)
			slot.Size = UDim2.new(1 / #kinds, 0, 1, -32)
			slot.Parent = gives
			local pictureArt = Instance.new("Frame")
			pictureArt.BackgroundTransparency = 1
			pictureArt.AnchorPoint = Vector2.new(0.5, 0)
			pictureArt.Position = UDim2.fromScale(0.5, 0)
			pictureArt.Size = UDim2.fromOffset(pictureSize, pictureSize)
			pictureArt.ZIndex = gives.ZIndex + 1
			pictureArt.Parent = slot
			Icon3D.outlined(pictureArt, kind.icon)
			local label = UiKit.makeTitle(slot, kind.text, kind.color, UDim2.new(1, -8, 0, 22), UDim2.new(0, 4, 0, pictureSize + 2), 2)
			UiKit.textConstraint(label, 20)
		end

		-- Where new ones come from.
		local hint = UiKit.addRow(list, 3, 56)
		UiKit.rowIcon(hint, "star", 42)
		local hintLabel = makeLabel(hint, "New codes come with updates and on our socials", UiKit.MUTED, UDim2.new(1, -72, 1, -14), UDim2.fromOffset(60, 7))
		hintLabel.TextXAlignment = Enum.TextXAlignment.Left
		UiKit.textConstraint(hintLabel, 18)
	end

	local function tickCountdown()
		local current = countdown
		local state = ClientState.rewards
		if current ~= nil and state ~= nil and current.label.Parent ~= nil then
			current.label.Text = current.prefix .. Hud.clock(untilTomorrow(state))
		end
	end

	-- What the screen was last built for. A sync that changes nothing it shows (the server sends a
	-- fresh one every time the screen opens) keeps what is there, pictures and typed code included.
	local builtFor: string? = nil
	local function signature(): string
		local shown: { [string]: any } = {}
		for key, value in ClientState.rewards or {} do
			if key ~= "serverNow" and key ~= "receivedAt" then
				shown[key] = value
			end
		end
		return `{tab}|{welcome}|{math.floor(rate())}|{UiKit.isCompact()}|{math.floor(listWidth())}|{UiKit.signature(shown)}`
	end

	local function render()
		local wanted = signature()
		if wanted == builtFor then
			scrollToToday = false -- still where the player left it
			tickCountdown()
			return
		end
		builtFor = wanted
		UiKit.clear(list)
		codeMessage = nil
		countdown = nil
		for name, button in tabButtons do
			UiKit.styleTab(button, name == tab)
		end
		header.Text = if welcome then "Welcome back!" else "Rewards"
		local state = ClientState.rewards
		-- Red badges on the tabs with something to claim.
		if state ~= nil then
			local dailyReady = Rewards.dailyStatus(state.daily, state.today)
			UiKit.badge(tabButtons.Daily, if dailyReady then "!" else nil)
			local requestsReady = claimableCount(state) - (if dailyReady then 1 else 0)
			UiKit.badge(tabButtons.Requests, if requestsReady > 0 then tostring(requestsReady) else nil)
		end
		if tab == "Codes" then
			renderCodes()
		elseif state == nil then
			local row = UiKit.addRow(list, 1, 52)
			makeLabel(row, "Loading...", UiKit.MUTED, UDim2.new(1, -20, 0.6, 0), UDim2.fromOffset(10, 10))
		elseif tab == "Daily" then
			renderDaily(state)
		else
			renderRequests(state)
		end
		tickCountdown()
	end

	for slot, name in tabNames do
		local button = makeButton(tabRow, name, UiKit.TAB_OFF, UDim2.new(0.32, 0, 1, 0), UDim2.new((slot - 1) * 0.34, 0, 0, 0))
		tabButtons[name] = button
		button.Activated:Connect(function()
			tab = name
			scrollToToday = name == "Daily"
			render()
		end)
	end

	local function open(which: string)
		tab = which
		scrollToToday = which == "Daily"
		-- Fresh state every time the screen opens (the server limits this to once a second).
		rewardsRequest:FireServer()
		if panel.Visible then
			render()
		else
			UiKit.togglePanel(panel, render)
		end
	end

	rewardsButton.Activated:Connect(function()
		welcome = false
		if panel.Visible and tab ~= "Codes" then
			panel.Visible = false
		else
			open(if tab == "Codes" then "Daily" else tab)
		end
	end)
	codesButton.Activated:Connect(function()
		welcome = false
		if panel.Visible and tab == "Codes" then
			panel.Visible = false
		else
			open("Codes")
		end
	end)
	-- The Rewards, Requests and Codes stands on the map open their tab.
	local function openTab(which: string): () -> ()
		return function()
			welcome = false
			open(which)
		end
	end
	Screens.register("Daily", openTab("Daily"))
	Screens.register("Requests", openTab("Requests"))
	Screens.register("Codes", openTab("Codes"))

	-- The first sync after joining: if today's reward is waiting (and the tutorial is out of the way),
	-- greet the player with the streak screen, like the games they know.
	local greeted = false
	ClientState.changed:Connect(function(kind)
		local state = ClientState.rewards
		if kind == "rewards" and state ~= nil then
			state.receivedAt = os.clock()
			SideMenu.setBadge(rewardsButton, claimableCount(state))
			if not greeted then
				greeted = true
				local studio = ClientState.studio
				if Rewards.dailyStatus(state.daily, state.today) and studio ~= nil and studio.tutorialDone then
					welcome = true
					open("Daily")
					Sfx.play("jingle")
					return
				end
			end
			if panel.Visible and tab ~= "Codes" then
				render()
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			if panel.Visible then
				tickCountdown()
			end
		end
	end)

	-- A new UTC day brings a new daily reward and new requests. Ask for them when it starts, so the
	-- badge and the open screen do not keep showing yesterday for a player who stays in the game.
	task.spawn(function()
		while true do
			task.wait(15)
			local state = ClientState.rewards
			if state ~= nil and untilTomorrow(state) <= 0 then
				state.today += 1 -- ask once per rollover; the sync replaces this state
				rewardsRequest:FireServer()
			end
		end
	end)

	-- "Don't leave yet!" popup. Opening the Roblox menu is usually the first step of leaving, so a
	-- gift waits behind the menu and is there when it closes. Shown only when the server would grant
	-- it (once a day, after a few minutes of play); the server checks again on claim.
	local gift = Instance.new("Frame")
	gift.Name = "StayGift"
	gift.AnchorPoint = Vector2.new(0.5, 0.5)
	gift.Position = UDim2.fromScale(0.5, 0.5)
	gift.Size = UDim2.fromScale(0.8, 0.5)
	gift.BackgroundColor3 = UiKit.PANEL
	gift.Visible = false
	gift.ZIndex = 30
	gift.Parent = gui
	UiKit.corner(gift, 18)
	local giftLimit = Instance.new("UISizeConstraint")
	giftLimit.MaxSize = Vector2.new(420, 260)
	giftLimit.Parent = gift
	UiKit.border(gift, 5, UiKit.AWARD_GOLD)
	local giftArt = Instance.new("Frame")
	giftArt.Name = "Art"
	giftArt.BackgroundTransparency = 1
	giftArt.Position = UDim2.fromOffset(-26, -40)
	giftArt.Size = UDim2.fromOffset(96, 96)
	giftArt.Parent = gift
	Icon3D.outlined(giftArt, "gift")
	local giftTitle = UiKit.makeTitle(gift, "Wait! A gift before you go", UiKit.GOLD, UDim2.new(1, -90, 0.2, 0), UDim2.new(0, 76, 0.06, 0))
	UiKit.textConstraint(giftTitle, 30)
	local giftText = makeLabel(gift, "", UiKit.WHITE, UDim2.new(0.9, 0, 0.24, 0), UDim2.fromScale(0.05, 0.32))
	local giftClaim = makeButton(gift, "CLAIM", UiKit.GREEN, UDim2.fromScale(0.5, 0.24), UDim2.fromScale(0.25, 0.68))
	local giftClose = makeButton(gift, "X", UiKit.CLOSE_RED, UDim2.fromOffset(36, 36), UDim2.new(1, -44, 0, 8))
	for _, child in gift:GetChildren() do
		if child:IsA("GuiObject") then
			child.ZIndex = 31
		end
	end
	giftClaim.Activated:Connect(function()
		claimStayGift:FireServer()
		gift.Visible = false
	end)
	giftClose.Activated:Connect(function()
		gift.Visible = false
	end)
	GuiService.MenuOpened:Connect(function()
		local state = ClientState.rewards
		if state == nil or (state.stayGiftDay or 0) >= state.today then
			return
		end
		if os.clock() - sessionStart < Config.StayGiftMinSeconds then
			return
		end
		giftText.Text = Rewards.describe(Rewards.StayGift, rate())
		gift.Visible = true
		Sfx.play("pop")
	end)

	rewardResult.OnClientEvent:Connect(function(ok, text)
		if type(text) ~= "string" then
			return
		end
		Sfx.play(if ok then "stinger" else "low")
		UiKit.toast(gui, text)
		local message = codeMessage
		if message ~= nil and panel.Visible and tab == "Codes" then
			message.Text = text
			message.TextColor3 = if ok then UiKit.GREEN else UiKit.RED
		end
	end)
end

return RewardsUi
