local H = require("./harness")
local Actors = H.require("Actors")
local Mascots = H.require("Mascots")
local MascotShapes = H.require("Models/MascotShapes")
local test, expect, equal = H.test, H.expect, H.equal

test("every mascot has a Blender design, a rarity color and a goal", function()
	local seen = {}
	for _, mascot in Mascots.List do
		expect(not seen[mascot.id], `{mascot.id} is listed twice`)
		seen[mascot.id] = true
		expect(Actors.getTier(mascot.tier) ~= nil, `{mascot.id} has an unknown tier {mascot.tier}`)
		local shapes = MascotShapes.Shapes[mascot.id]
		expect(shapes ~= nil and #shapes > 5, `{mascot.id} has no shapes: run art/blender/mascots.py`)
		local bounds = MascotShapes.Bounds[mascot.id]
		expect(bounds ~= nil, `{mascot.id} has no bounds`)
		-- About the height of a character's chest: big enough to see, small enough not to block.
		expect(bounds.size.Y > 2 and bounds.size.Y < 4.5, `{mascot.id} is {bounds.size.Y} studs tall`)
		expect(mascot.blurb ~= "" and mascot.name ~= "", `{mascot.id} needs its words`)
		expect(mascot.price >= 0 and mascot.price == math.floor(mascot.price), `{mascot.id} has a broken price`)
	end
	for id in MascotShapes.Shapes do
		expect(seen[id], `MascotShapes has {id}, which is not in the list`)
	end
	equal(Mascots.get(Mascots.Default) ~= nil, true, "the default mascot exists")
end)

test("a brand-new player has the Popcorn Pup and nothing else", function()
	local data = { stats = {}, index = {}, fame = 0, rebirths = 0, trophies = 0 }
	local unlocked = Mascots.owned(data)
	equal(#unlocked, 1, "one mascot")
	equal(unlocked[1], "PopcornPup", "the pup")
	equal(Mascots.equipped(data), "PopcornPup", "shown by default")
end)

test("only the starter is free, and prices and buffs rise together", function()
	local free = 0
	local previous = -1
	for _, mascot in Mascots.List do
		if mascot.price == 0 then
			free += 1
		end
		expect(mascot.price > previous, `{mascot.id} is not dearer than the one before it`)
		previous = mascot.price
	end
	equal(free, 1, "one free mascot")
	equal(Mascots.List[1].id, Mascots.Default, "the free one is the default")
	-- The two strongest buffs cost the most.
	for _, mascot in Mascots.List do
		if mascot.buff.amount >= 0.2 then
			expect(mascot.price >= 1000000, `{mascot.id}'s top buff is too cheap`)
		end
	end
end)

test("a bought mascot is owned for good, others are not", function()
	local data: any = { stats = {}, index = {}, fame = 0, rebirths = 0, trophies = 0 }
	local kitty = Mascots.get("ReelKitty")
	expect(not Mascots.owns(kitty, data), "not bought yet")
	data.mascotsOwned = { ReelKitty = true }
	expect(Mascots.owns(kitty, data), "bought")
	equal(#Mascots.owned(data), 2, "the pup and the kitty")
	data.mascotsOwned = "broken"
	equal(#Mascots.owned(data), 1, "a broken set leaves just the pup")
end)

test("the saved choice is kept only while it is owned, and hiding sticks", function()
	local data: any = { mascot = "PremiereDragon", mascotsOwned = { PremiereDragon = true } }
	equal(Mascots.equipped(data), "PremiereDragon", "an owned choice")
	data.mascot = "CameraBot"
	equal(Mascots.equipped(data), "PopcornPup", "a choice not owned falls back to the pup")
	data.mascot = ""
	equal(Mascots.equipped(data), "", "hidden")
	data.mascot = 42
	equal(Mascots.equipped(data), "PopcornPup", "a broken save shows the pup")
	data.mascot = "NoSuchMascot"
	equal(Mascots.equipped(data), "PopcornPup", "an unknown id shows the pup")
end)

test("no mascot buff goes over its cap, and the caps stay under the Robux passes", function()
	local Config = H.require("Config")
	for _, mascot in Mascots.List do
		local cap = Mascots.Caps[mascot.buff.kind]
		expect(cap ~= nil, `{mascot.id} has an unknown buff kind {mascot.buff.kind}`)
		expect(mascot.buff.amount > 0 and mascot.buff.amount <= cap, `{mascot.id} gives {mascot.buff.amount}, over {cap}`)
		expect(Mascots.describe(mascot.buff) ~= "", `{mascot.id} needs its buff words`)
	end
	expect(1 + Mascots.Caps.luck < Config.PassLuckMultiplier, "a Luck mascot beats the 2x Luck pass")
	expect(Mascots.Caps.speed < 1 - Config.FastFilmingMultiplier, "a speed mascot beats Faster Filming")
end)

test("only the equipped mascot's buff counts, after its warm-up", function()
	local data: any = { mascot = "PremiereDragon", mascotsOwned = { PremiereDragon = true, SpotlightOwl = true }, mascotSince = 1000 }
	local warm = 1000 + Mascots.WarmUp
	equal(Mascots.boost(data, "cash", warm - 1), 0, "still warming up")
	equal(Mascots.warmUpLeft(data, warm - 10), 10, "seconds left")
	equal(Mascots.boost(data, "cash", warm), 0.2, "Dragon's Cash once warm")
	equal(Mascots.boost(data, "luck", warm), 0, "Dragon gives no Luck while the Owl stays home")
	data.mascot = "SpotlightOwl"
	equal(Mascots.boost(data, "luck", warm), 0.2, "Owl's Luck")
	equal(Mascots.boost(data, "cash", warm), 0, "no Cash from the Owl")
	data.mascot = ""
	for kind in Mascots.Caps do
		equal(Mascots.boost(data, kind, warm), 0, `a hidden mascot gives no {kind}`)
	end
	data.mascot = "CameraBot"
	equal(Mascots.boost(data, "boxOffice", warm), 0, "a mascot not bought gives nothing")
	equal(Mascots.boost(data, "cash", warm), 0.05, "it falls back to the pup, whose buff counts")
end)

test("an older save with no equip time gets its buff straight away", function()
	local data = { stats = {}, index = {}, fame = 0, rebirths = 0, trophies = 0 }
	equal(Mascots.boost(data, "cash", 1800000000), 0.05, "the pup's Cash")
	equal(Mascots.warmUpLeft(data, 1800000000), 0, "no warm-up")
end)
