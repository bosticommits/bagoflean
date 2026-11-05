local H = require("./harness")
local CountUp = H.require("CountUp")
local test, expect, equal = H.test, H.expect, H.equal

test("comma groups thousands", function()
	equal(CountUp.comma(0), "0")
	equal(CountUp.comma(999), "999")
	equal(CountUp.comma(1000), "1,000")
	equal(CountUp.comma(1234567), "1,234,567")
	equal(CountUp.comma(-5000), "-5,000")
end)

test("count-up eases and lands exactly", function()
	equal(CountUp.at(100, 600, 0), 100)
	equal(CountUp.at(100, 600, 1), 600)
	equal(CountUp.at(100, 600, 2), 600)
	local mid = CountUp.at(100, 600, 0.5)
	expect(mid > 350 and mid < 600, `eased midpoint {mid} should be past halfway`)
	local last = 100
	for i = 1, 20 do
		local v = CountUp.at(100, 600, i / 20)
		expect(v >= last, "never goes backwards")
		last = v
	end
	equal(CountUp.at(600, 100, 1), 100)
end)

test("splitCash finds the first Cash amount", function()
	local before, amount, after = CountUp.splitCash("You got $12,500 and 3 Fame!")
	equal(before, "You got $")
	equal(amount, 12500)
	equal(after, " and 3 Fame!")
	equal(select(2, CountUp.splitCash("+$7")), 7)
	equal(CountUp.splitCash("Fame +30"), nil)
	equal(CountUp.splitCash("costs $"), nil)
end)

test("noticeable rises only", function()
	equal(CountUp.noticeable(1000, 1500), true)
	equal(CountUp.noticeable(1000, 1020), false)
	equal(CountUp.noticeable(0, 5), false)
	equal(CountUp.noticeable(0, 50), true)
	equal(CountUp.noticeable(500, 100), false)
end)
