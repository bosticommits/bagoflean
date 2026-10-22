local roblox = require("@lune/roblox")

local H = require("./harness")
local IconModels = H.require("Models/IconModels")
local LotLook = H.require("Models/LotLook")
local Movies = H.require("Movies")
local Rewards = H.require("Rewards")
local SpecialEvents = H.require("SpecialEvents")
local TopStudiosModels = H.require("Models/TopStudiosModels")
local test, expect, equal = H.test, H.expect, H.equal

local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local DAY = 86400
local FIRST_WEEK = Rewards.week(1_760_000_000) -- October 2025
local WEEKS = 52 * 5

-- Unix time of a UTC date.
local function date(year: number, month: number, day: number): number
	return os.time({ year = year, month = month, day = day, hour = 12 }) -- noon, clear of any offset
end

test("every week has a festival everyone can enter, with real goals", function()
	local icons = {}
	for _, id in IconModels.Ids do
		icons[id] = true
	end
	for week = FIRST_WEEK, FIRST_WEEK + WEEKS do
		local festival = SpecialEvents.festival(week)
		expect(festival ~= nil, `week {week} has a festival`)
		if festival == nil then
			continue
		end
		expect(table.find(Rewards.FestivalGenres, festival.genre) ~= nil, `week {week} genre {festival.genre}`)
		expect(Movies.GenreFame[festival.genre] <= 100, `{festival.genre} opens early`)
		expect(festival.name == string.upper(festival.name) and #festival.name > 0, "capital title")
		expect(#festival.colors >= 2, "gradient")
		expect(icons[festival.icon], `icon {festival.icon}`)
		equal(festival.starts, Rewards.weekStart(week), "starts Monday")
		equal(festival.ends - festival.starts, 7 * DAY, "lasts a week")
		local ids = Rewards.festivalFor(festival.genre)
		equal(#ids, 3, "three goals")
		for _, id in ids do
			local goal = Rewards.getRequest(id)
			expect(goal ~= nil, `goal {id} exists`)
			if goal ~= nil then
				expect(goal.target > 0, `{id} target`)
				expect(goal.kind == "request" or string.match(goal.kind, ":(.+)$") == festival.genre, `{id} is for {festival.genre}`)
			end
		end
	end
end)

test("festival goals give modest, valid rewards", function()
	for _, goal in Rewards.Festival do
		local reward = goal.reward
		expect((reward.cash or 0) <= 300, `{goal.id} Cash floor stays low`)
		expect((reward.luckMinutes or 0) <= 30, `{goal.id} Luck`)
		expect((reward.skips or 0) <= 2, `{goal.id} skips`)
		expect(reward.cash ~= nil or reward.luckMinutes ~= nil or reward.skips ~= nil, `{goal.id} gives something`)
	end
end)

test("an ordinary week's festival never asks for the weekly quest's genre", function()
	for week = FIRST_WEEK, FIRST_WEEK + WEEKS do
		if SpecialEvents.seasonFor(week) ~= nil then
			continue
		end
		local genreQuest = Rewards.getRequest(Rewards.weeklyFor(week)[2])
		local festival = SpecialEvents.festival(week)
		if genreQuest ~= nil and festival ~= nil then
			expect(genreQuest.kind ~= "premiere:" .. festival.genre, `week {week} doubles up on {festival.genre}`)
		end
	end
	-- And every genre comes round within a month.
	local seen = {}
	for week = FIRST_WEEK, FIRST_WEEK + 3 do
		seen[SpecialEvents.festivalGenre(week)] = true
	end
	for _, genre in Rewards.FestivalGenres do
		expect(seen[genre], `{genre} comes round`)
	end
end)

test("seasonal festivals take their weeks every year", function()
	local week = Rewards.week(date(2026, 10, 22))
	local festival = SpecialEvents.festival(week)
	equal(festival and festival.season, "FrightNight", "late October is Fright Night")
	equal(festival and festival.genre, "Horror", "Fright Night is Horror")
	equal(SpecialEvents.seasonFor(Rewards.week(date(2026, 12, 24))) and SpecialEvents.seasonFor(Rewards.week(date(2026, 12, 24))).id, "HolidayLights", "Christmas week")
	equal(SpecialEvents.seasonFor(Rewards.week(date(2027, 1, 1))) and SpecialEvents.seasonFor(Rewards.week(date(2027, 1, 1))).id, "HolidayLights", "New Year week (the season wraps the year)")
	equal(SpecialEvents.seasonFor(Rewards.week(date(2027, 2, 14))) and SpecialEvents.seasonFor(Rewards.week(date(2027, 2, 14))).id, "LoveStory", "Valentine's week")
	equal(SpecialEvents.seasonFor(Rewards.week(date(2027, 7, 1))) and SpecialEvents.seasonFor(Rewards.week(date(2027, 7, 1))).id, "SummerBlockbuster", "early July")
	equal(SpecialEvents.seasonFor(Rewards.week(date(2026, 11, 12))), nil, "mid November is an ordinary week")
	for year = 2025, 2031 do
		for _, season in SpecialEvents.Seasons do
			local found = false
			-- Look across the year the season starts in and the start of the next.
			for w = Rewards.week(date(year, 1, 1)), Rewards.week(date(year + 1, 1, 20)) do
				local s = SpecialEvents.seasonFor(w)
				if s ~= nil and s.id == season.id then
					found = true
				end
			end
			expect(found, `{season.id} gets a week in {year}`)
		end
	end
	for _, season in SpecialEvents.Seasons do
		equal(SpecialEvents.getSeason(season.id), season, `lookup {season.id}`)
		expect(table.find(Rewards.FestivalGenres, season.genre) ~= nil, `{season.id} genre`)
	end
end)

test("LiveConfig can switch the festival off", function()
	local week = FIRST_WEEK + 10
	equal(SpecialEvents.festival(week, { [SpecialEvents.FestivalId] = true }), nil, "off")
	expect(SpecialEvents.festival(week, { CashRain = true }) ~= nil, "other events don't matter")
	expect(SpecialEvents.festivalAt(Rewards.weekStart(week) + 5) ~= nil, "festivalAt")
	equal(SpecialEvents.festivalAt(Rewards.weekStart(week) + 5).week, week, "festivalAt week")
end)

test("finished festival goals carry over a week reset", function()
	local ids = Rewards.festivalFor("Comedy")
	local goal = Rewards.getRequest(ids[1])
	local carried = Rewards.carryOver({}, "festival", 2900, {
		{ id = ids[1], progress = if goal ~= nil then goal.target else 0, claimed = false },
		{ id = ids[2], progress = 0, claimed = false },
	})
	equal(#carried, 1, "only the finished one")
	equal(carried[1].key, `festival:2900:{ids[1]}`, "keyed by week")
	equal(carried[1].scope, "festival", "scope")
end)

-- World-space box of a part.
local function bounds(part: any): (any, any)
	local cf, size = part.CFrame, part.Size
	local extent = Vector3.new(
		math.abs(cf.RightVector.X) * size.X + math.abs(cf.UpVector.X) * size.Y + math.abs(cf.LookVector.X) * size.Z,
		math.abs(cf.RightVector.Y) * size.X + math.abs(cf.UpVector.Y) * size.Y + math.abs(cf.LookVector.Y) * size.Z,
		math.abs(cf.RightVector.Z) * size.X + math.abs(cf.UpVector.Z) * size.Y + math.abs(cf.LookVector.Z) * size.Z
	) / 2
	return cf.Position - extent, cf.Position + extent
end

test("the laurel stand fits on a full lot without touching anything", function()
	local folder = roblox.Instance.new("Folder")
	local C = roblox.Color3.fromRGB
	LotLook.build(folder, CFrame.new(), 1, {
		stages = 5,
		cinema = 6,
		office = 5,
		trophies = 9,
		laurels = { C(150, 60, 220), C(255, 170, 30), C(235, 70, 50), C(225, 60, 120) },
		filming = {},
		star = "PhantomAuteur",
		variant = "Award",
	})
	TopStudiosModels.rareWall(folder, CFrame.new(), {}, 5)
	local laurels, others = {}, {}
	for _, part in folder:GetDescendants() do
		if part:IsA("BasePart") then
			local lo, hi = bounds(part)
			if string.sub(part.Name, 1, 6) == "Laurel" then
				table.insert(laurels, { lo = lo, hi = hi, part = part })
			elseif hi.Y > 1.15 and part.Transparency < 1 then -- the lot floor and its paving are below that
				table.insert(others, { lo = lo, hi = hi, part = part })
			end
		end
	end
	local stands = 0
	for _, laurel in laurels do
		if laurel.part.Name == "LaurelPlinth" then
			stands += 1
		end
	end
	equal(stands, LotLook.MaxLaurelsShown, "shows the newest few")
	local half = 28
	for _, laurel in laurels do
		expect(math.abs(laurel.lo.X) < half and math.abs(laurel.hi.X) < half and math.abs(laurel.lo.Z) < half and math.abs(laurel.hi.Z) < half, `{laurel.part.Name} is on the lot`)
		for _, other in others do
			local apart = laurel.hi.X <= other.lo.X + 0.05
				or laurel.lo.X >= other.hi.X - 0.05
				or laurel.hi.Z <= other.lo.Z + 0.05
				or laurel.lo.Z >= other.hi.Z - 0.05
				or laurel.hi.Y <= other.lo.Y
				or laurel.lo.Y >= other.hi.Y
			expect(apart, `{laurel.part.Name} runs into {other.part.Name}`)
		end
	end
end)
