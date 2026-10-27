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
	equal(FilmSets.priceText(FilmSets.get("MoonBase")), "$250K", "Moon Base's price")
	equal(FilmSets.priceText(FilmSets.get("Jungle")), "$2.5M", "the Jungle Temple's price")
	-- Dearer sets give more Luck.
	for i = 2, #FilmSets.List do
		local a, b = FilmSets.List[i - 1], FilmSets.List[i]
		expect(b.price > a.price and b.luck > a.luck, `{b.id} should cost and give more than {a.id}`)
	end
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
	data.filmSetsOwned = { Gulch = true, Jungle = true, MoonBase = true }
	equal(FilmSets.luck(data), 0.15, "only the best set counts")
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
					local width = math.min(info.area.x1 - info.area.x0, info.area.z1 - info.area.z0)
					expect(d.Size.X >= width, `{set.id}'s wall is narrower than the set`)
					local p = d.CFrame.Position
					expect(not Walkways.isWalkable({ info.area }, p.X, p.Z), `{set.id}'s wall stands inside the set`)
					expect(Walkways.isWalkable(MapModels.PlayAreas, p.X, p.Z), `{set.id}'s wall stands off the map`)
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
	for id, scenes in FilmScenes.Sets do
		for _, who in scenes.cast do
			for _, part in { "Head", "Torso", "Arm", "Leg" } do
				local name = `Crew{who}{part}`
				expect(MapKitShapes.Shapes[name] ~= nil, `{name} is missing: run art/blender/map_kit.py`)
			end
		end
		for _, kit in scenes.things do
			expect(MapKitShapes.Shapes[kit] ~= nil, `{id}'s {kit} is not a kit model`)
		end
		for _, gear in scenes.gear do
			expect(MapKitShapes.Shapes[gear.kit] ~= nil, `{id}'s {gear.kit} is not a kit model`)
		end
	end
	for _, name in { "PropMegaphone", "PropRevolver", "PropClapper", "PropClapperStick", "PropFlag", "PropIdol", "PropTorch", "SetGate", "SetGateArm" } do
		expect(MapKitShapes.Shapes[name] ~= nil, `{name} is missing: run art/blender/map_kit.py`)
	end
	expect(MapKitShapes.Spots.PropClapper.Board ~= nil, "the clapperboard has a board to write on")
end)

local function infoFor(id: string): any
	for _, info in MapModels.FilmSets do
		if info.id == id then
			return info
		end
	end
	return nil
end

test("every scene plays inside its set: everyone on set, no one jumping about", function()
	for id, scenes in FilmScenes.Sets do
		local info = infoFor(id)
		expect(info ~= nil, `{id} has scenes but no place on the map`)
		local base = info.frame
		local said: { [string]: boolean } = {}
		local shots = 0
		local t = 0
		while t < scenes.period do
			local frame = FilmScenes.frame(id, t)
			for _, who in scenes.cast do
				local pose = frame.poses[who]
				expect(pose ~= nil, `{id}: {who} has no pose at {frame.time} in scene {frame.scene}`)
				if not pose.hidden then
					local torso = CrewRig.cframes(base, pose, frame.stick).Torso.Position
					expect(Walkways.isWalkable({ info.area }, torso.X, torso.Z), `{id}: {who} leaves the set at {frame.time}`)
					expect(torso.Y > 0 and torso.Y < 22, `{id}: {who} is at height {torso.Y}`)
				end
			end
			for kit, at in frame.things do
				expect(table.find(scenes.things, kit) ~= nil, `{id} shows {kit}, which it never builds`)
				local p = (base * at).Position
				expect(Walkways.isWalkable({ info.area }, p.X, p.Z), `{id}: the {kit} leaves the set at {frame.time}`)
			end
			for who, words in frame.say do
				said[words] = true
				expect(frame.poses[who] ~= nil, `{id}: {who} speaks without being on set`)
			end
			if frame.shot ~= nil and frame.poses[frame.shot].hold == "PropRevolver" then
				shots += 1
			end
			t += 0.05
		end
		if id == "Gulch" then
			expect(shots > 0, "the Gulch fires no shot with a revolver in hand")
		end
		-- The slate names the scene and the take.
		local found = false
		for words in said do
			if string.match(words, "^Scene %d, take %d+!$") then
				found = true
			end
		end
		expect(found, `the clapper loader slates {id}'s takes`)
	end
end)
