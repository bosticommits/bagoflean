local H = require("./harness")
local SaveVersion = H.require("SaveVersion")
local test, expect, equal = H.test, H.expect, H.equal

local CURRENT = 12

-- Steps that log which save versions they ran for, so a spec can see exactly what executed.
local function steps(log: { number })
	local list = {}
	for _, n in { 10, 11, 12 } do
		table.insert(list, {
			version = n,
			run = function(data: any)
				table.insert(log, n)
				data.ran = (data.ran or 0) + 1
			end,
		})
	end
	return list
end

test("a save at the current version keeps it and runs no steps", function()
	local log = {}
	local data = { version = 12 }
	SaveVersion.apply(data, CURRENT, steps(log))
	equal(data.version, 12)
	equal(#log, 0, "steps run")
end)

test("an older save runs only the steps above its version, in order, then moves up", function()
	local log = {}
	local data = { version = 10 }
	SaveVersion.apply(data, CURRENT, steps(log))
	equal(table.concat(log, ","), "11,12")
	equal(data.version, 12)
end)

test("a much older save runs every step once", function()
	local log = {}
	local data = { version = 1 }
	SaveVersion.apply(data, CURRENT, steps(log))
	equal(table.concat(log, ","), "10,11,12")
	equal(data.version, 12)
end)

test("a newer save (v13 on v12 code) stays v13 and runs no steps", function()
	local log = {}
	local data = { version = 13 }
	SaveVersion.apply(data, CURRENT, steps(log))
	equal(data.version, 13, "version must not be lowered")
	equal(#log, 0, "steps run")
end)

test("rollback then re-upgrade runs each step once, not twice", function()
	local log = {}
	local data = { version = 12 }
	-- v13 build upgrades the save (its step runs once)...
	SaveVersion.apply(data, 13, {
		{ version = 13, run = function()
			table.insert(log, 13)
		end },
	})
	equal(data.version, 13)
	-- ...the rollback to v12 loads and saves it...
	SaveVersion.apply(data, 12, steps(log))
	equal(data.version, 13, "v12 code must not lower it")
	-- ...and v13 loads it again: nothing re-runs.
	SaveVersion.apply(data, 13, {
		{ version = 13, run = function()
			table.insert(log, 13)
		end },
	})
	equal(table.concat(log, ","), "13", "the v13 step ran more than once")
	equal(data.version, 13)
end)

test("a missing or malformed version is treated as current: no steps, becomes current", function()
	for _, bad in { "x", true, {}, -3, 0, 11.5, 0 / 0, math.huge, -math.huge } do
		local log = {}
		local data = { version = bad }
		SaveVersion.apply(data, CURRENT, steps(log))
		equal(data.version, CURRENT, `version {tostring(bad)}`)
		equal(#log, 0, `steps for {tostring(bad)}`)
	end
	local data: any = {}
	SaveVersion.apply(data, CURRENT, {})
	equal(data.version, CURRENT, "nil version")
end)

test("read accepts only finite whole numbers of at least 1", function()
	equal(SaveVersion.read(12), 12)
	equal(SaveVersion.read(1), 1)
	equal(SaveVersion.read(99), 99)
	equal(SaveVersion.read(0), nil)
	equal(SaveVersion.read(1.5), nil)
	equal(SaveVersion.read("12"), nil)
	equal(SaveVersion.read(nil), nil)
	expect(SaveVersion.read(0 / 0) == nil, "nan")
end)

test("a throwing step stops the upgrade and leaves the version untouched", function()
	local data = { version = 10 }
	local ok = pcall(SaveVersion.apply, data, CURRENT, {
		{ version = 11, run = function()
			error("boom")
		end },
	})
	expect(not ok, "error should propagate")
	equal(data.version, 10, "version must not advance past a failed step")
end)
