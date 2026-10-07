--!strict
local Players = game:GetService("Players")

local CastingService = require(script.Parent.CastingService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local LotService = require(script.Parent.LotService)
local MovieService = require(script.Parent.MovieService)
local Remotes = require(script.Parent.Remotes)
local UpgradeService = require(script.Parent.UpgradeService)

LotService.start()
CastingService.start()
MovieService.start()
UpgradeService.start()
Remotes.publish()

local function onPlayerAdded(player: Player)
	local data = DataService.load(player)
	if data == nil then
		-- Never fall back to defaults: that could overwrite a real profile later.
		if player.Parent == Players then
			player:Kick("Your data could not be loaded. Please rejoin.")
		end
		return
	end
	EconomyService.refresh(player)
	CastingService.refresh(player)
	player:SetAttribute("DataLoaded", true)

	-- Keep the pending-royalty readout fresh for the HUD.
	while player.Parent == Players and DataService.getData(player) ~= nil do
		EconomyService.refresh(player)
		task.wait(1)
	end
end

local function onPlayerRemoving(player: Player)
	LotService.release(player)
	EconomyService.forget(player)
	CastingService.forget(player)
	MovieService.forget(player)
	UpgradeService.forget(player)
	DataService.release(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
