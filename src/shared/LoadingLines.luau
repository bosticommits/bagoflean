--!strict
-- The strings the loading screen shows a returning player, and which live line wins. Pure rules
-- (tests/luau/loadinglines.spec.luau); LoadingBridge reads the live values and calls these.
local Config = require(script.Parent.Config)
local Events = require(script.Parent.Events)

local LoadingLines = {}

export type Live = {
	awardNight: boolean, -- Events.awardNight(now) is active
	luckMultiplier: number, -- LiveConfig_CastingLuckMultiplier (1 = no Luck Weekend)
	surpriseName: string?, -- the surprise special event that is live right now
	festivalGenre: string?, -- this week's Film Festival genre
}

function LoadingLines.welcomeBack(displayName: string): string
	return `Welcome back, {displayName}!`
end

-- One line about what is on right now, or nil when nothing is. Priority: the biggest boost first
-- (Award Night, Luck Weekend), then the surprise event, then the festival.
function LoadingLines.liveLine(live: Live): string?
	if live.awardNight then
		return `Award Night is live! x{Config.AwardNightLuckMultiplier} Luck`
	end
	if Events.luckWeekendLive(live.luckMultiplier) then
		return `{Events.LuckWeekendName} {Events.luckWeekendMultiplier(live.luckMultiplier)}`
	end
	if live.surpriseName ~= nil and live.surpriseName ~= "" then
		return `{live.surpriseName} is on!`
	end
	if live.festivalGenre ~= nil and live.festivalGenre ~= "" then
		return `Film Festival: {live.festivalGenre} week`
	end
	return nil
end

return LoadingLines
