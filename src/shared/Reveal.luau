--!strict
-- How long the casting reveal builds up, and which rarity glows the card shows on the way. Pure
-- presentation (the server already decided the result); kept here so the tests can check the rule:
-- the build-up never shows a better tier than the real one, except the server's own near-miss tease.
-- Ranks are positions in Actors.Tiers: 1 Newcomer, 2 Rising, 3 Pro, 4 Star, 5 Superstar, 6 Legend, 7 Icon.
local Reveal = {}

-- Build-up seconds by rank. Newcomer and Rising stay quick so normal casting is not slowed.
Reveal.Seconds = { 0.45, 0.45, 0.8, 1.7, 2.7, 3.8, 4.4 }
Reveal.NearMissRank = 5 -- the near-miss tease builds up like a Superstar
Reveal.FakeOutChance = { [3] = 1 / 4, [4] = 1 / 6, [5] = 1 / 6, [6] = 1 / 6, [7] = 1 / 6 }

export type Step = { at: number, rank: number } -- at: seconds into the build-up
export type Plan = { seconds: number, steps: { Step }, fakeOut: boolean, nearMiss: boolean }

-- `roll` is a 0..1 random number (the client's own; the fake-out is never the server's business).
function Reveal.plan(rank: number, tease: string?, roll: number): Plan
	local nearMiss = tease == "nearMiss" and rank < Reveal.NearMissRank
	local fakeOut = not nearMiss and roll < (Reveal.FakeOutChance[rank] or 0)
	local seconds = if nearMiss then Reveal.Seconds[Reveal.NearMissRank] else Reveal.Seconds[rank] or 0.45
	local steps: { Step } = {}
	if fakeOut then
		-- Looks Common, then bursts into the real tier.
		seconds = math.max(seconds, 1.4)
		steps = { { at = 0, rank = 1 }, { at = seconds * 0.7, rank = rank } }
	else
		-- Climb one tier at a time up to the top glow; the near miss climbs to Superstar and then
		-- drops to the real tier on the flip.
		local top = if nearMiss then Reveal.NearMissRank else rank
		for r = 1, top do
			table.insert(steps, { at = seconds * 0.85 * (r - 1) / math.max(top - 1, 1), rank = r })
		end
		if nearMiss then
			table.insert(steps, { at = seconds, rank = rank })
		end
	end
	return { seconds = seconds, steps = steps, fakeOut = fakeOut, nearMiss = nearMiss }
end

return Reveal
