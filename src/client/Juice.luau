--!strict
-- Small UI juice: numbers that count up, button press, and a pop. No shake, no new sounds.
-- Everything snaps (no motion) when the player turned on Roblox's reduced-motion setting.
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CountUp = require(game:GetService("ReplicatedStorage").Shared.CountUp)

local Juice = {}

local COUNT_TIME = 0.6

local function reducedMotion(): boolean
	local ok, value = pcall(function()
		return (GuiService :: any).ReducedMotionEnabled
	end)
	return ok and value == true
end
Juice.reducedMotion = reducedMotion

type Counter = { value: number, target: number, conn: RBXScriptConnection? }
local counters: { [TextLabel]: Counter } = setmetatable({}, { __mode = "k" }) :: any

-- Shows `render(value)` in the label and rolls it to `target`. The first call (or a reduced-motion
-- player) just snaps, unless `from` says where to start (the "+$X" floats start at 0). Calling it
-- again with the same target does nothing, so it is safe from a refresh that runs on every change.
function Juice.count(label: TextLabel, target: number, render: (number) -> string, from: number?)
	local c = counters[label]
	if c == nil then
		c = { value = from or target, target = if from then from else target, conn = nil }
		counters[label] = c
		label.Text = render(c.value)
	end
	local counter = c :: Counter
	if counter.target == target then
		return
	end
	counter.target = target
	if counter.conn ~= nil then
		counter.conn:Disconnect()
		counter.conn = nil
	end
	if reducedMotion() then
		counter.value = target
		label.Text = render(target)
		return
	end
	local startValue, startTime = counter.value, os.clock()
	counter.conn = RunService.Heartbeat:Connect(function()
		local alpha = (os.clock() - startTime) / COUNT_TIME
		counter.value = CountUp.at(startValue, target, alpha)
		label.Text = render(counter.value)
		if alpha >= 1 and counter.conn ~= nil then
			counter.conn:Disconnect()
			counter.conn = nil
		end
	end)
end

-- One shared press feel for buttons: dips while held, springs back on release. UiKit.bounce and
-- UiKit.pulse own the button's scale instead: they destroy "Press" and set "NoPress", so a button
-- never carries two UIScales.
function Juice.press(button: GuiButton)
	if button:GetAttribute("NoPress") then
		return
	end
	local scale = Instance.new("UIScale")
	scale.Name = "Press"
	scale.Parent = button
	local function to(value: number, time: number, style: Enum.EasingStyle): Tween?
		if reducedMotion() or scale.Parent == nil then
			return nil
		end
		local tween = TweenService:Create(scale, TweenInfo.new(time, style, Enum.EasingDirection.Out), { Scale = value })
		tween:Play()
		return tween
	end
	local function isPointer(input: InputObject): boolean
		return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
	end
	button.InputBegan:Connect(function(input)
		if not isPointer(input) then
			return
		end
		to(0.93, 0.07, Enum.EasingStyle.Quad)
		-- MouseButton1Up only fires over the button; the input itself reports every release, also
		-- after a slide-off or a scroll-drag (Cancel).
		local conn: RBXScriptConnection
		conn = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End or input.UserInputState == Enum.UserInputState.Cancel then
				conn:Disconnect()
				to(1, 0.18, Enum.EasingStyle.Back)
			end
		end)
	end)
	-- Gamepad / keyboard activation has no press: a tiny dip so it still answers.
	button.Activated:Connect(function(input)
		if isPointer(input) then
			return
		end
		local down = to(0.96, 0.05, Enum.EasingStyle.Quad)
		if down ~= nil then
			down.Completed:Once(function()
				to(1, 0.12, Enum.EasingStyle.Back)
			end)
		end
	end)
end

-- Called by anything that brings its own UIScale for a button (bounce, pulse).
function Juice.dropPress(object: GuiObject)
	object:SetAttribute("NoPress", true)
	local press = object:FindFirstChild("Press")
	if press ~= nil and press:IsA("UIScale") then
		press:Destroy()
	end
end

-- A quick grow-and-settle on something that just got better. `anchor` is the point it grows
-- from (left-aligned text: Vector2.new(0, 0.5)); the object is moved so it does not shift.
function Juice.punch(object: GuiObject, anchor: Vector2?, amount: number?)
	if reducedMotion() then
		return
	end
	local want = anchor or Vector2.new(0.5, 0.5)
	if object.AnchorPoint ~= want then
		local d, size = want - object.AnchorPoint, object.Size
		object.AnchorPoint = want
		object.Position += UDim2.new(size.X.Scale * d.X, size.X.Offset * d.X, size.Y.Scale * d.Y, size.Y.Offset * d.Y)
	end
	local punch: UIScale
	local found = object:FindFirstChild("Punch")
	if found ~= nil and found:IsA("UIScale") then
		punch = found
	else
		punch = Instance.new("UIScale")
		punch.Name = "Punch"
		punch.Parent = object
	end
	punch.Scale = amount or 1.14
	TweenService:Create(punch, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

return Juice
