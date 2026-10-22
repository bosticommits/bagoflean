local H = require("./harness")
local Actors = H.require("Actors")
local Movies = H.require("Movies")
local Unlocks = H.require("Unlocks")
local test, expect, equal = H.test, H.expect, H.equal

local function has(list: { string }, name: string): boolean
	return table.find(list, name) ~= nil
end

test("every Fame gate is in the unlock list, lowest first", function()
	for _, agency in Actors.Agencies do
		if agency.fame > 0 then
			expect(has(Unlocks.crossed(0, agency.fame), agency.name), `{agency.name} is listed`)
		end
	end
	for _, length in Movies.Lengths do
		if length.fame > 0 then
			expect(has(Unlocks.crossed(0, length.fame), `{length.name} scripts`), `{length.name} is listed`)
		end
	end
	for genre, fame in Movies.GenreFame do
		if fame > 0 then
			expect(has(Unlocks.crossed(0, fame), `{genre} scripts`), `{genre} is listed`)
		end
	end
	for i = 2, #Unlocks.List do
		expect(Unlocks.List[i].fame >= Unlocks.List[i - 1].fame, "sorted by Fame")
	end
end)

test("a premiere names only the gates its Fame crossed, once", function()
	local talent = Actors.getAgency("Talent")
	assert(talent ~= nil)
	expect(has(Unlocks.crossed(talent.fame - 1, talent.fame), talent.name), "reaching the gate exactly unlocks it")
	expect(not has(Unlocks.crossed(talent.fame, talent.fame + 500), talent.name), "already past it: not again")
	expect(not has(Unlocks.crossed(0, talent.fame - 1), talent.name), "one short: still locked")
	equal(#Unlocks.crossed(500, 500), 0, "no Fame gained, nothing new")
	equal(#Unlocks.crossed(0, 0), 0, "nothing opens at 0 Fame")
end)

test("a big premiere can open several things in gate order", function()
	local names = Unlocks.crossed(0, math.huge)
	equal(#names, #Unlocks.List, "everything opens eventually")
	local seen = {}
	for _, name in names do
		expect(not seen[name], `{name} listed once`)
		seen[name] = true
	end
end)
