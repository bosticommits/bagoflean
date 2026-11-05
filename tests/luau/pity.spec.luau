local fs = require("@lune/fs")
local H = require("./harness")
local Actors = H.require("Actors")
local test, expect, equal = H.test, H.expect, H.equal

local OPEN = Actors.getAgency("Open") :: any
local TALENT = Actors.getAgency("Talent") :: any

-- A fake roll: always lands on `natural`, raised to the floor like Actors.roll does.
local function rollAs(natural: string, seen: { any }?)
	return function(floorTier: string?)
		if seen then
			table.insert(seen, floorTier or false)
		end
		local tier = natural
		local function rank(id: string)
			return table.find(Actors.Tiers, Actors.getTier(id))
		end
		if floorTier ~= nil and rank(floorTier) > rank(natural) then
			tier = floorTier
		end
		return Actors.actorsInTier(tier)[1], Actors.getVariant("Normal")
	end
end

local function veteran()
	return { hotStart = Actors.HotStartLength, pity = {}, early = Actors.EarlyDone, played = 0 }
end

test("pity fires exactly on the PityEvery-th cast and then resets", function()
	local save = veteran()
	for i = 1, Actors.PityEvery - 1 do
		local actor, _, guarantee = Actors.castWithGuarantees(save, OPEN, rollAs("Newcomer"))
		equal(actor.tier, "Newcomer", `cast {i}`)
		equal(guarantee, nil, `cast {i} guarantee`)
	end
	equal(save.pity.Open, Actors.PityEvery - 1, "meter full")
	local actor, _, guarantee = Actors.castWithGuarantees(save, OPEN, rollAs("Newcomer"))
	equal(actor.tier, "Star", "guaranteed tier")
	equal(guarantee, "pity", "reason")
	equal(save.pity.Open, 0, "reset after the guarantee")
end)

test("a natural rare resets the meter; a lesser one does not", function()
	local save = veteran()
	save.pity.Open = 50
	Actors.castWithGuarantees(save, OPEN, rollAs("Pro"))
	equal(save.pity.Open, 51, "Pro is not rare at Open Casting")
	Actors.castWithGuarantees(save, OPEN, rollAs("Superstar"))
	equal(save.pity.Open, 0, "a Superstar resets the Star meter")
	save.pity.Talent = 10
	Actors.castWithGuarantees(save, TALENT, rollAs("Star"))
	equal(save.pity.Talent, 11, "a Star is not rare at the Talent Agency")
	equal(save.pity.Open, 0, "meters are per agency")
end)

test("the pity guarantee never downgrades a better roll", function()
	local save = veteran()
	save.pity.Open = Actors.PityEvery - 1
	local actor, _, guarantee = Actors.castWithGuarantees(save, OPEN, rollAs("Legend"))
	equal(actor.tier, "Legend", "kept the Legend")
	equal(guarantee, "pity", "still covered by pity")
	equal(save.pity.Open, 0, "reset")
end)

test("every agency guarantees a real tier its pool can roll", function()
	for _, agency in Actors.Agencies do
		local tier = Actors.getTier(agency.pity)
		expect(tier ~= nil, `{agency.id} pity tier`)
		expect((table.find(Actors.Tiers, tier) :: number) >= agency.minTier + 2, `{agency.id} pity is a rare tier`)
	end
end)

test("early pulls: one guaranteed Superstar after FirstSuperstarAfter, and no tease", function()
	local save = { hotStart = Actors.HotStartLength, pity = {}, early = 0, played = Actors.FirstSuperstarAfter - 1 }
	local actor, _, guarantee = Actors.castWithGuarantees(save, OPEN, rollAs("Pro"))
	equal(actor.tier, "Pro", "too early for the Superstar, and a Pro is never teased")
	equal(guarantee, nil, "no guarantee yet")
	equal(save.early, 0, "nothing saved by a plain cast")
	save.played = Actors.FirstSuperstarAfter
	actor, _, guarantee = Actors.castWithGuarantees(save, OPEN, rollAs("Newcomer"), true)
	equal(actor.tier, "Newcomer", "live switch holds the first Superstar back")
	actor, _, guarantee = Actors.castWithGuarantees(save, OPEN, rollAs("Newcomer"))
	equal(actor.tier, "Superstar", "guaranteed Superstar")
	equal(guarantee, "firstSuperstar", "reason")
	equal(save.early, Actors.EarlyDone, "done")
	actor, _, guarantee = Actors.castWithGuarantees(save, OPEN, rollAs("Newcomer"))
	equal(actor.tier, "Newcomer", "normal odds after")
	equal(guarantee, nil, "no more guarantees")
end)

test("a save from the removed tease (early = 1) still gets its Superstar", function()
	local save = { hotStart = Actors.HotStartLength, pity = {}, early = 1, played = Actors.FirstSuperstarAfter }
	equal(Actors.nextFloor(save, OPEN), "Superstar", "early 1 counts as not yet")
end)

test("early pulls: a natural Superstar first uses the guarantee up; veterans get none", function()
	local save = { hotStart = Actors.HotStartLength, pity = {}, early = 0, played = 60 }
	Actors.castWithGuarantees(save, OPEN, rollAs("Superstar"))
	equal(save.early, Actors.EarlyDone, "natural Superstar counts")
	local old = veteran()
	old.played = 99999
	local actor, _, guarantee = Actors.castWithGuarantees(old, OPEN, rollAs("Pro"))
	equal(actor.tier, "Pro", "no Superstar for old saves")
	equal(guarantee, nil, "no guarantee")
end)

test("hot start still works and reports its reason", function()
	local save = { hotStart = 2, pity = {}, early = Actors.EarlyDone, played = 0 }
	local actor, _, guarantee = Actors.castWithGuarantees(save, OPEN, rollAs("Newcomer"))
	equal(actor.tier, "Rising", "cast 3 is a Rising")
	equal(guarantee, "hotStart", "reason")
end)

test("migration defaults: old saves start with empty meters and the early pulls done", function()
	local source = fs.readFile("src/server/DataService.luau")
	expect(string.find(source, "pity = {}, -- old saves", 1, true), "TEMPLATE pity = {}")
	expect(string.find(source, "early = Actors.EarlyDone, -- profiles from before v12", 1, true), "TEMPLATE early done")
	expect(string.find(source, "\tplayed = 0,", 1, true), "TEMPLATE played = 0")
	expect(string.find(source, "profile.Data.early = 0", 1, true), "new profiles get the early pulls")
	expect(string.find(source, "CURRENT_VERSION = 12", 1, true), "schema bumped")
end)

test("nextFloor says what the next cast is guaranteed, without changing the save", function()
	local save = { hotStart = 2, pity = {}, early = Actors.EarlyDone, played = 0 }
	local floor, why = Actors.nextFloor(save, OPEN)
	equal(floor, "Rising", "cast 3 is a Rising")
	equal(why, "hotStart", "reason")
	equal(save.hotStart, 2, "pure")
	save.hotStart = 9
	floor = Actors.nextFloor(save, OPEN)
	equal(floor, "Pro", "cast 10 is a Pro")
	save.hotStart = 24
	equal(Actors.nextFloor(save, OPEN), "Star", "cast 25 is a Star")
	save.hotStart = 5
	equal(Actors.nextFloor(save, OPEN), nil, "an ordinary cast has none")
	save.hotStart = Actors.HotStartLength
	equal(Actors.nextFloor(save, OPEN), nil, "the hot start is over")
end)

test("nextFloor: pity, first Superstar, and the best floor wins", function()
	local save = veteran()
	save.pity.Open = Actors.PityEvery - 2
	equal(Actors.nextFloor(save, OPEN), nil, "two casts out")
	save.pity.Open = Actors.PityEvery - 1
	local floor, why = Actors.nextFloor(save, OPEN)
	equal(floor, "Star", "Open Casting pity")
	equal(why, "pity", "reason")
	equal(Actors.nextFloor(save, TALENT), nil, "meters are per agency")
	save.pity.Talent = Actors.PityEvery - 1
	equal(Actors.nextFloor(save, TALENT), "Superstar", "Talent Agency pity")

	save = { hotStart = Actors.HotStartLength, pity = {}, early = 0, played = Actors.FirstSuperstarAfter - 1 }
	equal(Actors.nextFloor(save, OPEN), nil, "not yet 12 minutes")
	save.played = Actors.FirstSuperstarAfter
	floor, why = Actors.nextFloor(save, OPEN)
	equal(floor, "Superstar", "first Superstar")
	equal(why, "firstSuperstar", "reason")
	equal(Actors.nextFloor(save, OPEN, true), nil, "live switch")
	save.hotStart = 2
	equal(Actors.nextFloor(save, OPEN), "Superstar", "the better floor wins over a hot start Rising")
	save.pity.Open = Actors.PityEvery - 1
	equal(select(2, Actors.nextFloor(save, OPEN)), "firstSuperstar", "a Superstar beats a Star pity")
end)

test("castWithGuarantees rolls with exactly the floor nextFloor announced", function()
	for hotStart = 0, Actors.HotStartLength do
		local save = { hotStart = hotStart, pity = { Open = Actors.PityEvery - 1 }, early = 0, played = Actors.FirstSuperstarAfter }
		local copy = { hotStart = hotStart, pity = { Open = Actors.PityEvery - 1 }, early = 0, played = Actors.FirstSuperstarAfter }
		local announced, why = Actors.nextFloor(copy, OPEN)
		local seen = {}
		local _, _, guarantee, used = Actors.castWithGuarantees(save, OPEN, rollAs("Newcomer", seen))
		equal(seen[1], announced or false, `hotStart {hotStart}: the roll got the announced floor`)
		equal(used, announced, "and it is returned")
		equal(guarantee, why, "with the same reason")
	end
end)
