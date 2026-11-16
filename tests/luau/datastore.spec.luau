local H = require("./harness")
local MockDS = require("./mockds")
local SaveVersion = H.require("SaveVersion")
local test, expect, equal = H.test, H.expect, H.equal

-- The save code reads and writes through the DataStore API (ProfileStore uses UpdateAsync); these
-- cover that API offline: load a missing profile, save a default one, migrate an old one, reload.
local steps = {
	{ version = 2, run = function(d: any) d.cash = d.cash * 10 end },
}

local function migrate(d: any)
	SaveVersion.apply(d, 2, steps)
end

test("missing key loads as nil, default profile saves with UpdateAsync and reloads", function()
	local store = MockDS():GetDataStore("PlayerData_test")
	equal(store:GetAsync("player_1"), nil)
	store:UpdateAsync("player_1", function(old: any)
		expect(old == nil, "no old value")
		return { version = 2, cash = 0, roster = {} }
	end)
	local data = store:GetAsync("player_1")
	equal(data.version, 2)
	equal(data.cash, 0)
	expect(type(data.roster) == "table")
end)

test("an old save migrates on load and the migrated save persists once", function()
	local store = MockDS():GetDataStore("PlayerData_migrate")
	store:SetAsync("player_2", { version = 1, cash = 5 })
	local data = store:GetAsync("player_2")
	migrate(data)
	store:SetAsync("player_2", data)
	local again = store:GetAsync("player_2")
	equal(again.version, 2)
	equal(again.cash, 50)
	migrate(again) -- reloading must not run the step again
	equal(again.cash, 50)
end)

test("UpdateAsync returning nil keeps the stored value", function()
	local store = MockDS():GetDataStore("PlayerData_cancel")
	store:SetAsync("k", { cash = 7 })
	store:UpdateAsync("k", function()
		return nil
	end)
	equal(store:GetAsync("k").cash, 7)
end)
