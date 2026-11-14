--!strict
-- Custom loading screen (film-leader countdown). Runs from ReplicatedFirst, so it covers the game
-- from the first frame: it parents its ScreenGuis to PlayerGui, then removes Roblox's default screen.
--
-- Waits for: game:IsLoaded(), the client UI ("ClientReady" player attribute, set by LoadingBridge
-- once Main built the UI and the first StudioSync arrived), the character, and a small preload of the
-- first sounds. Min 1.5 s, hard cap 8 s, Skip ends it at once.
-- Hand-off: the player attribute "LoadingScreen" is "loading" while shown and "handoff" from the first
-- frame of the fade (Tutorial opens the curtain intro then; LoadingBridge plays the clapper), nil when gone.
local ContentProvider = game:GetService("ContentProvider")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Logic = require(script.Parent:WaitForChild("LoadingLogic"))
local View = require(script.Parent:WaitForChild("LoadingView"))

local player = Players.LocalPlayer
if player:GetAttribute("LoadingScreen") ~= nil then
	return -- Rojo can run this script twice; the first run owns the screen
end
player:SetAttribute("LoadingScreen", "loading") -- before any yield, so the tutorial never races past it

local playerGui = player:WaitForChild("PlayerGui")

local function reducedMotion(): boolean
	local ok, value = pcall(function()
		return (GuiService :: any).ReducedMotionEnabled
	end)
	return ok and value == true
end

-- Two screens, above everything (HUD 0, intro 15-18, Fx 20, premiere 25): the cover has no insets, the
-- content sits inside CoreUISafeInsets.
local function makeScreen(name: string, order: number, insets: Enum.ScreenInsets): (ScreenGui, CanvasGroup)
	local screen = Instance.new("ScreenGui")
	screen.Name = name
	screen.ResetOnSpawn = false
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.ScreenInsets = insets
	screen.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None
	screen.DisplayOrder = order
	local root = Instance.new("CanvasGroup")
	root.Name = "Root"
	root.Size = UDim2.fromScale(1, 1)
	root.BorderSizePixel = 0
	root.BackgroundTransparency = 1
	root.Active = true -- eats taps, so nothing underneath can be pressed
	root.Parent = screen
	screen.Parent = playerGui
	return screen, root
end

local coverGui, cover = makeScreen("LoadingCover", 1000, Enum.ScreenInsets.None)
local safeGui, safe = makeScreen("LoadingContent", 1001, Enum.ScreenInsets.CoreUISafeInsets)
cover.BackgroundTransparency = 0
safe.Active = false

-- The default screen goes only now that ours is in place.
pcall(function()
	ReplicatedFirst:RemoveDefaultLoadingScreen()
end)

-- Touch controls hide while it shows (they draw above PlayerGui), and come back after. The original
-- value is also kept in the "LoadingTouchSaved" attribute: UiKit.holdTouchControls may run while we are
-- up (the Daily panel opens on the first sync) and must save THAT, not our temporary false. UiKit sets
-- "TouchHeld" while any panel holds the controls hidden; then it, not we, puts them back.
local savedTouch: boolean? = nil
pcall(function()
	savedTouch = GuiService.TouchControlsEnabled
	player:SetAttribute("LoadingTouchSaved", savedTouch)
	GuiService.TouchControlsEnabled = false
end)

local function teardown()
	coverGui:Destroy()
	safeGui:Destroy()
	local saved = savedTouch
	if saved ~= nil and player:GetAttribute("TouchHeld") ~= true then
		pcall(function()
			GuiService.TouchControlsEnabled = saved
		end)
	end
	player:SetAttribute("LoadingTouchSaved", nil)
	player:SetAttribute("LoadingScreen", nil)
end

local reduced = reducedMotion()
local built, view = pcall(View.build, cover, safe, reduced)
if not built then
	warn("LoadingScreen: build failed, skipping it")
	teardown()
	return
end

-- Loading state ----------------------------------------------------------------------------------
local inputs: Logic.Inputs = { loaded = game:IsLoaded(), ready = false, character = false, preload = 0 }
local skipped = false
view.skip.Activated:Connect(function()
	skipped = true
end)

local function watchReady()
	inputs.ready = player:GetAttribute("ClientReady") == true
end
player:GetAttributeChangedSignal("ClientReady"):Connect(watchReady)
watchReady()

if not inputs.loaded then
	task.spawn(function()
		game.Loaded:Wait()
		inputs.loaded = true
	end)
end

-- Character, then (if streaming is on) the area around it.
task.spawn(function()
	local character = player.Character or player.CharacterAdded:Wait()
	local root = character:WaitForChild("HumanoidRootPart", 6) :: BasePart?
	if root ~= nil and workspace.StreamingEnabled then
		pcall(function()
			player:RequestStreamAroundAsync(root.Position, 4)
		end)
	end
	inputs.character = true
end)

-- First-screen sounds, in batches of 5 with per-asset status; TimedOut is retried once, Failure never.
-- (The game has no image assets yet: the intro, Lucien and the HUD icons are built from UI and 3D.)
task.spawn(function()
	local shared = ReplicatedStorage:WaitForChild("Shared", 6)
	local soundsModule = if shared ~= nil then shared:WaitForChild("Sounds", 3) else nil
	if soundsModule == nil then
		inputs.preload = 1
		return
	end
	local ok, Sounds = pcall(require, soundsModule)
	if not ok then
		inputs.preload = 1
		return
	end
	local ids: { string } = {}
	for _, name in { "click", "panelOpen", "welcome", "lucienTutWelcome", "lucienTutIntro", "LoadClapper" } do
		local slot = (Sounds :: any).Slots[name]
		if slot ~= nil then
			local id = slot.id
			if id == 0 then
				local library = (Sounds :: any).Library[slot.fallback]
				id = if library ~= nil then library.id else 0
			end
			if id ~= 0 then
				table.insert(ids, `rbxassetid://{id}`)
			end
		end
	end
	local batches = Logic.batches(ids, Logic.BATCH)
	local statuses: { [string]: string } = {}
	local handled = 0
	local function run(batch: { string })
		pcall(function()
			ContentProvider:PreloadAsync(batch, function(contentId: string, status: Enum.AssetFetchStatus)
				statuses[contentId] = status.Name
			end)
		end)
	end
	for _, batch in batches do
		run(batch)
		handled += #batch
		inputs.preload = handled / math.max(#ids, 1)
	end
	local retry = Logic.retryList(statuses)
	if #retry > 0 then
		run(retry)
	end
	inputs.preload = 1
end)

-- Main loop --------------------------------------------------------------------------------------
local started = os.clock()
local shown = 0
local startTip = math.random(1, #Logic.TIPS)
local welcomed = false
local reason: Logic.Reason? = nil

local connection: RBXScriptConnection
connection = RunService.RenderStepped:Connect(function(dt)
	local elapsed = os.clock() - started
	if not welcomed and player:GetAttribute("LoadingNew") == false then
		welcomed = true
		local welcome = player:GetAttribute("LoadingWelcome")
		local live = player:GetAttribute("LoadingLive")
		if type(welcome) == "string" then
			view.showWelcome(welcome, if type(live) == "string" then live else nil)
		end
	end
	shown = Logic.step(shown, Logic.target(inputs), dt)
	pcall(view.update, elapsed, shown, Logic.tipIndex(elapsed, startTip, #Logic.TIPS))
end)
-- The cap and the skip are decided here, not in RenderStepped, so they never depend on rendering.
while reason == nil do
	reason = Logic.decide(os.clock() - started, inputs, skipped)
	task.wait()
end
-- Skipped or capped before the first sync: keep the cover until it says new / returning (max 1.5 s).
local syncWait = os.clock()
while player:GetAttribute("LoadingNew") == nil and os.clock() - syncWait < 1.5 do
	task.wait()
end
connection:Disconnect()

-- Hand-off ---------------------------------------------------------------------------------------
-- "handoff" lets the tutorial build the curtain intro under us; a new player's fade (0.4 s) then
-- reveals the closed curtain, a returning player's (0.3 s) the world.
player:SetAttribute("LoadingScreen", "handoff")
local isNew = player:GetAttribute("LoadingNew") == true
if isNew then
	local gui = playerGui:FindFirstChild("MovieMogulUI")
	local waited = os.clock()
	while gui ~= nil and gui:GetAttribute("IntroOpen") ~= true and os.clock() - waited < 0.5 do
		task.wait()
	end
end
pcall(view.update, os.clock() - started, 1, 1)
local fade = TweenInfo.new(Logic.fadeSeconds(isNew), Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local fadeCover = TweenService:Create(cover, fade, { GroupTransparency = 1 })
TweenService:Create(safe, fade, { GroupTransparency = 1 }):Play()
fadeCover:Play()
fadeCover.Completed:Wait()

teardown()
