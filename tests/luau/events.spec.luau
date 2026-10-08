local roblox = require("@lune/roblox")

local H = require("./harness")
local Events = H.require("Events")
local EventModels = H.require("Models/EventModels")
local IconModels = H.require("Models/IconModels")
local LotModels = H.require("Models/LotModels")
local MapModels = H.require("Models/MapModels")
local Rewards = H.require("Rewards")
local SpecialEvents = H.require("SpecialEvents")
local test, expect, equal = H.test, H.expect, H.equal

local Vector3 = roblox.Vector3
local SLOT = SpecialEvents.SlotSeconds
local GAP = SpecialEvents.Gap
local FIRST_SLOT = 1_950_000 -- October 2025 in 15-minute slots
local SLOTS = 3000 -- about a month

-- [from, to) of every Award Night that could come near [from, to).
local function nearAwardNight(from: number, to: number): boolean
	local period, length = Events.AwardNightPeriod, Events.AwardNightLength
	for n = (from - length) // period - 1, to // period + 1 do
		local starts = n * period
		if starts < to and starts + length > from then
			return true
		end
	end
	return false
end

test("events have unique ids, a banner and a length that fits a slot", function()
	local seen = {}
	local icons = {}
	for _, id in IconModels.Ids do
		icons[id] = true
	end
	expect(#SpecialEvents.List >= 4, "at least four events")
	for _, event in SpecialEvents.List do
		expect(not seen[event.id], `duplicate event {event.id}`)
		seen[event.id] = true
		equal(SpecialEvents.get(event.id), event, `lookup {event.id}`)
		expect(event.name == string.upper(event.name) and #event.name > 0, `{event.id} name is a capital title`)
		expect(#event.tagline > 0, `{event.id} tagline`)
		expect(icons[event.icon], `{event.id} icon {event.icon} is an IconModels id`)
		expect(#event.colors >= 2, `{event.id} gradient`)
		-- It must fit a slot that starts with Award Night, with the gaps on both sides.
		local room = SLOT - Events.AwardNightLength - 3 * GAP
		expect(event.seconds >= 30 and event.seconds <= room, `{event.id} lasts {event.seconds} s`)
	end
	expect(SLOT * 2 <= Events.AwardNightPeriod or Events.AwardNightPeriod % SLOT == 0, "slots line up with Award Night")
end)

test("rewards are real and modest", function()
	expect(SpecialEvents.LuckMultiplier > 1 and SpecialEvents.LuckMultiplier <= 3, "Lucky Star luck")
	expect(SpecialEvents.CrateLuckMultiplier > 1 and SpecialEvents.CrateLuckMultiplier <= 5, "crate luck")
	expect(SpecialEvents.FilmSpeed > 1 and SpecialEvents.FilmSpeed <= 3, "Golden Hour speed")
	expect(SpecialEvents.CrateLandSeconds < SpecialEvents.get("MysteryCrate").seconds / 2, "the crate lands early")
	expect((SpecialEvents.SpotlightReward.luckMinutes or 0) > 0, "Spotlight gives Luck")
	-- Cash Rain coins grow with the player: never less than the floor, then cinema income or Fame.
	local floor = SpecialEvents.CoinCash
	equal(SpecialEvents.coinCash(0, 0), floor, "a new player's coin")
	expect(SpecialEvents.coinCash(1000, 0) > floor, "coins follow cinema income")
	expect(SpecialEvents.coinCash(0, 50000) > SpecialEvents.coinCash(0, 5000), "coins follow Fame")
	equal(SpecialEvents.coinCash(0 / 0, 0 / 0), floor, "bad numbers pay the floor")
	equal(SpecialEvents.coinCash(math.huge, 0), floor, "bad numbers pay the floor")
	-- A whole Cash Rain stays a treat, not a shortcut: at a Fame where income is ~3,000 Cash a
	-- minute (end of day one in the economy sim), all 16 coins are a few minutes of income at most.
	local rain = SpecialEvents.coinCash(110 / 60, 4000) * SpecialEvents.CoinCount
	expect(rain > 2917 / 2 and rain <= 2917 * 4, `a day-one Cash Rain gives {rain}`)
	equal(Rewards.describe({ cash = SpecialEvents.coinCash(0, 12345) }, 0), "$1,234", "coin text")
end)

test("the schedule keeps clear of Award Night and the slot edges", function()
	for slot = FIRST_SLOT, FIRST_SLOT + SLOTS do
		local event, starts = SpecialEvents.forSlot(slot)
		expect(event ~= nil, `slot {slot} has an event`)
		assert(event ~= nil)
		local ends = starts + event.seconds
		expect(starts >= slot * SLOT + GAP, `slot {slot} starts too early`)
		expect(ends <= (slot + 1) * SLOT - GAP, `slot {slot} ends too late`)
		expect(starts == math.floor(starts), "whole seconds")
		expect(not nearAwardNight(starts - GAP, ends + GAP), `slot {slot} ({event.id} at {starts}) is near Award Night`)
	end
end)

test("start times vary inside the slot", function()
	local offsets = {}
	for slot = FIRST_SLOT, FIRST_SLOT + 200 do
		local _, starts = SpecialEvents.forSlot(slot)
		offsets[starts - slot * SLOT] = true
	end
	local count = 0
	for _ in offsets do
		count += 1
	end
	expect(count > 100, `only {count} different start times`)
end)

test("every event comes up as often, never twice in a row", function()
	local counts: { [string]: number } = {}
	local previous = nil
	for slot = FIRST_SLOT, FIRST_SLOT + SLOTS - 1 do
		local event = SpecialEvents.forSlot(slot)
		assert(event ~= nil)
		expect(event ~= previous, `{event.id} twice in a row at slot {slot}`)
		previous = event
		counts[event.id] = (counts[event.id] or 0) + 1
	end
	local share = SLOTS / #SpecialEvents.List
	for _, event in SpecialEvents.List do
		local n = counts[event.id] or 0
		expect(math.abs(n - share) <= 2, `{event.id} came up {n} times, expected about {share}`)
	end
end)

test("at() and nextAfter() follow the schedule", function()
	for slot = FIRST_SLOT, FIRST_SLOT + 300 do
		local event, starts = SpecialEvents.forSlot(slot)
		assert(event ~= nil)
		local ends = starts + event.seconds
		local live, liveStarts, liveEnds = SpecialEvents.at(starts)
		equal(live, event, `live at the start of slot {slot}`)
		equal(liveStarts, starts, "starts")
		equal(liveEnds, ends, "ends")
		equal(SpecialEvents.at(ends - 0.5), event, "still live just before the end")
		equal(SpecialEvents.at(starts - 0.5), nil, "not before")
		equal(SpecialEvents.at(ends), nil, "not after")
		local nextEvent, nextStarts = SpecialEvents.nextAfter(starts - 30)
		equal(nextEvent, event, "next event")
		equal(nextStarts, starts, "next start")
		local following, followingStarts = SpecialEvents.nextAfter(starts)
		local after, afterStarts = SpecialEvents.forSlot(slot + 1)
		equal(following, after, "the one after")
		equal(followingStarts, afterStarts, "the one after starts")
	end
end)

test("switched-off events never run", function()
	local off = { LuckyStar = true, CashRain = true }
	local previous = nil
	for slot = FIRST_SLOT, FIRST_SLOT + 600 do
		local event = SpecialEvents.forSlot(slot, off)
		assert(event ~= nil)
		expect(not off[event.id], `{event.id} is switched off`)
		expect(event ~= previous, "still never twice in a row")
		previous = event
	end
	local two = {}
	for i, event in SpecialEvents.List do
		if i > 2 then
			two[event.id] = true
		end
	end
	local a, b = SpecialEvents.forSlot(FIRST_SLOT, two), SpecialEvents.forSlot(FIRST_SLOT + 1, two)
	expect(a ~= nil and b ~= nil and a ~= b, "two events take turns")
	local all = {}
	for _, event in SpecialEvents.List do
		all[event.id] = true
	end
	for slot = FIRST_SLOT, FIRST_SLOT + 20 do
		local _, starts = SpecialEvents.forSlot(slot)
		equal(SpecialEvents.forSlot(slot, all), nil, "all off")
		equal(SpecialEvents.at(starts + 1, all), nil, "nothing live")
	end
	equal(SpecialEvents.nextAfter(FIRST_SLOT * SLOT, all), nil, "nothing next")
end)

test("each Cash Rain has its own coins, the same everywhere", function()
	local starts = FIRST_SLOT * SLOT + 400
	local spots = SpecialEvents.coinSpots(starts)
	equal(#spots, SpecialEvents.CoinCount, "coin count")
	local again = SpecialEvents.coinSpots(starts)
	local known = {}
	for _, spot in SpecialEvents.CoinSpots do
		known[tostring(spot)] = true
	end
	local seen = {}
	for i, spot in spots do
		equal(spot, again[i], `coin {i} is the same both times`)
		expect(known[tostring(spot)], `coin {i} is on a coin spot`)
		expect(not seen[tostring(spot)], `coin {i} doubles up`)
		seen[tostring(spot)] = true
	end
	local differs = false
	for i, spot in SpecialEvents.coinSpots(starts + 1) do
		differs = differs or spot ~= spots[i]
	end
	expect(differs, "another Cash Rain lands elsewhere")
	local crate = SpecialEvents.crateSpot(starts)
	equal(crate, SpecialEvents.crateSpot(starts), "the crate lands in one place")
	expect(table.find(SpecialEvents.CrateSpots, crate) ~= nil, "on a crate spot")
end)

-- A part's world-space bounding box (corners min, max), including any turn.
local function bounds(part: any): (any, any)
	local cf, size = part.CFrame, part.Size / 2
	local extent = Vector3.new(
		math.abs(cf.RightVector.X) * size.X + math.abs(cf.UpVector.X) * size.Y + math.abs(cf.LookVector.X) * size.Z,
		math.abs(cf.RightVector.Y) * size.X + math.abs(cf.UpVector.Y) * size.Y + math.abs(cf.LookVector.Y) * size.Z,
		math.abs(cf.RightVector.Z) * size.X + math.abs(cf.UpVector.Z) * size.Y + math.abs(cf.LookVector.Z) * size.Z
	)
	return cf.Position - extent, cf.Position + extent
end

test("coins and the crate land on open ground", function()
	local town = roblox.Instance.new("Folder")
	MapModels.build(town)
	-- Anything solid from knee height up (paths, roads and the grass are below that).
	local solids = {}
	for _, part in town:GetDescendants() do
		if part:IsA("BasePart") and part.CanCollide then
			local lo, hi = bounds(part)
			if hi.Y > 0.6 and lo.Y < 8 and part.Name ~= "Ground" and part.Name ~= "Hill" then
				table.insert(solids, { lo = lo, hi = hi, part = part })
			end
		end
	end
	local half = LotModels.Layout.size / 2
	local function check(spot: any, radius: number, label: string)
		expect(math.abs(spot.X) < MapModels.Layout.fenceX - radius and math.abs(spot.Z) < MapModels.Layout.fenceZ - radius, `{label} {spot} is inside the hedge`)
		for index = 1, 6 do
			local lot = MapModels.lotBase(index).Position
			local inside = math.abs(spot.X - lot.X) < half + radius and math.abs(spot.Z - lot.Z) < half + radius
			expect(not inside, `{label} {spot} is on lot {index}`)
		end
		for _, solid in solids do
			local clear = spot.X + radius <= solid.lo.X or spot.X - radius >= solid.hi.X or spot.Z + radius <= solid.lo.Z or spot.Z - radius >= solid.hi.Z
			expect(clear, `{label} {spot} hits {solid.part:GetFullName()}`)
		end
	end
	for _, spot in SpecialEvents.CoinSpots do
		check(spot, 2.5, "coin")
	end
	for _, spot in SpecialEvents.CrateSpots do
		check(spot, 4.5, "crate")
	end
end)

test("event props build and never get in the way", function()
	local folder = roblox.Instance.new("Folder")
	local star = EventModels.star(folder, roblox.CFrame.new(0, 40, 0), 24)
	local coin = EventModels.coin(folder, roblox.CFrame.new(20, 3, 0), 4)
	local crate, lid = EventModels.crate(folder, roblox.CFrame.new(40, 0, 0))
	local chute = EventModels.parachute(folder, roblox.CFrame.new(40, 0, 0))
	EventModels.beam(folder, Vector3.new(0, 0, 0), 200, 3, roblox.Color3.new(1, 1, 0))
	EventModels.ring(folder, Vector3.new(0, 0, 0), 10, roblox.Color3.new(1, 1, 0))
	for _, model in { star, coin, crate, lid, chute } do
		local parts = 0
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				parts += 1
			end
		end
		expect(parts > 0, `{model.Name} has parts`)
	end
	for _, part in folder:GetDescendants() do
		if part:IsA("BasePart") then
			expect(not part.CanCollide and not part.CanTouch and not part.CanQuery, `{part:GetFullName()} can be bumped or clicked`)
		end
	end
	-- The star is about as tall as asked, around its centre.
	local lo, hi = math.huge, -math.huge
	for _, part in star:GetDescendants() do
		if part:IsA("BasePart") then
			local a, b = bounds(part)
			lo, hi = math.min(lo, a.Y), math.max(hi, b.Y)
		end
	end
	expect(hi - lo > 20 and hi - lo < 30, `star is {hi - lo} studs tall`)
	expect(math.abs((hi + lo) / 2 - 40) < 3, "star centred")
end)
