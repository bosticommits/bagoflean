--!strict
-- Compares the mesh names the game expects (LotMeshManifest) with the names present in the place.
-- Pure, so it runs in Lune tests. Build.mesh falls back to plain parts silently when a mesh is
-- missing; this makes the gap visible at server start.

local LotMeshCheck = {}

-- `expected`: manifest entries ({ name: string }). `present`: set of mesh names found in the place.
-- Returns the missing names in manifest order, and the number expected.
function LotMeshCheck.missing(expected: { { name: string } }, present: { [string]: boolean }): ({ string }, number)
	local out: { string } = {}
	for _, entry in expected do
		if not present[entry.name] then
			table.insert(out, entry.name)
		end
	end
	return out, #expected
end

-- One log line: "Lot models: 366 of 366 present", or the count plus the first `limit` missing names.
function LotMeshCheck.summary(missing: { string }, total: number, limit: number?): string
	local shown = limit or 20
	local present = total - #missing
	if #missing == 0 then
		return `Lot models: {present} of {total} present (0 missing)`
	end
	local names = table.concat(missing, ", ", 1, math.min(#missing, shown))
	local more = if #missing > shown then ` (+{#missing - shown} more)` else ""
	return `Lot models: {present} of {total} present, {#missing} missing: {names}{more}`
end

return table.freeze(LotMeshCheck)
