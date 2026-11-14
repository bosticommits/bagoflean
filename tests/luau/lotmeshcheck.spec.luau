local H = require("./harness")
local LotMeshCheck = H.require("LotMeshCheck")
local Manifest = H.require("LotMeshManifest")
local test, expect, equal = H.test, H.expect, H.equal

test("missing: lists absent names in manifest order", function()
	local list = { { name = "A" }, { name = "B" }, { name = "C" } }
	local missing, total = LotMeshCheck.missing(list, { A = true, C = true })
	equal(total, 3)
	equal(#missing, 1)
	equal(missing[1], "B")
	local none = LotMeshCheck.missing(list, { A = true, B = true, C = true })
	equal(#none, 0)
end)

test("missing: real manifest against an empty place reports every template", function()
	local missing, total = LotMeshCheck.missing(Manifest.meshes, {})
	equal(total, 411)
	equal(#missing, 411)
end)

test("summary: all present, and truncation to the first 20", function()
	equal(LotMeshCheck.summary({}, 5), "Lot models: 5 of 5 present (0 missing)")
	local names = {}
	for i = 1, 25 do
		table.insert(names, `M{i}`)
	end
	local s = LotMeshCheck.summary(names, 30)
	expect(string.find(s, "5 of 30 present, 25 missing", 1, true) ~= nil, s)
	expect(string.find(s, "M20", 1, true) ~= nil and string.find(s, "M21", 1, true) == nil, s)
	expect(string.find(s, "(+5 more)", 1, true) ~= nil, s)
end)

test("every Actors v2 actor has its five rig-piece rows in the manifest (pending id 0 until uploaded)", function()
	local ActorShapes = H.require("Models/ActorShapes")
	local Actors = H.require("Actors")
	local byName = {}
	for _, entry in Manifest.meshes do
		byName[entry.name] = entry
	end
	local V2 = { "WerewolfPup", "CardboardAstronaut", "RodeoRookie", "WobblyWitch", "LagoonMermaid", "TimeTourist", "CaptainKapow", "InspectorWhoops", "PirateCaptain" }
	for _, id in V2 do
		expect(Actors.getActor(id) ~= nil, `{id} is not an actor`)
		for _, piece in ActorShapes.Pieces do
			local entry = byName[`{id}_{piece}`]
			expect(entry ~= nil, `missing manifest row {id}_{piece}`)
			expect(entry.assetId >= 0, `{id}_{piece} has a bad asset id`)
		end
	end
end)

test("pending rows are exactly the placeholders: real rows have an id and a real size", function()
	local pending = 0
	for _, entry in Manifest.meshes do
		if entry.assetId > 0 then
			expect(entry.pending ~= true, `{entry.name} has an id but is flagged pending`)
			local s = entry.size
			expect(not (s[1] == 1 and s[2] == 1 and s[3] == 1), `{entry.name} has an id but the placeholder size 1x1x1`)
		else
			expect(entry.pending == true, `{entry.name} has assetId 0 but is not flagged pending`)
			pending += 1
		end
	end
	equal(pending, 45, "the nine new actors' pieces")
end)

test("manifest names are unique", function()
	local seen = {}
	for _, entry in Manifest.meshes do
		expect(not seen[entry.name], `duplicate manifest name {entry.name}`)
		seen[entry.name] = true
	end
end)
