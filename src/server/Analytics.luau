--!strict
-- Basic analytics through Roblox's AnalyticsService (Creator Hub > Analytics). Server only, so
-- exploiters cannot send fake events, and logged on success, never on attempt.
--
-- - Economy: every Cash source and sink, batched per player and flushed once a minute (and on
--   leave), because collecting can happen several times a second and the API is rate limited.
-- - Onboarding funnel: the first-session steps, logged once per new player (see Steps).
-- - Custom events: a few low-frequency moments (rare pulls, premieres, rewards, purchases).
-- Analytics is never the source of truth for anything; a failed log is ignored.
local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")

local DataService = require(script.Parent.DataService)

local CURRENCY = "Cash"
local FLUSH_SECONDS = 60

local FIELD1 = Enum.AnalyticsCustomFieldKeys.CustomField01.Name
local FIELD2 = Enum.AnalyticsCustomFieldKeys.CustomField02.Name

type Batch = { flow: Enum.AnalyticsEconomyFlowType, tx: string, sku: string, amount: number }

local batches: { [Player]: { [string]: Batch } } = {}
local balances: { [Player]: number } = {}

local Analytics = {}

-- Onboarding funnel steps, in order. Roblox back-fills skipped steps.
Analytics.Steps = table.freeze({
	Joined = 1,
	ClaimedLot = 2,
	FirstCast = 3,
	FirstScript = 4,
	FirstFilm = 5,
	FirstPremiere = 6,
	FirstCollect = 7,
	TutorialDone = 8,
})
local stepNames: { [number]: string } = {}
for name: string, step: number in Analytics.Steps :: any do
	stepNames[step] = name
end

local function try(fn: () -> ())
	local ok, err = pcall(function()
		fn()
	end)
	if not ok then
		warn(`[Analytics] {err}`)
	end
end

local function flush(player: Player)
	local batch = batches[player]
	if batch == nil then
		return
	end
	batches[player] = {}
	local balance = balances[player] or 0
	for _, entry in batch do
		try(function()
			AnalyticsService:LogEconomyEvent(player, entry.flow, CURRENCY, entry.amount, balance, entry.tx, entry.sku)
		end)
	end
end

-- `source` true for Cash coming in. `tx` is an Enum.AnalyticsEconomyTransactionType name
-- (Gameplay, Shop, IAP, TimedReward, Onboarding); `sku` names what it was for (keep it low-cardinality).
function Analytics.economy(player: Player, source: boolean, amount: number, balance: number, tx: string, sku: string)
	if amount <= 0 or amount ~= amount then
		return
	end
	local flow = if source then Enum.AnalyticsEconomyFlowType.Source else Enum.AnalyticsEconomyFlowType.Sink
	local key = `{flow.Name}|{tx}|{sku}`
	local batch = batches[player]
	if batch == nil then
		batch = {}
		batches[player] = batch
	end
	local entry = batch[key]
	if entry == nil then
		batch[key] = { flow = flow, tx = tx, sku = sku, amount = amount }
	else
		entry.amount += amount
	end
	balances[player] = balance
end

-- A custom event with an optional value and up to two breakdown fields.
function Analytics.event(player: Player, name: string, value: number?, field1: string?, field2: string?)
	local fields: { [string]: string } = {}
	if field1 ~= nil then
		fields[FIELD1] = field1
	end
	if field2 ~= nil then
		fields[FIELD2] = field2
	end
	try(function()
		AnalyticsService:LogCustomEvent(player, name, value or 1, fields)
	end)
end

-- Logs an onboarding step the first time a new player reaches it (saved, so never twice).
function Analytics.onboarding(player: Player, step: number)
	local data = DataService.getData(player)
	if data == nil or step <= data.funnel then
		return
	end
	data.funnel = step
	DataService.markDirty(player)
	try(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, stepNames[step])
	end)
end

function Analytics.start()
	task.spawn(function()
		while true do
			task.wait(FLUSH_SECONDS)
			for _, player in Players:GetPlayers() do
				flush(player)
			end
		end
	end)
end

function Analytics.forget(player: Player)
	flush(player)
	batches[player] = nil
	balances[player] = nil
end

return Analytics
