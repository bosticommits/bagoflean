--!strict
-- The only place Cash changes. Clients never send amounts; they can only ask to collect.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)

local lastCollectAttempt: { [Player]: number } = {}

local EconomyService = {}

function EconomyService.pending(data: DataService.PlayerData): number
	local elapsed = math.clamp(os.time() - data.lastCollect, 0, Config.OfflineCapSeconds)
	return math.floor(elapsed * Config.CinemaIncomePerSecond)
end

-- Mirror server-owned numbers to attributes so the HUD can read them. Read-only for clients.
function EconomyService.refresh(player: Player)
	local data = DataService.getData(player)
	if data == nil then
		return
	end
	player:SetAttribute("Cash", data.cash)
	player:SetAttribute("Pending", EconomyService.pending(data))
end

-- Server-only API for later milestones (premiere payouts, rewards).
function EconomyService.addCash(player: Player, amount: number): boolean
	local data = DataService.getData(player)
	if data == nil or amount ~= amount or amount <= 0 or amount == math.huge then
		return false
	end
	data.cash += math.floor(amount)
	DataService.markDirty(player)
	EconomyService.refresh(player)
	return true
end

-- Moves the cinema's accrued royalties into Cash. Returns the amount collected.
function EconomyService.collect(player: Player): number
	local now = os.clock()
	local last = lastCollectAttempt[player]
	if last ~= nil and now - last < Config.CollectCooldown then
		return 0
	end
	lastCollectAttempt[player] = now

	local data = DataService.getData(player)
	if data == nil then
		return 0
	end
	local amount = EconomyService.pending(data)
	if amount <= 0 then
		return 0
	end
	data.lastCollect = os.time()
	EconomyService.addCash(player, amount)
	return amount
end

function EconomyService.forget(player: Player)
	lastCollectAttempt[player] = nil
end

return EconomyService
