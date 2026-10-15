--!strict
-- "Direct the scene": the timing game while a movie films. A few times per film a TAKE! card pops
-- up; a marker sweeps across a bar and the player taps CUT! inside the green zone. Each good take
-- adds a little premiere Luck to that one film. Shared so the client draws exactly what the server
-- judges; the server owns the verdict (MovieService) and the bonus is capped here.
--
-- Economy (ECONOMY.md): takes only happen while the player is online and the film is still
-- shooting, so offline income is unchanged. Three perfect takes add +0.24 premiere Luck, which at
-- Luck 1 lifts the average premiere from x1.57 to about x1.76. Casting Luck is never touched.

local Takes = {}

export type Verdict = "Perfect" | "Good" | "Miss"

Takes.PerFilm = 3
-- Seconds the marker takes to cross the bar once (then it bounces back). Later takes are faster.
Takes.SweepSeconds = { 1.25, 1.05, 0.9 }
-- Zones, as a fraction of the bar either side of the target: gold in the middle, green around it.
Takes.PerfectHalfWidth = 0.045
Takes.GoodHalfWidth = 0.12
-- Premiere Luck each verdict adds to its film.
Takes.Luck = table.freeze({ Perfect = 0.08, Good = 0.04, Miss = 0 }) :: { [string]: number }
Takes.MaxLuck = 0.24 -- PerFilm x the Perfect bonus; tests check this cap
-- The client says how long after the sweep began it tapped. The server trusts that only when it is
-- within this many seconds of its own measurement (network jitter); otherwise it uses its own.
Takes.ClockTolerance = 0.3
-- A sweep left alone this long is dropped; the card simply starts a new one.
Takes.MaxOpenSeconds = 60

local function sweep(index: number): number
	return Takes.SweepSeconds[math.clamp(index, 1, #Takes.SweepSeconds)]
end

-- Where the marker is (0 = left edge, 1 = right edge) `elapsed` seconds into take `index`.
function Takes.marker(elapsed: number, index: number): number
	local t = (math.max(elapsed, 0) / sweep(index)) % 2
	return if t <= 1 then t else 2 - t
end

-- Centre of the green zone for take `index` of a film that started at `startTime` on `stage`.
-- The same on client and server, and different from take to take so the player has to watch.
function Takes.target(startTime: number, stage: number, index: number): number
	local mix = (math.floor(startTime) * 37 + stage * 131 + index * 977) % 1000
	return 0.22 + 0.56 * (mix / 999)
end

function Takes.judge(elapsed: number, target: number, index: number): Verdict
	local distance = math.abs(Takes.marker(elapsed, index) - target)
	if distance <= Takes.PerfectHalfWidth then
		return "Perfect"
	elseif distance <= Takes.GoodHalfWidth then
		return "Good"
	end
	return "Miss"
end

-- How many takes this film has opened by `now`: one at each quarter of the shoot (25%, 50%, 75%).
-- Clapping and Golden Hour move the end closer, so takes open sooner too. None once it has wrapped.
function Takes.opened(startTime: number, endTime: number, now: number): number
	if now >= endTime then
		return 0
	end
	local progress = (now - startTime) / math.max(1, endTime - startTime)
	return math.clamp(math.floor(progress * (Takes.PerFilm + 1)), 0, Takes.PerFilm)
end

-- Takes waiting to be played on a film (`takes` is the list of verdicts so far, nil for none).
function Takes.waiting(takes: { string }?, startTime: number, endTime: number, now: number): number
	return math.max(0, Takes.opened(startTime, endTime, now) - Takes.count(takes))
end

-- Verdicts recorded on a film; tolerates a missing or malformed save field.
function Takes.count(takes: any): number
	if type(takes) ~= "table" then
		return 0
	end
	return math.min(#takes, Takes.PerFilm)
end

-- Premiere Luck from a film's takes: only known verdicts, only the first PerFilm, never past MaxLuck.
function Takes.luck(takes: any): number
	if type(takes) ~= "table" then
		return 0
	end
	local total = 0
	for index = 1, math.min(#takes, Takes.PerFilm) do
		local bonus = Takes.Luck[takes[index]]
		if type(bonus) == "number" then
			total += bonus
		end
	end
	return math.min(total, Takes.MaxLuck)
end

-- The verdict's words on the card.
function Takes.verdictText(verdict: string): string
	if verdict == "Perfect" then
		return "PERFECT TAKE!"
	elseif verdict == "Good" then
		return "GOOD TAKE!"
	end
	return "MISSED IT!"
end

return Takes
