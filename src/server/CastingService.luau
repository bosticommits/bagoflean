--!strict
-- Casting Call: the server rolls, charges Cash and grants the actor. The client only asks.
-- Remotes carry no gameplay values from the client: Cast has no arguments, RosterRequest has none.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Actors = require(ReplicatedStorage.Shared.Actors)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local random = Random.new()
local lastCast: { [Player]: number } = {}
local lastRosterRequest: { [Player]: number } = {}

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local castRemote = Instance.new("RemoteEvent")
castRemote.Name = "Cast"
castRemote.Parent = remotes
local castResult = Instance.new("RemoteEvent")
castResult.Name = "CastResult"
castResult.Parent = remotes
local rosterRequest = Instance.new("RemoteEvent")
rosterRequest.Name = "RosterRequest"
rosterRequest.Parent = remotes
local rosterSync = Instance.new("RemoteEvent")
rosterSync.Name = "RosterSync"
rosterSync.Parent = remotes

local CastingService = {}

function CastingService.getLuck(_player: Player): number
	return Config.BaseLuck
end

-- Mirror luck to an attribute so the odds panel can compute the same numbers the roll uses.
function CastingService.refresh(player: Player)
	player:SetAttribute("Luck", CastingService.getLuck(player))
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

local function onCast(player: Player)
	local now = os.clock()
	local last = lastCast[player]
	if last ~= nil and now - last < Config.CastCooldown then
		-- Always answer so the client never waits on a result that will not come.
		castResult:FireClient(player, { ok = false, reason = "cooldown" })
		return
	end
	lastCast[player] = now

	if DataService.getData(player) == nil then
		castResult:FireClient(player, { ok = false, reason = "loading" })
		return
	end
	-- Charge, roll and grant with no yield in between, so nothing can interleave.
	if not EconomyService.spendCash(player, Config.CastCost) then
		castResult:FireClient(player, { ok = false, reason = "cash" })
		return
	end
	local actor, variant = Actors.roll(random, CastingService.getLuck(player))
	local isNew, count = CastingService.grant(player, actor.id, variant.id)
	castResult:FireClient(player, {
		ok = true,
		actorId = actor.id,
		variantId = variant.id,
		isNew = isNew,
		count = count,
	})
	sendRoster(player)
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
	remotes.Parent = ReplicatedStorage
	castRemote.OnServerEvent:Connect(onCast)
	rosterRequest.OnServerEvent:Connect(onRosterRequest)
end

function CastingService.forget(player: Player)
	lastCast[player] = nil
	lastRosterRequest[player] = nil
end

return CastingService
