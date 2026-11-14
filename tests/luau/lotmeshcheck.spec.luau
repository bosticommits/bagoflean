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
	equal(total, 366)
	equal(#missing, 366)
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
