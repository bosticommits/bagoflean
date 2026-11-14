--!strict
-- While any panel is open, the floating HUD that would draw over it (gift timers, the Studio-only
-- Events buttons, the top boards) steps aside, and comes back when the last panel closes. One
-- place for every panel: a panel is any visible child of the main screen named "...Panel".
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BubblePlacer = require(ReplicatedStorage.Shared.BubblePlacer)
local UiKit = require(script.Parent.UiKit)
local Declutter = {}

local FLOATING = { "PlaytimeGifts", "PlaytimeGiftsButton", "EventTests", "Hud" }

function Declutter.start(gui: ScreenGui)
	-- Object -> what its owner last wanted while we hold it hidden (an owner can still toggle it).
	local held: { [GuiObject]: boolean } = {}
	local watched: { [GuiObject]: boolean } = {}
	local mine: { [GuiObject]: number } = {} -- our own Visible=false writes still to be seen (Deferred signals run late)

	local function watch(object: GuiObject)
		if watched[object] then
			return
		end
		watched[object] = true
		object:GetPropertyChangedSignal("Visible"):Connect(function()
			if not object.Visible and (mine[object] or 0) > 0 then
				mine[object] -= 1
				return
			end
			if held[object] == nil then
				return
			end
			held[object] = object.Visible
			if object.Visible then
				mine[object] = (mine[object] or 0) + 1
				object.Visible = false
			end
		end)
	end

	local function panelOpen(): boolean
		for _, child in gui:GetChildren() do
			if child:IsA("GuiObject") and child.Visible and string.sub(child.Name, -5) == "Panel" then
				return true
			end
		end
		-- The premiere covers the screen (and hides the panels), so it counts as a panel too.
		local backdrop = gui.Parent and gui.Parent:FindFirstChild("PremiereRevealBackdrop")
		local reveal = backdrop and backdrop:FindFirstChild("PremiereReveal")
		return reveal ~= nil and reveal:IsA("GuiObject") and reveal.Visible
	end

	task.spawn(function()
		while true do
			local open = panelOpen()
			-- Names to hold hidden right now. The Wallet joins only on a phone, while the tutorial bubble shows over a panel.
			local want: { [string]: boolean } = {}
			if open then
				for _, name in FLOATING do
					want[name] = true
				end
				want.Wallet = BubblePlacer.hidesWallet(UiKit.isCompact(), true, gui:GetAttribute("TutorialActive") == true)
			end
			for name in want do
				local object = gui:FindFirstChild(name)
				if want[name] and object ~= nil and object:IsA("GuiObject") and held[object] == nil then
					watch(object)
					held[object] = object.Visible
					mine[object] = (mine[object] or 0) + 1
					object.Visible = false
				end
			end
			for object, wanted in held do
				if not want[object.Name] then
					held[object] = nil
					object.Visible = wanted
				end
			end
			task.wait(0.15)
		end
	end)
end

return Declutter
