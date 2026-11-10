local H = require("./harness")
local fs = require("@lune/fs")
local test, expect = H.test, H.expect

-- Analytics is a server module (needs DataService), so read its funnel table as text.
test("onboarding funnel lists FirstCast before ClaimedLot, like the tutorial", function()
	local source = fs.readFile("src/server/Analytics.luau")
	local cast = tonumber(string.match(source, "FirstCast = (%d+)"))
	local claim = tonumber(string.match(source, "ClaimedLot = (%d+)"))
	expect(cast ~= nil and claim ~= nil, "funnel steps not found")
	expect((cast :: number) < (claim :: number), "FirstCast must come first")
end)
