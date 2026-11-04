local roblox = require("@lune/roblox")

local H = require("./harness")
local Config = H.require("Config")
local CrewRig = H.require("Models/CrewRig")
local FilmScenes = H.require("FilmScenes")
local FilmSets = H.require("FilmSets")
local Walkways = H.require("Models/Walkways")
local IconModels = H.require("Models/IconModels")
local LotModels = H.require("Models/LotModels")
local MapModels = H.require("Models/MapModels")
local Visits = H.require("Visits")
local test, expect, equal = H.test, H.expect, H.equal

local Vector3 = roblox.Vector3

local bases = {}
for index = 1, Config.LotCount do
	bases[index] = MapModels.lotBase(index)
end

test("a visit record keeps today's tours and applause, and starts fresh on a new day", function()
	local today = Visits.fresh({ day = 100, toured = { ["7"] = true }, applauded = { ["7"] = true, bad = 1 } }, 100)
	expect(today.toured["7"] and today.applauded["7"], "today's record is kept")
	equal(today.applauded.bad, nil, "malformed entries are dropped")
	local tomorrow = Visits.fresh(today, 101)
	equal(tomorrow.day, 101, "the new day")
	equal(next(tomorrow.toured), nil, "no tours yet tomorrow")
	equal(next(tomorrow.applauded), nil, "applause can count again tomorrow")
	local broken = Visits.fresh("nonsense", 5)
	expect(broken.day == 5 and next(broken.applauded) == nil, "a broken save becomes an empty day")
end)

test("every lot is found from where a player stands, and the boulevard is on no lot", function()
	for index, base in bases do
		equal(Visits.lotAt(base.Position + Vector3.new(0, 3, 0), bases), index, `centre of lot {index}`)
		local corner = base * Vector3.new(LotModels.Layout.size / 2 - 1, 3, LotModels.Layout.size / 2 - 1)
		equal(Visits.lotAt(corner, bases), index, `back corner of lot {index}`)
	end
	-- Halfway between the two rows of lots is the boulevard.
	local boulevard = (bases[1].Position + bases[4].Position) / 2 + Vector3.new(0, 3, 0)
	equal(Visits.lotAt(boulevard, bases), nil, "the boulevard")
	equal(Visits.lotAt(Vector3.new(0, 3, 0), bases), nil, "the spawn plaza")
	-- Neighbouring lots never overlap, even with the premiere watching margin.
	for index, base in bases do
		local edge = base * Vector3.new(LotModels.Layout.size / 2 + Visits.WatchMargin, 3, 0)
		local found = Visits.lotAt(edge, bases, Visits.WatchMargin)
		expect(found == index or found == nil, `lot {index}'s watching margin reaches lot {found}`)
	end
end)

test("visitors land inside the gate, on their lot, facing the cinema and off the pads", function()
	local L = LotModels.Layout
	for index, base in bases do
		local arrival = Visits.arrival(base)
		equal(Visits.lotAt(arrival.Position, bases), index, `lot {index} arrival is on the lot`)
		local into = base:VectorToObjectSpace(arrival.LookVector)
		expect(into.Z > 0.99, `lot {index} arrival faces up the red carpet`)
		local at = base:PointToObjectSpace(arrival.Position)
		expect(at.Z > L.gateZ, "inside the gate")
		-- The claim and collect pads are 8 studs square: landing on one would touch it.
		for _, pad in { L.claimPad, L.collectPad } do
			local clear = math.abs(at.X - pad.X) > 4 or math.abs(at.Z - pad.Z) > 4
			expect(clear, `lot {index} arrival is clear of the pad at {pad}`)
		end
	end
end)

test("studio status reads ready, filming with a countdown, or between films", function()
	equal(Visits.status(nil, 1000).kind, "idle", "nothing filming")
	equal(Visits.status(900, 1000).kind, "ready", "a film is done")
	local filming = Visits.status(1125, 1000)
	equal(filming.kind, "filming", "still filming")
	equal(filming.text, "Filming  2:05", "minutes and seconds")
	equal(Visits.status(1000 + 3 * 3600 + 120, 1000).text, "Filming  3h 2m", "hours for long films")
	equal(Visits.nextPremiere({ { endTime = 50 }, { endTime = 20 }, { bad = true } }), 20, "the soonest film")
	equal(Visits.nextPremiere({}), nil, "no films")
end)

test("applause counts read well and never go below zero", function()
	equal(Visits.applauseText(0), "👏 0")
	equal(Visits.applauseText(7), "👏 7")
	equal(Visits.applauseText(1234), "👏 1,234")
	equal(Visits.applauseText(1234567), "👏 1,234,567")
	equal(Visits.applauseText(-3), "👏 0")
end)

test("the Visit button has its 3D icon", function()
	expect(table.find(IconModels.Ids, "visit") ~= nil, "visit is an icon id")
	local holder = roblox.Instance.new("Folder")
	local model = IconModels.build(holder, "visit")
	expect(#model:GetChildren() > 5, "the icon builds parts")
end)

test("applause can't be spammed and a tour takes a real stay", function()
	expect(Visits.DwellSeconds >= 3, "a tour needs a few seconds on the lot")
	expect(Visits.ApplaudCooldown >= 1, "claps are spaced out")
	expect(Visits.TeleportCooldown >= 2, "jumps are spaced out")
end)

-- Film sets -------------------------------------------------------------------------------------

test("a film set jump takes only a known set id and a real save", function()
	local owned = { filmSetsOwned = { Gulch = true } }
	for _, bad in { nil, 5, true, {}, "", "Nope", "gulch", string.rep("G", 41), "Gulch\0" } do
		equal(Visits.filmSetArrival(bad, owned), nil, `id {bad} is refused`)
	end
	equal(Visits.filmSetArrival("Gulch", nil), nil, "no save, no jump")
	equal(Visits.filmSetArrival("Gulch", "broken"), nil, "a broken save, no jump")
	local _, inside = Visits.filmSetArrival("Gulch", owned)
	expect(inside, "an owner goes inside")
	local _, outside = Visits.filmSetArrival("Gulch", { filmSetsOwned = "broken" })
	expect(not outside, "a broken owned list owns nothing: the gate")
	-- Moon Base's gate is in Dusty Gulch: no jumping past the Gulch's gate.
	local spot, _, needs = Visits.filmSetArrival("MoonBase", {})
	expect(spot == nil and needs == "Gulch", "Moon Base's gate needs the Gulch first")
	expect(Visits.filmSetArrival("MoonBase", owned) ~= nil, "with the Gulch, Moon Base's gate")
	expect(Visits.filmSetArrival("MoonBase", { filmSetsOwned = { MoonBase = true } }) ~= nil, "an owner always gets in")
end)

local town = roblox.Instance.new("Folder")
MapModels.build(town)
local solids = {}
for _, d in town:GetDescendants() do
	if d:IsA("BasePart") and d.CanCollide then
		table.insert(solids, d)
	end
end

-- The solid part a character standing at `spot` (its root part) would be inside, if any.
local function blocked(spot)
	local body = spot.Position - Vector3.new(0, 0.5, 0) -- feet 3 below the root, head 2 above
	for _, part in solids do
		local p = part.CFrame:PointToObjectSpace(body)
		local half = part.Size / 2
		if math.abs(p.X) < half.X + 1.5 and math.abs(p.Y) < half.Y + 2.5 and math.abs(p.Z) < half.Z + 1.5 then
			return part
		end
	end
	return nil
end

local everyone = { filmSetsOwned = {} }
for _, set in FilmSets.List do
	everyone.filmSetsOwned[set.id] = true
end

test("owners land inside their set, clear of props and the crew, facing the shoot", function()
	for _, info in MapModels.FilmSets do
		local spot, inside = Visits.filmSetArrival(info.id, everyone)
		expect(spot ~= nil and inside, `{info.id}: owners go inside`)
		local p = spot.Position
		expect(Walkways.isWalkable({ info.area }, p.X, p.Z), `{info.id}: the spot {p} is outside the set's area`)
		local part = blocked(spot)
		expect(part == nil, `{info.id}: the spot {p} is inside {part and part:GetFullName()}`)
		local scenes = FilmScenes.Sets[info.id]
		local centre = info.frame * scenes.centre
		local toShoot = Vector3.new(centre.X - p.X, 0, centre.Z - p.Z).Unit
		expect(spot.LookVector:Dot(toShoot) > 0.99, `{info.id}: the spot faces the shoot`)
		for _, gear in scenes.gear do
			local at = info.frame * gear.at
			local gap = Vector3.new(at.X - p.X, 0, at.Z - p.Z).Magnitude
			expect(gap > 6, `{info.id}: the spot is {gap} studs from the {gear.kit}`)
		end
		-- Nobody in the scene walks through the spot, over a whole loop (or two takes on sets
		-- without a loop period).
		local period = (scenes :: any).period or (FilmScenes :: any).TakeLength * 2
		for i = 0, period / 0.1 do
			local frame = FilmScenes.frame(info.id, 500 * period + i * 0.1)
			for who, pose in frame.poses do
				if not pose.hidden then
					local torso = CrewRig.cframes(info.frame, pose, frame.stick).Torso.Position
					local gap = Vector3.new(torso.X - p.X, 0, torso.Z - p.Z).Magnitude
					expect(gap > 5, `{info.id}: {who} passes {gap} studs from the spot at {frame.time}`)
				end
			end
		end
	end
end)

test("buyers land just outside the gate on the town side, facing its buy prompt", function()
	for _, info in MapModels.FilmSets do
		-- Owning the other sets, so only this set's gate decides.
		local data = { filmSetsOwned = table.clone(everyone.filmSetsOwned) }
		data.filmSetsOwned[info.id] = nil
		local spot, inside = Visits.filmSetArrival(info.id, data)
		expect(spot ~= nil and not inside, `{info.id}: buyers go to the gate`)
		local p = spot.Position
		expect(not Walkways.isWalkable({ info.area }, p.X, p.Z), `{info.id}: the gate spot is inside the set`)
		expect(Walkways.isWalkable(MapModels.PlayAreas, p.X, p.Z), `{info.id}: the gate spot is off the map`)
		local local_ = info.gate:PointToObjectSpace(p)
		expect(local_.Z < -2, `{info.id}: the gate spot is not on the town side of the wall`)
		local prompt = info.gate * Vector3.new(0, 3, -1.5)
		expect((prompt - p).Magnitude < 12, `{info.id}: the buy prompt is out of reach`)
		expect(spot.LookVector:Dot((prompt - p).Unit) > 0.9, `{info.id}: the spot faces the prompt`)
		local part = blocked(spot)
		expect(part == nil, `{info.id}: the gate spot is inside {part and part:GetFullName()}`)
	end
end)
