-- Loads the vendored MockDataStoreService (tests/vendor) in Lune with a few Roblox shims.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local task = require("@lune/task")
local H = require("./harness")

-- The mock's endless budget loop does `while task.wait(...)`; once finish() is called its wait returns nil and the loop ends, so Lune exits by itself.
local done = false
local mockTask = setmetatable({
	wait = function(t: number?)
		if done then
			return nil
		end
		return task.wait(t)
	end,
}, { __index = task })

local ROOT = "tests/vendor/MockDataStoreService/lib"
local cache: { [string]: any } = {}

local function noop() end
local services: { [string]: any } = {
	HttpService = {
		JSONEncode = function(_, v: any)
			return serde.encode("json", v)
		end,
		JSONDecode = function(_, s: string)
			return serde.decode("json", s)
		end,
	},
	RunService = {
		IsServer = function()
			return true
		end,
		IsStudio = function()
			return false
		end,
	},
	Players = {
		GetPlayers = function()
			return {}
		end,
	},
}
local game = {
	GameId = 1,
	BindToClose = noop,
	GetService = function(_, name: string)
		return services[name]
	end,
}

local node: (path: string) -> any

local function resolve(path: string): string
	if fs.isFile(`{path}.lua`) then
		return `{path}.lua`
	end
	return `{path}/init.lua`
end

local function load(path: string): any
	if cache[path] == nil then
		local env: { [string]: any } = {}
		for k, v in roblox :: any do
			env[k] = v
		end
		env.game = game
		env.task = mockTask
		-- Lune's BindableEvent has no Fire/Event; the mock only uses it for OnUpdate.
		env.Instance = { new = function() return { Fire = noop, Event = { Connect = noop }, Destroy = noop } end }
		-- Lune's Enum has no DataStoreRequestType; the mock only uses its items as table keys.
		env.Enum = setmetatable({ DataStoreRequestType = setmetatable({}, { __index = function(_, k) if k == "GetEnumItems" then return function() return {} end end return `DSR_{k}` end }) }, { __index = (roblox :: any).Enum })
		env.tick = os.clock
		env.Random = H.Random
		env.script = node(path)
		env.require = function(ref: any)
			return load(ref.__path)
		end
		cache[path] = luau.load(fs.readFile(resolve(path)), { debugName = path, environment = env })()
	end
	return cache[path]
end

function node(path: string): any
	return setmetatable({ Name = string.match(path, "[^/]+$"), __path = path }, {
		__index = function(_, key: string)
			if key == "Parent" then
				return node(string.match(path, "^(.*)/[^/]+$") :: string)
			end
			return node(`{path}/{key}`)
		end,
	})
end

local function build()
	-- Real DataStores throttle same-key writes (6 s); drop that so tests stay fast. Budgets stay on.
	local constants = load(`{ROOT}/MockDataStoreConstants`)
	constants.WRITE_COOLDOWN = 0
	constants.GET_COOLDOWN = 0
	constants.YIELD_TIME_MIN = 0
	constants.YIELD_TIME_MAX = 0
	return load(ROOT)
end

local M = {}

-- Call once after the last spec so the budget thread stops.
function M.finish()
	done = true
end

return setmetatable(M, {
	__call = function(_)
		return build()
	end,
})
