--!strict
-- Goals screen, two tabs. Achievements: one row per group showing its next goal, a progress bar and
-- the reward, with CLAIM when it is done. Quests: today's three Studio Requests and this week's three
-- weekly quests, with a countdown to each reset (the same lists the Rewards screen's Requests tab
-- shows; the server's QuestTracker keeps them). The side menu's Goals button carries a red badge
-- with the number ready to claim across both tabs, and reaching a goal or finishing a quest says so
-- at the bottom of the screen. Achievement claims go to AchievementService, quest claims to
-- RewardService; both check them, and answer on RewardResult (shown by RewardsUi).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Achievements = require(ReplicatedStorage.Shared.Achievements)
local Rewards = require(ReplicatedStorage.Shared.Rewards)
local ClientState = require(script.Parent.ClientState)
local Hud = require(script.Parent.Hud)
local Screens = require(script.Parent.Screens)
local SideMenu = require(script.Parent.SideMenu)
local Sfx = require(script.Parent.Sfx)
local UiKit = require(script.Parent.UiKit)

local makeLabel, makeButton = UiKit.makeLabel, UiKit.makeButton

local AchievementsUi = {}

local GROUP_ICONS: { [string]: string } = {
	cast = "dice",
	premiere = "popcorn",
	hit = "movieCamera",
	masterpiece = "trophy",
	index = "star",
	rare = "crown",
	variant = "bolt",
	fame = "stage",
	clap = "clapper",
	script = "script",
	collect = "moneybag",
}

-- Icon for each kind of quest (a "premiere:<genre>" kind is a premiere).
local QUEST_ICONS: { [string]: string } = {
	cast = "dice",
	premiere = "popcorn",
	clap = "clapper",
	script = "script",
	collect = "moneybag",
	hit = "trophy",
}

local function questIcon(kind: string): string
	if string.sub(kind, 1, 9) == "premiere:" then
		return "movieCamera"
	end
	return QUEST_ICONS[kind] or "clapper"
end

-- "2d 5h" while a day or more is left, else "4:12:09".
local function timeLeft(seconds: number): string
	seconds = math.max(0, seconds)
	if seconds >= 86400 then
		return `{seconds // 86400}d {seconds % 86400 // 3600}h`
	end
	return Hud.clock(seconds)
end

type Row = {
	frame: Frame,
	icon: Frame,
	title: TextLabel,
	reward: TextLabel,
	fill: Frame,
	count: TextLabel,
	claim: TextButton,
	waiting: TextLabel,
	done: Frame,
	outline: UIStroke,
	claimId: string?,
	onClaim: (() -> ())?,
}

-- One quest on the Quests tab: which list it is in ("daily" or "weekly") and where.
type QuestRow = { row: Row, scope: string, index: number }

function AchievementsUi.start(gui: ScreenGui, goalsButton: TextButton)
	local player = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 15)
	if remotes == nil then
		warn("[AchievementsUi] Remotes folder never arrived")
		return
	end
	local claimAchievement = remotes:WaitForChild("ClaimAchievement") :: RemoteEvent
	local claimRequest = remotes:WaitForChild("ClaimRequest") :: RemoteEvent
	local rewardsRequest = remotes:WaitForChild("RewardsRequest") :: RemoteEvent
	local achievementsSync = remotes:WaitForChild("AchievementsSync") :: RemoteEvent
	local achievementsRequest = remotes:WaitForChild("AchievementsRequest") :: RemoteEvent

	local panel, list, header = UiKit.makePanel(gui, "AchievementsPanel", "Goals", 108, nil, nil, UiKit.TEAL)
	UiKit.panelIcon(panel, header, "trophy")
	local tabRow = Instance.new("Frame")
	tabRow.Name = "Tabs"
	tabRow.BackgroundTransparency = 1
	tabRow.Position = UDim2.fromOffset(10, 58)
	tabRow.Size = UDim2.new(1, -20, 0, 42)
	tabRow.Parent = panel
	local tabNames = { "Achievements", "Quests" }
	local tabButtons: { [string]: TextButton } = {}
	local tab = "Achievements"

	-- Latest sync: progress (capped at each target) and claimed ids.
	local progress: { [string]: number } = {}
	local claimed: { [string]: boolean } = {}
	local synced = false

	local function rate(): number
		return player:GetAttribute("Rate") or 0
	end

	local function isReady(achievement: Achievements.Achievement): boolean
		return not claimed[achievement.id] and (progress[achievement.id] or 0) >= achievement.target
	end

	local function readyIds(): { [string]: boolean }
		local ready: { [string]: boolean } = {}
		for _, achievement in Achievements.List do
			if isReady(achievement) then
				ready[achievement.id] = true
			end
		end
		return ready
	end

	-- Rows are built once (their 3D icons would show blank for a moment if rebuilt) and then
	-- updated in place on every sync.
	local summary: TextLabel? = nil
	local summaryFill: Frame? = nil
	local summaryCount: TextLabel? = nil
	local rows: { [string]: Row } = {}

	local function bar(parent: Frame, position: UDim2, size: UDim2): (Frame, TextLabel)
		local track = Instance.new("Frame")
		track.BackgroundColor3 = UiKit.DARK
		track.Position = position
		track.Size = size
		track.Parent = parent
		UiKit.corner(track, 8)
		UiKit.border(track, 2)
		local fill = Instance.new("Frame")
		fill.BackgroundColor3 = UiKit.GREEN
		fill.Size = UDim2.fromScale(0, 1)
		fill.Parent = track
		UiKit.corner(fill, 8)
		local count = UiKit.makeTitle(track, "", UiKit.WHITE, UDim2.fromScale(1, 1), nil, 1.5)
		count.ZIndex = 2
		return fill, count
	end

	-- A goal or quest row: picture, text, reward, progress bar, and CLAIM / tick / "In progress".
	local function newRow(order: number, iconName: string): Row
		local frame = UiKit.addRow(list, order, 92)
		local icon = UiKit.rowIcon(frame, iconName, 70)
		local textLeft = 86
		local title = UiKit.makeTitle(frame, "", UiKit.WHITE, UDim2.new(0.66, -textLeft, 0, 28), UDim2.fromOffset(textLeft, 6))
		title.TextXAlignment = Enum.TextXAlignment.Left
		local reward = makeLabel(frame, "", UiKit.GOLD, UDim2.new(0.66, -textLeft, 0, 20), UDim2.fromOffset(textLeft, 36))
		reward.TextXAlignment = Enum.TextXAlignment.Left
		local fill, count = bar(frame, UDim2.fromOffset(textLeft, 64), UDim2.new(0.66, -(textLeft + 4), 0, 16))

		local claim = makeButton(frame, "CLAIM", UiKit.GREEN, UDim2.new(0.3, 0, 0, 48), UDim2.new(0.68, 0, 0.5, -24))
		UiKit.pulse(claim)
		local waiting = makeLabel(frame, "In progress", UiKit.MUTED, UDim2.new(0.3, 0, 0, 40), UDim2.new(0.68, 0, 0.5, -20))
		local done = Instance.new("Frame")
		done.BackgroundTransparency = 1
		done.Position = UDim2.fromScale(0.68, 0.08)
		done.Size = UDim2.fromScale(0.3, 0.84)
		done.Parent = frame
		UiKit.tick(done, 3)

		local row: Row = {
			frame = frame,
			icon = icon,
			title = title,
			reward = reward,
			fill = fill,
			count = count,
			claim = claim,
			waiting = waiting,
			done = done,
			outline = frame:FindFirstChild("Outline") :: UIStroke,
			claimId = nil,
			onClaim = nil,
		}
		claim.Activated:Connect(function()
			if row.onClaim ~= nil then
				row.onClaim()
			end
		end)
		return row
	end

	local achievementFrames: { Frame } = {}

	local function build()
		if summary ~= nil then
			return
		end
		local top = UiKit.addRow(list, 0, 56)
		local label = UiKit.makeTitle(top, "", UiKit.GOLD, UDim2.new(0.5, -12, 0, 30), UDim2.fromOffset(12, 13))
		label.TextXAlignment = Enum.TextXAlignment.Left
		summary = label
		summaryFill, summaryCount = bar(top, UDim2.new(0.5, 0, 0, 18), UDim2.new(0.5, -14, 0, 20))

		for _, group in Achievements.groups() do
			local row = newRow(1, GROUP_ICONS[group.id] or "trophy")
			row.onClaim = function()
				if row.claimId ~= nil then
					claimAchievement:FireServer(row.claimId)
				end
			end
			rows[group.id] = row
			table.insert(achievementFrames, row.frame)
		end
		table.insert(achievementFrames, top)
	end

	local function renderAchievements()
		build()
		local claimedCount = 0
		for _, achievement in Achievements.List do
			if claimed[achievement.id] then
				claimedCount += 1
			end
		end
		local total = #Achievements.List
		if summary ~= nil and summaryFill ~= nil and summaryCount ~= nil then
			summary.Text = if synced then `{claimedCount} of {total} claimed` else "Loading..."
			summaryFill.Size = UDim2.fromScale(claimedCount / total, 1)
			summaryCount.Text = `{claimedCount}/{total}`
		end

		for slot, group in Achievements.groups() do
			local row = rows[group.id]
			-- The group's next goal: the first one not claimed (the last one once all are).
			local current = group.list[#group.list]
			local step = #group.list
			for index, achievement in group.list do
				if not claimed[achievement.id] then
					current, step = achievement, index
					break
				end
			end
			local allDone = claimed[current.id] == true
			local ready = isReady(current)
			local value = progress[current.id] or 0

			row.title.Text = current.text
			local stepText = if #group.list > 1 then `Goal {step} of {#group.list}` else ""
			row.reward.Text = if allDone
				then (if stepText ~= "" then `All {#group.list} done!` else "Done!")
				else (if stepText ~= "" then stepText .. "  ·  " else "") .. "Reward: " .. Rewards.describe(current.reward, rate())
			row.fill.Size = UDim2.fromScale(math.clamp(value / current.target, 0, 1), 1)
			row.count.Text = `{Hud.comma(value)}/{Hud.comma(current.target)}`
			row.claimId = if ready then current.id else nil
			row.claim.Visible = ready
			row.waiting.Visible = not ready and not allDone
			row.done.Visible = allDone
			row.outline.Color = if ready then UiKit.GREEN else UiKit.INK
			row.outline.Thickness = if ready then 3 else 2
			-- Ready to claim first, then goals in progress, then finished groups.
			row.frame.LayoutOrder = (if ready then 0 elseif allDone then 200 else 100) + slot
		end
	end

	-- Quests tab. Rows are built once per set of quests (same reason: pictures) and then updated in
	-- place; a new day or week brings new quests, so the next sync rebuilds them.
	local questRows: { QuestRow } = {}
	local questFrames: { Frame } = {}
	local questKey = ""
	local dailyCountdown: TextLabel? = nil
	local weeklyCountdown: TextLabel? = nil
	local questsReceivedAt = os.clock()
	local questsReady: { [string]: boolean } = {} -- "daily:Cast10" / "weekly:WHit3" ready to claim
	local questsSynced = false

	local function heading(order: number, text: string): TextLabel
		local row = UiKit.addRow(list, order, 44)
		UiKit.plainRow(row)
		local title = UiKit.makeTitle(row, text, UiKit.GOLD, UDim2.new(0.5, -12, 0, 30), UDim2.fromOffset(12, 7))
		title.TextXAlignment = Enum.TextXAlignment.Left
		local countdown = makeLabel(row, "", UiKit.MUTED, UDim2.new(0.5, -12, 0, 24), UDim2.new(0.5, 0, 0, 10))
		countdown.TextXAlignment = Enum.TextXAlignment.Right
		table.insert(questFrames, row)
		return countdown
	end

	local function questList(state: any, scope: string): { any }
		local entries = if scope == "weekly" then state.weekly else state.requests
		return if type(entries) == "table" then entries else {}
	end

	local function buildQuests(state: any)
		local key = ""
		for _, scope in { "daily", "weekly" } do
			for _, entry in questList(state, scope) do
				key ..= `{scope}:{entry.id},`
			end
		end
		if key == questKey then
			return
		end
		questKey = key
		for _, frame in questFrames do
			frame:Destroy()
		end
		table.clear(questFrames)
		table.clear(questRows)
		local order = 1000
		for _, scope in { "daily", "weekly" } do
			order += 1
			local countdown = heading(order, if scope == "weekly" then "Weekly quests" else "Daily quests")
			if scope == "weekly" then
				weeklyCountdown = countdown
			else
				dailyCountdown = countdown
			end
			for index, entry in questList(state, scope) do
				local quest = Rewards.getRequest(entry.id)
				if quest == nil then
					continue
				end
				order += 1
				local row = newRow(order, questIcon(quest.kind))
				row.onClaim = function()
					claimRequest:FireServer(index, scope)
				end
				table.insert(questRows, { row = row, scope = scope, index = index })
				table.insert(questFrames, row.frame)
			end
		end
	end

	-- Seconds left in the day / week, by the server clock as of the last sync.
	local function tickQuestClocks()
		local state = ClientState.rewards
		if state == nil or state.serverNow == nil then
			return
		end
		local now = state.serverNow + (os.clock() - questsReceivedAt)
		if dailyCountdown ~= nil then
			dailyCountdown.Text = "New in " .. timeLeft((state.today + 1) * 86400 - now)
		end
		if weeklyCountdown ~= nil and state.weekEnds ~= nil then
			weeklyCountdown.Text = "New in " .. timeLeft(state.weekEnds - now)
		end
	end

	local function renderQuests()
		local state = ClientState.rewards
		if state == nil then
			return
		end
		buildQuests(state)
		for _, info in questRows do
			local entry = questList(state, info.scope)[info.index]
			local quest = if entry ~= nil then Rewards.getRequest(entry.id) else nil
			if entry == nil or quest == nil then
				continue
			end
			local row = info.row
			local value = math.min(entry.progress, quest.target)
			local finished = value >= quest.target
			local ready = finished and not entry.claimed
			row.title.Text = quest.text
			row.reward.Text = "Reward: " .. Rewards.describe(quest.reward, rate())
			row.fill.Size = UDim2.fromScale(math.clamp(value / quest.target, 0, 1), 1)
			row.count.Text = `{Hud.comma(value)}/{Hud.comma(quest.target)}`
			row.claim.Visible = ready
			row.waiting.Visible = not finished
			row.done.Visible = entry.claimed == true
			-- Weekly quests keep a gold outline: they are the bigger, slower ones.
			row.outline.Color = if ready then UiKit.GREEN elseif info.scope == "weekly" then UiKit.AWARD_GOLD else UiKit.INK
			row.outline.Thickness = if ready then 3 else 2
			row.frame.LayoutOrder = 1000 + (if info.scope == "weekly" then 100 else 0) + info.index + 10
		end
		tickQuestClocks()
	end

	local function readyQuests(state: any): { [string]: boolean }
		local ready: { [string]: boolean } = {}
		for _, scope in { "daily", "weekly" } do
			for _, entry in questList(state, scope) do
				local quest = Rewards.getRequest(entry.id)
				if quest ~= nil and not entry.claimed and entry.progress >= quest.target then
					ready[`{scope}:{entry.id}`] = true
				end
			end
		end
		return ready
	end

	local function updateBadge()
		local count = 0
		for _ in readyIds() do
			count += 1
		end
		for _ in questsReady do
			count += 1
		end
		SideMenu.setBadge(goalsButton, count)
	end

	local function render()
		for name, button in tabButtons do
			UiKit.styleTab(button, name == tab)
		end
		-- Red badges on the tabs with something to claim.
		local achievementCount, questCount = 0, 0
		for _ in readyIds() do
			achievementCount += 1
		end
		for _ in questsReady do
			questCount += 1
		end
		UiKit.badge(tabButtons.Achievements, if achievementCount > 0 then tostring(achievementCount) else nil)
		UiKit.badge(tabButtons.Quests, if questCount > 0 then tostring(questCount) else nil)

		renderAchievements()
		if tab == "Quests" then
			renderQuests()
		end
		for _, frame in achievementFrames do
			frame.Visible = tab == "Achievements"
		end
		for _, frame in questFrames do
			frame.Visible = tab == "Quests"
		end
	end

	local function open()
		achievementsRequest:FireServer() -- fresh progress every time (the server limits this)
		rewardsRequest:FireServer() -- and fresh quests
		if panel.Visible then
			render()
		else
			UiKit.togglePanel(panel, render)
		end
	end

	goalsButton.Activated:Connect(function()
		if panel.Visible then
			panel.Visible = false
		else
			open()
		end
	end)
	Screens.register("Goals", open)

	for slot, name in tabNames do
		local button = makeButton(tabRow, name, UiKit.TAB_OFF, UDim2.new(0.48, 0, 1, 0), UDim2.new((slot - 1) * 0.52, 0, 0, 0))
		tabButtons[name] = button
		button.Activated:Connect(function()
			tab = name
			render()
		end)
	end
	UiKit.evenText({ tabButtons.Achievements, tabButtons.Quests }, 24)
	-- Cash rewards are minutes of income: keep the amounts shown in step with it.
	player:GetAttributeChangedSignal("Rate"):Connect(function()
		if panel.Visible then
			render()
		end
	end)

	achievementsSync.OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" or type(payload.progress) ~= "table" or type(payload.claimed) ~= "table" then
			return
		end
		local before = if synced then readyIds() else nil
		progress = payload.progress
		claimed = payload.claimed
		synced = true
		for id in readyIds() do
			local achievement = Achievements.get(id)
			if before ~= nil and not before[id] and achievement ~= nil then
				UiKit.toast(gui, `Goal reached: {achievement.text}!`)
				Sfx.play("goal")
			end
		end
		updateBadge()
		if panel.Visible then
			render()
		end
	end)

	-- Quest progress arrives as the Rewards sync (the server sends it after every change).
	ClientState.changed:Connect(function(kind)
		local state = ClientState.rewards
		if kind ~= "rewards" or state == nil then
			return
		end
		questsReceivedAt = os.clock()
		local before = questsReady
		questsReady = readyQuests(state)
		for id in questsReady do
			if questsSynced and not before[id] then
				local quest = Rewards.getRequest(string.match(id, ":(.+)$") or "")
				if quest ~= nil then
					UiKit.toast(gui, `Quest done: {quest.text}!`)
					Sfx.play("goal")
				end
			end
		end
		questsSynced = true
		updateBadge()
		if panel.Visible then
			render()
		end
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			if panel.Visible and tab == "Quests" then
				tickQuestClocks()
			end
		end
	end)

	-- First sync once the server has this player's data.
	task.spawn(function()
		while not player:GetAttribute("DataLoaded") do
			player.AttributeChanged:Wait()
		end
		achievementsRequest:FireServer()
	end)
end

return AchievementsUi
