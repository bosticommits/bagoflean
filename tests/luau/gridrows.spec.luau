local H = require("./harness")
local GridRows = H.require("GridRows")
local test, expect = H.test, H.expect

local function same(a: { number }, b: { number }): boolean
	if #a ~= #b then
		return false
	end
	for i, v in a do
		if v ~= b[i] then
			return false
		end
	end
	return true
end

test("no cards, no rows", function()
	expect(same(GridRows.split(0, 2), {}), "empty")
end)

test("an even count fills whole rows", function()
	expect(same(GridRows.split(4, 2), { 2, 2 }), "4 in 2 columns")
end)

test("an odd count leaves a short last row (which the Shop centres)", function()
	expect(same(GridRows.split(1, 2), { 1 }), "1")
	expect(same(GridRows.split(3, 2), { 2, 1 }), "3")
	expect(same(GridRows.split(5, 2), { 2, 2, 1 }), "5")
	expect(same(GridRows.split(7, 3), { 3, 3, 1 }), "7 in 3 columns")
end)

test("every card lands in exactly one row, for any count", function()
	for count = 0, 25 do
		local total = 0
		for _, n in GridRows.split(count, 2) do
			expect(n >= 1 and n <= 2, "row size")
			total += n
		end
		expect(total == count, `count {count}`)
	end
end)
