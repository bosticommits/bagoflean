--!strict
-- While any panel is open, the floating HUD that would draw over it (gift timers, the Studio-only
-- Events buttons, the top boards) steps aside, and comes back when the last panel closes. One
-- place for every panel: a panel is any visible child of the main screen named "...Panel".
local Declutter = {}

local FLOATING = { "PlaytimeGifts", "PlaytimeGiftsButton", "EventTests", "Hud" }

function Declutter.start(gui: ScreenGui)
	-- Object -> what its owner last wanted while we hold it hidden (an owner can still toggle it).
	local held: { [GuiObject]: boolean } = {}
	local watched: { [GuiObject]: boolean } = {}
	local own = false

	local function watch(object: GuiObject)
		if watched[object] then
			return
		end
		watched[object] = true
		object:GetPropertyChangedSignal("Visible"):Connect(function()
			if own or held[object] == nil then
				return
			end
			held[object] = object.Visible
			if object.Visible then
				own = true
				object.Visible = false
				own = false
			end
		end)
	end

	local function panelOpen(): boolean
		for _, child in gui:GetChildren() do
			if child:IsA("GuiObject") and child.Visible and string.sub(child.Name, -5) == "Panel" then
				return true
			end
		end
		return false
	end

	task.spawn(function()
		while true do
			if panelOpen() then
				for _, name in FLOATING do
					local object = gui:FindFirstChild(name)
					if object ~= nil and object:IsA("GuiObject") and held[object] == nil then
						watch(object)
						held[object] = object.Visible
						own = true
						object.Visible = false
						own = false
					end
				end
			else
				for object, wanted in held do
					held[object] = nil
					object.Visible = wanted
				end
			end
			task.wait(0.15)
		end
	end)
end

return Declutter
