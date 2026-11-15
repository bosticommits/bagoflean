local H = require("./harness")
local Lines = H.require("LoadingLines")
local test, equal = H.test, H.equal

local quiet = { awardNight = false, luckMultiplier = 1, surpriseName = nil, festivalGenre = nil }
local function with(changes)
	local live = table.clone(quiet)
	for k, v in changes do
		live[k] = v
	end
	return live
end

test("welcome back uses the display name", function()
	equal(Lines.welcomeBack("Ada"), "Welcome back, Ada!")
end)

test("nothing on means no live line", function()
	equal(Lines.liveLine(quiet), nil)
	equal(Lines.liveLine(with({ luckMultiplier = 1 })), nil)
end)

test("each live thing gets its line", function()
	equal(Lines.liveLine(with({ luckMultiplier = 2 })), "Luck Weekend x2")
	equal(Lines.liveLine(with({ luckMultiplier = 1.25 })), "Luck Weekend x1.25")
	equal(Lines.liveLine(with({ surpriseName = "Lucky Star" })), "Lucky Star is on!")
	equal(Lines.liveLine(with({ festivalGenre = "Horror" })), "Film Festival: Horror week")
	equal(Lines.liveLine(with({ awardNight = true })), "Award Night is live! x2 Luck")
end)

test("priority: Award Night, Luck Weekend, surprise, festival", function()
	local all = { awardNight = true, luckMultiplier = 2, surpriseName = "Cash Rain", festivalGenre = "Comedy" }
	equal(Lines.liveLine(all), "Award Night is live! x2 Luck")
	all.awardNight = false
	equal(Lines.liveLine(all), "Luck Weekend x2")
	all.luckMultiplier = 1
	equal(Lines.liveLine(all), "Cash Rain is on!")
	all.surpriseName = nil
	equal(Lines.liveLine(all), "Film Festival: Comedy week")
end)
