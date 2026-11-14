--!strict
-- The save-data version rule, kept free of Roblox services so Lune can test it (tests/luau/
-- saveversion.spec.luau). DataService calls SaveVersion.apply when a profile loads.
--
-- A save's version is "the newest build that wrote it". An older build (a rollback) that loads a
-- newer save must leave the version alone: lowering it would make the newer build's upgrade steps
-- run again on data they already converted. So the stored version only ever goes up.

export type Step = { version: number, run: (data: any) -> () }

local SaveVersion = {}

-- A usable version is a finite whole number of at least 1. Anything else is malformed (nil).
function SaveVersion.read(raw: any): number?
	if type(raw) == "number" and raw == raw and raw >= 1 and raw < math.huge and raw == math.floor(raw) then
		return raw
	end
	return nil
end

-- Runs, in order, each step newer than the save's version (and not newer than `current`), then stores
-- max(saved, current). `steps` must be sorted by ascending version. A missing or malformed version
-- counts as `current` (no steps run), as before this module existed. If a step errors, the error
-- propagates and the version is left as it was.
function SaveVersion.apply(data: any, current: number, steps: { Step })
	local saved = SaveVersion.read(data.version) or current
	for _, step in steps do
		if saved < step.version and step.version <= current then
			step.run(data)
		end
	end
	data.version = math.max(saved, current)
end

return SaveVersion
