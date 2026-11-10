--!strict
-- How long the casting reveal builds up, and which rarity glows the card shows on the way. Pure
-- presentation (the server already decided the result); kept here so the tests can check the rule:
-- the build-up never shows a better tier than the real one (no teasing of a rarer result).
-- Ranks are positions in Actors.Tiers: 1 Newcomer, 2 Rising, 3 Pro, 4 Star, 5 Superstar, 6 Legend, 7 Icon.
local Reveal = {}

-- Build-up seconds by rank. Newcomer and Rising stay quick so normal casting is not slowed.
Reveal.Seconds = { 0.45, 0.45, 0.8, 1.7, 2.7, 3.8, 4.4 }
Reveal.FakeOutChance = { [3] = 1 / 4, [4] = 1 / 6, [5] = 1 / 6, [6] = 1 / 6, [7] = 1 / 6 }

export type Step = { at: number, rank: number } -- at: seconds into the build-up
export type Plan = { seconds: number, steps: { Step }, fakeOut: boolean }

-- `roll` is a 0..1 random number (the client's own; the fake-out is never the server's business).
function Reveal.plan(rank: number, roll: number): Plan
	local fakeOut = roll < (Reveal.FakeOutChance[rank] or 0)
	local seconds = Reveal.Seconds[rank] or 0.45
	local steps: { Step } = {}
	if fakeOut then
		-- Looks Common, then bursts into the real tier.
		seconds = math.max(seconds, 1.4)
		steps = { { at = 0, rank = 1 }, { at = seconds * 0.7, rank = rank } }
	else
		-- Climb one tier at a time up to the real tier's glow.
		for r = 1, rank do
			table.insert(steps, { at = seconds * 0.85 * (r - 1) / math.max(rank - 1, 1), rank = r })
		end
	end
	return { seconds = seconds, steps = steps, fakeOut = fakeOut }
end

-- Full-screen card or small headshot toast? Star (rank 4) and up, Award-Winning variants, server
-- guarantees (hot start, pity, first Superstar) and every cast before the tutorial is done get the
-- card; the rest get the toast. `ctx.tutorialDone` is false while unknown, so early casts stay full.
Reveal.CardRank = 4
function Reveal.useCard(rank: number, result: { variantId: string?, guarantee: string? }, ctx: { tutorialDone: boolean }): boolean
	return rank >= Reveal.CardRank or result.variantId == "Award" or result.guarantee ~= nil or not ctx.tutorialDone
end

-- After a Star+ card flips, the buttons ignore taps (and gamepad A) this long, so a button-mashing
-- player cannot skip the moment by accident: 0.6 s Star, 0.9 Superstar, 1.2 s Legend and Icon.
-- Cards below Star (tutorial, guaranteed pulls) are never held.
Reveal.GuardSeconds = { [4] = 0.6, [5] = 0.9, [6] = 1.2, [7] = 1.2 }
function Reveal.guardSeconds(rank: number): number
	return Reveal.GuardSeconds[rank] or 0
end

return Reveal
