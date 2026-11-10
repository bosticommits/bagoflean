--!strict
-- The Next Up strip's "Show me": opens the screen a start goal needs, then rings the exact control
-- (or, for a first lot, floats an arrow and a distance over the nearest free claim pad). One guide
-- at a time; it ends on a tap of the target, a goal change (the strip calls stop), the opened
-- screen closing, 12 s, or the player reaching the pad / owning a lot. Targets: ShowMe.luau.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Guides = require(script.Parent.Guides)
local Screens = require(script.Parent.Screens)
local UiKit = require(script.Parent.UiKit)
local ShowMe = require(ReplicatedStorage.Shared.ShowMe)

local ShowMeUi = {}

local LIFETIME = 12 -- seconds
local RESOLVE_EVERY = 0.15
local NEAR_STUDS = 10

local player = Players.LocalPlayer

-- Visible, with every ancestor visible, and on screen.
local function onScreen(object: GuiObject): boolean
	if object.AbsoluteSize.X < 1 then
		return false
	end
	local current: Instance? = object
	while current ~= nil and not current:IsA("LayerCollector") do
		if current:IsA("GuiObject") and not current.Visible then
			return false
		end
		current = current.Parent
	end
	return true
end

local function revealShowing(playerGui: Instance): boolean
	for _, holder in { playerGui:FindFirstChild("CastRevealSafe"), playerGui:FindFirstChild("PremiereRevealBackdrop") } do
		for _, name in { "Reveal", "PremiereReveal" } do
			local overlay = if holder ~= nil then holder:FindFirstChild(name) else nil
			if overlay ~= nil and overlay:IsA("GuiObject") and overlay.Visible then
				return true
			end
		end
	end
	return false
end

local function nearestClaimPad(from: Vector3): BasePart?
	local lots = workspace:FindFirstChild("Lots")
	local best: BasePart? = nil
	local bestDistance = math.huge
	for _, lot in if lots ~= nil then lots:GetChildren() else {} do
		local pad = lot:FindFirstChild("ClaimPad", true)
		if pad ~= nil and pad:IsA("BasePart") and lot:GetAttribute("OwnerUserId") == nil then
			local distance = (pad.Position - from).Magnitude
			if distance < bestDistance then
				best, bestDistance = pad, distance
			end
		end
	end
	return best
end

function ShowMeUi.start(gui: ScreenGui)
	local playerGui = gui.Parent :: Instance
	local connection: RBXScriptConnection? = nil
	local ringCleanup: (() -> ())? = nil
	local ringTarget: GuiObject? = nil
	local tapConnection: RBXScriptConnection? = nil
	local worldGuide: { cleanup: () -> (), board: BillboardGui? }? = nil
	local worldPad: BasePart? = nil
	local edge: Frame? = nil
	local distance: BillboardGui? = nil
	local distanceLabel: TextLabel? = nil

	local function clearRing()
		if ringCleanup ~= nil then
			ringCleanup()
		end
		if tapConnection ~= nil then
			tapConnection:Disconnect()
		end
		ringCleanup, ringTarget, tapConnection = nil, nil, nil
	end
	local function clearWorld()
		if worldGuide ~= nil then
			worldGuide.cleanup()
		end
		if distance ~= nil then
			distance:Destroy()
		end
		if edge ~= nil then
			edge:Destroy()
		end
		worldGuide, worldPad, edge, distance, distanceLabel = nil, nil, nil, nil, nil
	end

	function ShowMeUi.stop()
		if connection ~= nil then
			connection:Disconnect()
			connection = nil
		end
		clearRing()
		clearWorld()
	end

	-- A shown control for `ui`: the target, else its alternative, else the More tile hiding it.
	local roots: { [string]: Instance } = {}
	local function find(ui: ShowMe.Ui): GuiObject?
		local cached: Instance? = roots[ui.root]
		local root: Instance
		if cached == nil or cached.Parent == nil then
			local looked = playerGui:FindFirstChild(ui.root, true)
			if looked == nil then
				return nil
			end
			root = looked
			roots[ui.root] = looked
		else
			root = cached
		end
		local names: { string } = { ui.name }
		if ui.alt ~= nil then
			table.insert(names, ui.alt)
		end
		for _, name in names do
			local found = root:FindFirstChild(name, true)
			if found ~= nil and found:IsA("GuiObject") and onScreen(found) then
				return found
			end
		end
		-- Inside the closed More flyout: ring the More tile until it opens.
		local more = playerGui:FindFirstChild("MoreButton", true)
		if more ~= nil and more:IsA("GuiObject") and onScreen(more) and root:FindFirstChild(ui.name, true) ~= nil then
			return more
		end
		return nil
	end

	function ShowMeUi.show(goalId: string, onEnded: () -> ())
		ShowMeUi.stop()
		local target = ShowMe.TARGETS[goalId]
		if target == nil then
			return
		end
		local startedAt = os.clock()
		local sinceResolve = RESOLVE_EVERY
		local sawPanel = false
		if target.screen ~= nil then
			Screens.open(target.screen, target.focus)
		end
		local function finish()
			ShowMeUi.stop()
			onEnded()
		end

		connection = RunService.RenderStepped:Connect(function(dt)
			if os.clock() - startedAt > LIFETIME then
				return finish()
			end
			local panelOpen = UiKit.anyPanelOpen()
			sawPanel = sawPanel or panelOpen
			if target.screen ~= nil and sawPanel and not panelOpen then
				return finish() -- the screen was closed
			end
			local character = player.Character
			local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
			local hidden = panelOpen or revealShowing(playerGui)

			-- World guide: only while there is no lot yet.
			local lotless = player:GetAttribute("LotIndex") == nil
			if target.world == "claimPad" and lotless and root ~= nil and root:IsA("BasePart") then
				local pad = nearestClaimPad(root.Position)
				if pad == nil or (pad.Position - root.Position).Magnitude < NEAR_STUDS then
					return finish()
				end
				if hidden then
					clearWorld()
				else
					if pad ~= worldPad then
						clearWorld()
						worldPad = pad
						worldGuide = Guides.world({ adornee = pad, glow = pad, label = "", height = 4, kind = "primary" }, playerGui)
						local board = Instance.new("BillboardGui")
						board.Name = "ShowMeDistance"
						board.Adornee = pad
						board.AlwaysOnTop = true
						board.LightInfluence = 0
						board.Size = UDim2.fromOffset(if gui:GetAttribute("HudRight") == true then 72 else 96, if gui:GetAttribute("HudRight") == true then 28 else 36)
						board.StudsOffsetWorldSpace = Vector3.new(0, 10, 0)
						board.Parent = playerGui
						local label = Instance.new("TextLabel")
						label.BackgroundTransparency = 1
						label.Size = UDim2.fromScale(1, 1)
						label.TextColor3 = Guides.GUIDE
						label.Font = UiKit.DISPLAY_FONT
						label.TextScaled = true
						UiKit.outline(label, 3)
						label.Parent = board
						distance, distanceLabel = board, label
						local arrow = Guides.arrow(gui, if gui:GetAttribute("HudRight") == true then 48 else 64, 9)
						arrow.Visible = false
						edge = arrow
					end
					local camera = workspace.CurrentCamera
					if distanceLabel ~= nil then
						distanceLabel.Text = `{ShowMe.metres((pad.Position - root.Position).Magnitude)} m`
					end
					if edge ~= nil and camera ~= nil then
						Guides.placeEdge(edge, camera, pad.Position + Vector3.new(0, 2, 0), gui.AbsolutePosition, gui.AbsoluteSize, false)
					end
				end
			elseif worldGuide ~= nil then
				clearWorld()
			end

			-- UI ring, re-resolved a few times a second (screens open, tabs change, More flyout).
			local ui = target.ui
			sinceResolve += dt
			if ui ~= nil and sinceResolve >= RESOLVE_EVERY then
				sinceResolve = 0
				local found = if ui.needsLot == true and lotless then nil else find(ui)
				if found ~= ringTarget then
					clearRing()
					if found ~= nil then
						ringTarget = found
						ringCleanup = Guides.ring(found)
						if found:IsA("GuiButton") and found.Name ~= "MoreButton" then
							tapConnection = (found :: GuiButton).Activated:Connect(finish)
						end
					end
				end
			end
		end)
	end
end

return ShowMeUi
