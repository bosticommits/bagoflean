-- Lucien's first tutorial step ("Tap CAST") on a fresh save: the corner bubble must leave the CAST area
-- and its "star guaranteed" pill clear.
local H = require(game:GetService("ReplicatedStorage").UiTest.Harness)
return function(Target)
	local gui = H.boot(Target)
	local side = H.startHud(gui)
	local ClientState = require(H.client().ClientState)
	ClientState.roster = {}
	ClientState.index = {}
	ClientState.studio.tutorialDone = false
	ClientState.studio.scripts = {}
	ClientState.studio.films = {}
	ClientState.studio.cinema = {}
	local remotes = game:GetService("ReplicatedStorage").Remotes
	-- rur does not deliver RemoteEvents to the client, so the first server sync that wakes the
	-- tutorial is replaced by a BindableEvent the story fires itself.
	local sync = Instance.new("BindableEvent")
	ClientState.changed = sync.Event
	require(H.client().CastingUi).start(gui, side.actors)
	require(H.client().StudioUi).start(gui, side.studio)
	require(H.client().Tutorial).start(gui, remotes)
	-- rur draws only the story's own screen; the dialogue lives in its own ScreenGui, so its frame is
	-- moved into the story screen (same insets, so the same positions) to be rendered and checked.
	local dialogue = gui.Parent:FindFirstChild("TutorialDialogue")
	if dialogue ~= nil then
		for _, child in dialogue:GetChildren() do
			child.Parent = gui
		end
	end
	task.delay(0.2, function()
		sync:Fire("studio")
	end)
end
