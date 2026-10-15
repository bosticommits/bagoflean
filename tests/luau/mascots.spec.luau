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
		expect(mascot.unlock ~= "" and mascot.blurb ~= "" and mascot.name ~= "", `{mascot.id} needs its words`)
		expect(mascot.stat == "free" or mascot.target > 0, `{mascot.id} has no target`)
	end
	for id in MascotShapes.Shapes do
		expect(seen[id], `MascotShapes has {id}, which is not in the list`)
	end
	equal(Mascots.get(Mascots.Default) ~= nil, true, "the default mascot exists")
end)

test("a brand-new player has the Popcorn Pup and nothing else", function()
	local data = { stats = {}, index = {}, fame = 0, rebirths = 0, trophies = 0 }
	local unlocked = Mascots.unlocked(data)
	equal(#unlocked, 1, "one mascot")
	equal(unlocked[1], "PopcornPup", "the pup")
	equal(Mascots.equipped(data), "PopcornPup", "shown by default")
end)

test("each mascot unlocks from the milestone it names", function()
	local data = { stats = { premiere = 9 }, index = {}, fame = 0, rebirths = 0, trophies = 0 }
	local croc = Mascots.get("ClapperCroc")
	expect(not Mascots.isUnlocked(croc, data), "9 premieres is not enough")
	data.stats.premiere = 10
	expect(Mascots.isUnlocked(croc, data), "10 premieres")
	for i = 1, 15 do
		data.index[`Actor{i}:Normal`] = true
	end
	expect(Mascots.isUnlocked(Mascots.get("ReelKitty"), data), "15 Index slots")
	local talent
	for _, agency in Actors.Agencies do
		if agency.id == "Talent" then
			talent = agency.fame
		end
	end
	data.fame = talent
	expect(Mascots.isUnlocked(Mascots.get("CameraBot"), data), "the Talent Agency's Fame")
	data.rebirths = 1
	expect(Mascots.isUnlocked(Mascots.get("SpotlightOwl"), data), "a rebirth")
	expect(not Mascots.isUnlocked(Mascots.get("PremiereDragon"), data), "no Masterpiece yet")
	data.trophies = 1
	equal(#Mascots.unlocked(data), #Mascots.List, "everything after a Masterpiece")
end)

test("the saved choice is kept only while it is earned, and hiding sticks", function()
	local data = { stats = {}, index = {}, fame = 0, rebirths = 0, trophies = 1, mascot = "PremiereDragon" }
	equal(Mascots.equipped(data), "PremiereDragon", "an earned choice")
	data.mascot = "CameraBot"
	equal(Mascots.equipped(data), "PopcornPup", "a choice not earned falls back to the pup")
	data.mascot = ""
	equal(Mascots.equipped(data), "", "hidden")
	data.mascot = 42
	equal(Mascots.equipped(data), "PopcornPup", "a broken save shows the pup")
	data.mascot = "NoSuchMascot"
	equal(Mascots.equipped(data), "PopcornPup", "an unknown id shows the pup")
end)

test("progress never errors on an old or broken save", function()
	for _, mascot in Mascots.List do
		equal(Mascots.progress(mascot, {}), 0, `{mascot.id} on an empty save`)
		equal(Mascots.progress(mascot, { stats = "x", index = 3, fame = "y" }), 0, `{mascot.id} on a broken save`)
	end
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
	local data: any = { stats = {}, index = {}, fame = 0, rebirths = 1, trophies = 1, mascot = "PremiereDragon", mascotSince = 1000 }
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
	data.fame = 0
	equal(Mascots.boost(data, "boxOffice", warm), 0, "a mascot not earned yet gives nothing")
	equal(Mascots.boost(data, "cash", warm), 0.05, "it falls back to the pup, whose buff counts")
end)

test("an older save with no equip time gets its buff straight away", function()
	local data = { stats = {}, index = {}, fame = 0, rebirths = 0, trophies = 0 }
	equal(Mascots.boost(data, "cash", 1800000000), 0.05, "the pup's Cash")
	equal(Mascots.warmUpLeft(data, 1800000000), 0, "no warm-up")
end)
