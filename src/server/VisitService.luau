--!strict
-- Studio visits and applause (rules in Shared/Visits). Players jump to any claimed studio from the
-- Visit menu (or just walk there). Standing on someone else's lot for a few seconds is a tour: the
-- owner hears about it, the weekly "tour studios" quest counts it (once per studio per UTC day),
-- and the visitor can applaud.
--
-- Applause is cosmetic: it adds one to the studio's count (saved on the owner's profile, shown on
-- the gate and in the Visit menu) and pays nobody. A visitor's applause counts once per studio per
-- UTC day, saved on the visitor's profile, so rejoining or changing servers doesn't reset it; after
-- that the button still claps for the show. Every check is made here from where the server sees
-- the player: the remotes carry no values except which lot to jump to.
--
-- Premieres on a lot are shown to the people touring it (LotPremiere), and the owner hears how big
-- the audience was. Player attributes tell the visitor's tour card what it may do:
--   TouringLot     the lot index while standing on someone else's studio
--   TourCounted    true once the stay is long enough to count (applause allowed)
--   TourApplauded  true when their applause for this studio already counted today
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MapModels = require(ReplicatedStorage.Shared.Models.MapModels)
local Rewards = require(ReplicatedStorage.Shared.Rewards)
local Visits = require(ReplicatedStorage.Shared.Visits)
local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local LotService = require(script.Parent.LotService)
local QuestTracker = require(script.Parent.QuestTracker)
local Remotes = require(script.Parent.Remotes)

local TICK = 0.5
local AUDIENCE_NOTICE_DELAY = 6 -- after the owner's own premiere reveal has had its moment

type Tour = { lot: number, owner: Player, since: number, counted: boolean }

local tours: { [Player]: Tour } = {}
local lastApplaud: { [Player]: number } = {}
local lastJump: { [Player]: number } = {}

local visitRemote = Remotes.get("VisitStudio") -- client -> server: lot index to jump to
local applaudRemote = Remotes.get("Applaud") -- client -> server: no arguments
local applauseRemote = Remotes.get("Applause") -- server -> all: lot, clapper UserId, counted, total
local noticeRemote = Remotes.get("VisitNotice") -- server -> owner: a line to show
local arrivedRemote = Remotes.get("VisitArrived") -- server -> visitor: lot index, after a jump
local premiereRemote = Remotes.get("LotPremiere") -- server -> all: lot, title, result id

local bases: { CFrame } = {}
for index = 1, Config.LotCount do
	bases[index] = MapModels.lotBase(index)
end

local VisitService = {}

local function rootPart(player: Player): BasePart?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root ~= nil and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- Today's visit record for `data`, started fresh on a new UTC day.
local function record(data: DataService.PlayerData): Visits.Record
	local today = Rewards.today(os.time())
	if data.visits.day ~= today then
		data.visits = Visits.fresh(nil, today)
	end
	return data.visits
end

local function setTourAttributes(player: Player, tour: Tour?)
	if tour == nil then
		player:SetAttribute("TouringLot", nil)
		player:SetAttribute("TourCounted", nil)
		player:SetAttribute("TourApplauded", nil)
		return
	end
	local applauded = false
	local data = DataService.getData(player)
	if data ~= nil then
		applauded = record(data).applauded[Visits.key(tour.owner.UserId)] == true
	end
	player:SetAttribute("TouringLot", tour.lot)
	player:SetAttribute("TourCounted", tour.counted)
	player:SetAttribute("TourApplauded", applauded)
end

-- The stay is long enough: count the tour once per studio per day.
local function counted(visitor: Player, tour: Tour)
	tour.counted = true
	local data = DataService.getData(visitor)
	if data ~= nil then
		local today = record(data)
		local key = Visits.key(tour.owner.UserId)
		if not today.toured[key] then
			today.toured[key] = true
			DataService.markDirty(visitor)
			QuestTracker.track(visitor, "visit")
			Analytics.event(visitor, "StudioVisit", 1)
			noticeRemote:FireClient(tour.owner, `{visitor.DisplayName} is touring your studio!`)
		end
	end
	setTourAttributes(visitor, tour)
end

-- Who stands where: start, keep or end each player's tour.
local function update()
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local root = rootPart(player)
		local index = if root ~= nil then Visits.lotAt(root.Position, bases) else nil
		local owner = if index ~= nil then LotService.ownerOf(index) else nil
		local tour = tours[player]
		if index == nil or owner == nil or owner == player then
			if tour ~= nil then
				tours[player] = nil
				setTourAttributes(player, nil)
			end
		elseif tour == nil or tour.lot ~= index or tour.owner ~= owner then
			local started: Tour = { lot = index, owner = owner, since = now, counted = false }
			tours[player] = started
			setTourAttributes(player, started)
		elseif not tour.counted and now - tour.since >= Visits.DwellSeconds then
			counted(player, tour)
		end
	end
end

-- What each studio is filming, for the Visit menu's "Premiere ready!" and countdowns. Clapping and
-- Golden Hour change end times without a lot redraw, so this is kept fresh here.
local function publishStatus()
	for index = 1, Config.LotCount do
		local model = LotService.model(index)
		if model == nil then
			continue
		end
		local owner = LotService.ownerOf(index)
		local data = if owner ~= nil then DataService.getData(owner) else nil
		local soonest = if data ~= nil then Visits.nextPremiere(data.films) else nil
		if model:GetAttribute("NextPremiere") ~= soonest then
			model:SetAttribute("NextPremiere", soonest)
		end
	end
end

local function onApplaud(player: Player)
	local clock = os.clock()
	local last = lastApplaud[player]
	if last ~= nil and clock - last < Visits.ApplaudCooldown then
		return
	end
	local tour = tours[player]
	-- Only on a tour that has counted, of a studio its owner still holds.
	if tour == nil or not tour.counted or LotService.ownerOf(tour.lot) ~= tour.owner then
		return
	end
	local data = DataService.getData(player)
	local ownerData = DataService.getData(tour.owner)
	if data == nil or ownerData == nil then
		return
	end
	lastApplaud[player] = clock
	local today = record(data)
	local key = Visits.key(tour.owner.UserId)
	local counts = not today.applauded[key]
	if counts then
		today.applauded[key] = true
		ownerData.likes += 1
		DataService.markDirty(player)
		DataService.markDirty(tour.owner)
		LotService.refresh(tour.owner)
		setTourAttributes(player, tour)
		Analytics.event(player, "Applause", 1)
		noticeRemote:FireClient(tour.owner, `{player.DisplayName} applauded your studio! {Visits.applauseText(ownerData.likes)}`)
	end
	applauseRemote:FireAllClients(tour.lot, player.UserId, counts, ownerData.likes)
end

-- Jump to lot `index`: any claimed studio, or your own (home).
local function onVisit(player: Player, index: any)
	if type(index) ~= "number" or index ~= math.floor(index) or index < 1 or index > Config.LotCount then
		return
	end
	local clock = os.clock()
	local last = lastJump[player]
	if last ~= nil and clock - last < Visits.TeleportCooldown then
		return
	end
	if LotService.ownerOf(index) == nil then
		return -- a free lot: nothing to visit (the client only offers claimed ones)
	end
	local character = player.Character
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	if character == nil or humanoid == nil or humanoid.Health <= 0 or rootPart(player) == nil then
		return
	end
	lastJump[player] = clock
	humanoid.Sit = false
	character:PivotTo(Visits.arrival(bases[index]))
	arrivedRemote:FireClient(player, index)
end

-- `owner` just premiered a film: show it to the people on their lot and tell the owner about the
-- audience. Called by MovieService after the result is decided.
function VisitService.premiered(owner: Player, title: string, resultId: string)
	local index = LotService.indexOf(owner)
	if index == nil then
		return
	end
	premiereRemote:FireAllClients(index, title, resultId)
	local audience = 0
	for _, tour in tours do
		if tour.lot == index and tour.owner == owner then
			audience += 1
		end
	end
	if audience > 0 then
		local text = if audience == 1 then "1 visitor watched your premiere!" else `{audience} visitors watched your premiere!`
		task.delay(AUDIENCE_NOTICE_DELAY, function()
			if owner.Parent == Players then
				noticeRemote:FireClient(owner, text)
			end
		end)
	end
end

function VisitService.start()
	applaudRemote.OnServerEvent:Connect(onApplaud)
	visitRemote.OnServerEvent:Connect(onVisit)
	task.spawn(function()
		while true do
			local ok, err = pcall(function()
				update()
				publishStatus()
			end)
			if not ok then
				warn(`[VisitService] {err}`)
			end
			task.wait(TICK)
		end
	end)
end

function VisitService.forget(player: Player)
	tours[player] = nil
	lastApplaud[player] = nil
	lastJump[player] = nil
	-- A visitor on this player's studio is no longer touring it.
	for visitor, tour in tours do
		if tour.owner == player then
			tours[visitor] = nil
			setTourAttributes(visitor, nil)
		end
	end
end

return VisitService
