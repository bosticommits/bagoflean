--!strict
-- Placeholder HUD. Reads server-owned attributes; it never sends amounts to the server.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Events = require(ReplicatedStorage.Shared.Events)
local Sfx = require(script.Parent.Sfx)

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

	local frame = Instance.new("Frame")
	frame.Name = "Hud"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, 12)
	frame.Size = UDim2.fromOffset(280, 84)
	frame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	frame.BackgroundTransparency = 0.15
	frame.Parent = gui
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

	local function makeLabel(y: number, height: number, color: Color3): TextLabel
		local label = Instance.new("TextLabel")
		label.Position = UDim2.fromOffset(0, y)
		label.Size = UDim2.new(1, 0, 0, height)
		label.BackgroundTransparency = 1
		label.TextColor3 = color
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.Parent = frame
		return label
	end

	local cashLabel = makeLabel(6, 44, Color3.fromRGB(120, 255, 140))
	local pendingLabel = makeLabel(52, 26, Color3.fromRGB(255, 220, 90))
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
		local float = makeLabel(0, 0, Color3.fromRGB(120, 255, 140))
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
	local eventLabel = Instance.new("TextLabel")
	eventLabel.Name = "EventLine"
	eventLabel.AnchorPoint = Vector2.new(0.5, 0)
	eventLabel.Position = UDim2.new(0.5, 0, 0, 100)
	eventLabel.Size = UDim2.fromOffset(340, 30)
	eventLabel.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	eventLabel.BackgroundTransparency = 0.3
	eventLabel.TextColor3 = Color3.new(1, 1, 1)
	eventLabel.TextScaled = true
	eventLabel.Font = Enum.Font.GothamBold
	eventLabel.Parent = gui
	Instance.new("UICorner", eventLabel).CornerRadius = UDim.new(0, 10)
	local textLimit = Instance.new("UITextSizeConstraint")
	textLimit.MaxTextSize = 22
	textLimit.Parent = eventLabel

	task.spawn(function()
		while eventLabel.Parent ~= nil do
			local now = workspace:GetServerTimeNow()
			local active, left = Events.awardNight(now)
			local text
			if active then
				text = `AWARD NIGHT! x{Config.AwardNightLuckMultiplier} Luck & payouts  {clock(left)}`
				eventLabel.BackgroundColor3 = Color3.fromRGB(150, 110, 20)
			else
				text = `Award Night in {clock(left)}`
				eventLabel.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
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
		local away = makeLabel(0, 0, Color3.fromRGB(30, 20, 0))
		away.Name = "AwayEarnings"
		away.Text = `Your cinema earned ${comma(pending)} while you were away! Collect it at the gold pad`
		away.BackgroundTransparency = 0
		away.BackgroundColor3 = Color3.fromRGB(255, 220, 90)
		away.Position = UDim2.new(0, -60, 1, 38)
		away.Size = UDim2.new(1, 120, 0, 34)
		away.ZIndex = 4
		Instance.new("UICorner", away).CornerRadius = UDim.new(0, 10)
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
