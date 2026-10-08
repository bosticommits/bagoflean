--!strict
-- Rebirth, the game's "Sequel" (see Rebirth.luau). The client only asks: the Rebirth remote carries
-- no values, and the price, what resets and the new bonus are all decided here.
--
-- What a rebirth does, in one step with no yield: the box office waiting at the gold pad is banked
-- (at the old Cinema Size and Offline rates) and comes along as Cash; Cash goes to the starting
-- amount; every upgrade, sound stages included, goes back to level 0; the rebirth count goes up.
-- Films already filming keep going, and their stage stays open until they premiere.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Rebirth = require(ReplicatedStorage.Shared.Rebirth)
local Analytics = require(script.Parent.Analytics)
local CastingService = require(script.Parent.CastingService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local LotService = require(script.Parent.LotService)
local MovieService = require(script.Parent.MovieService)
local Remotes = require(script.Parent.Remotes)

local rebirthRemote = Remotes.get("Rebirth")
local rebirthResult = Remotes.get("RebirthResult")

local lastTry: { [Player]: number } = {}

local RebirthService = {}

-- Mirror the count to an attribute for the HUD chip and the Rebirth screen. Read-only for clients.
function RebirthService.refresh(player: Player)
	local data = DataService.getData(player)
	if data ~= nil then
		player:SetAttribute("Rebirths", data.rebirths)
	end
end

local function fail(player: Player, reason: string)
	rebirthResult:FireClient(player, { ok = false, reason = reason })
end

local function onRebirth(player: Player)
	local now = os.clock()
	local last = lastTry[player]
	if last ~= nil and now - last < Rebirth.Cooldown then
		return fail(player, "cooldown")
	end
	lastTry[player] = now

	local data = DataService.getData(player)
	if data == nil then
		return fail(player, "loading")
	end
	local cost = Rebirth.cost(data.rebirths)
	if cost == nil then
		return fail(player, "maxed")
	end
	if data.cash < cost then
		return fail(player, "cash")
	end

	-- Bank royalties at the current rate and cap first: Cinema Size and Offline are about to reset.
	EconomyService.accrue(data)
	local banked = math.floor(data.accrued)
	data.accrued -= banked
	EconomyService.spendCash(player, data.cash, "Rebirth")
	Rebirth.reset(data)
	EconomyService.addCash(player, Config.StartingCash, "Gameplay", "Rebirth")
	if banked > 0 then
		EconomyService.addCash(player, banked, "Gameplay", "BoxOffice")
	end
	DataService.markDirty(player)

	RebirthService.refresh(player)
	CastingService.refresh(player) -- Luck
	EconomyService.refresh(player) -- Cash and the box office rate
	MovieService.sync(player) -- stages and upgrades on every screen
	LotService.refresh(player) -- fewer stages, a smaller cinema and office, the sequel's name
	rebirthResult:FireClient(player, { ok = true, rebirths = data.rebirths, banked = banked })
	LotService.celebrate(player, "masterpiece")
	Remotes.announce(`{player.DisplayName} made a sequel: {player.DisplayName} Pictures{Rebirth.sequelSuffix(data.rebirths)}!`)
	Analytics.event(player, "Rebirth", data.rebirths)
end

-- Studio only, for playtests: a rebirth needs far more Cash than a quick test earns. From the
-- command bar in Server view:
--   game.ServerStorage.StudioGiveCash:Invoke(game.Players:GetPlayers()[1], 300000)
-- (A BindableFunction, because the command bar does not share the game's copy of EconomyService.)
-- Never created on live servers.
local function addStudioCashTool()
	local tool = Instance.new("BindableFunction")
	tool.Name = "StudioGiveCash"
	tool.OnInvoke = function(player: Player, amount: number): boolean
		return EconomyService.addCash(player, amount, "Gameplay", "StudioTest")
	end
	tool.Parent = ServerStorage
end

function RebirthService.start()
	rebirthRemote.OnServerEvent:Connect(onRebirth)
	if RunService:IsStudio() then
		addStudioCashTool()
	end
end

function RebirthService.forget(player: Player)
	lastTry[player] = nil
end

return RebirthService
