--!strict
-- Studio visits and applause: the rules shared by the server (src/server/VisitService.luau) and the
-- client (src/client/VisitUi.luau). Kept in shared so the rules tests can check them.
--
-- Applause is cosmetic on purpose. It adds one to a studio's count and pays nobody, so there is
-- nothing to farm: each visitor's applause counts once per studio per UTC day, and only after they
-- have stood on that studio for a few seconds (a real tour). After that the button still claps for
-- the show, without counting. A tour is counted once per studio per day too (QuestTracker kind
-- "visit"), ready for a quest that asks for tours.
local LotModels = require(script.Parent.Models.LotModels)

local Visits = {}

Visits.DwellSeconds = 5 -- standing on someone's studio this long counts as a tour
Visits.ApplaudCooldown = 1.5 -- seconds between claps, counted or not
Visits.TeleportCooldown = 3 -- seconds between Visit-menu jumps
Visits.LotMargin = 1 -- studs past the lot's edge that still count as "on the lot"
Visits.WatchMargin = 10 -- premieres show to people this close to the lot (in front of the gate)

-- What a player did today, saved in their profile (`visits`). Keys are owner UserIds as strings.
export type Record = {
	day: number, -- UTC day (Rewards.today)
	toured: { [string]: boolean }, -- studios toured today (each counts once for quests)
	applauded: { [string]: boolean }, -- studios whose applause counted today
}

local function cleanSet(value: any): { [string]: boolean }
	local set: { [string]: boolean } = {}
	if type(value) == "table" then
		for key, flag in value do
			if type(key) == "string" and flag == true then
				set[key] = true
			end
		end
	end
	return set
end

-- `record` made valid for `day`: kept as it is (cleaned) if it is today's, otherwise a fresh day.
function Visits.fresh(record: any, day: number): Record
	if type(record) == "table" and record.day == day then
		return { day = day, toured = cleanSet(record.toured), applauded = cleanSet(record.applauded) }
	end
	return { day = day, toured = {}, applauded = {} }
end

function Visits.key(userId: number): string
	return tostring(userId)
end

-- Which lot (its index in `bases`) a world position stands on, or nil. `bases` are the lots'
-- CFrames (MapModels.lotBase). `margin` widens each lot by that many studs on every side.
function Visits.lotAt(position: Vector3, bases: { CFrame }, margin: number?): number?
	local reach = LotModels.Layout.size / 2 + (margin or Visits.LotMargin)
	for index, base in bases do
		local p = base:PointToObjectSpace(position)
		if math.abs(p.X) <= reach and math.abs(p.Z) <= reach and p.Y > -10 and p.Y < 60 then
			return index
		end
	end
	return nil
end

-- Where a visitor lands: just inside the studio gate on the red carpet, facing the cinema (lot
-- space +Z; the gate faces -Z, toward the boulevard). Raised so the character stands on the floor.
function Visits.arrival(base: CFrame): CFrame
	return base * CFrame.new(0, 4.5, LotModels.Layout.gateZ + 3.5) * CFrame.Angles(0, math.pi, 0)
end

-- "1,234"
function Visits.comma(n: number): string
	local text = tostring(math.floor(n))
	local formatted = string.reverse((string.gsub(string.reverse(text), "(%d%d%d)", "%1,")))
	return (string.gsub(formatted, "^(-?),", "%1"))
end

-- A studio's applause count as shown on its gate and in the Visit menu.
function Visits.applauseText(count: number): string
	return "👏 " .. Visits.comma(math.max(0, count))
end

export type Status = { kind: string, text: string } -- kind: "ready", "filming" or "idle"

local function clock(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	if seconds >= 3600 then
		return `{seconds // 3600}h {seconds % 3600 // 60}m`
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- What a studio is up to, from its soonest film's end time (nil when nothing is filming).
function Visits.status(nextPremiere: number?, now: number): Status
	if nextPremiere == nil then
		return { kind = "idle", text = "Between films" }
	end
	if nextPremiere <= now then
		return { kind = "ready", text = "Premiere ready!" }
	end
	return { kind = "filming", text = "Filming  " .. clock(nextPremiere - now) }
end

-- The soonest end time among a studio's films (each has `endTime`), or nil when none is filming.
function Visits.nextPremiere(films: { any }): number?
	local soonest: number? = nil
	for _, film in films do
		local ends = if type(film) == "table" then film.endTime else nil
		if type(ends) == "number" and (soonest == nil or ends < soonest) then
			soonest = ends
		end
	end
	return soonest
end

return Visits
