--!strict
-- The store stands around the spawn plaza (built by the server's MapService) have a prompt
-- carrying a "Screen" attribute. Using it opens that screen, the same one its menu button opens.
local ProximityPromptService = game:GetService("ProximityPromptService")

local Screens = require(script.Parent.Screens)
local Sfx = require(script.Parent.Sfx)

local Stands = {}

function Stands.start()
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		local screen = prompt:GetAttribute("Screen")
		if typeof(screen) == "string" and Screens.open(screen) then
			Sfx.play("panelOpen")
		end
	end)
end

return Stands
