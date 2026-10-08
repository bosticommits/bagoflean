--!strict
-- Special events (plan section 5): every 15 minutes a surprise takes over the town for a minute
-- or two. A giant Lucky Star crashes into the plaza, coins rain down, a Mystery Crate parachutes
-- in, a searchlight Spotlight lands on someone's studio, or Golden Hour speeds up every film.
--
-- Like Award Night (Events), the schedule is a pure function of the clock, so every server runs
-- the same event at the same moment with no messaging, and changing servers finds nothing new.
-- The server passes os.time(). Events never come within a minute of Award Night, so the two never
-- stack. Which event comes next is shuffled like a deck: each one comes up once every few slots,
-- never twice in a row, and the start time inside its slot is random too.
local Events = require(script.Parent.Events)
local Shop = require(script.Parent.Shop)

local SpecialEvents = {}

export type Event = {
	id: string, -- stable: analytics, LiveConfig and saved pickups use it
	name: string, -- banner title, after "SPECIAL EVENT:"
	tagline: string, -- what everyone gets, under the title
	seconds: number, -- how long it lasts
	icon: string, -- IconModels id shown on the banner
	colors: { Color3 }, -- the title's gradient, top to bottom
}

SpecialEvents.List = {
	{
		id = "LuckyStar",
		name = "LUCKY STAR",
		tagline = "x2 casting Luck for everyone!",
		seconds = 120,
		icon = "star",
		colors = { Color3.fromRGB(255, 246, 130), Color3.fromRGB(255, 168, 28) },
	},
	{
		id = "CashRain",
		name = "CASH RAIN",
		tagline = "Grab the gold coins around town!",
		seconds = 90,
		icon = "coin",
		colors = { Color3.fromRGB(205, 255, 150), Color3.fromRGB(46, 196, 90) },
	},
	{
		id = "MysteryCrate",
		name = "MYSTERY CRATE",
		tagline = "Find the crate for a free x3 Luck cast!",
		seconds = 90,
		icon = "gift",
		colors = { Color3.fromRGB(236, 190, 255), Color3.fromRGB(150, 70, 235) },
	},
	{
		id = "Spotlight",
		name = "SPOTLIGHT",
		tagline = "Visit the studio in the spotlight for x2 Luck!",
		seconds = 90,
		icon = "camera",
		colors = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 196, 70) },
	},
	{
		id = "GoldenHour",
		name = "GOLDEN HOUR",
		tagline = "Every film shoots twice as fast!",
		seconds = 120,
		icon = "clapper",
		colors = { Color3.fromRGB(255, 214, 140), Color3.fromRGB(240, 96, 64) },
	},
} :: { Event }

local byId: { [string]: Event } = {}
for _, event in SpecialEvents.List do
	byId[event.id] = event
end

function SpecialEvents.get(id: string): Event?
	return byId[id]
end

-- Schedule.
SpecialEvents.SlotSeconds = 15 * 60 -- one event in every slot of the clock
SpecialEvents.Gap = 60 -- kept free between an event and Award Night, and at each slot's edges
SpecialEvents.TeaserSeconds = 10 -- clients count down "special event in 10" before one starts

-- Rewards. Nothing here is sold: every player on the server gets the same chance.
SpecialEvents.LuckMultiplier = 2 -- Lucky Star: casting Luck, on top of everything else
SpecialEvents.CoinCount = 16 -- Cash Rain: coins around town; each player can grab each one once
-- Each coin is worth the most of: a floor, some seconds of cinema income, or a share of Fame.
-- Fame tracks how far a player has got (most income comes from premieres, not the cinema), so
-- a coin is worth roughly 5-15 seconds of a player's income from their first minutes to week one.
SpecialEvents.CoinCash = 25
SpecialEvents.CoinCinemaSeconds = 20
SpecialEvents.CoinFameShare = 0.1
SpecialEvents.CoinRadius = 5 -- how close (studs, ignoring height) counts as touching a coin
SpecialEvents.CrateLandSeconds = 6 -- the Mystery Crate floats down on its parachute this long
SpecialEvents.CrateLuckMultiplier = 3 -- its free cast: best unlocked agency, x3 casting Luck
SpecialEvents.CrateRadius = 8
SpecialEvents.SpotlightReward = { luckMinutes = 5 } :: Shop.Reward -- visit the studio once
SpecialEvents.FilmSpeed = 2 -- Golden Hour: films shoot this many times as fast

-- Cash for one Cash Rain coin, for a player with cinema income `ratePerSecond` and `fame`.
function SpecialEvents.coinCash(ratePerSecond: number, fame: number): number
	local cash = math.max(SpecialEvents.CoinCash, ratePerSecond * SpecialEvents.CoinCinemaSeconds, fame * SpecialEvents.CoinFameShare)
	return if cash == cash and cash < math.huge then math.floor(cash) else SpecialEvents.CoinCash
end

-- Ignoring `disabled` ids (LiveConfig can switch events off), in List order.
local function enabledEvents(disabled: { [string]: boolean }?): { Event }
	local list: { Event } = {}
	for _, event in SpecialEvents.List do
		if disabled == nil or not disabled[event.id] then
			table.insert(list, event)
		end
	end
	return list
end

-- The enabled events shuffled for one cycle of slots (a fixed shuffle seeded by the cycle).
local function deck(cycle: number, events: { Event }): { Event }
	local cards = table.clone(events)
	local random = Random.new(cycle)
	for i = #cards, 2, -1 do
		local j = random:NextInteger(1, i)
		cards[i], cards[j] = cards[j], cards[i]
	end
	return cards
end

-- The event dealt to `slot`. Each cycle of #events slots deals the whole deck, so every event
-- comes up once per cycle, and a new deck never opens with the card the last one ended on.
local function eventFor(slot: number, events: { Event }): Event?
	local count = #events
	if count <= 2 then
		return events[slot % math.max(count, 1) + 1] -- one event, or two taking turns
	end
	local cycle = slot // count
	local cards = deck(cycle, events)
	if cards[1] == deck(cycle - 1, events)[count] then
		cards[1], cards[2] = cards[2], cards[1] -- the last card stays put, so this never chains
	end
	return cards[slot % count + 1]
end

-- The earliest and latest start for an event lasting `seconds` in `slot`: Gap clear of the slot's
-- edges and of every Award Night. nil when it does not fit.
function SpecialEvents.window(slot: number, seconds: number): (number?, number?)
	local gap = SpecialEvents.Gap
	local first = slot * SpecialEvents.SlotSeconds + gap
	local last = (slot + 1) * SpecialEvents.SlotSeconds - gap - seconds
	local period, length = Events.AwardNightPeriod, Events.AwardNightLength
	for n = (first - length - gap) // period, (last + seconds + gap) // period do
		-- Starts strictly between these two would run within Gap of this Award Night.
		local blockFrom = n * period - gap - seconds
		local blockTo = n * period + length + gap
		if blockTo > first and blockFrom < last then
			-- Keep the bigger side of the slot.
			if last - blockTo >= blockFrom - first then
				first = math.max(first, blockTo)
			else
				last = math.min(last, blockFrom)
			end
		end
	end
	if last < first then
		return nil, nil
	end
	return first, last
end

-- The event in `slot` and when it starts, or nil.
function SpecialEvents.forSlot(slot: number, disabled: { [string]: boolean }?): (Event?, number)
	local event = eventFor(slot, enabledEvents(disabled))
	if event == nil then
		return nil, 0
	end
	local first, last = SpecialEvents.window(slot, event.seconds)
	if first == nil or last == nil then
		return nil, 0
	end
	return event, first + Random.new(slot):NextInteger(0, last - first)
end

-- The event running at `now`: (event, starts, ends), or nil. Events stay inside their slot, so
-- only the current slot can have one.
function SpecialEvents.at(now: number, disabled: { [string]: boolean }?): (Event?, number, number)
	local event, starts = SpecialEvents.forSlot(now // SpecialEvents.SlotSeconds, disabled)
	if event ~= nil and now >= starts and now < starts + event.seconds then
		return event, starts, starts + event.seconds
	end
	return nil, 0, 0
end

-- The next event to start after `now`, and when (it looks a few slots ahead).
function SpecialEvents.nextAfter(now: number, disabled: { [string]: boolean }?): (Event?, number)
	local slot = now // SpecialEvents.SlotSeconds
	for ahead = 0, 3 do
		local event, starts = SpecialEvents.forSlot(slot + ahead, disabled)
		if event ~= nil and starts > now then
			return event, starts
		end
	end
	return nil, 0
end

-- Where things land ---------------------------------------------------------------------------
-- Open ground round town (MapModels): the boulevard, the plaza round the fountain, the sidewalks
-- by the curb, the paths between the lots, the back paths and the side paths. y is the grass;
-- clients drop each pickup onto whatever surface is there. tests/luau/events.spec.luau checks that
-- nothing solid stands on any spot and none is inside a lot.
local function spot(x: number, z: number): Vector3
	return Vector3.new(x, 0, z)
end

SpecialEvents.CoinSpots = table.freeze({
	-- Boulevard, zigzagging across the road (both ends).
	spot(30, -5), spot(46, 5), spot(62, -5), spot(78, 5), spot(94, -5), spot(110, 5),
	spot(-30, 5), spot(-46, -5), spot(-62, 5), spot(-78, -5), spot(-94, 5), spot(-110, -5),
	-- Sidewalks, between the curb and the stands.
	spot(36, 17), spot(64, -17), spot(92, 17), spot(-36, -17), spot(-64, 17), spot(-92, -17),
	-- Round the fountain.
	spot(0, 17), spot(0, -19), spot(15, 5), spot(-15, -5),
	-- Paths between the lots.
	spot(40, 64), spot(40, 80), spot(-40, 64), spot(-40, 80),
	spot(40, -64), spot(40, -80), spot(-40, -64), spot(-40, -80),
	-- Back paths behind the lots, and the side paths at each end of town.
	spot(0, 108), spot(80, 108), spot(-80, 108), spot(0, -108), spot(80, -108), spot(-80, -108),
	spot(120, 72), spot(120, -72), spot(-120, 72), spot(-120, -72),
}) :: { Vector3 }

-- The crate is bigger, so it only lands on the wide boulevard.
SpecialEvents.CrateSpots = table.freeze({
	spot(36, 0), spot(60, 0), spot(84, 0), spot(104, 0),
	spot(-36, 0), spot(-60, 0), spot(-84, 0), spot(-104, 0),
}) :: { Vector3 }

-- The Cash Rain coins for the event starting at `starts`: CoinCount spots, the same on the server
-- and every client.
function SpecialEvents.coinSpots(starts: number): { Vector3 }
	local spots = table.clone(SpecialEvents.CoinSpots)
	local count = math.min(SpecialEvents.CoinCount, #spots)
	local random = Random.new(starts)
	for i = 1, count do
		local j = random:NextInteger(i, #spots)
		spots[i], spots[j] = spots[j], spots[i]
	end
	return { table.unpack(spots, 1, count) }
end

-- Where the Mystery Crate of the event starting at `starts` lands.
function SpecialEvents.crateSpot(starts: number): Vector3
	return SpecialEvents.CrateSpots[Random.new(starts):NextInteger(1, #SpecialEvents.CrateSpots)]
end

-- Whether `position` is within `radius` of `spot` across the ground, and not far above it.
function SpecialEvents.near(position: Vector3, spotAt: Vector3, radius: number): boolean
	local dx, dz = position.X - spotAt.X, position.Z - spotAt.Z
	return dx * dx + dz * dz <= radius * radius and math.abs(position.Y - spotAt.Y) <= 25
end

return SpecialEvents
