--!strict
-- Award Night (plan section 5): every 30 minutes, 3 minutes of boosted casting Luck and doubled
-- premiere payouts. The schedule is a pure function of the clock, so every server and every client
-- agree on it without any syncing: the server passes os.time(), clients workspace:GetServerTimeNow().
local Events = {}

Events.AwardNightPeriod = 30 * 60
Events.AwardNightLength = 3 * 60

-- (active, seconds until it starts or ends)
function Events.awardNight(now: number): (boolean, number)
	local into = now % Events.AwardNightPeriod
	if into < Events.AwardNightLength then
		return true, Events.AwardNightLength - into
	end
	return false, Events.AwardNightPeriod - into
end

-- Luck Weekend: the live-config CastingLuckMultiplier (LiveConfigNumbers) above 1 for everyone,
-- optionally until LiveConfig LuckWeekendUntil (unix time, 0 = no end given).
function Events.luckWeekendLive(multiplier: number): boolean
	return multiplier > 1.0001
end

-- "x1.5": the real value, at most two decimals, no trailing zeros (2 -> "x2", 1.25 -> "x1.25").
function Events.luckWeekendMultiplier(multiplier: number): string
	local text = string.format("%.2f", multiplier)
	text = string.gsub(text, "0+$", "")
	text = string.gsub(text, "%.$", "")
	return `x{text}`
end

Events.LuckWeekendName = "Luck Weekend"

-- Time left for the badge: "Nd Hh" past 99 hours, else the caller's clock format (h:mm:ss).
function Events.luckWeekendTime(left: number, clock: (number) -> string): string
	if left > 99 * 3600 then
		local hours = math.floor(left / 3600)
		return `{hours // 24}d {hours % 24}h`
	end
	return clock(left)
end

-- Seconds left when an end time is set and still ahead, else nil (the badge then shows no countdown).
function Events.luckWeekendLeft(untilAt: number, now: number): number?
	if untilAt > now then
		return untilAt - now
	end
	return nil
end

-- Phones have room for one event badge: Award Night live, then an active Lucky Casting boost (a
-- purchase, so its buyer must see it), then a live Luck Weekend, then a live surprise event, else whichever countdown ends sooner. Lefts
-- are seconds (math.huge when there is none); luckyLeft > 0 means the boost is active.
function Events.phoneBadge(awardLive: boolean, surpriseLive: boolean, luckyLeft: number, awardLeft: number, surpriseLeft: number, weekendLive: boolean?): string
	if awardLive then
		return "award"
	elseif luckyLeft > 0 then
		return "lucky"
	elseif weekendLive == true then
		return "weekend"
	elseif surpriseLive then
		return "surprise"
	end
	return if surpriseLeft < awardLeft then "surprise" else "award"
end

return Events
