--!strict
-- Saves whether the player tucked the top HUD stack (and whether they chose quick premieres) (event badges, box office, Next Up) into its
-- pull tab, so it stays the way they left it on any server. Same pattern as SoundSettingsService:
-- the client asks on the HudTucked remote, the server stores `hudTucked` and sends it back as the
-- HudTucked attribute once the player's data has loaded.
local Players = game:GetService("Players")

local DataService = require(script.Parent.DataService)
local Remotes = require(script.Parent.Remotes)

local MIN_GAP = 0.25 -- seconds between saves per player; the client already batches taps

local HudSettingsService = {}

local lastChange: { [Player]: number } = {}

local function publish(player: Player)
	local data = DataService.getData(player)
	if data ~= nil then
		player:SetAttribute("HudTucked", data.hudTucked)
		player:SetAttribute("QuickPremieres", data.quickPremieres)
	end
end

function HudSettingsService.start()
	Remotes.get("HudTucked").OnServerEvent:Connect(function(player: Player, tucked: any)
		if type(tucked) ~= "boolean" then
			return
		end
		local now = os.clock()
		if now - (lastChange[player] or -math.huge) < MIN_GAP then
			return
		end
		lastChange[player] = now
		local data = DataService.getData(player)
		if data == nil then
			return
		end
		data.hudTucked = tucked
		publish(player)
	end)

	-- "Quick premieres": card only, no red-carpet show. Same checks as the tuck.
	Remotes.get("QuickPremieres").OnServerEvent:Connect(function(player: Player, quick: any)
		-- A rejected toggle sends the saved value back, so the client's switch never lies.
		if type(quick) ~= "boolean" then
			publish(player)
			return
		end
		local now = os.clock()
		if now - (lastChange[player] or -math.huge) < MIN_GAP then
			publish(player)
			return
		end
		lastChange[player] = now
		local data = DataService.getData(player)
		if data == nil then
			return
		end
		data.quickPremieres = quick
		publish(player)
	end)

	local function watch(player: Player)
		player:GetAttributeChangedSignal("DataLoaded"):Connect(function()
			if player:GetAttribute("DataLoaded") then
				publish(player)
			end
		end)
		if player:GetAttribute("DataLoaded") then
			publish(player)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastChange[player] = nil
	end)
end

return HudSettingsService
