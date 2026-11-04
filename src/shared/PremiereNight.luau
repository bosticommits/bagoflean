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
