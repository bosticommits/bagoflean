--!strict
-- Loads the game's shared modules outside Roblox (in Lune) and gives specs a tiny test API.
-- Only src/shared is tested here: those modules are pure rules, so they need just a few Roblox
-- globals (Color3, Random, script.Parent requires), which are stubbed below.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local SHARED_DIR = "src/shared"

local Harness = {}

-- Random --------------------------------------------------------------------------------------
-- Roblox's Random is not in Lune. This stand-in has the same methods and is deterministic per
-- seed, but its sequence differs from Roblox's, so specs must never depend on exact draws.
local RandomShim = {}
RandomShim.__index = RandomShim

function RandomShim.new(seed: number?)
	local state = math.floor(seed or os.clock() * 1e6) % 4294967296
	if state == 0 then
		state = 0x9E3779B9
	end
	return setmetatable({ state = state }, RandomShim)
end

-- xorshift32, returns a float in [0, 1)
function RandomShim._next(self: any): number
	local x = self.state
	x = bit32.bxor(x, bit32.lshift(x, 13))
	x = bit32.bxor(x, bit32.rshift(x, 17))
	x = bit32.bxor(x, bit32.lshift(x, 5))
	self.state = x
	return x / 4294967296
end

function RandomShim.NextNumber(self: any, min: number?, max: number?): number
	local lo, hi = min or 0, max or 1
	return lo + (hi - lo) * self:_next()
end

function RandomShim.NextInteger(self: any, min: number, max: number): number
	return min + math.floor(self:_next() * (max - min + 1))
end

Harness.Random = RandomShim

-- Module loader -------------------------------------------------------------------------------
local cache: { [string]: any } = {}
local loadShared: (name: string) -> any

local folder = setmetatable({}, {
	__index = function(_, name: string)
		return { __sharedModule = name }
	end,
})

local function requireShim(ref: any): any
	if type(ref) == "table" and ref.__sharedModule ~= nil then
		return loadShared(ref.__sharedModule)
	end
	error(`tests only support requiring sibling shared modules, got {tostring(ref)}`)
end

function loadShared(name: string): any
	local cached = cache[name]
	if cached ~= nil then
		return cached
	end
	local path = `{SHARED_DIR}/{name}.luau`
	local source = fs.readFile(path)
	local chunk = luau.load(source, {
		debugName = path,
		environment = {
			script = { Name = name, Parent = folder },
			require = requireShim,
			Color3 = roblox.Color3,
			Random = RandomShim,
		},
	})
	local result = chunk()
	cache[name] = result
	return result
end

Harness.require = loadShared

-- Test API ------------------------------------------------------------------------------------
type Case = { name: string, fn: () -> () }
local cases: { Case } = {}

function Harness.test(name: string, fn: () -> ())
	table.insert(cases, { name = name, fn = fn })
end

local function fail(message: string)
	error(message, 3)
end

function Harness.expect(condition: any, message: string?)
	if not condition then
		fail(message or "expectation failed")
	end
end

function Harness.equal(actual: any, expected: any, message: string?)
	if actual ~= expected then
		fail(`{message or "values differ"}: expected {tostring(expected)}, got {tostring(actual)}`)
	end
end

function Harness.near(actual: number, expected: number, tolerance: number, message: string?)
	if math.abs(actual - expected) > tolerance then
		fail(`{message or "numbers differ"}: expected {expected} ± {tolerance}, got {actual}`)
	end
end

-- Runs every registered case under `prefix`, prints results, and returns the failure count.
function Harness.run(prefix: string): (number, number)
	local failures = 0
	for _, case in cases do
		local ok, err = pcall(case.fn)
		if ok then
			print(`  ok   {prefix} > {case.name}`)
		else
			failures += 1
			print(`  FAIL {prefix} > {case.name}\n       {err}`)
		end
	end
	local count = #cases
	table.clear(cases)
	return count, failures
end

return Harness
