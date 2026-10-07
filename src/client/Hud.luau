--!strict
-- Cash HUD: big outlined gold Cash with the box office line under it. Reads server-owned attributes; it never sends amounts to the server.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Events = require(ReplicatedStorage.Shared.Events)
local Sfx = require(script.Parent.Sfx)
local UiKit = require(script.Parent.UiKit)

local Hud = {}

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

function Hud.start(gui: ScreenGui)
	local player = Players.LocalPlayer

	-- No box: outlined text floats over the world, as in the design kit.
	local frame = Instance.new("Frame")
	frame.Name = "Hud"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, 8)
	frame.Size = UDim2.fromOffset(320, 84)
	frame.BackgroundTransparency = 1
	frame.Parent = gui

	local function makeLabel(y: number, height: number, color: Color3): TextLabel
		local label = UiKit.makeTitle(frame, "", color, UDim2.new(1, 0, 0, height), UDim2.fromOffset(0, y), if height >= 40 then 3.5 else 2.5)
		UiKit.textConstraint(label, height)
		return label
	end

	local cashLabel = makeLabel(4, 48, UiKit.GOLD)
	local pendingLabel = makeLabel(54, 24, UiKit.WHITE)
	cashLabel.Text = "Loading..."
	pendingLabel.Text = ""

	local function refresh()
		if not player:GetAttribute("DataLoaded") then
			return
		end
		cashLabel.Text = "$" .. comma(player:GetAttribute("Cash") or 0)
		local pending = player:GetAttribute("Pending") or 0
		if player:GetAttribute("LotIndex") == nil then
			pendingLabel.Text = "Claim a lot (green pad)"
		elseif pending > 0 then
			pendingLabel.Text = "Box office: $" .. comma(pending) .. " - step on gold pad"
		else
			pendingLabel.Text = "Box office: $0"
		end
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
		Sfx.play("sweep")
		local float = makeLabel(0, 30, UiKit.CASH_GREEN)
		float.Text = "+$" .. comma(collected)
		float.Position = UDim2.new(0, 0, 1, 0)
		float.Size = UDim2.new(1, 0, 0, 30)
		float.ZIndex = 3
		TweenService:Create(float, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.new(0, 0, 1, 40), TextTransparency = 1 }):Play()
		task.delay(1.3, function()
			float:Destroy()
		end)
	end

	-- Event line under the HUD: the Award Night countdown (or the live event) and an active Lucky
	-- Casting boost. Award Night follows the shared schedule on the server's clock.
	-- Outlined text over the world, like "Current Event:" in the reference games; it turns into a
	-- gold banner while Award Night is live.
	local eventLabel = UiKit.makeTitle(gui, "", UiKit.WHITE, UDim2.fromOffset(360, 32), UDim2.new(0.5, 0, 0, 92), 2.5)
	eventLabel.Name = "EventLine"
	eventLabel.AnchorPoint = Vector2.new(0.5, 0)
	eventLabel.BackgroundColor3 = UiKit.AWARD_GOLD
	eventLabel.BackgroundTransparency = 1
	UiKit.corner(eventLabel, 12)
	local eventBorder = UiKit.border(eventLabel, 3)
	eventBorder.Enabled = false
	UiKit.textConstraint(eventLabel, 24)

	task.spawn(function()
		while eventLabel.Parent ~= nil do
			local now = workspace:GetServerTimeNow()
			local active, left = Events.awardNight(now)
			local text
			if active then
				text = `AWARD NIGHT! x{Config.AwardNightLuckMultiplier} Luck & payouts  {clock(left)}`
				eventLabel.BackgroundTransparency = 0
				eventBorder.Enabled = true
			else
				text = `Award Night in {clock(left)}`
				eventLabel.BackgroundTransparency = 1
				eventBorder.Enabled = false
			end
			local boostLeft = (player:GetAttribute("LuckBoostUntil") or 0) - now
			if boostLeft > 0 then
				text ..= `  -  Lucky Casting {clock(boostLeft)}`
			end
			eventLabel.Text = text
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
		away.Position = UDim2.new(0, -60, 1, 38)
		away.Size = UDim2.new(1, 120, 0, 34)
		away.ZIndex = 4
		UiKit.corner(away, 12)
		UiKit.border(away, 3, UiKit.AWARD_GOLD)
		UiKit.textConstraint(away, 22)
		Sfx.play("jingle")
		task.delay(7, function()
			away:Destroy()
		end)
	end

	player.AttributeChanged:Connect(function(name)
		if name == "Pending" then
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
end

return Hud
