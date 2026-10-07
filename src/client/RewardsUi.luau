--!strict
-- Rewards screen: the 7-day login streak (opens by itself as "Welcome back!" when today's reward is
-- waiting), today's three Studio Requests, and the code box. Everything is claimed from the server
-- (RewardService), which checks it and answers through RewardResult.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Rewards = require(ReplicatedStorage.Shared.Rewards)
local ClientState = require(script.Parent.ClientState)
local Hud = require(script.Parent.Hud)
local SideMenu = require(script.Parent.SideMenu)
local Sfx = require(script.Parent.Sfx)
local UiKit = require(script.Parent.UiKit)

local makeLabel, makeButton = UiKit.makeLabel, UiKit.makeButton

local RewardsUi = {}

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
	local sessionStart = os.clock()

	local panel, list, header = UiKit.makePanel(gui, "RewardsPanel", "Rewards", 108)
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

	local function rate(): number
		return player:GetAttribute("Rate") or 0
	end

	-- Seconds until the next UTC day, when the daily reward and requests reset.
	local function untilTomorrow(state: any): number
		local now = state.serverNow + (os.clock() - (state.receivedAt or os.clock()))
		return (state.today + 1) * 86400 - now
	end

	local function renderDaily(state: any)
		local canClaim, nextStreak = Rewards.dailyStatus(state.daily, state.today)
		local streak = if canClaim then nextStreak else state.daily.streak
		local cycleDay = (streak - 1) % #Rewards.Daily + 1
		local order = 1
		local top = UiKit.addRow(list, order, 44)
		local streakText = if canClaim and nextStreak == 1 and state.daily.day > 0 then "Streak lost - starting again!" else `Login streak: {math.max(state.daily.streak, 0)} day{if state.daily.streak == 1 then "" else "s"}`
		makeLabel(top, streakText, UiKit.GOLD, UDim2.new(1, -20, 1, -8), UDim2.fromOffset(10, 4))

		for day, reward in Rewards.Daily do
			order += 1
			local row = UiKit.addRow(list, order, 56)
			local isToday = day == cycleDay
			local title = makeLabel(row, `Day {day}`, if isToday then UiKit.GOLD else UiKit.WHITE, UDim2.new(0.2, 0, 0, 40), UDim2.fromOffset(10, 8))
			title.TextXAlignment = Enum.TextXAlignment.Left
			local text = makeLabel(row, Rewards.describe(reward, rate()), UiKit.WHITE, UDim2.new(0.46, 0, 0, 30), UDim2.new(0.2, 10, 0, 13))
			text.TextXAlignment = Enum.TextXAlignment.Left
			local done = day < cycleDay or (isToday and not canClaim)
			if isToday and canClaim then
				local claim = makeButton(row, "CLAIM", UiKit.GREEN, UDim2.new(0.3, 0, 0, 40), UDim2.new(0.68, 0, 0, 8))
				claim.Activated:Connect(function()
					claimDaily:FireServer()
				end)
			else
				makeLabel(row, if done then "Claimed" else "Soon", if done then UiKit.GREEN else UiKit.MUTED, UDim2.new(0.3, 0, 0, 30), UDim2.new(0.68, 0, 0, 13))
			end
		end

		order += 1
		local footer = UiKit.addRow(list, order, 34)
		footer.BackgroundTransparency = 1
		local footerText = if canClaim then "Miss a day and the streak starts again" else `Next reward in {Hud.clock(untilTomorrow(state))}`
		makeLabel(footer, footerText, UiKit.MUTED, UDim2.new(1, -20, 1, 0), UDim2.fromOffset(10, 0))
	end

	local function renderRequests(state: any)
		local order = 1
		local top = UiKit.addRow(list, order, 44)
		makeLabel(top, `New Studio Requests in {Hud.clock(untilTomorrow(state))}`, UiKit.GOLD, UDim2.new(1, -20, 1, -8), UDim2.fromOffset(10, 4))
		for index, entry in state.requests do
			local request = Rewards.getRequest(entry.id)
			if request == nil then
				continue
			end
			order += 1
			local row = UiKit.addRow(list, order, 92)
			local title = makeLabel(row, request.text, UiKit.WHITE, UDim2.new(0.64, 0, 0, 28), UDim2.fromOffset(10, 6))
			title.TextXAlignment = Enum.TextXAlignment.Left
			local reward = makeLabel(row, "Reward: " .. Rewards.describe(request.reward, rate()), UiKit.MUTED, UDim2.new(0.64, 0, 0, 20), UDim2.fromOffset(10, 36))
			reward.TextXAlignment = Enum.TextXAlignment.Left

			local bar = Instance.new("Frame")
			bar.BackgroundColor3 = Color3.fromRGB(55, 55, 70)
			bar.Position = UDim2.fromOffset(10, 66)
			bar.Size = UDim2.new(0.64, -10, 0, 14)
			bar.Parent = row
			UiKit.corner(bar, 7)
			local fill = Instance.new("Frame")
			fill.BackgroundColor3 = UiKit.GREEN
			fill.Size = UDim2.fromScale(math.clamp(entry.progress / request.target, 0, 1), 1)
			fill.Parent = bar
			UiKit.corner(fill, 7)
			local count = makeLabel(bar, `{entry.progress}/{request.target}`, UiKit.WHITE, UDim2.fromScale(1, 1))
			count.ZIndex = 2

			if entry.claimed then
				makeLabel(row, "Done", UiKit.GREEN, UDim2.new(0.3, 0, 0, 40), UDim2.new(0.68, 0, 0.5, -20))
			elseif entry.progress >= request.target then
				local claim = makeButton(row, "CLAIM", UiKit.GREEN, UDim2.new(0.3, 0, 0, 44), UDim2.new(0.68, 0, 0.5, -22))
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
		local row = UiKit.addRow(list, 1, 120)
		makeLabel(row, "Have a code? Find them on our socials.", UiKit.MUTED, UDim2.new(1, -20, 0, 24), UDim2.fromOffset(10, 6))
		local box = Instance.new("TextBox")
		box.PlaceholderText = "Enter code"
		box.Text = ""
		box.ClearTextOnFocus = false
		box.BackgroundColor3 = Color3.fromRGB(240, 240, 245)
		box.TextColor3 = Color3.fromRGB(20, 20, 25)
		box.TextScaled = true
		box.Font = Enum.Font.GothamBold
		box.Position = UDim2.fromOffset(10, 40)
		box.Size = UDim2.new(0.62, -10, 0, 44)
		box.Parent = row
		UiKit.corner(box, 10)
		UiKit.textConstraint(box :: any, 24)
		local redeem = makeButton(row, "Redeem", UiKit.GREEN, UDim2.new(0.34, 0, 0, 44), UDim2.new(0.64, 0, 0, 40))
		local message = makeLabel(row, "", UiKit.GOLD, UDim2.new(1, -20, 0, 24), UDim2.fromOffset(10, 90))
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
	end

	local function render()
		UiKit.clear(list)
		codeMessage = nil
		for name, button in tabButtons do
			button.BackgroundColor3 = if name == tab then Color3.fromRGB(70, 130, 110) else UiKit.BLUE
		end
		header.Text = if welcome then "Welcome back!" else "Rewards"
		local state = ClientState.rewards
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
	end

	for slot, name in tabNames do
		local button = makeButton(tabRow, name, UiKit.BLUE, UDim2.new(0.32, 0, 1, 0), UDim2.new((slot - 1) * 0.34, 0, 0, 0))
		tabButtons[name] = button
		button.Activated:Connect(function()
			tab = name
			render()
		end)
	end

	local function open(which: string)
		tab = which
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
	UiKit.corner(gift, 14)
	local giftLimit = Instance.new("UISizeConstraint")
	giftLimit.MaxSize = Vector2.new(420, 260)
	giftLimit.Parent = gift
	local giftStroke = Instance.new("UIStroke")
	giftStroke.Thickness = 4
	giftStroke.Color = UiKit.GOLD
	giftStroke.Parent = gift
	local giftTitle = makeLabel(gift, "Wait! A gift before you go", UiKit.GOLD, UDim2.new(0.9, 0, 0.2, 0), UDim2.fromScale(0.05, 0.06))
	UiKit.textConstraint(giftTitle, 30)
	local giftText = makeLabel(gift, "", UiKit.WHITE, UDim2.new(0.9, 0, 0.24, 0), UDim2.fromScale(0.05, 0.32))
	local giftClaim = makeButton(gift, "CLAIM", UiKit.GREEN, UDim2.fromScale(0.5, 0.24), UDim2.fromScale(0.25, 0.68))
	local giftClose = makeButton(gift, "X", Color3.fromRGB(200, 60, 60), UDim2.fromOffset(36, 36), UDim2.new(1, -44, 0, 8))
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
