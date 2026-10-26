--!strict
-- Playtime gift ladder: a compact row of seven presents in the bottom right corner, each with a
-- countdown. A ready present glows and bounces; tapping it asks the server (RewardService) to open
-- it, and the present pops with confetti and the reward floats up. The row folds away once all
-- seven are open. The server owns the clock: this only counts down from its last sync.
--
-- Placement: on touch screens it sits just above the jump button, so it never covers the
-- thumbstick (bottom left), the CAST bar (bottom centre) or the top HUD; on PC it sits above the
-- sound button.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local PlaytimeGifts = require(ReplicatedStorage.Shared.PlaytimeGifts)
local Sfx = require(script.Parent.Sfx)
local UiKit = require(script.Parent.UiKit)

local PlaytimeGiftsUi = {}

-- Present pictures (uploaded image ids). 0 = draw the present in code instead.
local ART = { closed = 0, ready = 0, opened = 0 }

local SLOT, BIG, GAP, LABEL = 44, 52, 4, 16
local COUNT = #PlaytimeGifts.Ladder
local CONFETTI = { UiKit.GOLD, UiKit.CLOSE_RED, UiKit.BLUE, UiKit.GREEN, UiKit.PURPLE, UiKit.WHITE }

type Slot = { button: ImageButton, art: GuiObject, lid: Frame?, label: TextLabel, pop: UIScale, halo: Frame, tick: Frame?, state: string }

local function clock(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

-- Code-drawn present: a box with a ribbon cross, a lid and a two-loop bow. Returns the art and lid.
local function drawPresent(parent: GuiObject, body: Color3, ribbon: Color3): (Frame, Frame)
	local art = Instance.new("Frame")
	art.Name = "Art"
	art.BackgroundTransparency = 1
	art.Size = UDim2.fromScale(1, 1)
	art.Parent = parent
	local function block(name: string, color: Color3, pos: UDim2, size: UDim2, into: GuiObject, stroke: boolean?): Frame
		local f = Instance.new("Frame")
		f.Name = name
		f.BackgroundColor3 = color
		f.BorderSizePixel = 0
		f.Position = pos
		f.Size = size
		f.Parent = into
		if stroke then
			UiKit.corner(f, 5)
			UiKit.border(f, 2.5)
		end
		return f
	end
	local box = block("Box", body, UDim2.fromScale(0.12, 0.42), UDim2.fromScale(0.76, 0.54), art, true)
	block("RibbonV", ribbon, UDim2.fromScale(0.42, 0), UDim2.fromScale(0.16, 1), box)
	local lid = block("Lid", body, UDim2.fromScale(0.06, 0.28), UDim2.fromScale(0.88, 0.18), art, true)
	block("RibbonL", ribbon, UDim2.fromScale(0.43, 0), UDim2.fromScale(0.14, 1), lid)
	for _, side in { -1, 1 } do
		local loop = block("Bow", ribbon, UDim2.fromScale(0.5 + side * 0.12, -0.6), UDim2.fromScale(0.26, 0.9), lid, true)
		loop.AnchorPoint = Vector2.new(0.5, 0.5)
		loop.Rotation = side * 35
	end
	return art, lid
end

function PlaytimeGiftsUi.start(gui: ScreenGui, remotes: Instance)
	local claim = remotes:WaitForChild("ClaimGift", 10) :: RemoteEvent?
	local sync = remotes:WaitForChild("GiftsSync", 10) :: RemoteEvent?
	local request = remotes:WaitForChild("GiftsRequest", 10) :: RemoteEvent?
	if claim == nil or sync == nil or request == nil then
		warn("[PlaytimeGiftsUi] gift remotes missing")
		return
	end

	local row = Instance.new("Frame")
	row.Name = "PlaytimeGifts"
	row.AnchorPoint = Vector2.new(1, 1)
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromOffset((COUNT - 1) * (SLOT + GAP) + BIG, BIG + LABEL)
	row.Visible = false
	row.ZIndex = 5
	row.Parent = gui
	local rowScale = Instance.new("UIScale")
	rowScale.Parent = row
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Padding = UDim.new(0, GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row

	local function place()
		local compact = UiKit.isCompact()
		rowScale.Scale = if compact then 0.8 else 1
		if UserInputService.TouchEnabled then
			-- Roblox's jump button: 70 px with its top 90 px up on small screens, 120 px / 210 px on big ones.
			row.Position = UDim2.new(1, -12, 1, if math.min(UiKit.viewport().X, UiKit.viewport().Y) <= 500 then -100 else -220)
		else
			row.Position = UDim2.new(1, -16, 1, -76) -- above the 48 px sound button
		end
	end
	UiKit.onViewportChanged(place)

	local slots: { Slot } = {}
	local played, syncedAt = 0, os.clock()
	local claimed: { boolean } = {}

	local function setState(slot: Slot, state: string)
		if slot.state == state then
			return
		end
		slot.state = state
		slot.halo.Visible = state == "ready"
		local image: ImageLabel? = if slot.art:IsA("ImageLabel") then slot.art else nil
		if image ~= nil then
			local id = if state == "opened" then ART.opened elseif state == "ready" then ART.ready else ART.closed
			image.Image = "rbxassetid://" .. id
		end
		if state == "opened" then
			slot.label.Text = ""
			if image == nil then
				for _, d in slot.art:GetDescendants() do
					if d:IsA("Frame") then
						d.BackgroundTransparency = 0.55
					end
				end
				if slot.lid ~= nil then
					slot.lid.Visible = false
				end
			end
			if slot.tick == nil then
				slot.tick = UiKit.tick(slot.button, slot.button.ZIndex + 3)
			end
			return
		end
		-- Closed or ready again (a new ladder): undo the opened look.
		if slot.tick ~= nil then
			slot.tick:Destroy()
			slot.tick = nil
			for _, d in slot.art:GetDescendants() do
				if d:IsA("Frame") then
					d.BackgroundTransparency = 0
				end
			end
			if slot.lid ~= nil then
				slot.lid.Visible = true
			end
		end
		if state == "ready" then
			slot.label.Text = "OPEN!"
			slot.label.TextColor3 = UiKit.CASH_GREEN
		end
	end

	-- Confetti and the reward text burst out of slot `k` (on the ScreenGui, so the row's layout
	-- never moves them).
	local function burst(k: number, text: string?)
		local slot = slots[k]
		local centre = slot.button.AbsolutePosition + slot.button.AbsoluteSize / 2 - gui.AbsolutePosition
		for i = 1, 14 do
			local bit = Instance.new("Frame")
			bit.AnchorPoint = Vector2.new(0.5, 0.5)
			bit.BorderSizePixel = 0
			bit.BackgroundColor3 = CONFETTI[i % #CONFETTI + 1]
			bit.Size = UDim2.fromOffset(7, 11)
			bit.Position = UDim2.fromOffset(centre.X, centre.Y)
			bit.Rotation = math.random(0, 180)
			bit.ZIndex = 12
			bit.Parent = gui
			local angle = math.rad(math.random(200, 340)) -- mostly upwards
			local reach = math.random(50, 110)
			local fly = TweenService:Create(bit, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = UDim2.fromOffset(centre.X + math.cos(angle) * reach, centre.Y + math.sin(angle) * reach),
				Rotation = bit.Rotation + math.random(-270, 270),
				BackgroundTransparency = 1,
			})
			fly.Completed:Once(function()
				bit:Destroy()
			end)
			fly:Play()
		end
		if text ~= nil then
			local float = UiKit.makeTitle(gui, text, UiKit.GOLD, UDim2.fromOffset(260, 30), UDim2.fromOffset(centre.X, centre.Y - 40))
			float.AnchorPoint = Vector2.new(0.5, 1)
			float.ZIndex = 13
			UiKit.textConstraint(float, 26)
			-- Keep the text on screen when the present is near the right edge.
			local maxX = gui.AbsoluteSize.X - 134
			float.Position = UDim2.fromOffset(math.min(centre.X, maxX), centre.Y - 40)
			local rise = TweenService:Create(float, TweenInfo.new(2.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = float.Position - UDim2.fromOffset(0, 50),
				TextTransparency = 1,
			})
			rise.Completed:Once(function()
				float:Destroy()
			end)
			task.delay(0.6, function()
				rise:Play()
			end)
		end
	end

	-- Shake, then a big pop as it opens.
	local function popOpen(k: number, text: string?)
		local slot = slots[k]
		Sfx.play("giftOpen")
		slot.pop.Scale = 1.45
		TweenService:Create(slot.pop, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		burst(k, text)
		setState(slot, "opened")
	end

	for k, gift in PlaytimeGifts.Ladder do
		local big = k == COUNT
		local size = if big then BIG else SLOT
		local holder = Instance.new("Frame")
		holder.Name = `Gift{k}`
		holder.BackgroundTransparency = 1
		holder.LayoutOrder = k
		holder.Size = UDim2.fromOffset(size, size + LABEL)
		holder.Parent = row
		local button = Instance.new("ImageButton")
		button.Name = "Present"
		button.BackgroundTransparency = 1
		button.Image = ""
		button.AnchorPoint = Vector2.new(0.5, 0.5)
		button.Position = UDim2.new(0.5, 0, 0, size / 2)
		button.Size = UDim2.fromOffset(size, size)
		button.ZIndex = 6
		button.Parent = holder
		local pop = Instance.new("UIScale")
		pop.Parent = button
		local art: GuiObject, lid: Frame? = nil :: any, nil
		if ART.closed ~= 0 then
			local image = Instance.new("ImageLabel")
			image.Name = "Art"
			image.BackgroundTransparency = 1
			image.Size = UDim2.fromScale(1, 1)
			image.ZIndex = 7
			image.Image = "rbxassetid://" .. ART.closed
			image.Parent = button
			art = image
		else
			art, lid = drawPresent(button, if big then UiKit.GOLD else UiKit.CLOSE_RED, if big then UiKit.CLOSE_RED else UiKit.GOLD)
			for _, d in art:GetDescendants() do
				if d:IsA("GuiObject") then
					d.ZIndex = 7
				end
			end
		end
		local halo = UiKit.halo(button, 10, 2)
		halo.Visible = false
		local label = UiKit.makeTitle(holder, clock(gift.minutes * 60), UiKit.WHITE, UDim2.new(1, 8, 0, LABEL), UDim2.new(0, -4, 0, size), 1.5)
		label.ZIndex = 8
		UiKit.textConstraint(label, 15)
		local slot: Slot = { button = button, art = art, lid = lid, label = label, pop = pop, halo = halo, tick = nil, state = "closed" }
		slots[k] = slot
		button.Activated:Connect(function()
			if slot.state == "ready" then
				-- A little wiggle while the server answers; the pop comes with its reply.
				TweenService:Create(button, TweenInfo.new(0.06, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 3, true), { Rotation = 12 }):Play()
				claim:FireServer(k)
			elseif slot.state == "closed" then
				Sfx.play("click")
				UiKit.toast(gui, `This present opens after {gift.minutes} min of play`)
			end
		end)
	end

	local function refresh()
		local now = played + (os.clock() - syncedAt)
		local open = 0
		for k, gift in PlaytimeGifts.Ladder do
			local slot = slots[k]
			if claimed[k] then
				setState(slot, "opened")
				open += 1
			elseif now >= gift.minutes * 60 + 1 then -- a second late, so the server agrees
				setState(slot, "ready")
			else
				setState(slot, "closed")
				slot.label.Text = clock(gift.minutes * 60 - now)
				slot.label.TextColor3 = UiKit.WHITE
			end
		end
		return open
	end

	local folding = false
	sync.OnClientEvent:Connect(function(payload: any)
		if type(payload) ~= "table" or type(payload.played) ~= "number" or type(payload.claimed) ~= "table" then
			return
		end
		played, syncedAt, claimed = payload.played, os.clock(), payload.claimed
		local opened = payload.opened
		if type(opened) == "number" and slots[opened] ~= nil then
			popOpen(opened, if type(payload.text) == "string" then payload.text else nil)
		end
		local open = refresh()
		if open < COUNT then
			folding = false
			row.Visible = true
			rowScale.Scale = if UiKit.isCompact() then 0.8 else 1
		elseif row.Visible and not folding then
			-- All seven open: fold the row away once the last pop has played.
			folding = true
			task.delay(2.5, function()
				if folding then
					local fold = TweenService:Create(rowScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 })
					fold.Completed:Once(function()
						if folding then
							row.Visible = false
						end
					end)
					fold:Play()
				end
			end)
		end
	end)
	request:FireServer()

	task.spawn(function()
		while gui.Parent ~= nil do
			if row.Visible then
				refresh()
			end
			task.wait(0.5)
		end
	end)
end

return PlaytimeGiftsUi
