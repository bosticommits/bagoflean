--!strict
-- Casting Call: the server rolls, charges Cash and grants the actor. The client only asks.
-- Remotes carry no gameplay values from the client: Cast has no arguments, RosterRequest has none.
--
-- CastResult payload (server -> client), every field decided here:
--   { ok = false, reason = "cooldown" | "loading" | "invalid" | "fame" | "cash" }
--   { ok = true,
--     actorId, variantId: string, isNew: boolean, count: number (copies owned now),
--     discovered: boolean,         -- same as guarantee == "hotStart" (the "DISCOVERED!" badge)
--     guarantee: string?,          -- the guarantee that covered this cast: "hotStart" | "pity" |
--                                  -- "firstSuperstar" | nil. Set even when the natural roll beat it.
--     tease: string?,              -- "nearMiss": build the reveal up like a Superstar, then land on
--                                  -- the real result (presentation only; never a Superstar itself)
--     pity: { agency: string, tier: string, count: number, every: number },
--                                  -- that agency's meter AFTER this cast: `every - count` casts
--                                  -- until a guaranteed `tier` (count 0 = just reset)
--   }
-- The meters are also mirrored as player attributes Pity<agencyId> (e.g. PityOpen) for the HUD.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Actors = require(ReplicatedStorage.Shared.Actors)
local Config = require(ReplicatedStorage.Shared.Config)
local Events = require(ReplicatedStorage.Shared.Events)
local FilmSets = require(ReplicatedStorage.Shared.FilmSets)
local Mascots = require(ReplicatedStorage.Shared.Mascots)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local LiveConfig = require(script.Parent.LiveConfig)
local LotService = require(script.Parent.LotService)
local QuestTracker = require(script.Parent.QuestTracker)
local Remotes = require(script.Parent.Remotes)

local random = Random.new()
local lastCast: { [Player]: number } = {}
local lastRosterRequest: { [Player]: number } = {}
local lastCooldownReply: { [Player]: number } = {}
local lastTick: { [Player]: number } = {} -- os.clock() of the last playtime count
local COOLDOWN_REPLY_INTERVAL = 1 -- a spammer gets at most one "cooldown" answer per second
-- A special event's casting Luck for everyone (the Lucky Star), until an os.time() stamp.
local eventLuck, eventLuckUntil = 1, 0

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
-- boost, Award Night, a Lucky Star special event and a Luck mascot. Premieres use the stat Luck
-- only.
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
	if eventLuckUntil > now then
		luck *= eventLuck
	end
	luck *= 1 + Mascots.boost(data, "luck", now)
	luck *= 1 + FilmSets.luck(data)
	return luck
end

-- Multiplies everyone's casting Luck by `multiplier` until `untilTime` (os.time()); it switches
-- itself off then, even if nobody calls this again. SpecialEventService runs the Lucky Star.
function CastingService.setEventLuck(multiplier: number, untilTime: number)
	eventLuck, eventLuckUntil = multiplier, untilTime
end

-- Mirror casting luck to an attribute so the odds panel can compute the same numbers the roll uses.
-- Called every second from Main, so boosts and Award Night show up as they start and end.
function CastingService.refresh(player: Player)
	player:SetAttribute("Luck", CastingService.castLuck(player))
	local data = DataService.getData(player)
	if data ~= nil then
		player:SetAttribute("LuckBoostUntil", data.luckBoostUntil)
		player:SetAttribute("HotStart", data.hotStart)
		for _, agency in Actors.Agencies do
			player:SetAttribute("Pity" .. agency.id, data.pity[agency.id] or 0)
		end
		-- Seconds played, counted here (never from the client); a long stall counts at most 5 s.
		local now = os.clock()
		data.played += math.clamp(now - (lastTick[player] or now), 0, 5)
		lastTick[player] = now
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

-- The limited actor that can be cast right now: the one of this week's seasonal Film Festival
-- (Actors.Limited), or nil in an ordinary week or while LiveConfig has festivals switched off.
function CastingService.limitedInSeason(): Actors.Actor?
	local festival = QuestTracker.festival(os.time())
	return if festival ~= nil then Actors.limitedFor(festival.season) else nil
end

-- Rolls an actor from `agency` at `luck`, grants it and shows the reveal. Never yields.
local function rollAndGrant(player: Player, agency: Actors.Agency, luck: number)
	local data = DataService.getData(player)
	if data == nil then
		return
	end
	local limited = CastingService.limitedInSeason()
	local actor, variant, guarantee, tease = Actors.castWithGuarantees(data, agency, function(floorTier)
		return Actors.roll(random, luck, agency.minTier, floorTier, limited)
	end, LiveConfig.switchedOff("FirstSuperstar"))
	player:SetAttribute("HotStart", data.hotStart)
	player:SetAttribute("Pity" .. agency.id, data.pity[agency.id])
	local isNew, count = CastingService.grant(player, actor.id, variant.id)
	castResult:FireClient(player, {
		ok = true,
		actorId = actor.id,
		variantId = variant.id,
		isNew = isNew,
		count = count,
		discovered = guarantee == "hotStart",
		guarantee = guarantee,
		tease = tease,
		pity = { agency = agency.id, tier = agency.pity, count = data.pity[agency.id], every = Actors.PityEvery },
	})
	if tease ~= nil then
		Analytics.event(player, "NearMissTease", math.floor(data.played), actor.tier)
	elseif guarantee == "firstSuperstar" then
		Analytics.event(player, "FirstSuperstar", math.floor(data.played), actor.tier, variant.id)
	end
	-- Counted first, so a slow or failing lot redraw below can never lose a cast's progress.
	QuestTracker.track(player, "cast")
	sendRoster(player)
	LotService.refresh(player) -- the billboard may have a new top star
	Analytics.onboarding(player, Analytics.Steps.FirstCast)
	if actor.tier == "Superstar" or actor.tier == "Legend" or actor.tier == "Icon" then
		Analytics.event(player, "RarePull", 1, actor.tier, variant.id)
		-- World reaction for everyone: sky flash, fireworks over the lot, a shake nearby (Fx.celebrate).
		LotService.celebrate(player, "pull", actor.tier)
	end
	if actor.tier == "Legend" or actor.tier == "Icon" then
		Remotes.announce(`{player.DisplayName} cast {actor.name} ({actor.tier})!`)
	elseif actor.season ~= nil then
		Analytics.event(player, "LimitedPull", 1, actor.id, variant.id)
		if isNew then
			Remotes.announce(`{player.DisplayName} cast the limited {actor.name}!`)
		end
	end
end

-- A season's limited actor for winning its Film Festival (SpecialEventService): one Normal copy,
-- with the roster and lot updated. Returns the actor given, or nil.
function CastingService.giveLimited(player: Player, seasonId: string?): Actors.Actor?
	local actor = Actors.limitedFor(seasonId)
	if actor == nil or DataService.getData(player) == nil then
		return nil
	end
	CastingService.grant(player, actor.id, "Normal")
	sendRoster(player)
	LotService.refresh(player)
	return actor
end

local function onCast(player: Player, agencyId: any)
	local now = os.clock()
	local last = lastCast[player]
	if last ~= nil and now - last < Config.CastCooldown then
		-- A rejection only happens within the cooldown of a cast that was answered, so the client is
		-- never left waiting; the extra "cooldown" answer is limited to one per second.
		local lastReply = lastCooldownReply[player]
		if lastReply == nil or now - lastReply >= COOLDOWN_REPLY_INTERVAL then
			lastCooldownReply[player] = now
			castResult:FireClient(player, { ok = false, reason = "cooldown" })
		end
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
	rollAndGrant(player, agency, CastingService.castLuck(player))
end

-- A free Casting Call (the Mystery Crate): the best agency the player's Fame has unlocked, with
-- `luckMultiplier` times their casting Luck. The client shows it like any other cast.
function CastingService.freeCast(player: Player, luckMultiplier: number): boolean
	local data = DataService.getData(player)
	if data == nil then
		return false
	end
	local agency = Actors.getAgency("Open") :: Actors.Agency
	for _, candidate in Actors.Agencies do
		if data.fame >= candidate.fame then
			agency = candidate
		end
	end
	rollAndGrant(player, agency, CastingService.castLuck(player) * luckMultiplier)
	return true
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
	lastCooldownReply[player] = nil
	lastTick[player] = nil
end

return CastingService
