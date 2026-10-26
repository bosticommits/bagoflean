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

test("early pulls: tease after TeaseAfter on a decent roll, then one Superstar", function()
	local save = { hotStart = Actors.HotStartLength, pity = {}, early = 0, played = Actors.TeaseAfter - 1 }
	local _, _, _, tease = Actors.castWithGuarantees(save, OPEN, rollAs("Pro"))
	equal(tease, nil, "too early")
	save.played = Actors.TeaseAfter
	_, _, _, tease = Actors.castWithGuarantees(save, OPEN, rollAs("Rising"))
	equal(tease, nil, "never teases onto a weak roll")
	_, _, _, tease = Actors.castWithGuarantees(save, OPEN, rollAs("Pro"))
	equal(tease, "nearMiss", "teased")
	equal(save.early, 1, "tease saved")
	_, _, _, tease = Actors.castWithGuarantees(save, OPEN, rollAs("Pro"))
	equal(tease, nil, "only once")
	save.played = Actors.FirstSuperstarAfter
	local actor, _, guarantee = Actors.castWithGuarantees(save, OPEN, rollAs("Newcomer"))
	equal(actor.tier, "Superstar", "guaranteed Superstar")
	equal(guarantee, "firstSuperstar", "reason")
	equal(save.early, Actors.EarlyDone, "done")
	actor, _, guarantee = Actors.castWithGuarantees(save, OPEN, rollAs("Newcomer"))
	equal(actor.tier, "Newcomer", "normal odds after")
	equal(guarantee, nil, "no more guarantees")
end)

test("early pulls: a natural Superstar first uses the guarantee up; veterans get none", function()
	local save = { hotStart = Actors.HotStartLength, pity = {}, early = 0, played = 60 }
	Actors.castWithGuarantees(save, OPEN, rollAs("Superstar"))
	equal(save.early, Actors.EarlyDone, "natural Superstar counts")
	local old = veteran()
	old.played = 99999
	local actor, _, guarantee, tease = Actors.castWithGuarantees(old, OPEN, rollAs("Pro"))
	equal(actor.tier, "Pro", "no Superstar for old saves")
	equal(guarantee, nil, "no guarantee")
	equal(tease, nil, "no tease")
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
