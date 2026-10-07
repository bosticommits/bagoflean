--!strict
-- Cash HUD: big outlined gold Cash with the box office line under it. Reads server-owned attributes; it never sends amounts to the server.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Sfx = require(script.Parent.Sfx)
local UiKit = require(script.Parent.UiKit)

local Hud = {}

local function comma(n: number): string
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end
Hud.comma = comma

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

	player.AttributeChanged:Connect(function(name)
		if name == "Pending" then
			onPending()
		end
		refresh()
	end)
	refresh()
end

return Hud
