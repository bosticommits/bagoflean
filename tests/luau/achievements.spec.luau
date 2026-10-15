local H = require("./harness")
local Achievements = H.require("Achievements")
local Actors = H.require("Actors")
local Movies = H.require("Movies")
local test, expect, equal = H.test, H.expect, H.equal

local function view(stats: any?, index: any?, trophies: number?, fame: number?): any
	return { stats = stats or {}, index = index or {}, trophies = trophies or 0, fame = fame or 0 }
end

test("every achievement has a unique id, a known stat and a valid reward", function()
	local seen = {}
	for _, a in Achievements.List do
		expect(not seen[a.id], `duplicate achievement id {a.id}`)
		seen[a.id] = true
		expect(a.target > 0 and a.target == math.floor(a.target), `{a.id} target`)
		expect(#a.text > 0, `{a.id} text`)
		local stat = a.stat
		local known = table.find(Achievements.Counted, stat) ~= nil or stat == "masterpiece" or stat == "fame" or stat == "index" or stat == "actors"
		local tier = string.match(stat, "^tier:(.+)$")
		local variant = string.match(stat, "^variant:(.+)$")
		known = known or (tier ~= nil and Actors.getTier(tier) ~= nil) or (variant ~= nil and Actors.getVariant(variant) ~= nil)
		expect(known, `{a.id} unknown stat {stat}`)
		local r = a.reward
		local gives = false
		for _, field in { "cash", "cashMinutes", "luckMinutes", "skips" } do
			if r[field] ~= nil then
				expect(r[field] > 0, `{a.id} {field}`)
				gives = true
			end
		end
		if r.script ~= nil then
			expect(Movies.isGenre(r.script.genre) and Movies.getLength(r.script.length) ~= nil, `{a.id} script`)
			gives = true
		end
		expect(gives, `{a.id} gives nothing`)
	end
end)

test("goals in a group get harder and the Index goal fits the Index", function()
	for _, group in Achievements.groups() do
		for i = 2, #group.list do
			local a, b = group.list[i - 1], group.list[i]
			expect(a.stat ~= b.stat or b.target > a.target, `{b.id} is not harder than {a.id}`)
		end
	end
	for _, a in Achievements.List do
		if a.stat == "index" then
			expect(a.target <= Actors.IndexSlots, `{a.id} needs more than the Index holds`)
		elseif a.stat == "actors" then
			expect(a.target <= #Actors.List, `{a.id} needs more actors than exist`)
		end
	end
end)

test("progress counts stats, the Index, trophies and Fame", function()
	local cast = Achievements.get("Cast1")
	equal(Achievements.progress(view({ cast = 4 }), cast), 4, "partial cast progress")
	equal(Achievements.progress(view({ cast = 400 }), cast), cast.target, "progress caps at the target")
	expect(Achievements.isDone(view({ cast = 10 }), cast), "done at the target")
	equal(Achievements.value(view(nil, nil, 3), "masterpiece"), 3, "trophies")
	equal(Achievements.value(view(nil, nil, 0, 1234), "fame"), 1234, "fame")

	local index = {
		["NervousIntern:Normal"] = true,
		["NervousIntern:Shiny"] = true,
		["TeenHeartthrob:Normal"] = true,
		["RetiredActor:Normal"] = true, -- unknown actor: never counts
		["StuntDouble:Normal"] = false,
	}
	equal(Achievements.value(view(nil, index), "index"), 3, "index count skips unknown and false keys")
	equal(Achievements.value(view(nil, index), "tier:Star"), 1, "a Star discovered")
	equal(Achievements.value(view(nil, index), "tier:Legend"), 0, "no Legend")
	equal(Achievements.value(view(nil, index), "variant:Shiny"), 1, "a Shiny discovered")
	equal(Achievements.value(view(nil, index), "actors"), 2, "actors count each actor once, in any variant")
end)

test("the top Index goal is every actor, not every variant", function()
	-- An Award-Winning Icon is about 1 in 26 million casts even at Hollywood Casting, so a goal that
	-- needs all 63 slots could never be earned (see ECONOMY_SUMMARY.md).
	local top = Achievements.get("Index5")
	expect(top ~= nil, "Index5 exists")
	local goal = top :: Achievements.Achievement
	equal(goal.stat, "actors", "Index5 counts actors")
	equal(goal.target, #Actors.List, "Index5 asks for every actor")
	local every = {}
	for _, actor in Actors.List do
		every[Actors.key(actor.id, "Normal")] = true
	end
	expect(Achievements.isDone(view(nil, every), goal), "one of each actor completes it")
end)

test("claimable lists finished goals that are not claimed", function()
	local v = view({ cast = 150 })
	local ready = Achievements.claimable(v, {})
	expect(table.find(ready, "Cast1") ~= nil and table.find(ready, "Cast2") ~= nil, "both cast goals ready")
	expect(table.find(ready, "Cast3") == nil, "500 casts not reached")
	ready = Achievements.claimable(v, { Cast1 = true })
	expect(table.find(ready, "Cast1") == nil, "claimed goals are not claimable")
	equal(#Achievements.claimable(view(), {}), 0, "a new player has nothing to claim")
end)
