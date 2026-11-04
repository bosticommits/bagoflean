--!strict
-- The theatre's red carpet in the world: while a finished film is waiting, the marquee reads
-- PREMIERE READY (blinking) and a PREMIERE prompt stands on the forecourt carpet. Using it fires the
-- same remotes as the Studio panel's buttons (PREMIERE, or PREMIERE ALL with two or more ready).
-- Both are local to this player: the prompt is made here, and only the marquee's text is changed on
-- this client (the server's map still says "TONIGHT: YOUR PREMIERE").
local Workspace = game:GetService("Workspace")

local MapModels = require(game:GetService("ReplicatedStorage").Shared.Models.MapModels)
local ClientState = require(script.Parent.ClientState)
local PremiereShow = require(script.Parent.PremiereShow)

local PremiereCarpet = {}

local READY_TEXT = "PREMIERE READY"
local GOLD = Color3.fromRGB(245, 184, 46)

-- The finished films' stages, in stage order.
local function readyStages(): { number }
	local studio = ClientState.studio
	local out: { number } = {}
	if studio ~= nil and type(studio.films) == "table" then
		local now = ClientState.serverNow()
		for _, film in studio.films do
			if type(film.endTime) == "number" and film.endTime - now <= 0 then
				table.insert(out, film.stage)
			end
		end
	end
	table.sort(out)
	return out
end

function PremiereCarpet.start(gui: ScreenGui, remotes: Instance)
	local premiere = remotes:WaitForChild("Premiere") :: RemoteEvent
	local premiereAll = remotes:WaitForChild("PremiereAll") :: RemoteEvent
	local tb = MapModels.theatreBase()

	local anchor: Part? = nil
	local prompt: ProximityPrompt? = nil
	local label: TextLabel? = nil
	local original = ""
	local originalColor = Color3.new(1, 1, 1)

	local function ensurePrompt()
		if anchor ~= nil and anchor.Parent ~= nil then
			return
		end
		local part = Instance.new("Part")
		part.Name = "PremiereCarpetPrompt"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Transparency = 1
		part.Size = Vector3.new(4, 1, 4)
		part.Position = tb.Position + tb.LookVector * 12 + Vector3.new(0, 1, 0)
		part.Parent = Workspace
		local p = Instance.new("ProximityPrompt")
		p.ActionText = "PREMIERE"
		p.ObjectText = "Red carpet"
		p.HoldDuration = 0.3
		p.MaxActivationDistance = 14
		p.RequiresLineOfSight = false
		p.Enabled = false
		p.Parent = part
		p.Triggered:Connect(function()
			local stages = readyStages()
			if #stages >= 2 then
				premiereAll:FireServer()
			elseif #stages == 1 then
				premiere:FireServer(stages[1])
			end
		end)
		anchor, prompt = part, p
	end

	-- The theatre's marquee text (the streamed-in map: look it up again whenever it is gone).
	local function findLabel()
		if label ~= nil and label:IsDescendantOf(Workspace) then
			return
		end
		label = nil
		local town = Workspace:FindFirstChild("Town")
		local theatre = if town ~= nil then town:FindFirstChild("PremiereTheatre", true) else nil
		if theatre == nil then
			return
		end
		for _, d in theatre:GetDescendants() do
			if d:IsA("TextLabel") and d.Parent ~= nil and d.Parent:IsA("SurfaceGui") and d.Text ~= READY_TEXT then
				label, original, originalColor = d, d.Text, d.TextColor3
				return
			end
		end
	end

	local flip = false
	task.spawn(function()
		while true do
			task.wait(0.5)
			local ready = #readyStages()
			-- Hidden while a premiere is on screen (the show has its own marquee).
			local overlay = gui:FindFirstChild("PremiereReveal")
			local busy = PremiereShow.active() or (overlay ~= nil and overlay:IsA("GuiObject") and overlay.Visible)
			if ready > 0 then
				ensurePrompt()
			end
			local p = prompt
			if p ~= nil then
				p.Enabled = ready > 0 and not busy
				p.ActionText = if ready >= 2 then `PREMIERE ALL ({ready})` else "PREMIERE"
			end
			findLabel()
			local l = label
			if l ~= nil then
				flip = not flip
				if ready > 0 and not busy then
					l.Text = READY_TEXT
					l.TextColor3 = if flip then GOLD else Color3.new(1, 1, 1)
				elseif l.Text == READY_TEXT then
					l.Text, l.TextColor3 = original, originalColor
				end
			end
		end
	end)
end

return PremiereCarpet
