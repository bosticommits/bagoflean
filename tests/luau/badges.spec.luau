--!strict
local fs = require("@lune/fs")
local H = require("./harness")
local Actors = H.require("Actors")
local test, expect, equal = H.test, H.expect, H.equal

test("tierRank orders tiers so Star and above earn A Star is Born", function()
	local star = Actors.tierRank("Star")
	for _, id in { "Star", "Superstar", "Legend", "Icon" } do
		expect(Actors.tierRank(id) >= star, `{id} should count`)
	end
	for _, id in { "Newcomer", "Rising", "Pro" } do
		expect(Actors.tierRank(id) < star, `{id} should not count`)
	end
	equal(Actors.tierRank("Nope"), 0)
end)

test("BadgeAwards marks the cache before spawning and only an award failure clears it", function()
	local source = fs.readFile("src/server/BadgeAwards.luau")
	local mark = string.find(source, "awardedCache[userId][badgeId] = true", 1, true)
	local spawn = string.find(source, "task.spawn", 1, true)
	expect(mark ~= nil and spawn ~= nil and mark < spawn, "cache marked before task.spawn")
	local _, clears = string.gsub(source, "giveUp()", "")
	equal(clears, 2) -- the definition and the one award-failure call
end)
