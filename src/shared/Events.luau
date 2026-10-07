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

return Events
