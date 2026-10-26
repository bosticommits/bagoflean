local H = require("./harness")
local Reveal = H.require("Reveal")
local test, expect, equal = H.test, H.expect, H.equal

test("the build-up never shows better than the real tier and ends on it", function()
	for rank = 1, 7 do
		for _, tease in { false, "nearMiss" } do
			for i = 0, 20 do
				local plan = Reveal.plan(rank, if tease then tease else nil, i / 20)
				local last = plan.steps[#plan.steps]
				equal(last.rank, rank, `rank {rank} ends on the truth`)
				expect(plan.steps[1].rank <= rank, `rank {rank} starts at or below the truth`)
				if not plan.nearMiss then
					for _, step in plan.steps do
						expect(step.rank <= rank, `rank {rank} never shows tier {step.rank}`)
					end
				end
				expect(plan.seconds <= 5, "build-up stays under 5 s")
			end
		end
	end
end)

test("fake-outs only on Pro and up, near misses only below Superstar", function()
	expect(not Reveal.plan(2, nil, 0).fakeOut, "no fake-out on Rising")
	expect(Reveal.plan(3, nil, 0).fakeOut, "Pro can fake out")
	expect(not Reveal.plan(3, nil, 0.99).fakeOut, "most Pro pulls do not")
	expect(Reveal.plan(4, "nearMiss", 0).nearMiss, "Star near miss")
	expect(not Reveal.plan(5, "nearMiss", 0).nearMiss, "a real Superstar is no near miss")
	expect(Reveal.plan(1, nil, 0).seconds < 0.6, "Newcomer stays quick")
end)
