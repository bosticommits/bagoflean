--!strict
-- Film sets (rules in Shared/FilmSets, places in MapModels.FilmSets). The server sells each set for
-- Cash at its gate, records it in the save, and pays owners their box office again while they
-- stand inside. CastingService adds the sets' casting Luck (FilmSets.luck). Every client reads
-- what a player owns from the player attribute "FilmSets" (ids, comma separated) and opens the gate
-- for its own player (src/client/FilmSetWorld.luau).
-- The save keeps `filmSetsOwned` (a set of bought ids). Like `mascotsOwned` it is not in
-- DataService's template, so this feature stays in its own file; a missing set means none owned.
-- A rebirth never takes film sets away.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FilmSets = require(ReplicatedStorage.Shared.FilmSets)
local MapModels = require(ReplicatedStorage.Shared.Models.MapModels)
local Walkways = require(ReplicatedStorage.Shared.Models.Walkways)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local Remotes = require(script.Parent.Remotes)

local MIN_GAP = 0.5 -- seconds between purchases per player

local FilmSetService = {}

local lastBuy: { [Player]: number } = {}
local inside: { [Player]: number } = {} -- seconds spent inside an owned set since the last payout

-- Publishes what the player owns. Cheap; Main calls it every second.
function FilmSetService.refresh(player: Player)
	local data = DataService.getData(player)
	if data == nil then
		return
	end
	local owned = table.concat(FilmSets.owned(data), ",")
	if player:GetAttribute("FilmSets") ~= owned then
		player:SetAttribute("FilmSets", owned)
	end
end

-- The owned set the player is standing in, if any.
local function setUnder(player: Player, data: any): FilmSets.FilmSet?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	local p = root.Position
	for _, info in MapModels.FilmSets do
		local set = FilmSets.get(info.id)
		if set ~= nil and FilmSets.owns(set, data) and Walkways.isWalkable({ info.area }, p.X, p.Z) then
			return set
		end
	end
	return nil
end

-- Main calls this once a second for each player: every FilmSets.PayEvery seconds inside an owned
-- set pays one payout. Leaving resets the count, so only time really spent inside pays.
function FilmSetService.tick(player: Player)
	local data = DataService.getData(player)
	if data == nil then
		return
	end
	local set = setUnder(player, data)
	if set == nil then
		inside[player] = 0
		if player:GetAttribute("OnFilmSet") ~= nil then
			player:SetAttribute("OnFilmSet", nil)
		end
		return
	end
	if player:GetAttribute("OnFilmSet") ~= set.id then
		player:SetAttribute("OnFilmSet", set.id)
	end
	inside[player] = (inside[player] or 0) + 1
	if inside[player] >= FilmSets.PayEvery then
		inside[player] = 0
		local cash = FilmSets.payout(set, EconomyService.rate(data))
		if cash > 0 then
			EconomyService.addCash(player, cash, "Gameplay", "FilmSet:" .. set.id)
		end
	end
end

function FilmSetService.start()
	Remotes.get("BuyFilmSet").OnServerEvent:Connect(function(player: Player, id: any)
		if type(id) ~= "string" or #id > 40 then
			return
		end
		local now = os.clock()
		if now - (lastBuy[player] or -math.huge) < MIN_GAP then
			return
		end
		lastBuy[player] = now
		local data: any = DataService.getData(player)
		local set = FilmSets.get(id)
		if data == nil or set == nil or FilmSets.owns(set, data) then
			return
		end
		if not EconomyService.spendCash(player, set.price, "FilmSet:" .. set.id) then
			return
		end
		if type(data.filmSetsOwned) ~= "table" then
			data.filmSetsOwned = {}
		end
		data.filmSetsOwned[set.id] = true
		DataService.markDirty(player)
		FilmSetService.refresh(player)
	end)
end

function FilmSetService.forget(player: Player)
	lastBuy[player] = nil
	inside[player] = nil
end

return FilmSetService
