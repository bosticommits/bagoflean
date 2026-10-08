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
	Flop = { icon = "popcorn", flashes = 0, tilt = -16, shine = false, beams = "down", rainbow = false },
	Hit = { icon = "ticket", flashes = 6, tilt = -8, shine = false, beams = "swing", rainbow = false },
	Blockbuster = { icon = "star", flashes = 12, tilt = -8, shine = true, beams = "party", rainbow = false },
	Cult = { icon = "crown", flashes = 14, tilt = -10, shine = true, beams = "party", rainbow = false },
	Masterpiece = { icon = "trophy", flashes = 22, tilt = -6, shine = true, beams = "party", rainbow = true },
} :: { [string]: Style })

-- Camera flashes while the reviews come in (before the result is known).
PremiereNight.DRUMROLL_FLASHES = 5
-- How long "The reviews are in..." lasts before the stamp lands. A tap skips it.
PremiereNight.DRUMROLL_SECONDS = 1.2

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
function PremiereNight.bonusLine(genreBonus: number?, awardNight: number?, rebirthBonus: number?): string
	local parts = {}
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
