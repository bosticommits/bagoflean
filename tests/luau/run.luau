-- Runs every *.spec.luau file in tests/luau. Run from the repo root: `lune run tests/luau/run`
local fs = require("@lune/fs")
local process = require("@lune/process")
local Harness = require("./harness")

local files = fs.readDir("tests/luau")
table.sort(files)

local total, failures = 0, 0
for _, file in files do
	local name = string.match(file, "^(.+)%.spec%.luau$")
	if name ~= nil then
		require(`./{name}.spec`)
		local count, failed = Harness.run(name)
		total += count
		failures += failed
	end
end

print(`\n{total - failures}/{total} passed`)
if total == 0 or failures > 0 then
	process.exit(1)
end
