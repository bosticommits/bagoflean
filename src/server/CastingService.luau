--!strict
-- Casting Call: the server rolls, charges Cash and grants the actor. The client only asks.
-- Remotes carry no gameplay values from the client: Cast has no arguments, RosterRequest has none.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Actors = require(ReplicatedStorage.Shared.Actors)
local Config = require(ReplicatedStorage.Shared.Config)
local Events = require(ReplicatedStorage.Shared.Events)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local LotService = require(script.Parent.LotService)
local QuestTracker = require(script.Parent.QuestTracker)
local Remotes = require(script.Parent.Remotes)

local random = Random.new()
local lastCast: { [Player]: number } = {}
local lastRosterRequest: { [Player]: number } = {}

local castRemote = Remotes.get("Cast")
local castResult = Remotes.get("CastResult")
local rosterRequest = Remotes.get("RosterRequest")
local rosterSync = Remotes.get("RosterSync")

local CastingService = {}

function CastingService.getLuck(player: Player): number
	local data = DataService.getData(player)
	if data == nil then
		return Config.BaseLuck
	end
	return Upgrades.luck(data)
end

-- Luck for Casting Calls: the stat Luck above times the 2x Luck pass, an active Lucky Casting
-- boost, and Award Night. Premieres use the stat Luck only.
function CastingService.castLuck(player: Player): number
	local data = DataService.getData(player)
	if data == nil then
		return Config.BaseLuck
	end
	local now = os.time()
	local luck = Upgrades.luck(data)
	if data.passes.Luck2x then
		luck *= Config.PassLuckMultiplier
	end
	if data.luckBoostUntil > now then
		luck *= Config.BoostLuckMultiplier
	end
	if Events.awardNight(now) then
		luck *= Config.AwardNightLuckMultiplier
	end
	return luck
end

-- Mirror casting luck to an attribute so the odds panel can compute the same numbers the roll uses.
-- Called every second from Main, so boosts and Award Night show up as they start and end.
function CastingService.refresh(player: Player)
	player:SetAttribute("Luck", CastingService.castLuck(player))
	local data = DataService.getData(player)
	if data ~= nil then
		player:SetAttribute("LuckBoostUntil", data.luckBoostUntil)
	end
end

local function sendRoster(player: Player)
	local data = DataService.getData(player)
	if data == nil then
		return
	end
	rosterSync:FireClient(player, data.roster, data.index)
end

-- Server-only grant used by casting (and later by rewards).
function CastingService.grant(player: Player, actorId: string, variantId: string): (boolean, number)
	local data = DataService.getData(player)
	if data == nil or Actors.getActor(actorId) == nil or Actors.getVariant(variantId) == nil then
		return false, 0
	end
	local key = Actors.key(actorId, variantId)
	local isNew = data.index[key] ~= true
	data.index[key] = true
	data.roster[key] = (data.roster[key] or 0) + 1
	DataService.markDirty(player)
	return isNew, data.roster[key]
end

local function onCast(player: Player, agencyId: any)
	local now = os.clock()
	local last = lastCast[player]
	if last ~= nil and now - last < Config.CastCooldown then
		-- Always answer so the client never waits on a result that will not come.
		castResult:FireClient(player, { ok = false, reason = "cooldown" })
		return
	end
	lastCast[player] = now

	local data = DataService.getData(player)
	if data == nil then
		castResult:FireClient(player, { ok = false, reason = "loading" })
		return
	end
	-- The client names an agency (or nothing for Open Casting); price, Fame gate and pool are ours.
	local agency = Actors.getAgency("Open")
	if agencyId ~= nil then
		agency = if type(agencyId) == "string" and #agencyId <= 16 then Actors.getAgency(agencyId) else nil
	end
	if agency == nil then
		castResult:FireClient(player, { ok = false, reason = "invalid" })
		return
	end
	if data.fame < agency.fame then
		castResult:FireClient(player, { ok = false, reason = "fame" })
		return
	end
	-- Charge, roll and grant with no yield in between, so nothing can interleave.
	if not EconomyService.spendCash(player, agency.cost, "Casting:" .. agency.id) then
		castResult:FireClient(player, { ok = false, reason = "cash" })
		return
	end
	local actor, variant = Actors.roll(random, CastingService.castLuck(player), agency.minTier)
	local isNew, count = CastingService.grant(player, actor.id, variant.id)
	castResult:FireClient(player, {
		ok = true,
		actorId = actor.id,
		variantId = variant.id,
		isNew = isNew,
		count = count,
	})
	sendRoster(player)
	LotService.refresh(player) -- the billboard may have a new top star
	Analytics.onboarding(player, Analytics.Steps.FirstCast)
	QuestTracker.track(player, "cast")
	if actor.tier == "Superstar" or actor.tier == "Legend" or actor.tier == "Icon" then
		Analytics.event(player, "RarePull", 1, actor.tier, variant.id)
	end
	if actor.tier == "Legend" or actor.tier == "Icon" then
		Remotes.announce(`{player.DisplayName} cast {actor.name} ({actor.tier})!`)
		LotService.celebrate(player, "pull")
	end
end

local function onRosterRequest(player: Player)
	local now = os.clock()
	local last = lastRosterRequest[player]
	if last ~= nil and now - last < 1 then
		return
	end
	lastRosterRequest[player] = now
	sendRoster(player)
end

function CastingService.start()
	castRemote.OnServerEvent:Connect(onCast)
	rosterRequest.OnServerEvent:Connect(onRosterRequest)
end

function CastingService.forget(player: Player)
	lastCast[player] = nil
	lastRosterRequest[player] = nil
end

return CastingService
