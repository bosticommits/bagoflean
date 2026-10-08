--!strict
-- The special event banner (plan section 5), like the reference games' server events: when an
-- event starts, "SPECIAL EVENT: LUCKY STAR" slams onto the middle of the screen in big gradient
-- letters between two spinning 3D icons, then settles at the top under the HUD with what to do
-- and a countdown. Ten seconds before one starts it counts down "SPECIAL EVENT IN 10".
-- The server says what is live (ReplicatedStorage attributes "SpecialEvent" and
-- "SpecialEventNext", set by SpecialEventService); EventWorld shows it in the world.
-- In Studio, an "Events" button on the right starts any event at once, for testing.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")

local SpecialEvents = require(ReplicatedStorage.Shared.SpecialEvents)
local EventWorld = require(script.Parent.EventWorld)
local Fx = require(script.Parent.Fx)
local Hud = require(script.Parent.Hud)
local Icon3D = require(script.Parent.Icon3D)
local Music = require(script.Parent.Music)
local Sfx = require(script.Parent.Sfx)
local UiKit = require(script.Parent.UiKit)

local SpecialEventsUi = {}

local WIDTH = 560
local TITLE_HEIGHT = 46
local INFO_HEIGHT = 26
local HEIGHT = TITLE_HEIGHT + 2 + INFO_HEIGHT
local ICON = 54 -- the spinning icons either side of the title
local INTRO_SECONDS = 3 -- the slam in the middle of the screen, before it moves to the top
local SLAM_MIN_LEFT = 8 -- after waiting for a panel to close, still slam if this much is left
local LATE_SECONDS = 4 -- arriving later than this into an event skips its entrance
local TEASER_COLORS = { Color3.fromRGB(255, 240, 150), Color3.fromRGB(255, 160, 40) }

local function readLive(): EventWorld.Live?
	local raw = ReplicatedStorage:GetAttribute("SpecialEvent")
	if type(raw) ~= "string" then
		return nil
	end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not ok or type(data) ~= "table" then
		return nil
	end
	local event = if type(data.id) == "string" then SpecialEvents.get(data.id) else nil
	if event == nil or type(data.starts) ~= "number" or type(data.ends) ~= "number" then
		return nil
	end
	return {
		event = event,
		starts = data.starts,
		ends = data.ends,
		key = `{event.id}:{data.starts}`,
		lot = if type(data.lot) == "number" then data.lot else nil,
		owner = if type(data.owner) == "string" then data.owner else nil,
		ownerId = if type(data.ownerId) == "number" then data.ownerId else nil,
	}
end

local function escape(text: string): string
	return (text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local function gradientOf(colors: { Color3 }): ColorSequence
	local keypoints = {}
	for index, color in colors do
		table.insert(keypoints, ColorSequenceKeypoint.new((index - 1) / math.max(1, #colors - 1), color))
	end
	if #keypoints < 2 then
		return ColorSequence.new(colors[1] or UiKit.WHITE)
	end
	return ColorSequence.new(keypoints)
end

-- One line in the chat, so players who missed the banner know what is going on.
local function chat(text: string)
	pcall(function()
		local channels = TextChatService:FindFirstChild("TextChannels")
		local system = if channels ~= nil then channels:FindFirstChild("RBXSystem") else nil
		if system ~= nil and system:IsA("TextChannel") then
			system:DisplaySystemMessage(text)
		end
	end)
end

function SpecialEventsUi.start(gui: ScreenGui, remotes: Instance)
	local claimRemote = remotes:WaitForChild("EventClaim", 10)
	local resultRemote = remotes:WaitForChild("EventResult", 10)
	if claimRemote == nil or not claimRemote:IsA("RemoteEvent") or resultRemote == nil or not resultRemote:IsA("RemoteEvent") then
		warn("[SpecialEvents] event remotes never arrived")
		return
	end
	local claim = claimRemote :: RemoteEvent
	local results = resultRemote :: RemoteEvent
	EventWorld.start(function(kind: string, index: number)
		claim:FireServer(kind, index)
	end)

	-- Banner --------------------------------------------------------------------------------------
	-- No box: outlined letters over the world, like the rest of the HUD.
	local banner = Instance.new("Frame")
	banner.Name = "SpecialEvent"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Size = UDim2.fromOffset(WIDTH, HEIGHT)
	banner.BackgroundTransparency = 1
	banner.Visible = false
	banner.ZIndex = 7 -- under the tutorial and announcements
	banner.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = banner

	local title = UiKit.makeTitle(banner, "", UiKit.WHITE, UDim2.new(1, 0, 0, TITLE_HEIGHT), UDim2.new(), 4)
	title.Name = "Title"
	UiKit.textConstraint(title, TITLE_HEIGHT)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90 -- top to bottom, like the reference's yellow-to-orange letters
	gradient.Parent = title
	local info = UiKit.makeTitle(banner, "", UiKit.WHITE, UDim2.new(1, 0, 0, INFO_HEIGHT), UDim2.fromOffset(0, TITLE_HEIGHT + 2), 3)
	info.Name = "Info"
	info.RichText = true
	UiKit.textConstraint(info, 24)

	local icons: { Frame } = {}
	for _ = 1, 2 do
		local holder = Instance.new("Frame")
		holder.Name = "Icon"
		holder.BackgroundTransparency = 1
		holder.AnchorPoint = Vector2.new(0.5, 0.5)
		holder.Size = UDim2.fromOffset(ICON, ICON)
		holder.ZIndex = 2
		holder.Parent = banner
		table.insert(icons, holder)
	end
	-- Just outside the title's letters, wherever they end. TextBounds is in screen pixels, so undo
	-- the banner's scale first.
	local function placeIcons()
		local pixels = banner.AbsoluteSize.X / WIDTH
		local half = title.TextBounds.X / math.max(pixels, 0.01) / 2
		icons[1].Position = UDim2.fromOffset(WIDTH / 2 - half - ICON / 2 - 4, TITLE_HEIGHT / 2)
		icons[2].Position = UDim2.fromOffset(WIDTH / 2 + half + ICON / 2 + 4, TITLE_HEIGHT / 2)
	end
	title:GetPropertyChangedSignal("TextBounds"):Connect(placeIcons)
	banner:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeIcons)

	local function setIcons(id: string?)
		for _, holder in icons do
			holder:ClearAllChildren()
			if id ~= nil then
				Icon3D.spin(Icon3D.outlined(holder, id, 0.95), 24)
			end
		end
	end

	-- Layout --------------------------------------------------------------------------------------
	-- How big the banner can be: clear of the side menu on the left (and as far from the right
	-- edge, since it is centred), never bigger than its design size.
	local function fitScale(): number
		local area = gui.AbsoluteSize
		if area.X < 1 then
			area = UiKit.viewport()
		end
		local menuRight = gui:GetAttribute("MenuRight")
		local margin = math.max(12, if typeof(menuRight) == "number" then menuRight + 8 else 12)
		return math.clamp((area.X - 2 * margin) / (WIDTH + 2 * ICON), 0.45, 1)
	end
	local function introScale(): number
		local area = gui.AbsoluteSize
		if area.X < 1 then
			area = UiKit.viewport()
		end
		return math.clamp((area.X - 32) / (WIDTH + 2 * ICON), 0.5, 1.35)
	end

	-- Just under whatever already sits at the top centre: the event and box office lines, the
	-- "while you were away" note, the wallet (top centre on touch screens) and the tutorial.
	local function dockTop(): number
		local origin = gui.AbsolutePosition
		local area = gui.AbsoluteSize
		local half = (WIDTH + 2 * ICON) * fitScale() / 2
		local lowest = 8
		local function consider(object: Instance?)
			if object == nil or not object:IsA("GuiObject") or not object.Visible then
				return
			end
			local at, size = object.AbsolutePosition - origin, object.AbsoluteSize
			if size.Y <= 0 or at.Y > area.Y * 0.4 then
				return -- not in the top band (the tutorial docks at the bottom while a panel is open)
			end
			if at.X > area.X / 2 + half or at.X + size.X < area.X / 2 - half then
				return -- not above the banner
			end
			lowest = math.max(lowest, at.Y + size.Y)
		end
		local hud = gui:FindFirstChild("Hud")
		if hud ~= nil and hud:IsA("GuiObject") and hud.Visible then
			for _, child in hud:GetChildren() do
				consider(child)
			end
		end
		consider(gui:FindFirstChild("Wallet"))
		consider(gui:FindFirstChild("Tutorial"))
		return lowest + 4
	end

	-- A panel covers the top of the screen; the docked banner steps aside while one is open.
	local function panelOpen(): boolean
		for _, child in gui:GetChildren() do
			if child:IsA("GuiObject") and child.Visible and string.sub(child.Name, -5) == "Panel" then
				return true
			end
		end
		return false
	end

	-- States: "hidden", "teaser" (counting down), "waiting" (a panel is open, so the slam waits for
	-- it to close), "intro" (the slam), "docked" (at the top).
	local mode = "hidden"
	local live: EventWorld.Live? = nil
	local token = 0
	local dockedAt = 0
	local grow: Tween? = nil -- the slam's growth, stopped if it docks early

	local function dock(animated: boolean)
		mode = "docked"
		if grow ~= nil then
			grow:Cancel()
			grow = nil
		end
		banner.ZIndex = 7
		dockedAt = dockTop()
		local target = UDim2.new(0.5, 0, 0, dockedAt)
		if animated then
			local move = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
			TweenService:Create(banner, move, { Position = target }):Play()
			TweenService:Create(scale, move, { Scale = fitScale() }):Play()
		else
			banner.Position = target
			scale.Scale = fitScale()
		end
	end

	local function hide()
		token += 1
		local mine = token
		mode = "hidden"
		if not banner.Visible then
			return
		end
		TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 }):Play()
		task.delay(0.32, function()
			if token == mine then
				banner.Visible = false
			end
		end)
	end

	-- The slam: big in the middle of the screen, then up to the top.
	local function slam(event: SpecialEvents.Event)
		token += 1
		local mine = token
		mode = "intro"
		banner.Visible = true
		banner.ZIndex = 15 -- above the HUD and the tutorial, for a moment
		banner.Position = UDim2.new(0.5, 0, 0.3, -HEIGHT / 2)
		scale.Scale = 0.2
		title.Rotation = -8
		local growth = TweenService:Create(scale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = introScale() })
		grow = growth
		growth:Play()
		TweenService:Create(title, TweenInfo.new(0.6, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Rotation = 0 }):Play()
		Sfx.play("eventStart")
		Sfx.play("eventWhoosh", 1.25)
		Fx.flash(event.colors[#event.colors], 0.3)
		Fx.confetti(45, { event.colors[1], event.colors[#event.colors], UiKit.WHITE })
		task.delay(INTRO_SECONDS, function()
			if token == mine and mode == "intro" then
				dock(true)
			end
		end)
	end

	local function showEvent(state: EventWorld.Live, late: boolean)
		token += 1
		local event = state.event
		title.Text = `SPECIAL EVENT: {event.name}`
		gradient.Color = gradientOf(event.colors)
		info.Text = escape(event.tagline)
		setIcons(event.icon)
		if late then
			banner.Visible = true
			dock(false)
			return
		end
		chat(`<font color="#FFD23F">SPECIAL EVENT: {event.name}!</font> {escape(event.tagline)}`)
		if panelOpen() then
			-- Not on top of a menu (or the "Welcome back!" rewards that open as a player joins).
			mode = "waiting"
			banner.Visible = false
			return
		end
		slam(event)
	end

	local lastTeaser = -1
	local function showTeaser(left: number)
		local whole = math.max(1, math.ceil(left))
		if mode ~= "teaser" then
			token += 1
			mode = "teaser"
			gradient.Color = gradientOf(TEASER_COLORS)
			info.Text = "Something big is coming to town..."
			setIcons(nil)
			banner.Visible = true
			dock(false)
		end
		title.Text = `SPECIAL EVENT IN {whole}`
		if whole ~= lastTeaser then
			lastTeaser = whole
			Sfx.play("eventTeaser", if whole <= 3 then 1.25 else 1)
			-- A little thump on every second.
			scale.Scale = fitScale() * 1.12
			TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = fitScale() }):Play()
		end
	end

	-- What changed on the server: a new event, or the end of one.
	local function onEventChanged()
		local state = readLive()
		local previous = live
		if state ~= nil and previous ~= nil and state.key == previous.key then
			return
		end
		if previous ~= nil then
			live = nil
			EventWorld.finish()
			hide()
			if state == nil then
				Sfx.play("eventEnd")
			end
		end
		Music.setEvent(state ~= nil) -- the event track, if one is set in Shared/Sounds
		if state ~= nil then
			live = state
			local late = workspace:GetServerTimeNow() - state.starts > LATE_SECONDS
			EventWorld.begin(state, late)
			showEvent(state, late)
		end
	end
	ReplicatedStorage:GetAttributeChangedSignal("SpecialEvent"):Connect(onEventChanged)
	onEventChanged()

	-- Rewards float up from under the banner (or show as a toast while it is out of sight).
	local function float(text: string, color: Color3)
		if not banner.Visible or mode ~= "docked" then
			UiKit.toast(gui, text)
			return
		end
		local label = UiKit.makeTitle(banner, text, color, UDim2.new(1, 0, 0, 34), UDim2.fromOffset(0, HEIGHT), 3)
		label.ZIndex = 3
		UiKit.textConstraint(label, 32)
		TweenService:Create(label, TweenInfo.new(1.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(0, HEIGHT + 40), TextTransparency = 1 }):Play()
		local stroke = label:FindFirstChildOfClass("UIStroke")
		if stroke ~= nil then
			TweenService:Create(stroke, TweenInfo.new(1.3), { Transparency = 1 }):Play()
		end
		task.delay(1.4, function()
			label:Destroy()
		end)
	end
	results.OnClientEvent:Connect(function(kind, index, ok, text)
		if type(kind) ~= "string" or type(index) ~= "number" or type(text) ~= "string" then
			return
		end
		EventWorld.result(kind, index, ok == true, text)
		if ok ~= true then
			return
		end
		if kind == "coin" then
			Sfx.play("cashCollect", 1.3)
			float("+" .. text, UiKit.CASH_GREEN)
		elseif kind == "spotlight" then
			Sfx.play("reward")
			float(text, UiKit.GOLD)
		else
			float(text, UiKit.GOLD)
		end
	end)

	-- Every frame-ish: the countdown, the teaser, and keeping the banner in its place.
	task.spawn(function()
		while banner.Parent ~= nil do
			local now = workspace:GetServerTimeNow()
			local state = live
			if state ~= nil then
				local status = EventWorld.status() or state.event.tagline
				info.Text = `{escape(status)}  <font color="#FFD23F">{Hud.clock(state.ends - now)}</font>`
			else
				local upcoming = ReplicatedStorage:GetAttribute("SpecialEventNext")
				local left = if typeof(upcoming) == "number" then upcoming - now else math.huge
				if left > 0 and left <= SpecialEvents.TeaserSeconds then
					showTeaser(left)
				elseif mode == "teaser" then
					hide()
				end
			end
			if mode == "waiting" then
				if state == nil then
					mode = "hidden"
				elseif not panelOpen() then
					if state.ends - now >= SLAM_MIN_LEFT then
						slam(state.event)
					else
						banner.Visible = true
						dock(false)
					end
				end
			elseif mode == "intro" and panelOpen() then
				dock(false) -- a menu opened mid-slam: get out of its way
			end
			if mode == "docked" or mode == "teaser" then
				local covered = panelOpen()
				banner.Visible = not covered
				local top = dockTop()
				if not covered and math.abs(top - dockedAt) >= 2 then
					dockedAt = top
					TweenService:Create(banner, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0, top) }):Play()
				end
			end
			task.wait(0.2)
		end
	end)
	gui:GetAttributeChangedSignal("MenuRight"):Connect(function()
		if mode == "docked" or mode == "teaser" then
			scale.Scale = fitScale()
		end
	end)

	-- Studio test buttons ---------------------------------------------------------------------------
	-- The server only makes TestEvent in Studio, so live games never show these.
	local test = remotes:FindFirstChild("TestEvent")
	if test ~= nil and test:IsA("RemoteEvent") then
		local testRemote = test :: RemoteEvent
		local column = Instance.new("Frame")
		column.Name = "EventTests"
		column.AnchorPoint = Vector2.new(1, 0.5)
		column.Position = UDim2.new(1, -10, 0.5, 0)
		column.Size = UDim2.fromOffset(150, 34)
		column.BackgroundTransparency = 1
		column.ZIndex = 6
		column.Parent = gui
		local toggle = UiKit.makeButton(column, "Events (Studio)", UiKit.PURPLE, UDim2.fromOffset(150, 34), UDim2.new())
		toggle.ZIndex = 6
		UiKit.textConstraint(toggle, 18)
		local list: { TextButton } = {}
		local names = {}
		for _, event in SpecialEvents.List do
			table.insert(names, event.id)
		end
		table.insert(names, "Stop")
		for index, id in names do
			local button = UiKit.makeButton(column, id, if id == "Stop" then UiKit.CLOSE_RED else UiKit.TAB_OFF, UDim2.fromOffset(150, 30), UDim2.fromOffset(0, 34 + index * 34))
			button.ZIndex = 6
			button.Visible = false
			UiKit.textConstraint(button, 16)
			button.Activated:Connect(function()
				testRemote:FireServer(id)
			end)
			table.insert(list, button)
		end
		toggle.Activated:Connect(function()
			for _, button in list do
				button.Visible = not button.Visible
			end
		end)
	end
end

return SpecialEventsUi
