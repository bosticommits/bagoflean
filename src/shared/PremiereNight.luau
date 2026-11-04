--!strict
-- How each premiere result is staged on "premiere night" (src/client/PremiereReveal.luau), plus the
-- poster's text. Presentation only: the server decides the result and the payout; this file just
-- says how big the moment should feel. Kept in shared so the rules tests can check it.
local Movies = require(script.Parent.Movies)

local PremiereNight = {}

export type Style = {
	icon: string, -- 3D icon beside the result (IconModels id)
	flashes: number, -- camera flashes when the stamp lands
	tilt: number, -- the stamp's rotation in degrees
	shine: boolean, -- a light sweep across the poster
	beams: "down" | "swing" | "party", -- the spotlights: drop for a Flop, sweep faster for big results
	rainbow: boolean, -- the stamp's edge turns rainbow
}

PremiereNight.Styles = table.freeze({
	Flop = { icon = "popcorn", flashes = 0, tilt = -9, shine = false, beams = "down", rainbow = false },
	Hit = { icon = "ticket", flashes = 6, tilt = -8, shine = false, beams = "swing", rainbow = false },
	Blockbuster = { icon = "star", flashes = 12, tilt = -8, shine = true, beams = "party", rainbow = false },
	Cult = { icon = "crown", flashes = 14, tilt = -10, shine = true, beams = "party", rainbow = false },
	Masterpiece = { icon = "trophy", flashes = 22, tilt = -6, shine = true, beams = "party", rainbow = true },
} :: { [string]: Style })

-- Camera flashes while the reviews come in (before the result is known).
PremiereNight.DRUMROLL_FLASHES = 5
-- How long "The reviews are in..." lasts before the stamp lands. A tap skips it.
PremiereNight.DRUMROLL_SECONDS = 1.2

-- The red-carpet show at the Grand Premiere Theatre (src/client/PremiereShow.luau), per result.
-- Bigger results get a longer build-up, a hush before the reveal and a longer celebration.
export type Show = {
	build: number, -- seconds of red-carpet drumroll (the camera dollies up the carpet)
	hush: number, -- seconds of silence before the result (0 = none); it hints something big is coming
	celebrate: number, -- seconds after the marquee flips before the box office card
	stars: { number }, -- the critic's stars: fewest, most
	mood: "aww" | "cheer" | "wild" | "chant", -- how the crowd behind the ropes reacts
	critic: { string }, -- the critic's line (one is picked)
}

PremiereNight.Shows = table.freeze({
	Flop = {
		build = 1.6, hush = 0, celebrate = 0.7, stars = { 1, 2 }, mood = "aww",
		critic = {
			"I fell asleep. Twice. The popcorn was the best actor.",
			"Even the seats tried to walk out.",
			"Bold choice: a movie with no ending. Or middle.",
		},
	},
	Hit = {
		build = 1.6, hush = 0, celebrate = 0.7, stars = { 2, 3 }, mood = "cheer",
		critic = {
			"Solid fun! I only checked my phone once.",
			"A good popcorn movie. I finished my popcorn.",
			"I smiled four times. That's a lot for me.",
		},
	},
	Blockbuster = {
		build = 1.8, hush = 0.4, celebrate = 0.8, stars = { 4, 4 }, mood = "wild",
		critic = {
			"Explosions! Feelings! I cried into my nachos!",
			"I clapped so hard my gloves flew off.",
			"Bring tissues AND a helmet.",
		},
	},
	Cult = {
		build = 1.9, hush = 0.6, celebrate = 0.9, stars = { 4, 4 }, mood = "chant",
		critic = {
			"Nobody gets it... and that's why we LOVE it.",
			"Weird. Wonderful. I've seen it nine times.",
			"My cat watched it with me. Now she wears a cape.",
		},
	},
	Masterpiece = {
		build = 2.0, hush = 1.0, celebrate = 1.5, stars = { 5, 5 }, mood = "wild",
		critic = {
			"I have run out of stars. Please send more stars.",
			"I'm framing my ticket. Maybe my whole seat.",
			"Hollywood will be talking about this one forever.",
		},
	},
} :: { [string]: Show })

PremiereNight.CRITIC = "Rita Reelwright, The Daily Clapper"
PremiereNight.SKIP_AFTER = 1 -- seconds before a tap can skip (the first premiere's tutorial too)
PremiereNight.FAR = 350 -- studs: farther than this, the camera cuts to the theatre instead of flying
PremiereNight.RETURN_SECONDS = 0.7 -- the glide home after Continue

function PremiereNight.show(resultId: string): Show
	return PremiereNight.Shows[resultId] or PremiereNight.Shows.Hit
end

-- How long the camera takes to glide `distance` studs to the theatre; nil when it is too far to fly.
function PremiereNight.glideSeconds(distance: number): number?
	if distance > PremiereNight.FAR then
		return nil
	end
	return math.clamp(distance / 260, 0.6, 1.1)
end

-- When the marquee flips and when the box office card comes up, in seconds after the glide.
function PremiereNight.beats(resultId: string): (number, number)
	local show = PremiereNight.show(resultId)
	local reveal = show.build + show.hush
	return reveal, reveal + 0.6 + show.celebrate
end

-- The critic's stars and line; `roll` is 0..1 (random), so the same roll gives the same review.
function PremiereNight.review(resultId: string, roll: number): (number, string)
	local show = PremiereNight.show(resultId)
	local low, high = show.stars[1], show.stars[2]
	local stars = math.min(high, low + math.floor(roll * (high - low + 1)))
	local line = show.critic[math.min(#show.critic, 1 + math.floor(roll * #show.critic))]
	return stars, line
end

-- PREMIERE ALL: how a batch of results is staged. Every Masterpiece gets its own full show (in
-- order); with none, the biggest result (rarest, then richest) gets one. The rest flip as quick
-- cards, worst to best by payout (only the first QUICK_CARDS are shown, then "+N more").
PremiereNight.QUICK_CARDS = 4
PremiereNight.QUICK_SECONDS = 0.35 -- per card

local function rank(resultId: string): number
	for index, result in Movies.Results do
		if result.id == resultId then
			return index
		end
	end
	return 0
end

function PremiereNight.plan(results: { any }): ({ any }, { any })
	local full: { any } = {}
	for _, r in results do
		if r.result == "Masterpiece" then
			table.insert(full, r)
		end
	end
	if #full == 0 and #results > 0 then
		local best = results[1]
		for _, r in results do
			local a, b = rank(r.result), rank(best.result)
			if a > b or (a == b and (r.payout or 0) > (best.payout or 0)) then
				best = r
			end
		end
		table.insert(full, best)
	end
	local rest: { any } = {}
	for _, r in results do
		if table.find(full, r) == nil then
			table.insert(rest, r)
		end
	end
	-- Worst to best; table.sort is not stable, so ties keep their order by position.
	local position: { [any]: number } = {}
	for index, r in rest do
		position[r] = index
	end
	table.sort(rest, function(a, b)
		local pa, pb = a.payout or 0, b.payout or 0
		if pa ~= pb then
			return pa < pb
		end
		return position[a] < position[b]
	end)
	return full, rest
end

-- The night's totals: Cash, Fame and how many films earned the Award Night bonus.
function PremiereNight.total(results: { any }): (number, number, number)
	local payout, fame, awards = 0, 0, 0
	for _, r in results do
		payout += if type(r.payout) == "number" then r.payout else 0
		fame += if type(r.fame) == "number" then r.fame else 0
		awards += if r.awardNight then 1 else 0
	end
	return payout, fame, awards
end

function PremiereNight.style(resultId: string): Style
	return PremiereNight.Styles[resultId] or PremiereNight.Styles.Hit
end

-- "RESULT!" for the stamp. Unknown ids show as they are.
function PremiereNight.stampText(resultId: string): string
	local result = Movies.getResult(resultId)
	return string.upper(if result ~= nil then result.name else resultId) .. "!"
end

-- The poster's bottom line, e.g. "FEATURE  -  NOW SHOWING".
function PremiereNight.lengthLine(lengthId: string): string
	local length = Movies.getLength(lengthId)
	return string.upper(if length ~= nil then length.name else lengthId) .. "  -  NOW SHOWING"
end

-- The poster's billing line, e.g. "STARRING  Ad Model, Indie Sidekick".
function PremiereNight.billing(names: { string }): string
	if #names == 0 then
		return ""
	end
	return "STARRING  " .. table.concat(names, ", ")
end

-- The payout bonuses on one line, e.g. "Award Night x2  -  genre set x1.5". Empty without bonuses.
-- `directed` is the premiere Luck the film's takes added (Takes.luau).
function PremiereNight.bonusLine(genreBonus: number?, awardNight: number?, rebirthBonus: number?, directed: number?): string
	local parts = {}
	if directed ~= nil and directed > 0 then
		table.insert(parts, `takes +{string.format("%.2f", directed)} Luck`)
	end
	if awardNight ~= nil and awardNight > 1 then
		table.insert(parts, `Award Night x{awardNight}`)
	end
	if genreBonus ~= nil and genreBonus > 1 then
		table.insert(parts, `genre set x{genreBonus}`)
	end
	if rebirthBonus ~= nil and rebirthBonus > 1 then
		table.insert(parts, `rebirth x{rebirthBonus}`)
	end
	return table.concat(parts, "  -  ")
end

return PremiereNight
