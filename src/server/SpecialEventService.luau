--!strict
-- Runs the special events (Shared/SpecialEvents) on this server. Every server follows the same
-- clock schedule; this module tells its clients what is live (the "SpecialEvent" attribute on
-- ReplicatedStorage, read by src/client/SpecialEventsUi) and hands out each event's reward:
--   Lucky Star     x2 casting Luck for everyone (CastingService.setEventLuck)
--   Cash Rain      coins round town: the client says which coin it touched, and we check that the
--                  player is standing there before paying
--   Mystery Crate  a free x3 Luck cast for everyone who reaches the crate after it lands
--   Spotlight      a Lucky Casting boost for the owner of a random claimed studio and everyone who
--                  visits it
--   Golden Hour    every film shoots twice as fast (MovieService.fastForward)
-- Each pickup is saved in the player's profile (eventKey, eventClaims), so rejoining or changing
-- servers during the same event cannot pick it up twice. LiveConfig can switch events off.
-- In Studio, the client shows test buttons that start any event at once (TestEvent).
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LotModels = require(ReplicatedStorage.Shared.Models.LotModels)
local MapModels = require(ReplicatedStorage.Shared.Models.MapModels)
local SpecialEvents = require(ReplicatedStorage.Shared.SpecialEvents)
local Analytics = require(script.Parent.Analytics)
local CastingService = require(script.Parent.CastingService)
local DataService = require(script.Parent.DataService)
local LiveConfig = require(script.Parent.LiveConfig)
local LotService = require(script.Parent.LotService)
local MovieService = require(script.Parent.MovieService)
local Remotes = require(script.Parent.Remotes)
local RewardService = require(script.Parent.RewardService)

local TICK = 0.5
local CLAIM_SLACK = 6 -- extra studs for lag between where the client and the server see a player
local CLAIM_COOLDOWN = 0.05
local LOT_REACH = LotModels.Layout.size / 2 + 2 -- Spotlight: standing anywhere on the lot
local TEST_LEAD = 3 -- a Studio test event starts this many seconds after its button

type Live = {
	event: SpecialEvents.Event,
	starts: number,
	ends: number,
	key: string, -- "<id>:<starts>", also saved with each player's pickups
	spots: { Vector3 }, -- Cash Rain coins, or the Mystery Crate
	lot: number?, -- Spotlight
	owner: Player?,
}

type Planned = { event: SpecialEvents.Event, starts: number, ends: number }

local live: Live? = nil
local forced: Planned? = nil -- a Studio test event
local random = Random.new()
local lastClaim: { [Player]: number } = {}
local lastSpeedUp = 0

local claimRemote = Remotes.get("EventClaim")
local resultRemote = Remotes.get("EventResult")
local testRemote = if RunService:IsStudio() then Remotes.get("TestEvent") else nil

local SpecialEventService = {}

local function disabled(): { [string]: boolean }
	local set = {}
	for _, event in SpecialEvents.List do
		if LiveConfig.eventDisabled(event.id) then
			set[event.id] = true
		end
	end
	return set
end

local function publish()
	local state = live
	if state == nil then
		ReplicatedStorage:SetAttribute("SpecialEvent", nil)
		return
	end
	local owner = state.owner
	ReplicatedStorage:SetAttribute(
		"SpecialEvent",
		HttpService:JSONEncode({
			id = state.event.id,
			starts = state.starts,
			ends = state.ends,
			lot = state.lot,
			owner = if owner ~= nil then owner.DisplayName else nil,
			ownerId = if owner ~= nil then owner.UserId else nil,
		})
	)
end

-- Luck readouts change as a Lucky Star starts and ends (Main also refreshes them every second).
local function refreshLuck()
	for _, player in Players:GetPlayers() do
		CastingService.refresh(player)
	end
end

local function rootPosition(player: Player): Vector3?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root ~= nil and root:IsA("BasePart") then
		return root.Position
	end
	return nil
end

-- Pickups are saved per event: a new event's first pickup drops the last event's.
local function hasClaimed(data: DataService.PlayerData, state: Live, item: string): boolean
	return data.eventKey == state.key and data.eventClaims[item] == true
end

local function markClaimed(player: Player, data: DataService.PlayerData, state: Live, item: string)
	if data.eventKey ~= state.key then
		data.eventKey = state.key
		data.eventClaims = {}
		Analytics.event(player, "SpecialEvent", 1, state.event.id) -- took part
	end
	data.eventClaims[item] = true
	DataService.markDirty(player)
end

local function giveSpotlight(player: Player, state: Live)
	local data = DataService.getData(player)
	if data == nil or hasClaimed(data, state, "spotlight") then
		return
	end
	markClaimed(player, data, state, "spotlight")
	local text = RewardService.apply(player, data, SpecialEvents.SpotlightReward, "TimedReward", "Spotlight")
	CastingService.refresh(player)
	resultRemote:FireClient(player, "spotlight", 1, true, text)
end

-- Returns false when the event cannot run here yet (a Spotlight with no claimed studio).
local function begin(event: SpecialEvents.Event, starts: number, ends: number): boolean
	local state: Live = { event = event, starts = starts, ends = ends, key = `{event.id}:{starts}`, spots = {} }
	if event.id == "Spotlight" then
		local owners = LotService.owners()
		if #owners == 0 then
			return false
		end
		local pick = owners[random:NextInteger(1, #owners)]
		state.lot, state.owner = pick.index, pick.owner
	elseif event.id == "CashRain" then
		state.spots = SpecialEvents.coinSpots(starts)
	elseif event.id == "MysteryCrate" then
		state.spots = { SpecialEvents.crateSpot(starts) }
	elseif event.id == "LuckyStar" then
		CastingService.setEventLuck(SpecialEvents.LuckMultiplier, ends)
	end
	live = state
	lastSpeedUp = os.clock()
	publish()
	refreshLuck()
	local owner = state.owner
	if owner ~= nil then
		giveSpotlight(owner, state) -- the star of the show
	end
	return true
end

local function finish()
	local state = live
	if state == nil then
		return
	end
	live = nil
	if state.event.id == "LuckyStar" then
		CastingService.setEventLuck(1, 0)
	end
	publish()
	refreshLuck()
end

-- What the live event does every tick.
local function update(state: Live)
	if state.event.id == "GoldenHour" then
		local clock = os.clock()
		local elapsed = clock - lastSpeedUp
		if elapsed >= 1 then
			lastSpeedUp = clock
			for _, player in Players:GetPlayers() do
				MovieService.fastForward(player, elapsed * (SpecialEvents.FilmSpeed - 1))
			end
		end
	elseif state.event.id == "Spotlight" and state.lot ~= nil then
		local center = MapModels.lotBase(state.lot).Position
		for _, player in Players:GetPlayers() do
			local at = rootPosition(player)
			if at ~= nil and math.abs(at.X - center.X) <= LOT_REACH and math.abs(at.Z - center.Z) <= LOT_REACH then
				giveSpotlight(player, state)
			end
		end
	end
end

local function tick()
	local now = os.time()
	local off = disabled()
	local event: SpecialEvents.Event?, starts: number, ends: number
	local test = forced
	if test ~= nil and now < test.ends then
		event, starts, ends = test.event, test.starts, test.ends
	else
		forced = nil
		test = nil
		event, starts, ends = SpecialEvents.at(now, off)
	end
	local key = if event ~= nil then `{event.id}:{starts}` else nil
	local state = live
	if state ~= nil and state.key ~= key then
		finish()
	end
	if event ~= nil and live == nil and now >= starts then
		begin(event, starts, ends)
	end
	state = live
	if state ~= nil then
		update(state)
	end
	-- When the next one starts, so clients can count down to it.
	local upcoming: number? = nil
	if test ~= nil then
		upcoming = if now < test.starts then test.starts else nil
	else
		local nextEvent, nextStarts = SpecialEvents.nextAfter(now, off)
		upcoming = if nextEvent ~= nil then nextStarts else nil
	end
	ReplicatedStorage:SetAttribute("SpecialEventNext", upcoming)
end

local function refuse(player: Player, kind: string, index: number, reason: string)
	resultRemote:FireClient(player, kind, index, false, reason)
end

-- A client touched a Cash Rain coin ("coin", its number) or reached the crate ("crate", 1).
local function onClaim(player: Player, kind: any, index: any)
	local clock = os.clock()
	local last = lastClaim[player]
	if last ~= nil and clock - last < CLAIM_COOLDOWN then
		return
	end
	lastClaim[player] = clock
	local state = live
	local data = DataService.getData(player)
	if state == nil or data == nil or type(kind) ~= "string" then
		return -- the event is over (clients clear their own pickups) or still loading
	end
	if type(index) ~= "number" or index ~= math.floor(index) or index < 1 or index > #state.spots then
		return
	end
	local item, radius
	if kind == "coin" and state.event.id == "CashRain" then
		item, radius = "coin" .. index, SpecialEvents.CoinRadius
	elseif kind == "crate" and state.event.id == "MysteryCrate" then
		if os.time() < state.starts + SpecialEvents.CrateLandSeconds then
			return refuse(player, kind, index, "early")
		end
		item, radius = "crate", SpecialEvents.CrateRadius
	else
		return
	end
	if hasClaimed(data, state, item) then
		return refuse(player, kind, index, "claimed")
	end
	local at = rootPosition(player)
	if at == nil or not SpecialEvents.near(at, state.spots[index], radius + CLAIM_SLACK) then
		return refuse(player, kind, index, "far")
	end
	markClaimed(player, data, state, item)
	if kind == "coin" then
		local text = RewardService.apply(player, data, SpecialEvents.CoinReward, "Gameplay", "CashRain")
		resultRemote:FireClient(player, kind, index, true, text)
	else
		CastingService.freeCast(player, SpecialEvents.CrateLuckMultiplier)
		resultRemote:FireClient(player, kind, index, true, `Free x{SpecialEvents.CrateLuckMultiplier} Luck cast!`)
	end
end

-- Studio only: start event `id` now ("Stop" ends a test event).
local function onTest(_player: Player, id: any)
	if not RunService:IsStudio() or type(id) ~= "string" then
		return
	end
	if id == "Stop" then
		forced = nil
		return
	end
	local event = SpecialEvents.get(id)
	if event ~= nil then
		local starts = os.time() + TEST_LEAD
		forced = { event = event, starts = starts, ends = starts + event.seconds }
	end
end

function SpecialEventService.start()
	claimRemote.OnServerEvent:Connect(onClaim)
	if testRemote ~= nil then
		testRemote.OnServerEvent:Connect(onTest)
	end
	task.spawn(function()
		while true do
			local ok, err = pcall(function()
				tick()
			end)
			if not ok then
				warn(`[SpecialEvents] {err}`)
			end
			task.wait(TICK)
		end
	end)
end

function SpecialEventService.forget(player: Player)
	lastClaim[player] = nil
end

return SpecialEventService
