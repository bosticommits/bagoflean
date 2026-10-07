--!strict
-- Placeholder HUD. Reads server-owned attributes; it never sends amounts to the server.
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "HUD"
gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Parent = playerGui

local frame = Instance.new("Frame")
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

local function comma(n: number): string
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

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

player.AttributeChanged:Connect(refresh)
refresh()
