--!strict
-- Goals screen (achievements): one row per group showing its next goal, a progress bar and the
-- reward, with CLAIM when it is done. The side menu's Goals button carries a red badge with the
-- number ready to claim, and reaching a goal says so at the bottom of the screen. Claims go to
-- AchievementService, which checks them; its answer arrives on RewardResult (shown by RewardsUi).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Achievements = require(ReplicatedStorage.Shared.Achievements)
local Rewards = require(ReplicatedStorage.Shared.Rewards)
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
}

function AchievementsUi.start(gui: ScreenGui, goalsButton: TextButton)
	local player = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 15)
	if remotes == nil then
		warn("[AchievementsUi] Remotes folder never arrived")
		return
	end
	local claimAchievement = remotes:WaitForChild("ClaimAchievement") :: RemoteEvent
	local achievementsSync = remotes:WaitForChild("AchievementsSync") :: RemoteEvent
	local achievementsRequest = remotes:WaitForChild("AchievementsRequest") :: RemoteEvent

	local panel, list, header = UiKit.makePanel(gui, "AchievementsPanel", "Achievements", nil, nil, nil, UiKit.TEAL)
	UiKit.panelIcon(panel, header, "trophy")

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
			local frame = UiKit.addRow(list, 1, 92)
			local icon = UiKit.rowIcon(frame, GROUP_ICONS[group.id] or "trophy", 70)
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
			}
			claim.Activated:Connect(function()
				if row.claimId ~= nil then
					claimAchievement:FireServer(row.claimId)
				end
			end)
			rows[group.id] = row
		end
	end

	local function render()
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

	local function open()
		achievementsRequest:FireServer() -- fresh progress every time (the server limits this)
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
		local ready = readyIds()
		local count = 0
		for id in ready do
			count += 1
			local achievement = Achievements.get(id)
			if before ~= nil and not before[id] and achievement ~= nil then
				UiKit.toast(gui, `Goal reached: {achievement.text}!`)
				Sfx.play("goal")
			end
		end
		SideMenu.setBadge(goalsButton, count)
		if panel.Visible then
			render()
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
