--!strict
-- Goals screen, two tabs. Achievements: one row per group showing its next goal, a progress bar and
-- the reward, with CLAIM when it is done. Quests: today's three Studio Requests and this week's three
-- weekly quests, with a countdown to each reset (the same lists the Rewards screen's Requests tab
-- shows; the server's QuestTracker keeps them), and above them any quest finished before its day or
-- week ended and not claimed yet ("Finished earlier"): a reset never takes a reward that was earned.
-- This week's Film Festival (SpecialEvents.festival) comes first on the Quests tab: its three goals
-- and the prize row, the Festival Laurel that finishing all three puts on the lot.
-- The side menu's Goals button carries a red badge with the number ready to claim across both tabs, and reaching a goal or finishing a quest says so
-- at the bottom of the screen. Achievement claims go to AchievementService, quest claims to
-- RewardService; both check them, and answer on RewardResult (shown by RewardsUi).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Achievements = require(ReplicatedStorage.Shared.Achievements)
local Rewards = require(ReplicatedStorage.Shared.Rewards)
local SpecialEvents = require(ReplicatedStorage.Shared.SpecialEvents)
local Config = require(ReplicatedStorage.Shared.Config)
local Events = require(ReplicatedStorage.Shared.Events)
local ClientState = require(script.Parent.ClientState)
local Hud = require(script.Parent.Hud)
local Screens = require(script.Parent.Screens)
local SideMenu = require(script.Parent.SideMenu)
local Sfx = require(script.Parent.Sfx)
local SpecialEventsUi = require(script.Parent.SpecialEventsUi)
local UiKit = require(script.Parent.UiKit)

local makeLabel, makeButton = UiKit.makeLabel, UiKit.makeButton

local AchievementsUi = {}

local GROUP_ICONS: { [string]: string } = {
	start = "star",
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
	elseif string.sub(kind, 1, 4) == "hit:" then
		return "trophy"
	elseif kind == "request" then
		return "script"
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

-- One quest on the Quests tab: which list it is in ("carried", "festival", "daily" or "weekly") and where. A
-- carried quest (finished before its day or week ended, still unclaimed) is named by its `key`.
type QuestRow = { row: Row, scope: string, index: number, key: string? }

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
	local function newRow(target: ScrollingFrame, order: number, iconName: string): Row
		local frame = UiKit.addRow(target, order, 92)
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

	-- A goal row: CLAIM claims the goal it shows (fillGoalRow sets which).
	local function goalRow(target: ScrollingFrame, order: number, groupId: string): Row
		local row = newRow(target, order, GROUP_ICONS[groupId] or "trophy")
		row.onClaim = function()
			if row.claimId ~= nil then
				claimAchievement:FireServer(row.claimId)
			end
		end
		return row
	end

	-- A group's next goal: the first one not claimed (the last one once all are), and its step.
	local function nextGoal(group: { list: { Achievements.Achievement } }): (Achievements.Achievement, number)
		for index, achievement in group.list do
			if not claimed[achievement.id] then
				return achievement, index
			end
		end
		return group.list[#group.list], #group.list
	end

	-- Shows `group`'s next goal on `row`. Returns (ready to claim, whole group claimed).
	local function fillGoalRow(row: Row, group: { list: { Achievements.Achievement } }): (boolean, boolean)
		local current, step = nextGoal(group)
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
		return ready, allDone
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
			local row = goalRow(list, 1, group.id)
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
			local ready, allDone = fillGoalRow(row, group)
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
	local festivalCountdown: TextLabel? = nil
	local boardDailyCountdown: TextLabel? = nil -- the same two on the Quests board
	local boardWeeklyCountdown: TextLabel? = nil
	local prizeRow: Row? = nil -- the festival's prize: the Festival Laurel
	local questsReceivedAt = os.clock()
	local questsReady: { [string]: boolean } = {} -- "daily:Cast10" / "weekly:WHit3" ready to claim
	local questsSynced = false

	local function heading(target: ScrollingFrame, order: number, text: string, colors: { Color3 }?): (TextLabel, Frame)
		local row = UiKit.addRow(target, order, 44)
		UiKit.plainRow(row)
		local title = UiKit.makeTitle(row, text, UiKit.GOLD, UDim2.new(0.5, -12, 0, 30), UDim2.fromOffset(12, 7))
		title.TextXAlignment = Enum.TextXAlignment.Left
		if colors ~= nil and #colors >= 2 then
			-- The festival's own colors, like its banner.
			title.TextColor3 = UiKit.WHITE
			local gradient = Instance.new("UIGradient")
			gradient.Rotation = 90
			gradient.Color = ColorSequence.new(colors[1], colors[#colors])
			gradient.Parent = title
		end
		local countdown = makeLabel(row, "", UiKit.MUTED, UDim2.new(0.5, -12, 0, 24), UDim2.new(0.5, 0, 0, 10))
		countdown.TextXAlignment = Enum.TextXAlignment.Right
		return countdown, row
	end

	local function questList(state: any, scope: string): { any }
		local entries = if scope == "weekly"
			then state.weekly
			elseif scope == "carried" then state.carried
			elseif scope == "festival" then state.festival
			else state.requests
		return if type(entries) == "table" then entries else {}
	end

	-- This week's festival, when the server says one is on.
	local function festivalOf(state: any): SpecialEvents.Festival?
		return if type(state.festivalWeek) == "number" then SpecialEvents.festival(state.festivalWeek) else nil
	end

	local questScopes: { string } = { "carried", "festival", "daily", "weekly" }

	-- Where each list sits on the tab: its heading at the section's number, its rows just after.
	local function sectionOf(scope: string): number
		return 1000 + (if scope == "carried" then 0 elseif scope == "festival" then 50 elseif scope == "daily" then 100 else 200)
	end

	local function buildQuests(state: any)
		local key = ""
		for _, scope in questScopes do
			for _, entry in questList(state, scope) do
				key ..= `{scope}:{entry.key or entry.id},`
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
		dailyCountdown, weeklyCountdown, festivalCountdown, prizeRow = nil, nil, nil, nil
		local festival = festivalOf(state)
		local order = 1000
		for _, scope in questScopes do
			if (scope == "carried" or scope == "festival") and #questList(state, scope) == 0 then
				continue
			end
			if scope == "festival" and festival == nil then
				continue
			end
			order += 1
			local title = if scope == "weekly"
				then "Weekly quests"
				elseif scope == "carried" then "Finished earlier"
				elseif scope == "festival" and festival ~= nil then festival.name
				else "Daily quests"
			local countdown, headingRow = heading(list, sectionOf(scope), title, if scope == "festival" and festival ~= nil then festival.colors else nil)
			table.insert(questFrames, headingRow)
			if scope == "weekly" then
				weeklyCountdown = countdown
			elseif scope == "festival" then
				festivalCountdown = countdown
			elseif scope == "daily" then
				dailyCountdown = countdown
			else
				countdown.Text = "Still yours to claim"
			end
			for index, entry in questList(state, scope) do
				local quest = Rewards.getRequest(entry.id)
				if quest == nil then
					continue
				end
				order += 1
				local row = newRow(list, order, questIcon(quest.kind))
				local waiting: string? = if scope == "carried" then entry.key else nil
				row.onClaim = function()
					claimRequest:FireServer(waiting or index, scope)
				end
				local scopeName: string = scope
				table.insert(questRows, { row = row, scope = scopeName, index = index, key = waiting })
				table.insert(questFrames, row.frame)
			end
			if scope == "festival" then
				-- The prize: nothing to claim, it goes up on the lot by itself.
				order += 1
				local prize = newRow(list, order, "trophy")
				prize.claim.Visible = false
				prize.title.Text = "Prize: a Festival Laurel"
				table.insert(questFrames, prize.frame)
				prizeRow = prize
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
		for _, label in { dailyCountdown, boardDailyCountdown } do
			if label ~= nil then
				label.Text = "New in " .. timeLeft((state.today + 1) * 86400 - now)
			end
		end
		for _, label in { weeklyCountdown, boardWeeklyCountdown } do
			if label ~= nil and state.weekEnds ~= nil then
				label.Text = "New in " .. timeLeft(state.weekEnds - now)
			end
		end
		if festivalCountdown ~= nil and state.weekEnds ~= nil then
			festivalCountdown.Text = "Ends in " .. timeLeft(state.weekEnds - now)
		end
	end

	-- Shows a quest's progress on its row. False when the quest is no longer in the sync.
	local function fillQuestRow(info: QuestRow, state: any): boolean
		local entry = questList(state, info.scope)[info.index]
		local quest = if entry ~= nil then Rewards.getRequest(entry.id) else nil
		if entry == nil or quest == nil then
			return false
		end
		local row = info.row
		-- A carried quest was finished when its day or week ended: it only waits for CLAIM.
		local value = if info.scope == "carried" then quest.target else math.min(entry.progress, quest.target)
		local finished = value >= quest.target
		local ready = finished and not entry.claimed
		row.title.Text = quest.text
		row.reward.Text = "Reward: " .. Rewards.describe(quest.reward, rate())
		row.fill.Size = UDim2.fromScale(math.clamp(value / quest.target, 0, 1), 1)
		row.count.Text = `{Hud.comma(value)}/{Hud.comma(quest.target)}`
		row.claim.Visible = ready
		row.waiting.Visible = not finished
		row.done.Visible = entry.claimed == true
		-- Weekly quests and festival goals keep a gold outline: they are the bigger, slower ones.
		row.outline.Color = if ready then UiKit.GREEN elseif info.scope == "weekly" or info.scope == "festival" then UiKit.AWARD_GOLD else UiKit.INK
		row.outline.Thickness = if ready then 3 else 2
		return true
	end

	local function renderQuests()
		local state = ClientState.rewards
		if state == nil then
			return
		end
		buildQuests(state)
		for _, info in questRows do
			if fillQuestRow(info, state) then
				info.row.frame.LayoutOrder = sectionOf(info.scope) + info.index + 10
			end
		end
		local prize = prizeRow
		if prize ~= nil then
			local goals = questList(state, "festival")
			local done = 0
			for _, entry in goals do
				local goal = Rewards.getRequest(entry.id)
				if goal ~= nil and entry.progress >= goal.target then
					done += 1
				end
			end
			local won = state.festivalWon == true
			prize.reward.Text = if won then "Won! It stands on your lot" else `Finish all {#goals} goals to put it on your lot`
			prize.fill.Size = UDim2.fromScale(if #goals > 0 then done / #goals else 0, 1)
			prize.count.Text = `{done}/{#goals}`
			prize.waiting.Visible = not won
			prize.waiting.Text = "Keep going!"
			prize.done.Visible = won
			prize.outline.Color = UiKit.AWARD_GOLD
			prize.outline.Thickness = if won then 3 else 2
			prize.frame.LayoutOrder = sectionOf("festival") + #goals + 11
		end
		tickQuestClocks()
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
		gui:SetAttribute("ClaimReady", count) -- the HUD pull tab's dot
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

	-- Quests board -------------------------------------------------------------------------------
	-- Everything the HUD stack sums up, in one big window (tap any HUD card): the next goal, today's
	-- and this week's quests, Award Night and any special event, and the box office. Goal and quest
	-- rows are the Goals screen's own rows and claim the same way.
	local board, boardList, boardHeader = UiKit.makePanel(gui, "QuestBoardPanel", "Quests", nil, nil, nil, UiKit.PURPLE)
	UiKit.panelIcon(board, boardHeader, "trophy")

	local _, nextHeading = heading(boardList, 1, "Next up")
	local allGoals = makeButton(nextHeading, "ALL GOALS", UiKit.TEAL, UDim2.new(0.36, 0, 0, 34), UDim2.new(0.64, -8, 0, 5))
	UiKit.textConstraint(allGoals, 20)
	allGoals.Activated:Connect(function()
		Screens.open("Goals")
	end)
	local boardGoal: Row? = nil
	local boardGoalGroup = ""

	-- The starter chain while it lasts; after it a goal ready to claim, else the one closest to done.
	local function featuredGroup(): { id: string, list: { Achievements.Achievement } }
		local groups = Achievements.groups()
		local best, bestShare = groups[1], -1
		for _, group in groups do
			local current = nextGoal(group)
			if claimed[current.id] then
				continue
			end
			if group.id == "start" or isReady(current) then
				return group
			end
			local share = (progress[current.id] or 0) / current.target
			if share > bestShare then
				best, bestShare = group, share
			end
		end
		return best
	end

	boardDailyCountdown = heading(boardList, 10, "Daily quests")
	boardWeeklyCountdown = heading(boardList, 20, "Weekly quests")
	local boardQuests: { QuestRow } = {}
	local boardQuestKey = ""
	local function buildBoardQuests(state: any)
		local key = ""
		for _, scope in { "daily", "weekly" } do
			for _, entry in questList(state, scope) do
				key ..= `{scope}:{entry.id},`
			end
		end
		if key == boardQuestKey then
			return
		end
		boardQuestKey = key
		for _, info in boardQuests do
			info.row.frame:Destroy()
		end
		table.clear(boardQuests)
		for slot, scope in { "daily", "weekly" } do
			for index, entry in questList(state, scope) do
				local quest = Rewards.getRequest(entry.id)
				if quest ~= nil then
					local row = newRow(boardList, slot * 10 + index, questIcon(quest.kind))
					row.onClaim = function()
						claimRequest:FireServer(index, scope)
					end
					table.insert(boardQuests, { row = row, scope = scope, index = index })
				end
			end
		end
	end

	-- Rows that only show something: no CLAIM, a status where "In progress" goes.
	local function infoRow(order: number, icon: string): Row
		local row = newRow(boardList, order, icon)
		row.claim.Visible = false
		row.done.Visible = false
		row.outline.Color = UiKit.AWARD_GOLD
		return row
	end
	local function show(row: Row, title: string, line: string, share: number, count: string, status: string)
		row.title.Text = title
		row.reward.Text = line
		row.fill.Size = UDim2.fromScale(math.clamp(share, 0, 1), 1)
		row.count.Text = count
		row.waiting.Text = status
	end

	heading(boardList, 30, "Events")
	local awardRow = infoRow(31, "trophy")
	local luckyRow = infoRow(32, "clover")
	local specialRow: Row? = nil
	local specialKey = ""

	heading(boardList, 40, "Box office")
	local cinemaRow = infoRow(41, "ticket")
	local filmRows: { Row } = {}
	local filmKey = ""
	local noFilm = UiKit.addRow(boardList, 42, 44)
	UiKit.plainRow(noFilm)
	local noFilmText = makeLabel(noFilm, "No film shooting: start one at a sound stage!", UiKit.MUTED, UDim2.new(1, -24, 0, 24), UDim2.fromOffset(12, 10))
	noFilmText.TextXAlignment = Enum.TextXAlignment.Left

	local function renderBoard()
		local ready = gui:GetAttribute("ClaimReady")
		UiKit.badge(allGoals, if typeof(ready) == "number" and ready > 0 then tostring(ready) else nil)

		local group = featuredGroup()
		local goal = boardGoal
		if goal == nil or group.id ~= boardGoalGroup then
			if goal ~= nil then
				goal.frame:Destroy()
			end
			goal = goalRow(boardList, 2, group.id)
			boardGoal, boardGoalGroup = goal, group.id
		end
		fillGoalRow(goal, group)

		local state = ClientState.rewards
		if state ~= nil then
			buildBoardQuests(state)
			for _, info in boardQuests do
				fillQuestRow(info, state)
			end
			tickQuestClocks()
		end

		local now = workspace:GetServerTimeNow()
		local active, left = Events.awardNight(now)
		show(
			awardRow,
			if active then "AWARD NIGHT LIVE!" else "Award Night",
			`x{Config.AwardNightLuckMultiplier} casting Luck, x{Config.AwardNightPayoutMultiplier} premiere payouts`,
			if active then left / Events.AwardNightLength else 1 - left / (Events.AwardNightPeriod - Events.AwardNightLength),
			Hud.clock(left),
			if active then "LIVE NOW" else "Coming up"
		)
		awardRow.waiting.TextColor3 = if active then UiKit.GOLD else UiKit.MUTED
		local boostLeft = (player:GetAttribute("LuckBoostUntil") or 0) - now
		luckyRow.frame.Visible = boostLeft > 0
		show(luckyRow, "Lucky Casting", `x{Config.BoostLuckMultiplier} casting Luck from a boost`, 1, Hud.clock(boostLeft), "Active")

		-- A special event while one runs, else the countdown to the next one.
		local live = SpecialEventsUi.readLive()
		local upcoming = ReplicatedStorage:GetAttribute("SpecialEventNext")
		local key = if live ~= nil and live.ends > now then live.event.id elseif typeof(upcoming) == "number" and upcoming > now then "next" else ""
		if key ~= specialKey then
			specialKey = key
			if specialRow ~= nil then
				specialRow.frame:Destroy()
				specialRow = nil
			end
			if key ~= "" then
				specialRow = infoRow(33, if live ~= nil and key ~= "next" then live.event.icon else "gift")
			end
		end
		local special = specialRow
		if special ~= nil then
			if live ~= nil and key ~= "next" then
				show(special, live.event.name, live.event.tagline, (live.ends - now) / math.max(1, live.ends - live.starts), Hud.clock(live.ends - now), "LIVE NOW")
				special.waiting.TextColor3 = UiKit.GOLD
			elseif typeof(upcoming) == "number" then
				show(special, "Special event", "A surprise for everyone in this server", 0, Hud.clock(upcoming - now), "Coming up")
			end
		end

		local pending, _, share, full = Hud.boxOffice()
		local studio = ClientState.studio
		local showing = if studio ~= nil and type(studio.cinema) == "table" then #studio.cinema else 0
		if player:GetAttribute("LotIndex") == nil then
			show(cinemaRow, "Claim a lot", "Step on a green pad to start your studio", 0, "", "")
		else
			local royalties = `Royalties ${string.format("%.2f", player:GetAttribute("Rate") or 0)}/s from {showing} {if showing == 1 then "movie" else "movies"}`
			show(cinemaRow, `${Hud.comma(pending)} waiting`, royalties, share, if full then "FULL!" else `{math.floor(share * 100)}%`, if full then "Collect it!" else "Gold pad")
		end
		cinemaRow.fill.BackgroundColor3 = if full then UiKit.CLOSE_RED elseif share >= 0.8 then UiKit.AWARD_GOLD else UiKit.GREEN
		cinemaRow.waiting.TextColor3 = if full then UiKit.WARN else UiKit.MUTED

		-- The films shooting now, one row each (rebuilt when a film starts or premieres).
		local films = if studio ~= nil and type(studio.films) == "table" then studio.films else {}
		local fkey = ""
		for _, film in films do
			fkey ..= `{film.stage}:{film.startTime},`
		end
		if fkey ~= filmKey then
			filmKey = fkey
			for _, row in filmRows do
				row.frame:Destroy()
			end
			table.clear(filmRows)
			for index in films do
				table.insert(filmRows, infoRow(42 + index, "movieCamera"))
			end
		end
		noFilm.Visible = #films == 0
		local serverNow = ClientState.serverNow()
		for index, film in films do
			local row = filmRows[index]
			local remaining = film.endTime - serverNow
			local total = math.max(1, film.endTime - film.startTime)
			show(row, film.title, `Stage {film.stage}  ·  {film.genre}`, 1 - remaining / total, if remaining > 0 then Hud.clock(remaining) else "Done!", if remaining > 0 then "Filming" else "Premiere it!")
			row.waiting.TextColor3 = if remaining > 0 then UiKit.MUTED else UiKit.GOLD
		end
	end

	local function openBoard()
		achievementsRequest:FireServer() -- fresh progress, as the Goals screen does
		rewardsRequest:FireServer()
		if board.Visible then
			renderBoard()
		else
			UiKit.togglePanel(board, renderBoard)
		end
	end
	Screens.register("Quests", openBoard)

	-- "Next up" strip on the HUD: the first unclaimed goal of the "start" group (the first-ten-minutes
	-- chain). It sits under the box office bar, inside the HUD stack (so it scales and tucks away with
	-- it), hides while the tutorial is up, and disappears once the whole chain is claimed. Tapping it
	-- opens the Quests board; CLAIM claims right there.
	local stripGoals: { Achievements.Achievement } = {}
	for _, group in Achievements.groups() do
		if group.id == "start" then
			stripGoals = group.list
		end
	end
	local strip = Instance.new("TextButton")
	strip.Name = "NextUp"
	strip.Text = ""
	strip.AutoButtonColor = false
	strip.BackgroundColor3 = UiKit.NAVY
	strip.Size = UDim2.fromOffset(300, 50)
	strip.Visible = false
	strip.Parent = gui:FindFirstChild("Hud") or gui
	UiKit.corner(strip, 14)
	local stripOutline = UiKit.border(strip, 3)
	local stripTag = UiKit.makeTitle(strip, "NEXT UP", UiKit.GOLD, UDim2.fromOffset(70, 16), UDim2.fromOffset(10, 4), 1.5)
	stripTag.TextXAlignment = Enum.TextXAlignment.Left
	local stripTitle = UiKit.makeTitle(strip, "", UiKit.WHITE, UDim2.new(1, -118, 0, 22), UDim2.fromOffset(10, 20), 2)
	stripTitle.TextXAlignment = Enum.TextXAlignment.Left
	UiKit.textConstraint(stripTitle, 18)
	local stripTrack = Instance.new("Frame")
	stripTrack.BackgroundColor3 = UiKit.DARK
	stripTrack.Position = UDim2.fromOffset(86, 4)
	stripTrack.Size = UDim2.new(1, -184, 0, 12)
	stripTrack.Parent = strip
	UiKit.corner(stripTrack, 6)
	UiKit.border(stripTrack, 2)
	local stripFill = Instance.new("Frame")
	stripFill.BackgroundColor3 = UiKit.GREEN
	stripFill.Size = UDim2.fromScale(0, 1)
	stripFill.Parent = stripTrack
	UiKit.corner(stripFill, 6)
	local stripCount = UiKit.makeTitle(strip, "", UiKit.WHITE, UDim2.fromOffset(86, 16), UDim2.new(1, -96, 0, 2), 1.5)
	stripCount.TextXAlignment = Enum.TextXAlignment.Right
	UiKit.textConstraint(stripCount, 14)
	local stripClaim = makeButton(strip, "CLAIM", UiKit.GREEN, UDim2.fromOffset(92, 36), UDim2.new(1, -100, 0.5, -18))
	UiKit.pulse(stripClaim)
	local stripClaimId: string? = nil

	-- Lined up with the box office card (Hud): centred, or on the right on touch screens.
	local function placeStrip()
		local right = gui:GetAttribute("HudRight") == true
		strip.AnchorPoint = Vector2.new(if right then 1 else 0.5, 0)
		strip.Position = if right then UDim2.new(1, -4, 0, 112) else UDim2.new(0.5, 0, 0, 112)
	end

	local function updateStrip()
		local current: Achievements.Achievement? = nil
		for _, achievement in stripGoals do
			if not claimed[achievement.id] then
				current = achievement
				break
			end
		end
		-- Hidden until the first sync, while the Director tutorial runs (it sets "PanelTop"), and
		-- once every goal in the chain is claimed.
		if current == nil or not synced or gui:GetAttribute("PanelTop") ~= nil then
			strip.Visible = false
			stripClaimId = nil
			return
		end
		local value = progress[current.id] or 0
		local ready = isReady(current)
		stripClaimId = if ready then current.id else nil
		stripTitle.Text = current.text
		stripFill.Size = UDim2.fromScale(math.clamp(value / current.target, 0, 1), 1)
		stripCount.Text = `{Hud.comma(value)}/{Hud.comma(current.target)}`
		stripClaim.Visible = ready
		stripCount.Visible = not ready
		stripOutline.Color = if ready then UiKit.GREEN else UiKit.INK
		strip.Visible = true
	end

	stripClaim.Activated:Connect(function()
		if stripClaimId ~= nil then
			claimAchievement:FireServer(stripClaimId)
		end
	end)
	strip.Activated:Connect(function()
		if stripClaimId == nil then
			openBoard()
		end
	end)
	for _, attribute in { "HudRight", "PanelTop" } do
		gui:GetAttributeChangedSignal(attribute):Connect(function()
			placeStrip()
			updateStrip()
		end)
	end
	placeStrip()

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
		updateStrip()
		if panel.Visible then
			render()
		end
		if board.Visible then
			renderBoard()
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
		questsReady = Rewards.readyQuests(state)
		for id in questsReady do
			-- A carried quest was announced when it finished; it only moves here at a reset.
			if questsSynced and not before[id] and string.sub(id, 1, 8) ~= "carried:" then
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
		if board.Visible then
			renderBoard()
		end
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			if panel.Visible and tab == "Quests" then
				tickQuestClocks()
			end
			if board.Visible then
				renderBoard() -- its timers, and the studio's films and box office
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
