--!strict
-- "Direct the scene" (Takes.luau): while a movie films, a TAKE! card pops up above the Cast button
-- a few times. A marker sweeps across a bar; tap CUT! while it is inside the green zone (gold for a
-- perfect take). The server judges the tap and adds the take's Luck to that film's premiere; this
-- screen only draws the sweep and shows the verdict.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Takes = require(ReplicatedStorage.Shared.Takes)
local ClientState = require(script.Parent.ClientState)
local Sfx = require(script.Parent.Sfx)
local UiKit = require(script.Parent.UiKit)

local WHITE = UiKit.WHITE
local CARD_W, CARD_H = 320, 124
-- The Cast bar (CastingUi) is 88 tall, 14 above the bottom (130 on portrait touch screens).
local CAST_BAR_H, CAST_GAP, TOUCH_PORTRAIT_LIFT = 88, 14, 130
local VERDICT_SECONDS = 1.3 -- the verdict stays up this long before the card leaves
local NEXT_DELAY = 1.5 -- a breath before the next waiting take pops up
-- The client judges with a safety margin, so it never asks for a take before the server's whole-second
-- clock agrees one has opened.
local CLOCK_MARGIN = 1

local VERDICT_COLORS: { [string]: Color3 } = {
	Perfect = UiKit.GOLD,
	Good = UiKit.CASH_GREEN,
	Miss = UiKit.WARN,
}

local TakeUi = {}

function TakeUi.start(gui: ScreenGui, remotes: Instance)
	local takeStart = remotes:WaitForChild("TakeStart") :: RemoteEvent
	local takeTap = remotes:WaitForChild("TakeTap") :: RemoteEvent
	local takeResult = remotes:WaitForChild("TakeResult") :: RemoteEvent

	-- Card ------------------------------------------------------------------------------------
	local card = Instance.new("Frame")
	card.Name = "TakeCard"
	card.AnchorPoint = Vector2.new(0.5, 1)
	card.Size = UDim2.fromOffset(CARD_W, CARD_H)
	card.BackgroundColor3 = UiKit.NAVY
	card.Visible = false
	card.Active = true
	card.ZIndex = 9 -- above panels, below the casting and premiere reveals
	card.Parent = gui
	UiKit.corner(card, 14)
	UiKit.border(card, 3)
	local cardScale = Instance.new("UIScale")
	cardScale.Parent = card
	local popScale = Instance.new("UIScale")
	popScale.Name = "Pop"
	popScale.Parent = card

	UiKit.onViewportChanged(function()
		local viewport = UiKit.viewport()
		local compact = UiKit.isCompact()
		cardScale.Scale = if compact then 0.82 else 1
		local castScale = if compact then 0.82 else 1
		local bottom = if UserInputService.TouchEnabled and viewport.X < viewport.Y then TOUCH_PORTRAIT_LIFT else CAST_GAP
		card.Position = UDim2.new(0.5, 0, 1, -(bottom + CAST_BAR_H * castScale + 10))
	end)

	local title = UiKit.makeTitle(card, "TAKE 1!", UiKit.GOLD, UDim2.new(0.5, -12, 0, 26), UDim2.fromOffset(12, 6))
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = 10
	UiKit.textConstraint(title, 24)
	local subtitle = UiKit.makeLabel(card, "", UiKit.MUTED, UDim2.new(0.5, -12, 0, 22), UDim2.new(0.5, 0, 0, 8))
	subtitle.TextXAlignment = Enum.TextXAlignment.Right
	subtitle.ZIndex = 10
	UiKit.textConstraint(subtitle, 16)

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.BackgroundColor3 = UiKit.DARK
	bar.Position = UDim2.fromOffset(12, 38)
	bar.Size = UDim2.new(1, -24, 0, 28)
	bar.ClipsDescendants = true
	bar.ZIndex = 10
	bar.Parent = card
	UiKit.corner(bar, 8)
	UiKit.border(bar, 2)

	local function zone(halfWidth: number, color: Color3, z: number): Frame
		local frame = Instance.new("Frame")
		frame.AnchorPoint = Vector2.new(0.5, 0)
		frame.Size = UDim2.fromScale(halfWidth * 2, 1)
		frame.BackgroundColor3 = color
		frame.BorderSizePixel = 0
		frame.ZIndex = z
		frame.Parent = bar
		return frame
	end
	local goodZone = zone(Takes.GoodHalfWidth, UiKit.GREEN, 11)
	local perfectZone = zone(Takes.PerfectHalfWidth, UiKit.GOLD, 12)

	local marker = Instance.new("Frame")
	marker.Name = "Marker"
	marker.AnchorPoint = Vector2.new(0.5, 0.5)
	marker.Size = UDim2.new(0, 8, 1, 10)
	marker.BackgroundColor3 = WHITE
	marker.ZIndex = 13
	marker.Parent = bar
	UiKit.corner(marker, 4)
	UiKit.border(marker, 2)

	local cut = UiKit.makeButton(card, "CUT!", UiKit.RED, UDim2.new(1, -24, 0, 42), UDim2.fromOffset(12, 74))
	cut.Name = "CutButton"
	cut.ZIndex = 10
	cut:SetAttribute("Silent", true)
	UiKit.textConstraint(cut, 28)

	-- The verdict, stamped over the card.
	local verdictLabel = UiKit.makeTitle(card, "", WHITE, UDim2.new(1, -24, 0, 46), UDim2.fromOffset(12, 72), 3)
	verdictLabel.ZIndex = 15
	verdictLabel.Visible = false
	UiKit.textConstraint(verdictLabel, 34)

	-- State -----------------------------------------------------------------------------------
	-- "idle": no card. "sweep": the marker runs and CUT! is live. "verdict": showing the result.
	local mode = "idle"
	local current: { stage: number, index: number, startTime: number, target: number }? = nil
	local startedAt = 0
	local localVerdict: string? = nil
	local idleUntil = 0
	local token = 0

	local function placeZones(target: number)
		goodZone.Position = UDim2.fromScale(target, 0)
		perfectZone.Position = UDim2.fromScale(target, 0)
	end

	local function hide()
		token += 1
		mode = "idle"
		current = nil
		card.Visible = false
		idleUntil = os.clock() + NEXT_DELAY
	end

	local function showVerdict(verdict: string)
		verdictLabel.Text = Takes.verdictText(verdict)
		verdictLabel.TextColor3 = VERDICT_COLORS[verdict] or WHITE
		verdictLabel.Visible = true
	end

	local function beginSweep()
		local take = current
		if take == nil then
			return
		end
		startedAt = os.clock()
		takeStart:FireServer(take.stage)
	end

	-- The first stage (or only `onStage`) with a take waiting, judged by the last studio sync.
	local function findWaiting(onStage: number?): { stage: number, index: number, startTime: number, target: number }?
		local studio = ClientState.studio
		if studio == nil or not studio.tutorialDone or type(studio.films) ~= "table" then
			return nil
		end
		local now = ClientState.serverNow() - CLOCK_MARGIN
		local best = nil
		for _, film in studio.films do
			if type(film.stage) == "number" and (onStage == nil or film.stage == onStage)
				and Takes.waiting(film.takes, film.startTime, film.endTime, now) > 0 then
				if best == nil or film.stage < best.stage then
					best = film
				end
			end
		end
		if best == nil then
			return nil
		end
		local index = Takes.count(best.takes) + 1
		return { stage = best.stage, index = index, startTime = best.startTime, target = Takes.target(best.startTime, best.stage, index) }
	end

	local function show(take: { stage: number, index: number, startTime: number, target: number })
		token += 1
		current = take
		mode = "sweep"
		localVerdict = nil
		title.Text = `TAKE {take.index}!`
		local film = nil
		for _, f in ClientState.studio.films do
			if f.stage == take.stage then
				film = f
			end
		end
		subtitle.Text = if film ~= nil and type(film.title) == "string" then `{film.title}  -  Stage {take.stage}` else `Stage {take.stage}`
		placeZones(take.target)
		verdictLabel.Visible = false
		cut.Visible = true
		card.Visible = true
		popScale.Scale = 0.6
		TweenService:Create(popScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		Sfx.play("takePop")
		beginSweep()
	end

	cut.Activated:Connect(function()
		local take = current
		if mode ~= "sweep" or take == nil then
			return
		end
		local elapsed = os.clock() - startedAt
		local verdict = Takes.judge(elapsed, take.target, take.index)
		mode = "verdict"
		localVerdict = verdict
		takeTap:FireServer(take.stage, elapsed)
		cut.Visible = false
		showVerdict(verdict)
		Sfx.play(if verdict == "Perfect" then "takePerfect" elseif verdict == "Good" then "takeGood" else "takeMiss")
		popScale.Scale = 1.12
		TweenService:Create(popScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		local mine = token
		task.delay(VERDICT_SECONDS, function()
			if token == mine then
				hide()
			end
		end)
	end)

	-- The server's verdict is the real one; it only differs from ours after a lag spike.
	takeResult.OnClientEvent:Connect(function(stage, verdict)
		local take = current
		if take == nil or take.stage ~= stage then
			return
		end
		if verdict == "none" then
			-- The server had no sweep for this (the film wrapped, or a sync raced). The card comes
			-- back by itself if the take is still waiting.
			hide()
			return
		end
		if type(verdict) == "string" and mode == "verdict" and verdict ~= localVerdict then
			showVerdict(verdict)
		end
	end)

	-- Marker: moves every frame, but only while the card is up.
	RunService.RenderStepped:Connect(function()
		local take = current
		if mode ~= "sweep" or take == nil then
			return
		end
		marker.Position = UDim2.fromScale(Takes.marker(os.clock() - startedAt, take.index), 0.5)
	end)

	-- Watcher: pops the card when a take opens, drops it when its film wraps or premieres, and
	-- restarts a sweep left alone so long the server would have dropped it.
	task.spawn(function()
		while true do
			task.wait(0.25)
			if mode == "idle" then
				if os.clock() >= idleUntil then
					local take = findWaiting()
					if take ~= nil then
						show(take)
					end
				end
			elseif mode == "sweep" then
				local take = current
				local still = if take ~= nil then findWaiting(take.stage) else nil
				if take == nil or still == nil or still.index ~= take.index or still.startTime ~= take.startTime then
					hide() -- wrapped, premiered or skipped: nothing left to cut
				elseif os.clock() - startedAt > Takes.MaxOpenSeconds - 10 then
					beginSweep()
				end
			end
		end
	end)
end

return TakeUi
