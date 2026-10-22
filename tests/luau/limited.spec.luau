local roblox = require("@lune/roblox")

local H = require("./harness")
local Achievements = H.require("Achievements")
local ActorModels = H.require("Models/ActorModels")
local Actors = H.require("Actors")
local Rewards = H.require("Rewards")
local SeasonalShapes = H.require("Models/SeasonalShapes")
local SpecialEvents = H.require("SpecialEvents")
local TopStudios = H.require("TopStudios")
local Upgrades = H.require("Upgrades")
local test, expect, equal = H.test, H.expect, H.equal

local CFrame = roblox.CFrame
local FIRST_WEEK = Rewards.week(1_760_000_000) -- October 2025

test("every seasonal festival has one limited actor, of its genre, and nothing else does", function()
	local seen = {}
	for _, season in SpecialEvents.Seasons do
		local actor = Actors.limitedFor(season.id)
		expect(actor ~= nil, `{season.id} has a limited actor`)
		if actor ~= nil then
			equal(actor.season, season.id, "points back at its season")
			equal(actor.genre, season.genre, `{actor.id} is a {season.genre} actor`)
			expect(Actors.getTier(actor.tier) ~= nil, `{actor.id} has a real tier`)
			seen[actor.id] = true
		end
	end
	for _, actor in Actors.Limited do
		expect(seen[actor.id], `{actor.id} belongs to a season`)
		expect(Actors.isLimited(actor.id), `{actor.id} is limited`)
		equal(Actors.getActor(actor.id), actor, "lookup by id")
	end
	equal(Actors.limitedFor(nil), nil, "an ordinary week has none")
	for _, actor in Actors.List do
		expect(not Actors.isLimited(actor.id), `{actor.id} is an everyday actor`)
		expect(not seen[actor.id], `{actor.id} id not reused`)
	end
end)

test("limited actors stay out of the Index rows, genre sets and the everyday pools", function()
	equal(Actors.IndexSlots, #Actors.List * #Actors.Variants, "Index slots count everyday actors only")
	local index = {}
	for _, actor in Actors.List do
		index[Actors.key(actor.id, "Normal")] = true
	end
	for _, tier in Actors.Tiers do
		for _, actor in Actors.actorsInTier(tier.id) do
			expect(actor.season == nil, `{actor.id} in {tier.id}'s everyday pool`)
		end
		expect(Upgrades.rewardEarned(index, "tier:" .. tier.id), `{tier.id} row finishes without limited actors`)
	end
	for _, genre in Rewards.FestivalGenres do
		expect(Upgrades.rewardEarned(index, "genre:" .. genre), `{genre} set finishes without limited actors`)
	end
	-- Owning a limited actor never counts toward a row or set it is not part of.
	local onlyLimited = { [Actors.key(Actors.Limited[1].id, "Normal")] = true }
	local found = Upgrades.genreProgress(onlyLimited, Actors.Limited[1].genre)
	equal(found, 0, "genre set ignores limited actors")
	local view = { stats = {}, index = onlyLimited, trophies = 0, fame = 0 }
	equal(Achievements.value(view, "index"), 0, "the Index count ignores limited actors")
	equal(Achievements.value(view, "actors"), 0, "so does the all-actors goal")
end)

test("a limited actor is as likely as one actor of its tier, and nobody else's odds move", function()
	local limited = Actors.Limited[1]
	equal(#Actors.actorsInTier(limited.tier), 3, "the everyday pool is not changed")
	for _, agency in Actors.Agencies do
		for _, luck in { 1, 2, 10, 50 } do
			local chances = Actors.tierChances(luck, agency.minTier)
			local chance = Actors.limitedChance(chances, limited)
			equal(Actors.limitedChance(chances, nil), 0, "none out of season")
			expect(chance > 0, `castable at {agency.id} Luck {luck}`)
			expect(chance <= chances[limited.tier] / 3 + 1e-12, "never more than one Star actor")
			local commonest = 0
			for _, tier in Actors.Tiers do
				if chances[tier.id] > 0 then
					commonest = chances[tier.id]
					break
				end
			end
			expect(chance <= commonest, "fits inside the commonest tier")
		end
	end
	local open = Actors.tierChances(1, 1)
	H.near(1 / Actors.limitedChance(open, limited), 3 * 700, 30, "about 1 in 2,100 at Open Casting")

	-- Same seed, with and without the limited actor: every cast is identical except the few that
	-- land on its slice, which were the commonest tier's (so no Star, or better, is ever lost).
	local a, b = H.Random.new(7), H.Random.new(7)
	local hollywood = Actors.getAgency("Hollywood") :: Actors.Agency
	local swapped, got = 0, 0
	for _ = 1, 20000 do
		local plain, plainVariant = Actors.roll(a, 5, hollywood.minTier, nil, nil)
		local seasonal, seasonalVariant = Actors.roll(b, 5, hollywood.minTier, nil, limited)
		equal(plainVariant, seasonalVariant, "variants match")
		expect(plain.season == nil, "never cast out of season")
		if seasonal.id ~= plain.id then
			swapped += 1
			equal(seasonal, limited, "only ever swapped for the limited actor")
			equal(plain.tier, Actors.Tiers[hollywood.minTier].id, "taken from the commonest tier")
		end
		if seasonal == limited then
			got += 1
		end
	end
	equal(swapped, got, "every limited cast replaced a commonest-tier cast")
	local expected = 20000 * Actors.limitedChance(Actors.tierChances(5, hollywood.minTier), limited)
	expect(got > expected * 0.6 and got < expected * 1.4, `about {expected} limited casts (got {got})`)
end)

test("a limited actor can be cast in its season's weeks and in no other week", function()
	local weeks = 0
	for week = FIRST_WEEK, FIRST_WEEK + 52 * 3 do
		local festival = SpecialEvents.festival(week) :: SpecialEvents.Festival
		local limited = Actors.limitedFor(festival.season)
		if festival.season == nil then
			equal(limited, nil, `week {week} has no limited actor`)
		else
			weeks += 1
			expect(limited ~= nil, `week {week} ({festival.season}) has one`)
			expect(string.find(festival.tagline, (limited :: Actors.Actor).name, 1, true) ~= nil, "the banner names it")
		end
	end
	expect(weeks >= 4 * 3, "every season comes round each year")
	equal(SpecialEvents.festival(FIRST_WEEK, { [SpecialEvents.FestivalId] = true }), nil, "switched off with the festival")
	equal(SpecialEvents.seasonDates(SpecialEvents.getSeason("FrightNight") :: SpecialEvents.Season), "Oct 18 - Nov 3", "dates for people")
end)

test("limited actors build from their Blender shapes, with variant effects", function()
	for _, actor in Actors.Limited do
		expect(SeasonalShapes.Shapes[actor.id] ~= nil and #SeasonalShapes.Shapes[actor.id] > 20, `{actor.id} has Blender shapes`)
		local bounds = SeasonalShapes.Bounds[actor.id]
		expect(bounds ~= nil and bounds.size.Y > 5 and bounds.size.Y < 7.5, `{actor.id} stands about actor height`)
		local folder = roblox.Instance.new("Folder")
		local model = ActorModels.build(folder, CFrame.new(), actor.id, "Award")
		local parts = 0
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				parts += 1
			end
		end
		expect(parts > 20, `{actor.id} is built (got {parts} parts)`)
		expect(model:FindFirstChild("Medal") ~= nil, `{actor.id} wears the Award-Winning medal`)
	end
end)

test("limited actors rank on the Rare Wall by tier like everyone else", function()
	local limited = Actors.Limited[1]
	local everyday = Actors.actorsInTier(limited.tier)[1]
	local roster = {
		[Actors.key(limited.id, "Normal")] = 1,
		[Actors.key(everyday.id, "Normal")] = 1,
		[Actors.key(Actors.List[1].id, "Normal")] = 1,
	}
	local top = TopStudios.rarest(roster, 3)
	equal(#top, 3, "all three shown")
	equal(top[3].actor.id, Actors.List[1].id, "the commoner comes last")
end)
