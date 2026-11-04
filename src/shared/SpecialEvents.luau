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
-- Each week is also a Film Festival for one genre, with seasonal festivals on set dates (below).
local Actors = require(script.Parent.Actors)
local Events = require(script.Parent.Events)
local Rewards = require(script.Parent.Rewards)
local Shop = require(script.Parent.Shop)

local SpecialEvents = {}

export type Event = {
	id: string, -- stable: analytics, LiveConfig and saved pickups use it
	name: string, -- banner title, after "SPECIAL EVENT:"
	tagline: string, -- what everyone gets, under the title
	seconds: number, -- how long it lasts
	icon: string, -- IconModels id shown on the banner
	colors: { Color3 }, -- the title's gradient, top to bottom
	season: string?, -- a Seasons id: only dealt while that season runs
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
	{
		-- Fright Night only: fog rolls in, the sky darkens and glowing pumpkins pop up round town
		-- (candy Cash, like Cash Rain coins), with one golden pumpkin (a free cast, like the crate).
		id = "PumpkinPatch",
		name = "PUMPKIN PATCH",
		tagline = "Grab the glowing pumpkins and find the golden one!",
		seconds = 120,
		icon = "pumpkin",
		colors = { Color3.fromRGB(255, 196, 80), Color3.fromRGB(150, 60, 220) },
		season = "FrightNight",
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
-- Pumpkin Patch: fewer pickups than Cash Rain, each paying a Cash Rain coin, plus one golden
-- pumpkin with the Mystery Crate's free cast, so the whole event is worth less than those two.
SpecialEvents.PumpkinCount = 12
SpecialEvents.GoldenLuckMultiplier = 3

-- Cash for one Cash Rain coin, for a player with cinema income `ratePerSecond` and `fame`.
function SpecialEvents.coinCash(ratePerSecond: number, fame: number): number
	local cash = math.max(SpecialEvents.CoinCash, ratePerSecond * SpecialEvents.CoinCinemaSeconds, fame * SpecialEvents.CoinFameShare)
	return if cash == cash and cash < math.huge then math.floor(cash) else SpecialEvents.CoinCash
end

-- The season running at `now`, by festival week (seasonFor, below), so the Pumpkin Patch, the
-- town decor and the limited actor come and go together.
function SpecialEvents.seasonAt(now: number): Season?
	return SpecialEvents.seasonFor(Rewards.week(now))
end

-- The events dealt in `slot`, in List order: not switched off (LiveConfig `disabled` ids), and
-- seasonal ones only in their season.
local function enabledEvents(disabled: { [string]: boolean }?, slot: number): { Event }
	local list: { Event } = {}
	local season = SpecialEvents.seasonAt(slot * SpecialEvents.SlotSeconds)
	local seasonId = if season ~= nil then season.id else nil
	for _, event in SpecialEvents.List do
		if (disabled == nil or not disabled[event.id]) and (event.season == nil or event.season == seasonId) then
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

-- At default weights, each cycle deals a shuffled deck so every event appears once and adjacent
-- cycles do not repeat. An explicit live weight override uses deterministic weighted picks instead.
local weightedSchedules: { [string]: { Event } } = {}

local function eventFor(slot: number, events: { Event }, weights: { [string]: number }?): Event?
	local count = #events
	if weights ~= nil then
		local keyParts = {}
		for _, event in events do
			table.insert(keyParts, `{event.id}:{weights[event.id] or 1}`)
		end
		local key = table.concat(keyParts, ",")
		local schedule = weightedSchedules[key]
		if schedule == nil then
			local positive = {}
			for _, event in events do
				if (weights[event.id] or 1) > 0 then
					table.insert(positive, event)
				end
			end
			local built: { Event } = {}
			if #positive > 0 then
				local seed = 2166136261
				for index = 1, #key do
					seed = bit32.bxor(seed, string.byte(key, index))
					seed = (seed * 16777619) % 4294967296
				end
				local random = Random.new(seed)
				local first: Event? = nil
				local previous: Event? = nil
				for index = 1, 512 do
					local candidates = {}
					local total = 0
					for _, event in positive do
						if #positive == 1 or (event ~= previous and (index < 512 or event ~= first)) then
							table.insert(candidates, event)
							total += weights[event.id] or 1
						end
					end
					local pick = random:NextNumber() * total
					local selected = candidates[#candidates]
					for _, event in candidates do
						pick -= weights[event.id] or 1
						if pick < 0 then
							selected = event
							break
						end
					end
					if first == nil then first = selected end
					table.insert(built, selected)
					previous = selected
				end
			end
			weightedSchedules[key] = built
			schedule = built
		end
		if #schedule == 0 then
			return nil
		end
		return schedule[slot % #schedule + 1]
	end
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
function SpecialEvents.forSlot(slot: number, disabled: { [string]: boolean }?, weights: { [string]: number }?): (Event?, number)
	local events = enabledEvents(disabled, slot)
	local event = eventFor(slot, events, weights)
	-- When a season starts or ends the deck changes, so its first card could repeat the last
	-- slot's event: deal one unlike both neighbours instead (seasons are weeks apart, so the
	-- neighbours themselves are ordinary deals).
	if event ~= nil and #events >= 3 then
		local before = enabledEvents(disabled, slot - 1)
		if #before ~= #events and eventFor(slot - 1, before, weights) == event then
			local after = eventFor(slot + 1, events, weights)
			for _, other in events do
				if other ~= event and other ~= after and (weights == nil or (weights[other.id] or 1) > 0) then
					event = other
					break
				end
			end
		end
	end
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
function SpecialEvents.at(now: number, disabled: { [string]: boolean }?, weights: { [string]: number }?): (Event?, number, number)
	local event, starts = SpecialEvents.forSlot(now // SpecialEvents.SlotSeconds, disabled, weights)
	if event ~= nil and now >= starts and now < starts + event.seconds then
		return event, starts, starts + event.seconds
	end
	return nil, 0, 0
end

-- The next event to start after `now`, and when (it looks a few slots ahead).
function SpecialEvents.nextAfter(now: number, disabled: { [string]: boolean }?, weights: { [string]: number }?): (Event?, number)
	local slot = now // SpecialEvents.SlotSeconds
	for ahead = 0, 3 do
		local event, starts = SpecialEvents.forSlot(slot + ahead, disabled, weights)
		if event ~= nil and starts > now then
			return event, starts
		end
	end
	return nil, 0
end

-- Film Festival -------------------------------------------------------------------------------
-- Plan section 5, Live events. Every week (Monday to Sunday UTC, the weekly quests' weeks) is a
-- Film Festival for one genre: three festival goals (Rewards.festivalFor) and, for finishing all
-- three, a Festival Laurel that stands on the player's lot for good. Genres take turns, never the
-- genre the weekly quest asks for that week. On set dates a seasonal festival takes over the week
-- with its own title, colors and genre (Fright Night in late October is Horror). Like the events
-- above, this is a pure function of the clock, so every server agrees. LiveConfig switches it off
-- with "FilmFestival" in DisabledEvents (or "ALL").
SpecialEvents.FestivalId = "FilmFestival"

export type Season = {
	id: string, -- stable: saved with each Festival Laurel won in it
	name: string, -- banner title
	genre: string,
	from: { number }, -- { month, day } (UTC) it starts on
	to: { number }, -- { month, day } it ends on, inclusive; may be in the next year
	colors: { Color3 },
	icon: string, -- IconModels id
}

-- A week belongs to a season when its Thursday falls inside these dates, so a season lasting a
-- week or more always gets at least one festival week.
SpecialEvents.Seasons = {
	{
		id = "FrightNight",
		name = "FRIGHT NIGHT FESTIVAL",
		genre = "Horror",
		from = { 10, 18 },
		to = { 11, 3 },
		colors = { Color3.fromRGB(255, 176, 60), Color3.fromRGB(150, 60, 220) },
		icon = "popcorn",
	},
	{
		id = "HolidayLights",
		name = "HOLIDAY FILM FESTIVAL",
		genre = "Comedy",
		from = { 12, 15 },
		to = { 1, 5 },
		colors = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(230, 60, 70) },
		icon = "gift",
	},
	{
		id = "LoveStory",
		name = "LOVE STORY FESTIVAL",
		genre = "Romance",
		from = { 2, 8 },
		to = { 2, 21 },
		colors = { Color3.fromRGB(255, 210, 230), Color3.fromRGB(240, 70, 150) },
		icon = "ticket",
	},
	{
		id = "SummerBlockbuster",
		name = "SUMMER BLOCKBUSTER FESTIVAL",
		genre = "Action",
		from = { 6, 21 },
		to = { 7, 12 },
		colors = { Color3.fromRGB(255, 246, 130), Color3.fromRGB(255, 120, 40) },
		icon = "movieCamera",
	},
} :: { Season }

-- An ordinary week's festival colors, by genre.
SpecialEvents.GenreColors = table.freeze({
	Action = { Color3.fromRGB(255, 214, 120), Color3.fromRGB(235, 70, 50) },
	Comedy = { Color3.fromRGB(255, 250, 160), Color3.fromRGB(255, 170, 30) },
	Horror = { Color3.fromRGB(200, 255, 170), Color3.fromRGB(90, 60, 170) },
	Romance = { Color3.fromRGB(255, 205, 225), Color3.fromRGB(225, 60, 120) },
}) :: { [string]: { Color3 } }

export type Festival = {
	id: string, -- SpecialEvents.FestivalId
	week: number, -- Rewards.week
	genre: string,
	name: string, -- "COMEDY FILM FESTIVAL", or the season's title
	tagline: string,
	season: string?, -- Season id, for a seasonal festival
	colors: { Color3 },
	icon: string,
	starts: number, -- Monday 00:00 UTC
	ends: number, -- the next Monday 00:00 UTC
}

local seasonById: { [string]: Season } = {}
for _, season in SpecialEvents.Seasons do
	seasonById[season.id] = season
end

function SpecialEvents.getSeason(id: string): Season?
	return seasonById[id]
end

local MONTHS = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }

-- A season's dates for people: "Oct 18 - Nov 3".
function SpecialEvents.seasonDates(season: Season): string
	return `{MONTHS[season.from[1]]} {season.from[2]} - {MONTHS[season.to[1]]} {season.to[2]}`
end

-- The season `week` belongs to, if any.
function SpecialEvents.seasonFor(week: number): Season?
	local thursday = os.date("!*t", Rewards.weekStart(week) + 3 * 86400)
	local date = thursday.month * 100 + thursday.day
	for _, season in SpecialEvents.Seasons do
		local from, to = season.from[1] * 100 + season.from[2], season.to[1] * 100 + season.to[2]
		local inside = if from <= to then date >= from and date <= to else date >= from or date <= to
		if inside then
			return season
		end
	end
	return nil
end

-- The genre an ordinary week's festival is for. The weekly quest's genre slot steps through the
-- same four genres in the same order, so starting two along means the two never ask for the same
-- genre in the same week.
function SpecialEvents.festivalGenre(week: number): string
	local genres = Rewards.FestivalGenres
	return genres[(week + 2) % #genres + 1]
end

-- The Film Festival of `week`, or nil when LiveConfig has switched festivals off.
function SpecialEvents.festival(week: number, disabled: { [string]: boolean }?): Festival?
	if disabled ~= nil and disabled[SpecialEvents.FestivalId] then
		return nil
	end
	local season = SpecialEvents.seasonFor(week)
	local genre = if season ~= nil then season.genre else SpecialEvents.festivalGenre(week)
	-- A seasonal festival's limited actor (Actors.Limited) can be cast only while it runs.
	local limited = Actors.limitedFor(if season ~= nil then season.id else nil)
	return {
		id = SpecialEvents.FestivalId,
		week = week,
		genre = genre,
		name = if season ~= nil then season.name else `{string.upper(genre)} FILM FESTIVAL`,
		tagline = if limited ~= nil
			then `Limited actor {limited.name}: cast now or win the festival!`
			else `Premiere {genre} movies to win a Festival Laurel!`,
		season = if season ~= nil then season.id else nil,
		colors = if season ~= nil then season.colors else SpecialEvents.GenreColors[genre],
		icon = if season ~= nil then season.icon else "trophy",
		starts = Rewards.weekStart(week),
		ends = Rewards.weekStart(week + 1),
	}
end

-- The festival running at `now`.
function SpecialEvents.festivalAt(now: number, disabled: { [string]: boolean }?): Festival?
	return SpecialEvents.festival(Rewards.week(now), disabled)
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
	spot(30, -5), spot(50, 5), spot(70, -5), spot(90, 5), spot(110, -5), spot(130, 5), spot(150, -5), spot(170, 5),
	spot(-30, 5), spot(-50, -5), spot(-70, 5), spot(-90, -5), spot(-110, 5), spot(-130, -5), spot(-150, 5), spot(-170, -5),
	-- Sidewalks, between the curb and the stands.
	spot(36, 17), spot(64, -17), spot(92, 17), spot(-36, -17), spot(-64, 17), spot(-92, -17),
	spot(124, 17), spot(166, -17), spot(-124, -17), spot(-166, 17),
	-- Round the fountain.
	spot(0, 17), spot(0, -19), spot(15, 5), spot(-15, -5),
	-- Paths between the lots, between the tall buildings and past the film sets.
	spot(58, 72), spot(58, 88), spot(-58, 72), spot(-58, 88),
	spot(58, -72), spot(58, -88), spot(-58, -72), spot(-58, -88),
	-- Down the middle of the back paths behind the lots, and the side paths at each end of town.
	spot(0, 118), spot(90, 118), spot(-90, 118), spot(0, -118), spot(90, -118), spot(-90, -118),
	spot(182, 80), spot(182, -80), spot(-182, 80), spot(-182, -80),
}) :: { Vector3 }

-- The crate is bigger, so it only lands on the wide boulevard.
SpecialEvents.CrateSpots = table.freeze({
	spot(36, 0), spot(60, 0), spot(84, 0), spot(104, 0), spot(124, 0), spot(160, 0),
	spot(-36, 0), spot(-60, 0), spot(-84, 0), spot(-104, 0), spot(-124, 0), spot(-160, 0),
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

-- The Pumpkin Patch's pumpkins for the event starting at `starts` (on coin spots); its golden
-- pumpkin sits on crateSpot(starts).
function SpecialEvents.pumpkinSpots(starts: number): { Vector3 }
	return { table.unpack(SpecialEvents.coinSpots(starts), 1, SpecialEvents.PumpkinCount) }
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
