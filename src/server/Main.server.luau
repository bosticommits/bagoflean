--!strict
local Players = game:GetService("Players")

-- Startup guard. A duplicated script (for example from two sync tools creating the same file) must
-- not start every service twice, and duplicate modules should be reported rather than ignored.
local container = script.Parent
if container:GetAttribute("MovieMogulStarted") then
	warn(`[MovieMogul] duplicate Main ignored ({script:GetFullName()}); remove the extra copy`)
	return
end
container:SetAttribute("MovieMogulStarted", true)
do
	local seen: { [string]: boolean } = {}
	for _, child in container:GetChildren() do
		if seen[child.Name] then
			warn(`[MovieMogul] duplicate script "{child.Name}" in {container:GetFullName()}; remove the extra copy`)
		end
		seen[child.Name] = true
	end
end

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
