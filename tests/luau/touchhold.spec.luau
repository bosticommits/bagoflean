local H = require("./harness")
local T = H.require("TouchHold")
local test, equal = H.test, H.equal

test("with the loading screen up, the stored original wins over the temporary false", function()
	equal(T.original(false, true, true), true)
	equal(T.original(false, true, false), false)
end)

test("without the loading screen, or without a stored value, the current value is the original", function()
	equal(T.original(true, false, true), true)
	equal(T.original(false, false, true), false)
	equal(T.original(false, true, nil), false)
end)
