local roblox = require("@lune/roblox")

local H = require("./harness")
local Config = H.require("Config")
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
