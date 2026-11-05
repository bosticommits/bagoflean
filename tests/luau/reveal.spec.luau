local H = require("./harness")
local Reveal = H.require("Reveal")
local test, expect, equal = H.test, H.expect, H.equal

test("the build-up never shows better than the real tier and ends on it", function()
	for rank = 1, 7 do
		for i = 0, 20 do
			local plan = Reveal.plan(rank, i / 20)
			local last = plan.steps[#plan.steps]
			equal(last.rank, rank, `rank {rank} ends on the truth`)
			for _, step in plan.steps do
				expect(step.rank <= rank, `rank {rank} never shows tier {step.rank}`)
			end
			expect(plan.seconds <= 5, "build-up stays under 5 s")
		end
	end
end)

test("fake-outs only on Pro and up; there is no near-miss tease", function()
	expect(not Reveal.plan(2, 0).fakeOut, "no fake-out on Rising")
	expect(Reveal.plan(3, 0).fakeOut, "Pro can fake out")
	expect(not Reveal.plan(3, 0.99).fakeOut, "most Pro pulls do not")
	expect(Reveal.plan(1, 0).seconds < 0.6, "Newcomer stays quick")
	expect((Reveal :: any).NearMissRank == nil, "no near-miss rank")
	expect((Reveal.plan(4, 0.99) :: any).nearMiss == nil, "no near-miss plan field")
end)
