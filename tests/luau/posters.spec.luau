local H = require("./harness")
local Posters = H.require("Posters")
local test, expect, equal = H.test, H.expect, H.equal

local function poster(title: string, genre: string?)
	return { title = title, genre = genre or "Horror", cast = { "Intern:Normal" }, time = 100 }
end

test("an old save with no posters loads as an empty list", function()
	equal(#Posters.clean(nil), 0)
	equal(#Posters.clean("garbage"), 0)
	equal(#Posters.clean({}), 0)
end)

test("a saved list keeps its good posters and drops the damaged ones", function()
	local cleaned = Posters.clean({
		poster("Night of the Mop"),
		{ title = 5, genre = "Horror" }, -- wrong type
		{ title = "", genre = "Horror" }, -- empty title
		"nope",
		{ title = "No Cast Film", genre = "Comedy", time = -1 / 0 + 1 / 0 }, -- NaN time, no cast
		{ title = "Big Cast", genre = "Action", cast = { "A:1", "B:1", "C:1", "D:1" }, time = 5 },
	})
	equal(#cleaned, 3)
	equal(cleaned[1].title, "Night of the Mop")
	equal(cleaned[2].time, 0)
	equal(#cleaned[2].cast, 0)
	equal(#cleaned[3].cast, 3, "a poster never holds more than 3 cast")
end)

test("the list is capped, newest kept", function()
	local list = {}
	for i = 1, Posters.Cap + 5 do
		expect(Posters.add(list, poster("Film " .. i)), "added")
	end
	equal(#list, Posters.Cap)
	equal(list[1].title, "Film 6")
	equal(list[#list].title, "Film " .. (Posters.Cap + 5))
	-- cleaning a too-long saved list trims it the same way
	local long = {}
	for i = 1, Posters.Cap + 3 do
		table.insert(long, poster("Film " .. i))
	end
	equal(#Posters.clean(long), Posters.Cap)
end)

test("the same film never earns a second poster", function()
	local list = {}
	expect(Posters.add(list, poster("Twin Peaks of Doom")), "first")
	expect(not Posters.add(list, poster("Twin Peaks of Doom")), "duplicate refused")
	expect(Posters.add(list, poster("Twin Peaks of Doom", "Comedy")), "another genre is another film")
	equal(#list, 2)
	expect(not Posters.add(list, { title = "", genre = "Horror", cast = {}, time = 1 }), "malformed refused")
end)
