local H = require("./harness")
local L = H.require("LoadingLogic")
local test, expect, equal, near = H.test, H.expect, H.equal, H.near

local done = { loaded = true, ready = true, character = true, preload = 1 }
local none = { loaded = false, ready = false, character = false, preload = 0 }

test("target progress adds up to 1 and ignores a bad preload value", function()
	near(L.target(done), 1, 1e-9)
	near(L.target(none), 0, 1e-9)
	near(L.target({ loaded = false, ready = false, character = false, preload = 5 }), 0.3, 1e-9)
end)

test("displayed progress eases up, never goes back, and reaches exactly 1", function()
	local shown = 0
	local last = 0
	for _ = 1, 600 do
		shown = L.step(shown, 1, 1 / 60)
		expect(shown >= last, "went backwards")
		last = shown
	end
	equal(shown, 1)
	equal(L.step(0.8, 0.2, 0.1) >= 0.8, true, "a lower target must not pull the bar back")
end)

test("the bar never freezes for a second while loading", function()
	local shown = 0.1
	for _ = 1, 60 do -- 1 s at 60 fps with no real progress
		shown = L.step(shown, 0.1, 1 / 60)
	end
	expect(shown > 0.1 + 0.03, "frozen")
	for _ = 1, 3000 do
		shown = L.step(shown, 0.1, 1 / 60)
	end
	expect(shown <= L.CREEP_CEILING + 1e-9, "creep passed its ceiling")
end)

test("decide: min time, cap and skip", function()
	equal(L.decide(0.5, done, false), nil, "before the minimum")
	equal(L.decide(1.5, done, false), "ready")
	equal(L.decide(5, { loaded = true, ready = false, character = true, preload = 1 }, false), nil, "waits for the UI")
	equal(L.decide(7.99, none, false), nil)
	equal(L.decide(8, none, false), "cap")
	equal(L.decide(0.4, none, true), "skip", "skip works before anything is ready")
	equal(L.decide(0.1, done, true), "skip")
end)

test("fade lengths", function()
	equal(L.fadeSeconds(true), 0.4)
	equal(L.fadeSeconds(false), 0.3)
end)

test("tips: at most 12 words, no purchase talk, rotate every 3 s and wrap", function()
	expect(#L.TIPS >= 6 and #L.TIPS <= 8, "6 to 8 tips")
	for _, tip in L.TIPS do
		local words = #string.split(tip, " ")
		expect(words <= 12, `too long: {tip}`)
		expect(string.find(string.lower(tip), "robux") == nil and string.find(string.lower(tip), "buy") == nil, `purchase tip: {tip}`)
	end
	local n = #L.TIPS
	equal(L.tipIndex(0, 3, n), 3)
	equal(L.tipIndex(2.9, 3, n), 3)
	equal(L.tipIndex(3, 3, n), 4)
	equal(L.tipIndex(3 * n, 3, n), 3, "wraps to the start")
	equal(L.tipIndex(3 * (n - 2), 3, n), 1)
end)

test("countdown 3-2-1 loops and the hand turns once a second", function()
	equal(L.countNumber(0), 3)
	equal(L.countNumber(1.2), 2)
	equal(L.countNumber(2.99), 1)
	equal(L.countNumber(3), 3)
	near(L.handAngle(0.5), 180, 1e-9)
	near(L.handAngle(1.25), 90, 1e-9)
end)

test("film strip fill", function()
	local whole, part = L.filled(0, 10)
	equal(whole, 0)
	equal(part, 0)
	whole, part = L.filled(0.35, 10)
	equal(whole, 3)
	near(part, 0.5, 1e-9)
	whole, part = L.filled(1, 10)
	equal(whole, 10)
	equal(part, 0)
end)

test("preload: batches of 5, retry only TimedOut", function()
	local list = {}
	for i = 1, 12 do
		table.insert(list, `id{i}`)
	end
	local batches = L.batches(list, 5)
	equal(#batches, 3)
	equal(#batches[3], 2)
	local retry = L.retryList({ a = "Success", b = "TimedOut", c = "Failure", d = "TimedOut" })
	equal(#retry, 2)
	equal(retry[1], "b")
	equal(retry[2], "d")
end)
