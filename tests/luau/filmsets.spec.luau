local roblox = require("@lune/roblox")

local H = require("./harness")
local FilmSets = H.require("FilmSets")
local FilmScenes = H.require("FilmScenes")
local Rebirth = H.require("Rebirth")
local CrewRig = H.require("Models/CrewRig")
local MapKitShapes = H.require("Models/MapKitShapes")
local MapModels = H.require("Models/MapModels")
local Walkways = H.require("Models/Walkways")
local test, expect, equal = H.test, H.expect, H.equal

test("film sets have a name, a Cash price and boosts under their caps", function()
	local seen = {}
	for _, set in FilmSets.List do
		expect(not seen[set.id], `{set.id} is listed twice`)
		seen[set.id] = true
		expect(set.name ~= "", `{set.id} needs a name`)
		expect(set.price > 0 and set.price == math.floor(set.price), `{set.id} has a broken price`)
		expect(set.luck > 0 and set.luck <= FilmSets.Caps.luck, `{set.id} luck is out of range`)
		expect(set.boxOffice > 0 and set.boxOffice <= FilmSets.Caps.boxOffice, `{set.id} box office is out of range`)
	end
	equal(FilmSets.priceText(FilmSets.get("Gulch")), "$25K", "the Gulch's price on its gate")
	equal(FilmSets.describe(FilmSets.get("Gulch")), "x1.05 casting Luck\nDouble box office inside", "what the Gulch gives")
end)

test("a new player owns no film set; a bought one gives its Luck and survives a rebirth", function()
	local data: any = { upgrades = {}, stageCount = 3, rebirths = 0 }
	equal(#FilmSets.owned(data), 0, "nothing owned")
	equal(FilmSets.luck(data), 0, "no Luck")
	data.filmSetsOwned = "broken"
	equal(#FilmSets.owned(data), 0, "a broken save owns nothing")
	data.filmSetsOwned = { Gulch = true }
	equal(FilmSets.owned(data)[1], "Gulch", "the Gulch is owned")
	equal(FilmSets.luck(data), 0.05, "x1.05 Luck")
	Rebirth.reset(data)
	equal(FilmSets.luck(data), 0.05, "still owned after a rebirth")
end)

test("standing on a set pays the box office again, never less than nothing", function()
	local gulch = FilmSets.get("Gulch")
	equal(FilmSets.payout(gulch, 10), 10 * FilmSets.PayEvery, "double: the same again")
	equal(FilmSets.payout(gulch, 2.5), math.floor(2.5 * FilmSets.PayEvery), "whole Cash")
	equal(FilmSets.payout(gulch, -4), 0, "no negative pay")
end)

local town = roblox.Instance.new("Folder")
local built = MapModels.build(town)

test("every film set has a gate on the way in, a wall across it and a buy prompt", function()
	for _, set in FilmSets.List do
		local info
		for _, i in MapModels.FilmSets do
			if i.id == set.id then
				info = i
			end
		end
		expect(info ~= nil, `{set.id} has no place on the map`)
		local found = { gate = false, arm = false, wall = false }
		for _, d in town:GetDescendants() do
			if d:GetAttribute("FilmSet") == set.id then
				if d.Name == "FilmSetGate" then
					found.gate = true
				elseif d.Name == "FilmSetGateArm" then
					found.arm = true
				elseif d.Name == "FilmSetWall" then
					found.wall = true
					-- Across the whole way in from town, so nobody walks round the gate.
					expect(d.Size.X >= 172, "the wall spans the Gulch's width")
					expect(d.CFrame.Position.Z > info.area.z1 and d.CFrame.Position.Z < -(MapModels.Layout.fenceZ + 1), "the wall stands between town and set")
				end
			end
		end
		expect(found.gate and found.arm and found.wall, `{set.id} gate pieces: {found.gate} {found.arm} {found.wall}`)
		local anchors = 0
		for _, f in built.filmSets do
			if f.id == set.id then
				anchors += 1
				-- The prompt is on the town side of the gate, where buyers stand.
				expect(not Walkways.isWalkable({ info.area }, f.anchor.CFrame.Position.X, f.anchor.CFrame.Position.Z), "the prompt is outside the set")
			end
		end
		equal(anchors, 1, `{set.id} has one buy prompt`)
		-- The set's area is all inside the playable map.
		for _, corner in { { info.area.x0, info.area.z0 }, { info.area.x1, info.area.z1 } } do
			expect(Walkways.isWalkable(MapModels.PlayAreas, corner[1], corner[2]), "the set's area is in the map")
		end
	end
end)

test("every crew piece and prop is in the Blender map kit", function()
	for _, who in FilmScenes.Cast do
		for _, part in { "Head", "Torso", "Arm", "Leg" } do
			local name = `Crew{who}{part}`
			expect(MapKitShapes.Shapes[name] ~= nil, `{name} is missing: run art/blender/map_kit.py`)
		end
	end
	for _, name in { "PropMegaphone", "PropRevolver", "PropClapper", "PropClapperStick", "SetGate", "SetGateArm" } do
		expect(MapKitShapes.Shapes[name] ~= nil, `{name} is missing: run art/blender/map_kit.py`)
	end
	expect(MapKitShapes.Spots.PropClapper.Board ~= nil, "the clapperboard has a board to write on")
	for _, gear in FilmScenes.Gear do
		expect(MapKitShapes.Shapes[gear.kit] ~= nil, `{gear.kit} is not a kit model`)
	end
end)

test("both scenes play inside the set: everyone on set, no one jumping about", function()
	local gulch = MapModels.FilmSets[1]
	local base = MapModels.GulchFrame
	local last: { [string]: any } = {}
	local said: { [number]: { [string]: boolean } } = { {}, {} }
	local shots = { 0, 0 }
	local step = 0.05
	local length = FilmScenes.TakeLength * 2
	for i = 0, length / step do
		local t = 1000 * FilmScenes.TakeLength + i * step -- an even take: scene 1 first
		local frame = FilmScenes.frame(t)
		for _, who in FilmScenes.Cast do
			local pose = frame.poses[who]
			expect(pose ~= nil, `{who} has no pose at {frame.time} in scene {frame.scene}`)
			if pose.hidden then
				last[who] = nil
			else
				local torso = CrewRig.cframes(base, pose, frame.stick).Torso.Position
				expect(Walkways.isWalkable({ gulch.area }, torso.X, torso.Z), `{who} leaves the set at {frame.time} in scene {frame.scene}`)
				expect(torso.Y > 0 and torso.Y < 20, `{who} is at height {torso.Y}`)
				if last[who] ~= nil then
					local moved = (torso - last[who]).Magnitude
					expect(moved < 3, `{who} jumps {moved} studs at {frame.time} in scene {frame.scene}`)
				end
				last[who] = torso
			end
		end
		for who, words in frame.say do
			said[frame.scene][words] = true
			expect(frame.poses[who] ~= nil, `{who} speaks without being on set`)
		end
		if frame.shot ~= nil and frame.poses[frame.shot].hold == "PropRevolver" then
			shots[frame.scene] += 1
		end
	end
	for scene = 1, 2 do
		expect(said[scene]["ACTION!"], `scene {scene} has no ACTION!`)
		expect(said[scene]["CUT! Print it!"], `scene {scene} has no CUT!`)
		expect(shots[scene] > 0, `scene {scene} fires no shot with a revolver in hand`)
	end
	-- The slate names the scene and the take.
	local found = false
	for words in said[1] do
		if string.match(words, "^Scene 1, take %d+!$") then
			found = true
		end
	end
	expect(found, "the clapper loader slates scene 1")
end)

test("the scenes start where the last one ended, so nobody pops into place", function()
	for n = 0, 3 do
		local ending = FilmScenes.frame(n * FilmScenes.TakeLength - 0.001)
		local starting = FilmScenes.frame(n * FilmScenes.TakeLength)
		for _, who in FilmScenes.Cast do
			local a, b = ending.poses[who], starting.poses[who]
			if not a.hidden then
				local gap = (a.at - b.at).Magnitude
				expect(gap < 0.2, `{who} pops {gap} studs as scene {starting.scene} starts`)
			end
		end
	end
end)
