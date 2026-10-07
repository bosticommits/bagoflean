--!strict
-- First-time tutorial, about a minute: claim a lot, cast, buy a script, film, premiere, collect.
-- Each step completes from real game state (not from button presses), so a player who already did
-- something skips it, and nothing here can grant anything. Finishing or skipping tells the server
-- once (TutorialDone), and it never shows again. The first Short Film is shortened server-side.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local ClientState = require(script.Parent.ClientState)
local Sfx = require(script.Parent.Sfx)
local UiKit = require(script.Parent.UiKit)

type Step = {
	text: string,
	target: string, -- a bottom-bar button name, or "claimPad" / "collectPad" in the world
	done: () -> boolean,
}

local Tutorial = {}

function Tutorial.start(gui: ScreenGui, remotes: Instance)
	local player = Players.LocalPlayer
	local tutorialDone = remotes:WaitForChild("TutorialDone", 10) :: RemoteEvent?
	if tutorialDone == nil then
		return
	end

	local collected = false
	local function studio(): any
		return ClientState.studio
	end
	local function count(t: { [any]: any }?): number
		local n = 0
		if t ~= nil then
			for _ in t do
				n += 1
			end
		end
		return n
	end

	local steps: { Step } = {
		{
			text = "Walk onto a green pad to claim your studio lot",
			target = "claimPad",
			done = function()
				return player:GetAttribute("LotIndex") ~= nil
			end,
		},
		{
			text = "Tap CAST to hold a Casting Call for your first actor",
			target = "CastButton",
			done = function()
				return count(ClientState.roster) > 0
			end,
		},
		{
			text = "Open Studio, then Scripts, and buy a Short Film script",
			target = "StudioButton",
			done = function()
				local s = studio()
				return s ~= nil and (count(s.scripts) > 0 or #s.films > 0 or #s.cinema > 0)
			end,
		},
		{
			text = "In Studio > Stages tap Start movie: pick your script and an actor",
			target = "StudioButton",
			done = function()
				local s = studio()
				return s ~= nil and (#s.films > 0 or #s.cinema > 0)
			end,
		},
		{
			text = "Tap CLAP to speed up filming, then tap PREMIERE!",
			target = "StudioButton",
			done = function()
				local s = studio()
				return s ~= nil and #s.cinema > 0
			end,
		},
		{
			text = "Your cinema now earns Cash. Step on your gold pad to collect it",
			target = "collectPad",
			done = function()
				return collected
			end,
		},
	}

	-- Banner ------------------------------------------------------------------------------------
	-- Below the Cash HUD and the Award Night line (which ends 124 px down), so it covers neither.
	local TOP_POSITION = UDim2.new(0.5, 0, 0, 132)
	local banner = Instance.new("Frame")
	banner.Name = "Tutorial"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = TOP_POSITION
	banner.Size = UDim2.new(0.9, 0, 0, 58)
	banner.BackgroundColor3 = UiKit.NAVY
	banner.BackgroundTransparency = 0.05
	banner.Visible = false
	banner.ZIndex = 8 -- above panels, below the reveal overlays
	banner.Parent = gui
	UiKit.corner(banner, 12)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(520, 70)
	limit.Parent = banner
	UiKit.border(banner, 3, UiKit.GOLD)

	local stepLabel = UiKit.makeTitle(banner, "", UiKit.GOLD, UDim2.new(0, 46, 1, -12), UDim2.fromOffset(8, 6))
	stepLabel.ZIndex = 9
	local textLabel = UiKit.makeLabel(banner, "", UiKit.WHITE, UDim2.new(1, -140, 1, -12), UDim2.fromOffset(58, 6))
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.TextWrapped = true
	textLabel.ZIndex = 9
	UiKit.textConstraint(textLabel, 20)
	local skip = UiKit.makeButton(banner, "Skip", UiKit.TAB_OFF, UDim2.fromOffset(66, 40), UDim2.new(1, -74, 0.5, -20))
	skip.ZIndex = 9

	-- Highlights ----------------------------------------------------------------------------------
	-- The pulsing outline borrows the button's own outline (a button keeps one border stroke), so
	-- clearing it puts the original color and thickness back.
	local highlight: UIStroke? = nil
	local highlightRestore: { Color: Color3, Thickness: number, Transparency: number }? = nil
	local highlightTween: Tween? = nil
	local arrow: BillboardGui? = nil
	local outline: Highlight? = nil
	local outlineTween: Tween? = nil

	local function clearHighlight()
		if highlightTween ~= nil then
			highlightTween:Cancel()
			highlightTween = nil
		end
		if highlight ~= nil then
			if highlightRestore ~= nil then
				highlight.Color = highlightRestore.Color
				highlight.Thickness = highlightRestore.Thickness
				highlight.Transparency = highlightRestore.Transparency
				highlightRestore = nil
			else
				highlight:Destroy()
			end
			highlight = nil
		end
		if arrow ~= nil then
			arrow:Destroy()
			arrow = nil
		end
		if outlineTween ~= nil then
			outlineTween:Cancel()
			outlineTween = nil
		end
		if outline ~= nil then
			outline:Destroy()
			outline = nil
		end
	end

	-- A glowing outline on the target pad, visible from any angle (local only, never replicated).
	local function outlinePad(pad: BasePart)
		local glow = Instance.new("Highlight")
		glow.Name = "TutorialGlow"
		glow.Adornee = pad
		glow.FillColor = UiKit.GOLD
		glow.OutlineColor = Color3.new(1, 1, 1)
		glow.FillTransparency = 0.6
		glow.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		glow.Parent = pad
		outline = glow
		local tween = TweenService:Create(glow, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { FillTransparency = 0.15 })
		outlineTween = tween
		tween:Play()
	end

	-- The pad to point at: the player's own collect pad, or the nearest free claim pad.
	local function findPad(kind: string): BasePart?
		local lots = workspace:FindFirstChild("Lots")
		if lots == nil then
			return nil
		end
		if kind == "collectPad" then
			local index = player:GetAttribute("LotIndex")
			local lot = if index ~= nil then lots:FindFirstChild("Lot" .. tostring(index)) else nil
			local pad = if lot ~= nil then lot:FindFirstChild("CollectPad") else nil
			return if pad ~= nil and pad:IsA("BasePart") then pad else nil
		end
		local character = player.Character
		local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		local camera = workspace.CurrentCamera
		local best: BasePart? = nil
		local bestScore = math.huge
		for _, lot in lots:GetChildren() do
			local pad = lot:FindFirstChild("ClaimPad")
			if pad ~= nil and pad:IsA("BasePart") and lot:GetAttribute("OwnerUserId") == nil then
				local distance = if root ~= nil and root:IsA("BasePart") then (root.Position - pad.Position).Magnitude else 0
				-- Prefer pads the player can see: one behind the camera counts as twice as far.
				local facing = 1
				if camera ~= nil then
					local toPad = pad.Position - camera.CFrame.Position
					facing = if toPad.Magnitude > 0 then camera.CFrame.LookVector:Dot(toPad.Unit) else 1
				end
				local score = distance * (1.5 - 0.5 * facing)
				if score < bestScore then
					best, bestScore = pad, score
				end
			end
		end
		return best
	end

	local function showHighlight(target: string)
		clearHighlight()
		if target == "claimPad" or target == "collectPad" then
			local pad = findPad(target)
			if pad == nil then
				return
			end
			local board = Instance.new("BillboardGui")
			board.Name = "TutorialArrow"
			board.Adornee = pad
			board.AlwaysOnTop = true
			board.Size = UDim2.fromOffset(150, 56)
			-- Low over the pad, so it stays clear of the tutorial banner at the top of the screen.
			board.StudsOffset = Vector3.new(0, 4, 0)
			-- BillboardGuis do not render inside a ScreenGui; they live directly under PlayerGui.
			board.Parent = gui.Parent
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundColor3 = UiKit.AWARD_GOLD
			label.TextColor3 = UiKit.WHITE
			label.Font = UiKit.DISPLAY_FONT
			UiKit.outline(label, 3)
			UiKit.border(label, 3)
			label.TextScaled = true
			label.Text = if target == "claimPad" then "CLAIM HERE" else "COLLECT HERE"
			label.Parent = board
			UiKit.corner(label, 12)
			arrow = board
			local tween = TweenService:Create(board, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { StudsOffset = Vector3.new(0, 5.5, 0) })
			highlightTween = tween
			tween:Play()
			outlinePad(pad)
			return
		end
		local bar = gui:FindFirstChild("CastingBar")
		local button = if bar ~= nil then bar:FindFirstChild(target) else nil
		if button == nil or not button:IsA("GuiObject") then
			return
		end
		local existing = button:FindFirstChild("Outline")
		local pulse: UIStroke
		if existing ~= nil and existing:IsA("UIStroke") then
			pulse = existing
			highlightRestore = { Color = pulse.Color, Thickness = pulse.Thickness, Transparency = pulse.Transparency }
		else
			pulse = Instance.new("UIStroke")
			pulse.Name = "TutorialPulse"
			pulse.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		end
		pulse.Color = UiKit.GOLD
		pulse.Thickness = 4
		pulse.Parent = button
		highlight = pulse
		local tween = TweenService:Create(pulse, TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Thickness = 8, Transparency = 0.5 })
		highlightTween = tween
		tween:Play()
	end

	-- Driver --------------------------------------------------------------------------------------
	local active = false
	local finished = false
	local currentIndex = 0

	local function finish(skipped: boolean)
		if finished then
			return
		end
		finished = true
		active = false
		clearHighlight()
		tutorialDone:FireServer()
		if skipped then
			banner.Visible = false
			return
		end
		Sfx.play("jingle")
		stepLabel.Text = ""
		textLabel.Text = "You're a movie mogul! Keep casting, filming and upgrading."
		skip.Visible = false
		task.delay(5, function()
			banner.Visible = false
		end)
	end

	local function update()
		if not active then
			return
		end
		local nextIndex = nil
		for index, step in steps do
			if not step.done() then
				nextIndex = index
				break
			end
		end
		if nextIndex == nil then
			finish(false)
			return
		end
		if nextIndex ~= currentIndex then
			if currentIndex ~= 0 then
				Sfx.play("indicator")
			end
			currentIndex = nextIndex
			local step = steps[nextIndex]
			stepLabel.Text = `{nextIndex}/{#steps}`
			textLabel.Text = step.text
			showHighlight(step.target)
		end
	end

	skip.Activated:Connect(function()
		finish(true)
	end)

	-- A collect is the only thing that lowers pending royalties.
	local lastPending = player:GetAttribute("Pending") or 0
	player.AttributeChanged:Connect(function(name)
		if name == "Pending" then
			local pending = player:GetAttribute("Pending") or 0
			if pending < lastPending - 0.5 then
				collected = true
			end
			lastPending = pending
		end
		update()
	end)
	ClientState.changed:Connect(function()
		local s = studio()
		if s == nil then
			return
		end
		if not active and not finished then
			if s.tutorialDone then
				finished = true
				return
			end
			active = true
			banner.Visible = true
		end
		update()
	end)
	-- While a panel is open the banner would cover its title and close button, so it docks at the
	-- bottom of the screen instead (over the button bar, which is not needed while a panel is up).
	local docked = false
	task.spawn(function()
		while not finished do
			local panelOpen = false
			for _, child in gui:GetChildren() do
				if child:IsA("GuiObject") and child.Visible and string.sub(child.Name, -5) == "Panel" then
					panelOpen = true
					break
				end
			end
			if panelOpen ~= docked then
				docked = panelOpen
				if docked then
					banner.AnchorPoint = Vector2.new(0.5, 1)
					banner.Position = UDim2.new(0.5, 0, 1, -12)
				else
					banner.AnchorPoint = Vector2.new(0.5, 0)
					banner.Position = TOP_POSITION
				end
			end
			task.wait(0.2)
		end
	end)

	-- The claim-pad arrow follows the player to the nearest free lot (moved, not rebuilt).
	task.spawn(function()
		while not finished do
			task.wait(2)
			local board = arrow
			if active and board ~= nil and steps[currentIndex] ~= nil and steps[currentIndex].target == "claimPad" then
				local pad = findPad("claimPad")
				if pad ~= nil and board.Adornee ~= pad then
					board.Adornee = pad
					if outline ~= nil then
						outline.Adornee = pad
						outline.Parent = pad
					end
				end
			end
		end
	end)
end

return Tutorial
