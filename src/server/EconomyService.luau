--!strict
-- The only place Cash changes. Clients never send amounts; they can only ask to collect.
--
-- Cinema royalties: the rate is a free trickle plus a share of every movie in the cinema. Because
-- the rate changes when a movie premieres, earnings are banked into `data.accrued` at the old
-- rate first (see accrue), then the rate changes. The bank is capped at OfflineCapSeconds of income.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
local DataService = require(script.Parent.DataService)

local lastCollectAttempt: { [Player]: number } = {}

local EconomyService = {}

-- Cash per second the cinema earns right now.
function EconomyService.rate(data: DataService.PlayerData): number
	local royalties = 0
	for _, movie in data.cinema do
		royalties += movie.payout * Config.RoyaltyRate
	end
	return Config.CinemaIncomePerSecond + royalties * Upgrades.royaltyMultiplier(data)
end

local function bankedAt(data: DataService.PlayerData, now: number): number
	local elapsed = math.max(now - data.lastCollect, 0)
	local rate = EconomyService.rate(data)
	return math.min(data.accrued + elapsed * rate, Upgrades.offlineCap(data) * rate)
end

-- Moves royalties earned so far into the bank. Call before anything that changes the rate.
function EconomyService.accrue(data: DataService.PlayerData)
	local now = os.time()
	data.accrued = bankedAt(data, now)
	data.lastCollect = now
end

function EconomyService.pending(data: DataService.PlayerData): number
	return math.floor(bankedAt(data, os.time()))
end

-- Mirror server-owned numbers to attributes so the HUD can read them. Read-only for clients.
function EconomyService.refresh(player: Player)
	local data = DataService.getData(player)
	if data == nil then
		return
	end
	player:SetAttribute("Cash", data.cash)
	player:SetAttribute("Pending", EconomyService.pending(data))
	player:SetAttribute("Rate", math.floor(EconomyService.rate(data) * 100) / 100)
	player:SetAttribute("Fame", data.fame)
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

-- Removes Cash if the player can afford it. Returns whether it was spent.
function EconomyService.spendCash(player: Player, amount: number): boolean
	local data = DataService.getData(player)
	if data == nil or amount ~= amount or amount <= 0 or data.cash < amount then
		return false
	end
	data.cash -= math.floor(amount)
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
	EconomyService.accrue(data)
	local amount = math.floor(data.accrued)
	if amount <= 0 then
		return 0
	end
	data.accrued -= amount -- keep the fractional remainder
	EconomyService.addCash(player, amount)
	return amount
end

function EconomyService.forget(player: Player)
	lastCollectAttempt[player] = nil
end

return EconomyService
